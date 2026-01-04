package dev.slamrecorder.android

import android.Manifest
import android.hardware.SensorManager
import android.hardware.camera2.CameraManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.core.content.ContextCompat
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import dev.slamrecorder.android.recording.MultiCamSupportChecker
import dev.slamrecorder.android.recording.RecordingCoordinator
import dev.slamrecorder.android.recording.RecordingViewModel
import dev.slamrecorder.android.ui.appTheme
import dev.slamrecorder.android.ui.recorderScreen

class MainActivity : ComponentActivity() {
    private val permissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { /* no-op; state checked on launch */ }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        ensurePermissions()

        val cameraManager = getSystemService(CAMERA_SERVICE) as CameraManager
        val sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        val recordingCoordinator = RecordingCoordinator(applicationContext, sensorManager)
        val supportChecker = MultiCamSupportChecker(cameraManager)

        setContent {
            val viewModel: RecordingViewModel = viewModel(factory = recordingViewModelFactory(supportChecker, recordingCoordinator))
            val state by viewModel.uiState.collectAsState()

            appTheme {
                recorderScreen(
                    state = state,
                    onModeSelected = viewModel::selectMode,
                    onToggleRecording = viewModel::toggleRecording,
                    onPreviewReady = viewModel::setPreviewSurfaceProvider,
                )
            }
        }
    }

    private fun ensurePermissions() {
        val required =
            listOf(
                Manifest.permission.CAMERA,
                Manifest.permission.RECORD_AUDIO,
            )
        val missing =
            required.filter {
                ContextCompat.checkSelfPermission(
                    this,
                    it,
                ) != android.content.pm.PackageManager.PERMISSION_GRANTED
            }
        if (missing.isNotEmpty()) {
            permissionLauncher.launch(missing.toTypedArray())
        }
    }

    private fun recordingViewModelFactory(
        supportChecker: MultiCamSupportChecker,
        coordinator: RecordingCoordinator,
    ): ViewModelProvider.Factory =
        object : ViewModelProvider.Factory {
            override fun <T : ViewModel> create(modelClass: Class<T>): T {
                return RecordingViewModel(supportChecker, coordinator) as T
            }
        }
}
