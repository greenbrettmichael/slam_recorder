package dev.slamrecorder.android.recording

import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager

/** Represents a single selectable camera (physical or logical). */
data class CameraOption(
    val id: String,
    val facing: Int?,
    val isLogical: Boolean,
    val physicalIds: Set<String>,
    val parentLogicalCameraId: String? = null,
    val focalLength: Float? = null,
) {
    val label: String
        get() {
            val facingLabel = when (facing) {
                CameraCharacteristics.LENS_FACING_FRONT -> "Front"
                CameraCharacteristics.LENS_FACING_BACK -> "Back"
                CameraCharacteristics.LENS_FACING_EXTERNAL -> "External"
                else -> "Unknown"
            }
            
            val typeHint = focalLength?.let { fl ->
                when {
                    fl < 3.0f -> "Ultra-wide"
                    fl < 5.0f -> "Wide"
                    fl < 8.0f -> "Standard"
                    else -> "Telephoto"
                }
            }
            
            return if (isLogical && physicalIds.isNotEmpty()) {
                "$facingLabel Logical (${physicalIds.size} cameras)"
            } else if (parentLogicalCameraId != null && typeHint != null) {
                "$facingLabel $typeHint"
            } else if (parentLogicalCameraId != null) {
                "$facingLabel Physical $id"
            } else {
                "$facingLabel Camera $id"
            }
        }
}

/** Enumerates available cameras and exposes logical/physical relationships. */
open class CameraEnumerator(private val cameraManager: CameraManager) {
    open fun listCameraOptions(): List<CameraOption> {
        val options = mutableListOf<CameraOption>()
        val seenIds = mutableSetOf<String>()
        
        // Enumerate all logical cameras and their physical sub-cameras
        cameraManager.cameraIdList.forEach { id ->
            val chars = runCatching { cameraManager.getCameraCharacteristics(id) }.getOrNull() ?: return@forEach
            val facing = chars.get(CameraCharacteristics.LENS_FACING)
            val physicalIds = chars.physicalCameraIds
            val isLogical = physicalIds.isNotEmpty()
            val focalLengths = chars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
            val focalLength = focalLengths?.firstOrNull()
            
            // Only add logical camera if it has no physical sub-cameras
            // Otherwise, we'll expose the physical cameras instead
            if (!isLogical) {
                options.add(
                    CameraOption(
                        id = id,
                        facing = facing,
                        isLogical = false,
                        physicalIds = emptySet(),
                        parentLogicalCameraId = null,
                        focalLength = focalLength,
                    )
                )
                seenIds.add(id)
            } else {
                // For logical cameras, expose each physical camera as accessible through parent
                physicalIds.forEach { physicalId ->
                    if (!seenIds.contains(physicalId)) {
                        val physicalChars = runCatching { 
                            cameraManager.getCameraCharacteristics(physicalId) 
                        }.getOrNull()
                        val physicalFacing = physicalChars?.get(CameraCharacteristics.LENS_FACING)
                        val physicalFocalLengths = physicalChars?.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
                        val physicalFocalLength = physicalFocalLengths?.firstOrNull()
                        options.add(
                            CameraOption(
                                id = physicalId,
                                facing = physicalFacing,
                                isLogical = false,
                                physicalIds = emptySet(),
                                parentLogicalCameraId = id,
                                focalLength = physicalFocalLength,
                            )
                        )
                        seenIds.add(physicalId)
                    }
                }
            }
        }
        
        return options
    }
}
