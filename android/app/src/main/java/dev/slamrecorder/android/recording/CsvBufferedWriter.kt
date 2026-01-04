package dev.slamrecorder.android.recording

import java.io.BufferedWriter
import java.io.File
import java.io.FileWriter
import java.io.IOException
import java.util.concurrent.atomic.AtomicBoolean

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
