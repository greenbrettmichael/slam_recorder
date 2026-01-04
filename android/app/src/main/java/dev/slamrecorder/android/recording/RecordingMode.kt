package dev.slamrecorder.android.recording

/**
 * Recording modes supported by the SLAM recorder application.
 *
 * @property label User-facing display label for the mode
 */
enum class RecordingMode(val label: String) {
    /** ARCore-based recording with pose tracking and single camera video */
    AR_CORE("ARCore"),

    /** Multi-camera simultaneous recording (up to 2 cameras) without AR tracking */
    MULTI_CAMERA("Multi-camera"),
}
