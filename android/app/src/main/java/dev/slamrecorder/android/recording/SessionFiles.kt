package dev.slamrecorder.android.recording

import android.content.Context
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

internal const val SESSION_PREFIX = "session_"

data class SessionFiles(
    val root: File,
    val imuFile: File,
    val poseFile: File,
    val videoFile: File,
    val videoStartFile: File,
) {
    companion object {
        fun create(context: Context): SessionFiles {
            val sessionsRoot = context.getExternalFilesDir(null) ?: context.filesDir
            val folderName = SESSION_PREFIX + SimpleDateFormat("yyyy-MM-dd_HH-mm-ss-SSS", Locale.US).format(Date())
            val root = File(sessionsRoot, folderName).also { it.mkdirs() }
            return SessionFiles(
                root = root,
                imuFile = File(root, "imu_data.csv"),
                poseFile = File(root, "arcore_groundtruth.csv"),
                videoFile = File(root, "video.mp4"),
                videoStartFile = File(root, "video_start_time.txt"),
            )
        }
    }

    /**
     * Helper for multi-camera: builds a deterministic file name per camera id.
     */
    fun videoFileForCamera(cameraId: String): File = File(root, "video_$cameraId.mp4")

    fun videoStartFileForCamera(cameraId: String): File = File(root, "video_start_time_$cameraId.txt")
}
