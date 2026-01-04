package dev.slamrecorder.android.recording

import android.content.Context
import android.hardware.SensorManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.withContext

class RecordingCoordinator(
    private val context: Context,
    private val sensorManager: SensorManager,
) {
    data class Result(val success: Boolean, val message: String? = null)

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    private var sessionFiles: SessionFiles? = null
    private var imuRecorder: ImuRecorder? = null
    private var poseRecorder: ArCorePoseRecorder? = null
    private var videoCapture: VideoCaptureController? = null
    private var previewSurfaceProvider: androidx.camera.core.Preview.SurfaceProvider? = null

    suspend fun start(mode: RecordingMode): Result =
        withContext(Dispatchers.Default) {
            if (sessionFiles != null) return@withContext Result(false, "Recording already in progress")

            val files = SessionFiles.create(context)
            val imuWriter = CsvBufferedWriter(files.imuFile, listOf("timestamp", "x", "y", "z", "type"))

            imuRecorder = ImuRecorder(sensorManager, imuWriter, scope).also { it.start() }

            var arMessage: String? = null
            if (mode == RecordingMode.AR_CORE) {
                val poseWriter = CsvBufferedWriter(files.poseFile, listOf("timestamp", "px", "py", "pz", "qx", "qy", "qz", "qw"))
                val recorder = ArCorePoseRecorder(context, poseWriter, scope)
                val arResult = recorder.start()
                if (arResult.success.not()) {
                    arMessage = arResult.message
                    recorder.stop()
                }
                poseRecorder = recorder
            }

            videoCapture = VideoCaptureController(context)
            val videoStartNanos = videoCapture?.start(files.videoFile, previewSurfaceProvider) ?: 0L
            files.videoStartFile.writeText(videoStartNanos.toString())

            sessionFiles = files
            Result(true, arMessage)
        }

    fun stop(): Result {
        imuRecorder?.stop()
        poseRecorder?.stop()
        videoCapture?.stop()
        sessionFiles = null
        imuRecorder = null
        poseRecorder = null
        videoCapture = null
        return Result(true)
    }

    fun updatePreviewSurfaceProvider(provider: androidx.camera.core.Preview.SurfaceProvider?) {
        previewSurfaceProvider = provider
    }
}
