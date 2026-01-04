package dev.slamrecorder.android.recording

import android.hardware.camera2.CameraManager
import io.mockk.mockk

internal class FakeSupportChecker(
    private val supported: Boolean,
) : MultiCamSupportChecker(mockk<CameraManager>(relaxed = true)) {
    override fun isSupported(): Boolean = supported
}

internal class FakeCameraEnumerator(
    private val ids: List<String> = emptyList(),
) : CameraEnumerator(mockk(relaxed = true)) {
    override fun listCameraOptions(): List<CameraOption> =
        ids.map { id ->
            CameraOption(
                id = id,
                facing = null,
                isLogical = false,
                physicalIds = emptySet(),
                parentLogicalCameraId = null,
                focalLength = null,
            )
        }
}
