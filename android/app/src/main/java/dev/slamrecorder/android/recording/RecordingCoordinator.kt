package dev.slamrecorder.android.recording

import android.content.Context
import android.hardware.SensorManager
import android.net.Uri
import androidx.core.content.FileProvider
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.withContext
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

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

    sealed interface ExportResult {
        data class Success(val uri: Uri) : ExportResult

        data class Failure(val message: String) : ExportResult
    }

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
