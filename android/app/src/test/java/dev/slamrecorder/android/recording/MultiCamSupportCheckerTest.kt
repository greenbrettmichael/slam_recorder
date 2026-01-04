package dev.slamrecorder.android.recording

import android.hardware.camera2.CameraCharacteristics
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MultiCamSupportCheckerTest {
    @Test
    fun `detects logical multi-camera capability`() {
        val capabilities =
            intArrayOf(
                CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_BACKWARD_COMPATIBLE,
                CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_LOGICAL_MULTI_CAMERA,
            )

        assertTrue(hasLogicalMultiCamera(capabilities))
    }

    @Test
    fun `returns false when capability absent`() {
        val capabilities =
            intArrayOf(
                CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_BACKWARD_COMPATIBLE,
            )

        assertFalse(hasLogicalMultiCamera(capabilities))
        assertFalse(hasLogicalMultiCamera(null))
    }

    @Test
    fun `view model blocks unsupported multi-camera selection`() {
        val viewModel =
            RecordingViewModel(
                FakeSupportChecker(supported = false),
                FakeCameraEnumerator(),
                coordinator = null,
            )

        viewModel.selectMode(RecordingMode.MULTI_CAMERA)

        assertEquals(RecordingMode.AR_CORE, viewModel.uiState.value.selectedMode)
        assertFalse(viewModel.uiState.value.multiCamSupported)
    }

    @Test
    fun `view model allows multi-camera when supported`() {
        val viewModel =
            RecordingViewModel(
                FakeSupportChecker(supported = true),
                FakeCameraEnumerator(),
                coordinator = null,
            )

        viewModel.selectMode(RecordingMode.MULTI_CAMERA)

        assertEquals(RecordingMode.MULTI_CAMERA, viewModel.uiState.value.selectedMode)
        assertTrue(viewModel.uiState.value.multiCamSupported)
    }
}
