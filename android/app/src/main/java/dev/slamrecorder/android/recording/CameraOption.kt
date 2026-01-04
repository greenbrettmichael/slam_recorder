package dev.slamrecorder.android.recording

import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager

/** Represents a single selectable camera (physical or logical). */
data class CameraOption(
    val id: String,
    val facing: Int?,
    val isLogical: Boolean,
    val physicalIds: Set<String>,
) {
    val label: String
        get() {
            val facingLabel = when (facing) {
                CameraCharacteristics.LENS_FACING_FRONT -> "Front"
                CameraCharacteristics.LENS_FACING_BACK -> "Back"
                CameraCharacteristics.LENS_FACING_EXTERNAL -> "External"
                else -> "Unknown"
            }
            return if (isLogical && physicalIds.isNotEmpty()) {
                "$facingLabel (logical: ${physicalIds.joinToString(",")})"
            } else {
                "$facingLabel ($id)"
            }
        }
}

/** Enumerates available cameras and exposes logical/physical relationships. */
class CameraEnumerator(private val cameraManager: CameraManager) {
    fun listCameraOptions(): List<CameraOption> {
        return cameraManager.cameraIdList.mapNotNull { id ->
            val chars = runCatching { cameraManager.getCameraCharacteristics(id) }.getOrNull() ?: return@mapNotNull null
            val facing = chars.get(CameraCharacteristics.LENS_FACING)
            val physicalIds = chars.physicalCameraIds
            val isLogical = physicalIds.isNotEmpty()
            CameraOption(
                id = id,
                facing = facing,
                isLogical = isLogical,
                physicalIds = physicalIds,
            )
        }
    }
}
