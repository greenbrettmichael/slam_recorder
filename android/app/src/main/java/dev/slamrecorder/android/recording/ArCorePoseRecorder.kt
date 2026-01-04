package dev.slamrecorder.android.recording

import android.content.Context
import com.google.ar.core.ArCoreApk
import com.google.ar.core.Frame
import com.google.ar.core.Pose
import com.google.ar.core.Session
import com.google.ar.core.exceptions.CameraNotAvailableException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.TimeUnit

class ArCorePoseRecorder(
    private val context: Context,
    private val writer: CsvBufferedWriter,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.Default),
) {
    data class StartResult(val success: Boolean, val message: String? = null)

    private var session: Session? = null
    private var job: Job? = null

    suspend fun start(): StartResult =
        withContext(Dispatchers.Default) {
            val availability = ArCoreApk.getInstance().checkAvailability(context)
            if (!availability.isSupported) {
                return@withContext StartResult(success = false, message = "ARCore not supported on this device")
            }
            return@withContext try {
                session = Session(context)
                session?.resume()
                job =
                    scope.launch {
                        loop(session)
                    }
                StartResult(success = true)
            } catch (cn: CameraNotAvailableException) {
                StartResult(success = false, message = cn.localizedMessage)
            } catch (ex: Exception) {
                StartResult(success = false, message = ex.localizedMessage)
            }
        }

    private suspend fun loop(session: Session?) {
        session ?: return
        while (scope.isActive) {
            try {
                val frame: Frame = session.update()
                writePose(frame.camera.pose, frame.timestamp)
            } catch (_: Exception) {
                // ignore individual frame errors to keep recording alive
            }
            delay(30)
        }
    }

    private fun writePose(
        pose: Pose,
        timestampNanos: Long,
    ) {
        val ts = timestampNanos.toDouble() / TimeUnit.SECONDS.toNanos(1).toDouble()
        val translation = pose.translation
        val rotation = pose.rotationQuaternion
        writer.writeRow(
            listOf(
                ts.toString(),
                translation[0].toString(),
                translation[1].toString(),
                translation[2].toString(),
                rotation[0].toString(),
                rotation[1].toString(),
                rotation[2].toString(),
                rotation[3].toString(),
            ),
        )
    }

    fun stop() {
        job?.cancel()
        job = null
        try {
            session?.pause()
        } catch (_: Exception) {
        }
        session?.close()
        session = null
        writer.flushAndClose()
    }
}
