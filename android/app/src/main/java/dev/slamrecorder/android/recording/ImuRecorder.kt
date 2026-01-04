package dev.slamrecorder.android.recording

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.util.concurrent.TimeUnit

/**
 * Records accelerometer and gyroscope data from the device's IMU sensors to CSV.
 *
 * Registers for SENSOR_DELAY_FASTEST with automatic fallback to SENSOR_DELAY_GAME
 * if high sampling rate permissions are unavailable. Timestamps are converted to
 * seconds (double precision) for consistency with ARCore pose timestamps.
 *
 * Output format: timestamp, x, y, z, type ("accel" or "gyro")
 *
 * @property sensorManager The system sensor manager
 * @property writer CSV writer for outputting sensor data
 * @property scope Coroutine scope for launching sensor registration
 */
class ImuRecorder(
    private val sensorManager: SensorManager,
    private val writer: CsvBufferedWriter,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.Default),
) : SensorEventListener {
    private var job: Job? = null

    /**
     * Starts IMU sensor recording.
     *
     * Registers listeners for accelerometer and gyroscope at maximum available rate.
     */
    fun start() {
        job =
            scope.launch {
                registerWithFallback(Sensor.TYPE_ACCELEROMETER)
                registerWithFallback(Sensor.TYPE_GYROSCOPE)
            }
    }

    /**
     * Stops IMU recording and closes the output file.
     *
     * Unregisters all sensor listeners and flushes buffered data.
     */
    fun stop() {
        job?.cancel()
        sensorManager.unregisterListener(this)
        writer.flushAndClose()
    }

    override fun onSensorChanged(event: SensorEvent?) {
        event ?: return
        val timestampSeconds = event.timestamp.toDouble() / TimeUnit.SECONDS.toNanos(1).toDouble()
        when (event.sensor.type) {
            Sensor.TYPE_ACCELEROMETER -> writeAccel(timestampSeconds, event.values)
            Sensor.TYPE_GYROSCOPE -> writeGyro(timestampSeconds, event.values)
        }
    }

    override fun onAccuracyChanged(
        sensor: Sensor?,
        accuracy: Int,
    ) = Unit

    private fun writeAccel(
        timestamp: Double,
        values: FloatArray,
    ) {
        if (values.size < 3) return
        writer.writeRow(
            listOf(
                timestamp.toString(),
                values[0].toString(),
                values[1].toString(),
                values[2].toString(),
                "accel",
            ),
        )
    }

    private fun writeGyro(
        timestamp: Double,
        values: FloatArray,
    ) {
        if (values.size < 3) return
        writer.writeRow(
            listOf(
                timestamp.toString(),
                values[0].toString(),
                values[1].toString(),
                values[2].toString(),
                "gyro",
            ),
        )
    }

    private fun registerWithFallback(sensorType: Int) {
        val sensor = sensorManager.getDefaultSensor(sensorType) ?: return
        try {
            sensorManager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_FASTEST)
        } catch (_: SecurityException) {
            // Fall back to a slower rate if HIGH_SAMPLING_RATE_SENSORS is unavailable
            sensorManager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_GAME)
        }
    }
}
