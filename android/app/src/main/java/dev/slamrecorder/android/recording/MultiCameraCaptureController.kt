package dev.slamrecorder.android.recording

import android.content.Context
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.media.MediaRecorder
import android.os.Handler
import android.os.HandlerThread
import android.view.Surface
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.io.File
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
    )

    suspend fun start(cameras: List<CamSpec>): Boolean {
        if (cameras.isEmpty()) return false
        if (cameras.size > 2) error("Only up to 2 cameras supported")
        return withContext(Dispatchers.IO) {
            stopped.set(false)
            handlerThread.start()
            val handler = Handler(handlerThread.looper)
            try {
                for (spec in cameras) {
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
                true
            } catch (t: Throwable) {
                stop()
                false
            }
        }
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
}
