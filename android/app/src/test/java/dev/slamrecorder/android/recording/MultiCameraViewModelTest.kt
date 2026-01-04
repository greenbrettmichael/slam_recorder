package dev.slamrecorder.android.recording

import android.hardware.camera2.CameraManager
import android.view.Surface
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class MultiCameraViewModelTest {
    private val dispatcher = StandardTestDispatcher()

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `caps selection at two cameras`() = runTest {
        val viewModel =
            RecordingViewModel(
                supportChecker = FakeSupportChecker(true),
                cameraEnumerator = FakeCameraEnumerator(listOf("0", "1", "2")),
                coordinator = null,
            )

        // Default selection takes the first camera
        assertEquals(setOf("0"), viewModel.uiState.value.selectedCameraIds)

        viewModel.toggleCameraSelection("1")
        viewModel.toggleCameraSelection("2")

        assertEquals(setOf("0", "1"), viewModel.uiState.value.selectedCameraIds)
    }

    @Test
    fun `forwards preview surface updates to coordinator`() {
        val coordinator = mockk<RecordingCoordinator>(relaxed = true)
        val surface = mockk<Surface>(relaxed = true)
        val viewModel =
            RecordingViewModel(
                supportChecker = FakeSupportChecker(true),
                cameraEnumerator = FakeCameraEnumerator(),
                coordinator = coordinator,
            )

        viewModel.setMultiPreviewSurface("camA", surface)

        verify { coordinator.updateMultiPreviewSurface("camA", surface) }
    }

    @Test
    fun `starts multi-camera recording with selected ids`() = runTest {
        val coordinator = mockk<RecordingCoordinator>(relaxed = true)
        coEvery { coordinator.start(any(), any()) } returns RecordingCoordinator.Result(success = true)

        val viewModel =
            RecordingViewModel(
                supportChecker = FakeSupportChecker(true),
                cameraEnumerator = FakeCameraEnumerator(listOf("0", "1")),
                coordinator = coordinator,
            )

        viewModel.selectMode(RecordingMode.MULTI_CAMERA)
        viewModel.toggleCameraSelection("1")
        viewModel.toggleRecording()
        dispatcher.scheduler.advanceUntilIdle()

        coVerify {
            coordinator.start(
                RecordingMode.MULTI_CAMERA,
                match { ids -> ids.size == 2 && ids.containsAll(listOf("0", "1")) },
            )
        }
        assertTrue(viewModel.uiState.value.isRecording)
    }
}
