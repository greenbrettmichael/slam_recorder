package dev.slamrecorder.android.recording

import android.content.Context
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

internal const val SESSION_PREFIX = "session_"

/**
 * Container for all files in a recording session.
 *
 * Creates a timestamped directory and provides paths for IMU data,
 * ARCore poses, video files, and timing metadata.
 *
 * @property root Session root directory
 * @property imuFile IMU sensor data CSV (accelerometer + gyroscope)
 * @property poseFile ARCore pose tracking CSV (position + orientation)
 * @property videoFile Primary video file (single-camera or ARCore mode)
 * @property videoStartFile Video start timestamp file (nanoseconds)
 */
data class SessionFiles(
    val root: File,
    val imuFile: File,
    val poseFile: File,
    val videoFile: File,
    val videoStartFile: File,
) {
    companion object {
        /**
         * Creates a new session directory with timestamp.
         *
         * Directory format: session_yyyy-MM-dd_HH-mm-ss-SSS
         *
         * @param context Application context for file system access
         * @return SessionFiles instance with all file paths initialized
         */
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
     * Generates a video file path for a specific camera ID.
     *
     * Used in multi-camera mode to create separate video files per camera.
     *
     * @param cameraId Camera identifier
     * @return File path for this camera's video
     */
    fun videoFileForCamera(cameraId: String): File = File(root, "video_$cameraId.mp4")

    /**
     * Generates a video start timestamp file path for a specific camera ID.
     *
     * @param cameraId Camera identifier
     * @return File path for this camera's timestamp metadata
     */
    fun videoStartFileForCamera(cameraId: String): File = File(root, "video_start_time_$cameraId.txt")
}
