package dev.slamrecorder.android.ui

import androidx.camera.view.PreviewView
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
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
    onToggleRecording: () -> Unit,
    onExportLatest: () -> Unit = {},
    onPreviewReady: (androidx.camera.core.Preview.SurfaceProvider) -> Unit = {},
) {
    Column(
        modifier =
            Modifier
                .fillMaxSize()
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
                Text(
                    text = "Recording Mode",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Medium,
                )
                modeSelector(
                    selectedMode = state.selectedMode,
                    multiCamSupported = state.multiCamSupported,
                    onModeSelected = onModeSelected,
                )
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
                cameraPreview(onPreviewReady = onPreviewReady)

                Text(
                    text = if (state.isRecording) "Recording..." else "Idle",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Medium,
                )
                Button(
                    onClick = onToggleRecording,
                    modifier = Modifier.fillMaxWidth(),
                    enabled = state.selectedMode != RecordingMode.MULTI_CAMERA || state.multiCamSupported,
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
            onToggleRecording = {},
        )
    }
}
