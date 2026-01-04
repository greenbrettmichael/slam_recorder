package dev.slamrecorder.android.recording

import android.view.Surface
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

private const val MULTI_CAM_UNSUPPORTED = "Multi-camera not supported on this device"

/**
 * UI state for the recording screen.
 *
 * @property selectedMode Current recording mode
 * @property isRecording Whether a recording is in progress
 * @property multiCamSupported Whether the device supports multi-camera recording
 * @property supportMessage Error message if mode is unsupported
 * @property statusMessage General status message (e.g., ARCore warnings)
 * @property availableCameras List of available camera options
 * @property selectedCameraIds Set of selected camera IDs for multi-camera mode
 */
data class RecorderUiState(
    val selectedMode: RecordingMode = RecordingMode.AR_CORE,
    val isRecording: Boolean = false,
    val multiCamSupported: Boolean = false,
    val supportMessage: String = "",
    val statusMessage: String = "",
    val availableCameras: List<CameraOption> = emptyList(),
    val selectedCameraIds: Set<String> = emptySet(),
)

/**
 * ViewModel for the recording screen.
 *
 * Manages UI state, recording lifecycle, and camera selection. Exposes state as a
 * StateFlow and provides methods for user interactions.
 *
 * @property supportChecker Multi-camera capability checker
 * @property cameraEnumerator Camera discovery and enumeration
 * @property coordinator Recording session coordinator
 */
class RecordingViewModel(
    private val supportChecker: MultiCamSupportChecker,
    private val cameraEnumerator: CameraEnumerator,
    private val coordinator: RecordingCoordinator?,
) : ViewModel() {
    private val _uiState = MutableStateFlow(RecorderUiState())
    val uiState: StateFlow<RecorderUiState> = _uiState.asStateFlow()

    init {
        refreshMultiCameraSupport()
        refreshCameraList()
    }

    /** Checks multi-camera support and updates UI state accordingly */
    fun refreshMultiCameraSupport() {
        val supported = supportChecker.isSupported()
        _uiState.update { state ->
            state.copy(
                multiCamSupported = supported,
                supportMessage = if (supported) "" else MULTI_CAM_UNSUPPORTED,
                selectedMode = if (supported) state.selectedMode else RecordingMode.AR_CORE,
            )
        }
    }

    /** Enumerates available cameras and updates UI state */
    fun refreshCameraList() {
        val cams = cameraEnumerator.listCameraOptions()
        _uiState.update { state ->
            state.copy(
                availableCameras = cams,
                // Default to first back camera if nothing selected
                selectedCameraIds = if (state.selectedCameraIds.isEmpty() && cams.isNotEmpty()) {
                    setOf(cams.first().id)
                } else {
                    state.selectedCameraIds
                },
            )
        }
    }

    /**
     * Toggles camera selection for multi-camera mode.
     *
     * Maximum 2 cameras can be selected simultaneously.
     *
     * @param id Camera ID to toggle
     */
    fun toggleCameraSelection(id: String) {
        _uiState.update { state ->
            val current = state.selectedCameraIds
            val next =
                if (current.contains(id)) {
                    current - id
                } else {
                    if (current.size >= 2) current else current + id
                }
            state.copy(selectedCameraIds = next)
        }
    }

    /** Updates the preview surface provider for single-camera recording */
    fun setPreviewSurfaceProvider(provider: androidx.camera.core.Preview.SurfaceProvider?) {
        coordinator?.updatePreviewSurfaceProvider(provider)
    }

    /** Updates a preview surface for multi-camera recording */
    fun setMultiPreviewSurface(cameraId: String, surface: android.view.Surface?) {
        coordinator?.updateMultiPreviewSurface(cameraId, surface)
    }

    /**
     * Selects a recording mode.
     *
     * Validates that multi-camera mode is supported before allowing selection.
     *
     * @param mode The mode to select
     */
    fun selectMode(mode: RecordingMode) {
        _uiState.update { state ->
            if (mode == RecordingMode.MULTI_CAMERA && !state.multiCamSupported) {
                state.copy(supportMessage = MULTI_CAM_UNSUPPORTED)
            } else {
                state.copy(selectedMode = mode, supportMessage = "")
            }
        }
    }

    /** Toggles recording on/off based on current state */
    fun toggleRecording() {
        val currentlyRecording = _uiState.value.isRecording
        if (currentlyRecording) {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private fun startRecording() {
        viewModelScope.launch {
            val mode = _uiState.value.selectedMode
            val selected = _uiState.value.selectedCameraIds.toList()
            val result = coordinator?.start(mode, selected)
            _uiState.update { state ->
                state.copy(
                    isRecording = true,
                    statusMessage = result?.message.orEmpty(),
                )
            }
        }
    }

    private fun stopRecording() {
        viewModelScope.launch {
            coordinator?.stop()
            _uiState.update { state ->
                state.copy(isRecording = false)
            }
        }
    }
}
