package dev.slamrecorder.android.recording

import android.content.Context
import android.os.SystemClock
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.FileOutputOptions
import androidx.camera.video.Quality
import androidx.camera.video.QualitySelector
import androidx.camera.video.Recorder
import androidx.camera.video.Recording
import androidx.camera.video.VideoCapture
import androidx.core.content.ContextCompat
import androidx.lifecycle.ProcessLifecycleOwner
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.io.File
import java.util.concurrent.Executor
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Controls single-camera video recording using CameraX.
 *
 * Manages CameraX lifecycle, binds the camera to the process lifecycle,
 * and handles video recording with optional preview. Records at highest
 * available quality using the default back camera.
 *
 * @property context Application context for CameraX initialization
 */
class VideoCaptureController(private val context: Context) {
    private val mainExecutor: Executor = ContextCompat.getMainExecutor(context)
    private var cameraProvider: ProcessCameraProvider? = null
    private var videoCapture: VideoCapture<Recorder>? = null
    private var activeRecording: Recording? = null

    /**
     * Starts video recording.
     *
     * Binds CameraX to the process lifecycle, configures the camera with
     * optional preview, and begins recording to the specified file.
     *
     * @param outputFile File to write video output
     * @param surfaceProvider Optional preview surface provider for displaying camera feed
     * @return Video start timestamp in nanoseconds (SystemClock.elapsedRealtimeNanos)
     */
    suspend fun start(
        outputFile: File,
        surfaceProvider: Preview.SurfaceProvider?,
    ): Long =
        withContext(Dispatchers.Main) {
            android.util.Log.i("VideoCaptureController", "Starting with preview surface provider: ${if (surfaceProvider != null) "READY" else "NULL"}")
            cameraProvider = ProcessCameraProvider.getInstance(context).await(mainExecutor)
            val provider = cameraProvider ?: error("Camera provider unavailable")

            val qualitySelector = QualitySelector.from(Quality.HIGHEST)
            val recorder =
                Recorder.Builder()
                    .setQualitySelector(qualitySelector)
                    .build()
            videoCapture = VideoCapture.withOutput(recorder)

            val preview = Preview.Builder().build()
            surfaceProvider?.let { preview.setSurfaceProvider(it) }

            provider.unbindAll()
            provider.bindToLifecycle(
                ProcessLifecycleOwner.get(),
                CameraSelector.DEFAULT_BACK_CAMERA,
                preview,
                videoCapture,
            )

            val outputOptions = FileOutputOptions.Builder(outputFile).build()
            val pendingRecording = videoCapture!!.output.prepareRecording(context, outputOptions)

            val startTimeNanos = SystemClock.elapsedRealtimeNanos()
            activeRecording = pendingRecording.start(mainExecutor) { /* capture callbacks not used */ }
            startTimeNanos
        }

    /**
     * Stops video recording and unbinds the camera.
     *
     * Safe to call even if recording is not active.
     */
    fun stop() {
        activeRecording?.stop()
        activeRecording = null
        cameraProvider?.unbindAll()
        videoCapture = null
    }
}

/**
 * Suspends until a ListenableFuture completes.
 *
 * Converts Guava's ListenableFuture to Kotlin's coroutine-based suspension.
 *
 * @param executor Executor for the completion listener
 * @return The result value from the future
 * @throws Throwable if the future completes exceptionally
 */
private suspend fun <T> com.google.common.util.concurrent.ListenableFuture<T>.await(executor: Executor): T =
    suspendCancellableCoroutine { cont ->
        addListener({
            try {
                cont.resume(get())
            } catch (t: Throwable) {
                cont.resumeWithException(t)
            }
        }, executor)
    }
