package dev.slamrecorder.android.recording

import java.io.BufferedWriter
import java.io.File
import java.io.FileWriter
import java.io.IOException
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Thread-safe CSV writer with buffering for high-frequency sensor data recording.
 *
 * Automatically writes CSV headers on initialization and provides synchronized methods
 * for writing rows and closing the file. Designed to handle high-frequency data streams
 * without blocking the caller on I/O errors.
 *
 * @property file The output CSV file
 * @property headers Column headers to write as the first line
 */
class CsvBufferedWriter(
    private val file: File,
    headers: List<String>,
) {
    private val writer: BufferedWriter = BufferedWriter(FileWriter(file, false))
    private val closed = AtomicBoolean(false)

    init {
        writer.write(headers.joinToString(","))
        writer.newLine()
        writer.flush()
    }

    /**
     * Writes a single row of CSV data.
     *
     * Thread-safe method that silently ignores I/O errors to prevent recording crashes.
     * No-op if the writer has been closed.
     *
     * @param values The values to write as a comma-separated row
     */
    @Synchronized
    fun writeRow(values: List<String>) {
        if (closed.get()) return
        try {
            writer.write(values.joinToString(","))
            writer.newLine()
        } catch (ioe: IOException) {
            // swallow to avoid crashing recording; caller can check file later
        }
    }

    /**
     * Flushes buffered data and closes the writer.
     *
     * Thread-safe and idempotent - safe to call multiple times.
     * Suppresses I/O exceptions during flush and close operations.
     */
    @Synchronized
    fun flushAndClose() {
        if (closed.compareAndSet(false, true)) {
            try {
                writer.flush()
            } catch (_: IOException) {
            }
            try {
                writer.close()
            } catch (_: IOException) {
            }
        }
    }
}
