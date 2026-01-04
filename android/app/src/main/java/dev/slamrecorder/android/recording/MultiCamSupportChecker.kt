package dev.slamrecorder.android.recording

import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager

open class MultiCamSupportChecker(
    private val cameraManager: CameraManager,
) {
    open fun isSupported(): Boolean {
        return cameraManager.cameraIdList.any { id ->
            val characteristics = cameraManager.getCameraCharacteristics(id)
            val capabilities = characteristics.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES)
            hasLogicalMultiCamera(capabilities)
        }
    }
}

internal fun hasLogicalMultiCamera(capabilities: IntArray?): Boolean {
    return capabilities?.any { it == CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_LOGICAL_MULTI_CAMERA } ?: false
}
