package dev.slamrecorder.android.recording

import androidx.lifecycle.ViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

private const val MULTI_CAM_UNSUPPORTED = "Multi-camera not supported on this device"

data class RecorderUiState(
    val selectedMode: RecordingMode = RecordingMode.AR_CORE,
    val isRecording: Boolean = false,
    val multiCamSupported: Boolean = false,
    val supportMessage: String = "",
)

class RecordingViewModel(
    private val supportChecker: MultiCamSupportChecker,
) : ViewModel() {
    private val _uiState = MutableStateFlow(RecorderUiState())
    val uiState: StateFlow<RecorderUiState> = _uiState.asStateFlow()

    init {
        refreshMultiCameraSupport()
    }

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

    fun selectMode(mode: RecordingMode) {
        _uiState.update { state ->
            if (mode == RecordingMode.MULTI_CAMERA && !state.multiCamSupported) {
                state.copy(supportMessage = MULTI_CAM_UNSUPPORTED)
            } else {
                state.copy(selectedMode = mode, supportMessage = "")
            }
        }
    }

    fun toggleRecording() {
        _uiState.update { state ->
            state.copy(isRecording = !state.isRecording)
        }
    }
}
