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
            val infos = mutableListOf<CameraInfo>()

            cameraManager.cameraIdList.forEach { id ->
                val chars = runCatching { cameraManager.getCameraCharacteristics(id) }.getOrNull() ?: return@forEach
                val facing = chars.get(CameraCharacteristics.LENS_FACING)
                val physicalIds = chars.physicalCameraIds
                val focalLengths = chars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
                val focalLength = focalLengths?.firstOrNull()

                infos.add(
                    CameraInfo(
                        id = id,
                        facing = facing,
                        physicalIds = physicalIds,
                        focalLength = focalLength,
                    ),
                )
            }

            return buildCameraOptions(infos)
    }
}

    data class CameraInfo(
        val id: String,
        val facing: Int?,
        val physicalIds: Set<String>,
        val focalLength: Float?,
    )

    internal fun buildCameraOptions(infos: List<CameraInfo>): List<CameraOption> {
        val options = mutableListOf<CameraOption>()
        val seenKeys = mutableSetOf<String>()
        val physicalChildIds = infos.flatMapTo(mutableSetOf()) { it.physicalIds }

        infos.forEach { info ->
            val isLogical = info.physicalIds.isNotEmpty()

            if (!isLogical) {
                if (info.id in physicalChildIds) return@forEach

                options.add(
                    CameraOption(
                        id = info.id,
                        facing = info.facing,
                        isLogical = false,
                        physicalIds = emptySet(),
                        parentLogicalCameraId = null,
                        focalLength = info.focalLength,
                    ),
                )
                seenKeys.add(keyFor(info.facing, info.focalLength, parentId = null))
            } else {
                info.physicalIds.forEach { physicalId ->
                    val physicalInfo = infos.find { it.id == physicalId }
                    val physicalFacing = physicalInfo?.facing
                    val physicalFocal = physicalInfo?.focalLength
                    val key = keyFor(physicalFacing, physicalFocal, parentId = info.id)
                    if (seenKeys.add(key)) {
                        options.add(
                            CameraOption(
                                id = physicalId,
                                facing = physicalFacing,
                                isLogical = false,
                                physicalIds = emptySet(),
                                parentLogicalCameraId = info.id,
                                focalLength = physicalFocal,
                            ),
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
