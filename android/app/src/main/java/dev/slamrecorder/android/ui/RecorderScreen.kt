package dev.slamrecorder.android.ui

import androidx.camera.view.PreviewView
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.TextButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import dev.slamrecorder.android.recording.RecorderUiState
import dev.slamrecorder.android.recording.RecordingMode

@Composable
fun recorderScreen(
    state: RecorderUiState,
    onModeSelected: (RecordingMode) -> Unit,
    onCameraToggle: (String) -> Unit,
    onToggleRecording: () -> Unit,
    onExportLatest: () -> Unit = {},
    onPreviewReady: (androidx.camera.core.Preview.SurfaceProvider) -> Unit = {},
    onMultiPreviewSurface: (String, android.view.Surface?) -> Unit = { _, _ -> },
) {
    var showModeEditor by rememberSaveable { mutableStateOf(false) }

    Column(
        modifier =
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(
            text = "SLAM Recorder (Android)",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
        )

        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(
                            text = "Recording Mode",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Medium,
                        )
                        if (!showModeEditor) {
                            Text(
                                text = state.selectedMode.label,
                                style = MaterialTheme.typography.bodyMedium,
                            )
                        }
                    }
                    TextButton(onClick = { showModeEditor = !showModeEditor }) {
                        Text(if (showModeEditor) "Done" else "Change")
                    }
                }

                if (showModeEditor) {
                    modeSelector(
                        selectedMode = state.selectedMode,
                        multiCamSupported = state.multiCamSupported,
                        onModeSelected = onModeSelected,
                    )
                }

                val supportMessage = state.supportMessage
                if (supportMessage.isNotBlank()) {
                    Text(
                        text = supportMessage,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            }
        }

        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                if (state.selectedMode == RecordingMode.MULTI_CAMERA) {
                    Text(
                        text = "Multi-camera: select up to 2 cameras and preview below.",
                        style = MaterialTheme.typography.bodySmall,
                    )
                    cameraSelectorList(state, onCameraToggle)
                    multiCameraPreviews(state, onMultiPreviewSurface)
                } else {
                    cameraPreview(onPreviewReady = onPreviewReady)
                }

                Text(
                    text = if (state.isRecording) "Recording..." else "Idle",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Medium,
                )
                Button(
                    onClick = onToggleRecording,
                    modifier = Modifier.fillMaxWidth(),
                    enabled =
                        state.selectedMode != RecordingMode.MULTI_CAMERA ||
                            (state.multiCamSupported && state.selectedCameraIds.isNotEmpty()),
                ) {
                    Text(text = if (state.isRecording) "Stop Recording" else "Start Recording")
                }
                Button(
                    onClick = onExportLatest,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(text = "Export Latest Session")
                }
                if (state.statusMessage.isNotBlank()) {
                    Text(
                        text = state.statusMessage,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.secondary,
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(12.dp))
    }
}

@Composable
private fun cameraPreview(onPreviewReady: (androidx.camera.core.Preview.SurfaceProvider) -> Unit) {
    AndroidView(
        modifier =
            Modifier
                .fillMaxWidth()
                .height(220.dp),
        factory = { context ->
            PreviewView(context).apply {
                this.scaleType = PreviewView.ScaleType.FILL_CENTER
            }
        },
        update = { previewView ->
            val provider = previewView.surfaceProvider
            onPreviewReady(provider)
        },
    )
}

@Composable
private fun cameraSelectorList(
    state: RecorderUiState,
    onCameraToggle: (String) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(text = "Select up to 2 cameras:", style = MaterialTheme.typography.titleSmall)
        state.availableCameras.forEach { cam ->
            val selected = state.selectedCameraIds.contains(cam.id)
            FilterChip(
                selected = selected,
                onClick = { onCameraToggle(cam.id) },
                label = { Text(cam.label) },
                enabled = true,
            )
        }
        if (state.selectedCameraIds.size > 2) {
            Text(
                text = "Limit 2 cameras at once.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.error,
            )
        }
    }
}

@Composable
private fun multiCameraPreviews(
    state: RecorderUiState,
    onSurfaceReady: (String, android.view.Surface?) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        state.selectedCameraIds.take(2).forEach { camId ->
            AndroidView(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .height(180.dp),
                factory = { context ->
                    android.view.TextureView(context).apply {
                        surfaceTextureListener = object : android.view.TextureView.SurfaceTextureListener {
                            override fun onSurfaceTextureAvailable(
                                surfaceTexture: android.graphics.SurfaceTexture,
                                width: Int,
                                height: Int,
                            ) {
                                onSurfaceReady(camId, android.view.Surface(surfaceTexture))
                            }

                            override fun onSurfaceTextureSizeChanged(
                                surfaceTexture: android.graphics.SurfaceTexture,
                                width: Int,
                                height: Int,
                            ) = Unit

                            override fun onSurfaceTextureDestroyed(surfaceTexture: android.graphics.SurfaceTexture): Boolean {
                                onSurfaceReady(camId, null)
                                return true
                            }

                            override fun onSurfaceTextureUpdated(surfaceTexture: android.graphics.SurfaceTexture) = Unit
                        }
                    }
                },
            )
            Text(text = "Preview: $camId", style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
private fun modeSelector(
    selectedMode: RecordingMode,
    multiCamSupported: Boolean,
    onModeSelected: (RecordingMode) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        FilterChip(
            selected = selectedMode == RecordingMode.AR_CORE,
            onClick = { onModeSelected(RecordingMode.AR_CORE) },
            label = { Text(RecordingMode.AR_CORE.label) },
            enabled = true,
        )
        FilterChip(
            selected = selectedMode == RecordingMode.MULTI_CAMERA,
            onClick = { onModeSelected(RecordingMode.MULTI_CAMERA) },
            label = { Text(RecordingMode.MULTI_CAMERA.label) },
            enabled = multiCamSupported,
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun recorderScreenPreview() {
    appTheme {
        recorderScreen(
            state =
                RecorderUiState(
                    selectedMode = RecordingMode.AR_CORE,
                    isRecording = false,
                    multiCamSupported = false,
                    supportMessage = "Multi-camera not supported",
                ),
            onModeSelected = {},
            onCameraToggle = {},
            onToggleRecording = {},
        )
    }
}
