package dev.slamrecorder.android.recording

import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager

/**
 * Represents a selectable camera option (physical or logical) for recording.
 *
 * Physical cameras are individual camera sensors, while logical cameras combine
 * multiple physical cameras. This class provides metadata for camera selection UI.
 *
 * @property id Camera identifier from Camera2 API
 * @property facing Camera facing direction (LENS_FACING_FRONT, LENS_FACING_BACK, etc.)
 * @property isLogical Whether this is a logical multi-camera
 * @property physicalIds Set of physical camera IDs for logical cameras
 * @property parentLogicalCameraId Parent logical camera ID if this is a physical sub-camera
 * @property focalLength Primary focal length in millimeters
 */
data class CameraOption(
    val id: String,
    val facing: Int?,
    val isLogical: Boolean,
    val physicalIds: Set<String>,
    val parentLogicalCameraId: String? = null,
    val focalLength: Float? = null,
) {
    /**
     * Human-readable label for UI display.
     *
     * Generates descriptive labels based on facing direction, focal length,
     * and whether the camera is physical or logical.
     */
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

/**
 * Enumerates available cameras and exposes logical/physical camera relationships.
 *
 * For devices with logical multi-cameras, this class exposes the individual physical
 * cameras rather than the logical camera itself. Implements deduplication based on
 * facing direction and focal length to avoid showing duplicate physical cameras.
 *
 * @property cameraManager Camera2 API manager
 */
open class CameraEnumerator(private val cameraManager: CameraManager) {
    /**
     * Lists all available camera options for selection.
     *
     * For logical cameras with physical sub-cameras, only the physical cameras are returned.
     * Deduplicates cameras with identical facing direction and focal length within the same
     * logical camera group.
     *
     * @return List of selectable camera options
     */
    open fun listCameraOptions(): List<CameraOption> {
        val options = mutableListOf<CameraOption>()
        val seenKeys = mutableSetOf<String>()
        
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
                seenKeys.add(keyFor(facing, focalLength, parentId = null))
            } else {
                // For logical cameras, expose each physical camera as accessible through parent
                physicalIds.forEach { physicalId ->
                    val physicalChars = runCatching { 
                        cameraManager.getCameraCharacteristics(physicalId) 
                    }.getOrNull()
                    val physicalFacing = physicalChars?.get(CameraCharacteristics.LENS_FACING)
                    val physicalFocalLengths = physicalChars?.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
                    val physicalFocalLength = physicalFocalLengths?.firstOrNull()
                    val key = keyFor(physicalFacing, physicalFocalLength, parentId = id)
                    if (seenKeys.add(key)) {
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
                    }
                }
            }
        }
        
        return options
    }

    private fun keyFor(facing: Int?, focalLength: Float?, parentId: String?): String {
        val roundedFocal = focalLength?.let { kotlin.math.round(it * 10) / 10f } ?: -1f
        return "${parentId ?: "root"}-$facing-$roundedFocal"
    }
}
