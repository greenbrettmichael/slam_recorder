package dev.slamrecorder.android

import android.Manifest
import android.content.Intent
import android.hardware.SensorManager
import android.hardware.camera2.CameraManager
import android.net.Uri
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.core.content.ContextCompat
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.viewmodel.compose.viewModel
import dev.slamrecorder.android.recording.CameraEnumerator
import dev.slamrecorder.android.recording.MultiCamSupportChecker
import dev.slamrecorder.android.recording.RecordingCoordinator
import dev.slamrecorder.android.recording.RecordingViewModel
import dev.slamrecorder.android.ui.appTheme
import dev.slamrecorder.android.ui.recorderScreen
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    private val permissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { /* no-op; state checked on launch */ }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        ensurePermissions()

        val cameraManager = getSystemService(CAMERA_SERVICE) as CameraManager
        val sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        val recordingCoordinator = RecordingCoordinator(applicationContext, sensorManager, cameraManager)
        val supportChecker = MultiCamSupportChecker(cameraManager)
        val cameraEnumerator = CameraEnumerator(cameraManager)

        setContent {
            val viewModel: RecordingViewModel = viewModel(factory = recordingViewModelFactory(supportChecker, cameraEnumerator, recordingCoordinator))
            val state by viewModel.uiState.collectAsState()

            appTheme {
                recorderScreen(
                    state = state,
                    onModeSelected = viewModel::selectMode,
                    onCameraToggle = viewModel::toggleCameraSelection,
                    onToggleRecording = viewModel::toggleRecording,
                    onExportLatest = { exportLatestSession(recordingCoordinator) },
                    onPreviewReady = viewModel::setPreviewSurfaceProvider,
                    onMultiPreviewSurface = viewModel::setMultiPreviewSurface,
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

    private fun exportLatestSession(coordinator: RecordingCoordinator) {
        lifecycleScope.launch {
            when (val result = coordinator.exportLatest()) {
                is RecordingCoordinator.ExportResult.Success -> shareZip(result.uri)
                is RecordingCoordinator.ExportResult.Failure ->
                    Toast.makeText(this@MainActivity, result.message, Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun shareZip(uri: Uri) {
        val intent =
            Intent(Intent.ACTION_SEND).apply {
                type = "application/zip"
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
        startActivity(Intent.createChooser(intent, "Share session"))
    }

    private fun recordingViewModelFactory(
        supportChecker: MultiCamSupportChecker,
        cameraEnumerator: CameraEnumerator,
        coordinator: RecordingCoordinator,
    ): ViewModelProvider.Factory =
        object : ViewModelProvider.Factory {
            override fun <T : ViewModel> create(modelClass: Class<T>): T {
                return RecordingViewModel(supportChecker, cameraEnumerator, coordinator) as T
            }
        }
}
