package dev.slamrecorder.android.recording

import android.content.Context
import android.hardware.SensorManager
import android.net.Uri
import android.os.SystemClock
import android.view.Surface
import androidx.core.content.FileProvider
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/**
 * Coordinates all recording activities including IMU, video, and ARCore pose tracking.
 *
 * Manages the lifecycle of recording sessions, handles multi-camera vs single-camera modes,
 * and provides session export functionality. Implements camera warmup delays to ensure
 * stable focus and exposure before recording begins.
 *
 * @property context Application context for file access and system services
 * @property sensorManager System sensor manager for IMU data
 * @property cameraManager Camera2 API manager for multi-camera support
 * @property cameraEnumerator Camera discovery and enumeration utility
 */
class RecordingCoordinator(
    private val context: Context,
    private val sensorManager: SensorManager,
    private val cameraManager: android.hardware.camera2.CameraManager,
    private val cameraEnumerator: CameraEnumerator,
) {
    /**
     * Result of a recording operation.
     *
     * @property success Whether the operation succeeded
     * @property message Optional error or status message
     */
    data class Result(val success: Boolean, val message: String? = null)

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    private var sessionFiles: SessionFiles? = null
    private var imuRecorder: ImuRecorder? = null
    private var arCoreRecorder: SimpleArCoreRecorder? = null
    private var videoCapture: VideoCaptureController? = null
    private var multiCameraCapture: MultiCameraCaptureController? = null
    private var previewSurfaceProvider: androidx.camera.core.Preview.SurfaceProvider? = null
    private val multiPreviewSurfaces: MutableMap<String, Surface?> = mutableMapOf()

    /** Result of a session export operation */
    sealed interface ExportResult {
        data class Success(val uri: Uri) : ExportResult

        data class Failure(val message: String) : ExportResult
    }

    /**
     * Starts a recording session.
     *
     * Creates a new session directory, initializes IMU recording, and starts video/ARCore
     * recording based on the selected mode. Implements a 1.5s warmup delay to allow camera
     * autofocus and auto-exposure to stabilize before recording.
     *
     * @param mode Recording mode (ARCore or multi-camera)
     * @param selectedCameraIds Camera IDs to record (for multi-camera mode only)
     * @return Result indicating success/failure and optional status message
     */
    suspend fun start(
        mode: RecordingMode,
        selectedCameraIds: List<String> = emptyList(),
    ): Result =
        withContext(Dispatchers.Default) {
            if (sessionFiles != null) return@withContext Result(false, "Recording already in progress")

            val files = SessionFiles.create(context)
            val imuWriter = CsvBufferedWriter(files.imuFile, listOf("timestamp", "x", "y", "z", "type"))

            imuRecorder = ImuRecorder(sensorManager, imuWriter, scope).also { it.start() }

            var arMessage: String? = null
            if (mode == RecordingMode.AR_CORE) {
                val poseWriter = CsvBufferedWriter(files.poseFile, listOf("timestamp", "px", "py", "pz", "qx", "qy", "qz", "qw"))
                val recorder = SimpleArCoreRecorder(context, poseWriter, scope)
                val arResult = recorder.start()
                if (!arResult.success) {
                    arMessage = arResult.message
                    recorder.stop()
                } else {
                    arCoreRecorder = recorder
                }
            }

            // Start video capture for all modes except multi-camera
            if (mode != RecordingMode.MULTI_CAMERA) {
                // Warmup delay: let camera stabilize focus/exposure
                kotlinx.coroutines.delay(1500)
                
                videoCapture = VideoCaptureController(context)
                val videoStartNanos = videoCapture?.start(files.videoFile, previewSurfaceProvider) ?: 0L
                files.videoStartFile.writeText(videoStartNanos.toString())
            }

            if (mode == RecordingMode.MULTI_CAMERA) {
                // Multi-camera: record up to two cameras simultaneously
                val ids = selectedCameraIds.take(2)
                if (ids.isEmpty()) {
                    return@withContext Result(false, "No cameras selected")
                }
                
                // Look up camera options to determine if we need physical camera handling
                val allOptions = cameraEnumerator.listCameraOptions()
                val selectedOptions = ids.mapNotNull { id -> allOptions.find { opt -> opt.id == id } }
                
                // Warmup delay: let cameras stabilize focus/exposure
                kotlinx.coroutines.delay(1500)
                
                val multi = MultiCameraCaptureController(context, cameraManager)
                multiCameraCapture = multi
                val camFiles = selectedOptions.map { option ->
                    MultiCameraCaptureController.CamSpec(
                        cameraId = option.id,
                        outputFile = files.videoFileForCamera(option.id),
                        previewSurface = multiPreviewSurfaces[option.id],
                        parentLogicalCameraId = option.parentLogicalCameraId,
                    )
                }
                val sharedStart = SystemClock.elapsedRealtimeNanos()
                val started = multi.start(camFiles)
                if (!started) {
                    multi.stop()
                    return@withContext Result(false, "Failed to start multi-camera recording")
                }
                files.videoStartFile.writeText(sharedStart.toString())
            }

            sessionFiles = files
            Result(true, arMessage)
        }

    /**
     * Stops the current recording session.
     *
     * Stops all active recorders (IMU, video, multi-camera, ARCore) and flushes data to disk.
     * Safe to call even if no recording is in progress.
     *
     * @return Result indicating successful stop
     */
    fun stop(): Result {
        imuRecorder?.stop()
        videoCapture?.stop()
        multiCameraCapture?.stop()
        sessionFiles = null
        imuRecorder = null
        videoCapture = null
        multiCameraCapture = null
        
        // Stop ARCore recorder in a coroutine since it's suspend
        val toStop = arCoreRecorder
        arCoreRecorder = null
        if (toStop != null) {
            scope.launch {
                toStop.stop()
            }
        }
        
        return Result(true)
    }

    /**
     * Updates the CameraX preview surface provider for single-camera video recording.
     *
     * @param provider CameraX surface provider from the preview composable
     */
    fun updatePreviewSurfaceProvider(provider: androidx.camera.core.Preview.SurfaceProvider?) {
        android.util.Log.i("RecordingCoordinator", "Preview surface provider updated: ${if (provider != null) "READY" else "NULL"}")
        previewSurfaceProvider = provider
    }

    /**
     * Updates a preview surface for multi-camera recording.
     *
     * @param cameraId The camera ID to associate with this surface
     * @param surface The preview surface or null to clear
     */
    fun updateMultiPreviewSurface(cameraId: String, surface: Surface?) {
        multiPreviewSurfaces[cameraId] = surface
    }

    /**
     * Exports the most recent recording session as a ZIP file.
     *
     * Finds the latest session directory by modification time, zips all files,
     * and returns a shareable content URI.
     *
     * @return ExportResult.Success with URI or ExportResult.Failure with error message
     */
    suspend fun exportLatest(): ExportResult =
        withContext(Dispatchers.IO) {
            val sessionsRoot = context.getExternalFilesDir(null) ?: context.filesDir
            val latest =
                sessionsRoot
                    ?.listFiles { file -> file.isDirectory && file.name.startsWith(SESSION_PREFIX) }
                    ?.maxByOrNull { it.lastModified() }
            if (latest == null) {
                return@withContext ExportResult.Failure("No sessions found")
            }

            val zipFile = File(context.cacheDir, "latest_session.zip")
            if (zipFile.exists()) zipFile.delete()
            zipDirectory(latest, zipFile)

            val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", zipFile)
            ExportResult.Success(uri)
        }

    private fun zipDirectory(
        sourceDir: File,
        destination: File,
    ) {
        ZipOutputStream(BufferedOutputStream(FileOutputStream(destination))).use { zos ->
            sourceDir.walkTopDown().filter { it.isFile }.forEach { file ->
                val entryName = sourceDir.toPath().relativize(file.toPath()).toString()
                zos.putNextEntry(ZipEntry(entryName))
                BufferedInputStream(FileInputStream(file)).use { input ->
                    input.copyTo(zos)
                }
                zos.closeEntry()
            }
        }
    }
}
