package dev.slamrecorder.android.recording

import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager

/**
 * Checks whether the device supports logical multi-camera functionality.
 *
 * Queries the Camera2 API to determine if any camera device has the
 * LOGICAL_MULTI_CAMERA capability, which is required for simultaneous
 * multi-camera recording.
 *
 * @property cameraManager Camera2 API manager
 */
open class MultiCamSupportChecker(
    private val cameraManager: CameraManager,
) {
    /**
     * Checks if the device supports logical multi-camera recording.
     *
     * @return true if at least one camera has LOGICAL_MULTI_CAMERA capability
     */
    open fun isSupported(): Boolean {
        return cameraManager.cameraIdList.any { id ->
            val characteristics = cameraManager.getCameraCharacteristics(id)
            val capabilities = characteristics.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES)
            hasLogicalMultiCamera(capabilities)
        }
    }
}

/**
 * Checks if a capabilities array contains LOGICAL_MULTI_CAMERA.
 *
 * @param capabilities Camera capabilities array from CameraCharacteristics
 * @return true if LOGICAL_MULTI_CAMERA capability is present
 */
internal fun hasLogicalMultiCamera(capabilities: IntArray?): Boolean {
    return capabilities?.any { it == CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_LOGICAL_MULTI_CAMERA } ?: false
}
