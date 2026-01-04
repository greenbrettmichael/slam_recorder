package dev.slamrecorder.android.recording

import android.content.Context
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface
import android.opengl.GLES11Ext
import android.opengl.GLES20
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
import kotlinx.coroutines.newSingleThreadContext
import kotlinx.coroutines.withContext
import java.util.concurrent.TimeUnit

/**
 * Minimal ARCore recorder that:
 * 1. Records camera poses to CSV
 * 2. Manages ARCore texture for preview rendering
 * 3. No video encoding, no CameraX - just pose data + texture
 */
class SimpleArCoreRecorder(
    private val context: Context,
    private val poseWriter: CsvBufferedWriter,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.Default),
) {
    data class StartResult(val success: Boolean, val message: String? = null)

    private val glDispatcher = newSingleThreadContext("SimpleArCoreGl")
    
    private var session: Session? = null
    private var poseJob: Job? = null
    private var eglDisplay: EGLDisplay? = null
    private var eglContext: EGLContext? = null
    private var eglSurface: EGLSurface? = null
    private var cameraTextureId: Int = 0

    /**
     * The camera texture ID that ARCore updates each frame.
     * Can be used to render preview.
     */
    fun getCameraTextureId(): Int = cameraTextureId

    suspend fun start(): StartResult =
        withContext(Dispatchers.Default) {
            val availability = ArCoreApk.getInstance().checkAvailability(context)
            if (!availability.isSupported) {
                return@withContext StartResult(success = false, message = "ARCore not supported on this device")
            }
            if (
                availability == ArCoreApk.Availability.SUPPORTED_NOT_INSTALLED ||
                availability == ArCoreApk.Availability.SUPPORTED_APK_TOO_OLD
            ) {
                return@withContext StartResult(success = false, message = "ARCore not installed or outdated")
            }

            return@withContext try {
                // Setup GL context on dedicated thread
                val glReady = withContext(glDispatcher) { setupGlContext() }
                if (!glReady) {
                    return@withContext StartResult(false, "GL context setup failed")
                }

                // Create ARCore session with texture
                val sessionReady = withContext(glDispatcher) {
                    try {
                        session = Session(context)
                        session?.setCameraTextureNames(intArrayOf(cameraTextureId))
                        session?.resume()
                        true
                    } catch (ex: Exception) {
                        android.util.Log.e("SimpleArCore", "Session setup failed: ${ex.message}", ex)
                        false
                    }
                }
                if (!sessionReady) {
                    return@withContext StartResult(false, "ARCore session setup failed")
                }

                // Start pose recording loop
                poseJob = scope.launch(glDispatcher) {
                    poseLoop(session)
                }

                StartResult(success = true)
            } catch (cn: CameraNotAvailableException) {
                android.util.Log.e("SimpleArCore", "Camera not available", cn)
                StartResult(success = false, message = "Camera not available: ${cn.message}")
            } catch (ex: Exception) {
                android.util.Log.e("SimpleArCore", "Start failed: ${ex.message}", ex)
                StartResult(success = false, message = ex.message)
            }
        }

    suspend fun stop() {
        poseJob?.cancel()
        poseJob = null

        try {
            session?.pause()
        } catch (_: Exception) {
        }
        session?.close()
        session = null

        withContext(glDispatcher) {
            tearDownGlContext()
        }

        poseWriter.flushAndClose()
    }

    private fun setupGlContext(): Boolean {
        return try {
            val display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
            if (display == EGL14.EGL_NO_DISPLAY) {
                android.util.Log.e("SimpleArCore", "Failed to get EGL display")
                return false
            }

            val version = IntArray(2)
            if (!EGL14.eglInitialize(display, version, 0, version, 1)) {
                android.util.Log.e("SimpleArCore", "Failed to initialize EGL")
                return false
            }

            val attribList = intArrayOf(
                EGL14.EGL_RED_SIZE, 8,
                EGL14.EGL_GREEN_SIZE, 8,
                EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_ALPHA_SIZE, 8,
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_NONE,
            )
            val configs = arrayOfNulls<EGLConfig>(1)
            val numConfig = IntArray(1)
            if (!EGL14.eglChooseConfig(display, attribList, 0, configs, 0, 1, numConfig, 0)) {
                android.util.Log.e("SimpleArCore", "Failed to choose EGL config")
                return false
            }

            val contextAttribs = intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE)
            val context = EGL14.eglCreateContext(display, configs[0], EGL14.EGL_NO_CONTEXT, contextAttribs, 0)
            if (context == null || context == EGL14.EGL_NO_CONTEXT) {
                android.util.Log.e("SimpleArCore", "Failed to create EGL context")
                return false
            }

            val surfaceAttribs = intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE)
            val surface = EGL14.eglCreatePbufferSurface(display, configs[0], surfaceAttribs, 0)
            if (surface == null || surface == EGL14.EGL_NO_SURFACE) {
                android.util.Log.e("SimpleArCore", "Failed to create pbuffer surface")
                return false
            }

            if (!EGL14.eglMakeCurrent(display, surface, surface, context)) {
                android.util.Log.e("SimpleArCore", "Failed to make EGL current")
                return false
            }

            eglDisplay = display
            eglContext = context
            eglSurface = surface
            cameraTextureId = generateExternalTexture()

            android.util.Log.i("SimpleArCore", "GL context setup successful. TextureId=$cameraTextureId")
            true
        } catch (ex: Exception) {
            android.util.Log.e("SimpleArCore", "GL setup failed: ${ex.message}", ex)
            false
        }
    }

    private fun generateExternalTexture(): Int {
        val textures = IntArray(1)
        GLES20.glGenTextures(1, textures, 0)
        val texId = textures[0]
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, texId)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        return texId
    }

    private fun tearDownGlContext() {
        val display = eglDisplay ?: return
        val surface = eglSurface ?: EGL14.EGL_NO_SURFACE
        val context = eglContext ?: EGL14.EGL_NO_CONTEXT

        EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
        if (surface != EGL14.EGL_NO_SURFACE) {
            EGL14.eglDestroySurface(display, surface)
        }
        if (context != EGL14.EGL_NO_CONTEXT) {
            EGL14.eglDestroyContext(display, context)
        }
        EGL14.eglTerminate(display)

        eglDisplay = null
        eglContext = null
        eglSurface = null
    }

    private suspend fun poseLoop(session: Session?) {
        session ?: return
        var frameCount = 0
        val skipInitialFrames = 10  // Skip first ~300ms of frames to avoid bad tracking
        while (scope.isActive) {
            try {
                // Make GL current before updating session
                makeGlCurrent()
                
                val frame: Frame = session.update()
                frameCount++
                
                // Skip initial frames with unreliable tracking
                if (frameCount <= skipInitialFrames) {
                    delay(30)
                    continue
                }
                
                // Only write poses when tracking is active (not LIMITED or PAUSED)
                if (frame.camera.trackingState == com.google.ar.core.TrackingState.TRACKING) {
                    writePose(frame.camera.pose, frame.timestamp)
                }
                
                if (frameCount % 30 == 0) {
                    android.util.Log.d("SimpleArCore", "Pose frame: $frameCount, tracking=${frame.camera.trackingState}")
                }
            } catch (ex: Exception) {
                android.util.Log.e("SimpleArCore", "Pose loop error: ${ex.message}", ex)
            }
            delay(30)
        }
    }

    private fun makeGlCurrent(): Boolean {
        val display = eglDisplay ?: return false
        val surface = eglSurface ?: return false
        val context = eglContext ?: return false
        return EGL14.eglMakeCurrent(display, surface, surface, context)
    }

    private fun writePose(
        pose: Pose,
        timestampNanos: Long,
    ) {
        val ts = timestampNanos.toDouble() / TimeUnit.SECONDS.toNanos(1).toDouble()
        val translation = pose.translation
        val rotation = pose.rotationQuaternion
        poseWriter.writeRow(
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
}
