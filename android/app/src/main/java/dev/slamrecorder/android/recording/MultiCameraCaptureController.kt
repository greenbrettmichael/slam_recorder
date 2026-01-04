package dev.slamrecorder.android.recording

import android.content.Context
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.hardware.camera2.params.OutputConfiguration
import android.hardware.camera2.params.SessionConfiguration
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.view.Surface
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.io.File
import java.util.concurrent.Executor
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Simple dual-camera (max 2) recorder using Camera2 and MediaRecorder per camera.
 * Preview is not provided; goal is simultaneous recording to separate files.
 */
class MultiCameraCaptureController(
    private val context: Context,
    private val cameraManager: CameraManager,
) {
    private val handlerThread = HandlerThread("MultiCamThread")
    private val stopped = AtomicBoolean(false)

    private val cameraDevices = mutableListOf<CameraDevice>()
    private val captureSessions = mutableListOf<CameraCaptureSession>()
    private val recorders = mutableListOf<MediaRecorder>()

    data class CamSpec(
        val cameraId: String,
        val outputFile: File,
        val previewSurface: Surface? = null,
        val parentLogicalCameraId: String? = null,
    )

    suspend fun start(cameras: List<CamSpec>): Boolean {
        if (cameras.isEmpty()) return false
        if (cameras.size > 2) error("Only up to 2 cameras supported")
        return withContext(Dispatchers.IO) {
            stopped.set(false)
            handlerThread.start()
            val handler = Handler(handlerThread.looper)
            try {
                // Separate cameras with no parent (independent) from those with parents (physical)
                val independentCameras = cameras.filter { it.parentLogicalCameraId == null }
                val physicalCameras = cameras.filter { it.parentLogicalCameraId != null }
                
                // Start each independent camera separately
                independentCameras.forEach { spec ->
                    startSingleCamera(spec, handler)
                }
                
                // Group physical cameras by their parent logical camera
                // Only use physical camera API if multiple cameras share the same parent
                val physicalByParent = physicalCameras.groupBy { it.parentLogicalCameraId!! }
                physicalByParent.forEach { (parentId, specs) ->
                    if (specs.size > 1) {
                        // Multiple physical cameras from same parent - use physical camera API
                        startPhysicalCameras(specs, handler)
                    } else {
                        // Single physical camera - just open the parent as independent camera
                        val spec = specs[0]
                        startSingleCamera(spec.copy(cameraId = parentId), handler)
                    }
                }
                
                true
            } catch (t: Throwable) {
                android.util.Log.e("MultiCamCapture", "Failed to start cameras", t)
                stop()
                false
            }
        }
    }
    
    private suspend fun startSingleCamera(spec: CamSpec, handler: Handler) {
        val recorder = createRecorder(spec.outputFile)
        val recorderSurface = recorder.surface

        val camera = openCamera(spec.cameraId, handler)
        cameraDevices += camera

        val surfaces = buildList {
            add(recorderSurface)
            spec.previewSurface?.let { add(it) }
        }
        val session = createSession(camera, surfaces, handler)
        captureSessions += session

        val request = camera.createCaptureRequest(CameraDevice.TEMPLATE_RECORD).apply {
            addTarget(recorderSurface)
            spec.previewSurface?.let { addTarget(it) }
        }.build()
        session.setRepeatingRequest(request, null, handler)

        recorder.start()
        recorders += recorder
    }
    
    private suspend fun startPhysicalCameras(specs: List<CamSpec>, handler: Handler) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            error("Physical camera selection requires Android P+")
        }
        
        val parentId = specs[0].parentLogicalCameraId ?: error("No parent camera ID")
        val camera = openCamera(parentId, handler)
        cameraDevices += camera
        
        val outputConfigs = mutableListOf<OutputConfiguration>()
        val allSurfaces = mutableListOf<Surface>()
        
        specs.forEach { spec ->
            val recorder = createRecorder(spec.outputFile)
            val recorderSurface = recorder.surface
            
            val recorderConfig = OutputConfiguration(recorderSurface)
            recorderConfig.setPhysicalCameraId(spec.cameraId)
            outputConfigs.add(recorderConfig)
            allSurfaces.add(recorderSurface)
            
            spec.previewSurface?.let { previewSurface ->
                val previewConfig = OutputConfiguration(previewSurface)
                previewConfig.setPhysicalCameraId(spec.cameraId)
                outputConfigs.add(previewConfig)
                allSurfaces.add(previewSurface)
            }
            
            recorders += recorder
        }
        
        val session = createSessionWithPhysicalCameras(camera, outputConfigs, handler)
        captureSessions += session
        
        val request = camera.createCaptureRequest(CameraDevice.TEMPLATE_RECORD).apply {
            allSurfaces.forEach { addTarget(it) }
        }.build()
        session.setRepeatingRequest(request, null, handler)
        
        recorders.forEach { it.start() }
    }

    fun stop() {
        if (!stopped.compareAndSet(false, true)) return
        recorders.forEach { r ->
            runCatching {
                r.stop()
            }
            runCatching { r.reset() }
            runCatching { r.release() }
        }
        recorders.clear()

        captureSessions.forEach { s -> runCatching { s.close() } }
        captureSessions.clear()

        cameraDevices.forEach { d -> runCatching { d.close() } }
        cameraDevices.clear()

        runCatching { handlerThread.quitSafely() }
    }

    private fun createRecorder(outputFile: File): MediaRecorder {
        @Suppress("DEPRECATION")
        return MediaRecorder().apply {
            setVideoSource(MediaRecorder.VideoSource.SURFACE)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setOutputFile(outputFile.absolutePath)
            setVideoEncoder(MediaRecorder.VideoEncoder.H264)
            setVideoEncodingBitRate(10_000_000)
            setVideoFrameRate(30)
            setVideoSize(1920, 1080)
            prepare()
        }
    }

    private suspend fun openCamera(cameraId: String, handler: Handler): CameraDevice =
        suspendCancellableCoroutine { cont ->
            try {
                cameraManager.openCamera(cameraId, object : CameraDevice.StateCallback() {
                    override fun onOpened(camera: CameraDevice) {
                        if (cont.isActive) cont.resume(camera)
                    }

                    override fun onDisconnected(camera: CameraDevice) {
                        if (cont.isActive) cont.resumeWithException(IllegalStateException("Camera $cameraId disconnected"))
                        camera.close()
                    }

                    override fun onError(camera: CameraDevice, error: Int) {
                        if (cont.isActive) cont.resumeWithException(IllegalStateException("Camera $cameraId error $error"))
                        camera.close()
                    }
                }, handler)
            } catch (se: SecurityException) {
                cont.resumeWithException(se)
            }
        }

    private suspend fun createSession(
        camera: CameraDevice,
        surfaces: List<Surface>,
        handler: Handler,
    ): CameraCaptureSession = suspendCancellableCoroutine { cont ->
        camera.createCaptureSession(surfaces, object : CameraCaptureSession.StateCallback() {
            override fun onConfigured(session: CameraCaptureSession) {
                if (cont.isActive) cont.resume(session)
            }

            override fun onConfigureFailed(session: CameraCaptureSession) {
                if (cont.isActive) cont.resumeWithException(IllegalStateException("Session configure failed"))
            }
        }, handler)
    }
    
    private suspend fun createSessionWithPhysicalCameras(
        camera: CameraDevice,
        outputConfigs: List<OutputConfiguration>,
        handler: Handler,
    ): CameraCaptureSession = suspendCancellableCoroutine { cont ->
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val executor = Executor { it.run() }
            val sessionConfig = SessionConfiguration(
                SessionConfiguration.SESSION_REGULAR,
                outputConfigs,
                executor,
                object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(session: CameraCaptureSession) {
                        if (cont.isActive) cont.resume(session)
                    }

                    override fun onConfigureFailed(session: CameraCaptureSession) {
                        if (cont.isActive) cont.resumeWithException(IllegalStateException("Physical camera session configure failed"))
                    }
                }
            )
            camera.createCaptureSession(sessionConfig)
        } else {
            cont.resumeWithException(IllegalStateException("Physical camera support requires Android P+"))
        }
    }
}
