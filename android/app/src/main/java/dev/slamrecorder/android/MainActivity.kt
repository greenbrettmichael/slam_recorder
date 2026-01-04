package dev.slamrecorder.android

import android.hardware.camera2.CameraManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import dev.slamrecorder.android.recording.MultiCamSupportChecker
import dev.slamrecorder.android.recording.RecordingViewModel
import dev.slamrecorder.android.ui.appTheme
import dev.slamrecorder.android.ui.recorderScreen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val cameraManager = getSystemService(CAMERA_SERVICE) as CameraManager
        val supportChecker = MultiCamSupportChecker(cameraManager)

        setContent {
            val viewModel: RecordingViewModel = viewModel(factory = recordingViewModelFactory(supportChecker))
            val state by viewModel.uiState.collectAsState()

            appTheme {
                recorderScreen(
                    state = state,
                    onModeSelected = viewModel::selectMode,
                    onToggleRecording = viewModel::toggleRecording,
                )
            }
        }
    }

    private fun recordingViewModelFactory(supportChecker: MultiCamSupportChecker): ViewModelProvider.Factory =
        object : ViewModelProvider.Factory {
            override fun <T : ViewModel> create(modelClass: Class<T>): T {
                return RecordingViewModel(supportChecker) as T
            }
        }
}
