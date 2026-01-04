import Foundation

/// A helper class to manage CSV file writing.
///
/// This class abstracts the `FileHandle` operations for writing text data to a file.
/// It handles file creation, header writing, and appending rows efficiently.
/// Optimized for performance with background I/O buffering.
class CSVWriter {
    private var fileHandle: FileHandle?
    private let fileURL: URL

    // Performance optimization: buffer writes and flush on background queue
    private var writeBuffer: [String] = []
    private let writeQueue = DispatchQueue(label: "com.slamrecorder.csvwrite", qos: .userInitiated)
    private let bufferFlushInterval = 0.5 // seconds

    /// Initializes the CSVWriter with a file URL and header.
    ///
    /// This initializer creates the file at the specified URL and writes the header immediately.
    /// If file creation fails or the handle cannot be opened, initialization returns `nil`.
    ///
    /// - Parameters:
    ///   - url: The destination URL for the CSV file.
    ///   - header: The initial header row to write (e.g., "timestamp,x,y,z\n").
    init?(url: URL, header: String) {
        fileURL = url

        // Create file with header
        guard let data = header.data(using: .utf8) else { return nil }
        if !FileManager.default.createFile(atPath: url.path, contents: data) {
            return nil
        }

        do {
            fileHandle = try FileHandle(forWritingTo: url)
            fileHandle?.seekToEndOfFile()
        } catch {
            print("Failed to create file handle for \(url.lastPathComponent): \(error)")
            return nil
        }

        // Start periodic buffer flush
        startPeriodicFlush()
    }

    /// Writes a row to the CSV file with buffering for performance.
    /// - Parameter row: The string content of the row.
    func write(row: String) {
        // Add to buffer instead of writing immediately (main thread optimization)
        writeQueue.async { [weak self] in
            self?.writeBuffer.append(row)

            // Flush if buffer gets large
            if self?.writeBuffer.count ?? 0 >= 100 {
                self?.flushBuffer()
            }
        }
    }

    private func startPeriodicFlush() {
        writeQueue.asyncAfter(deadline: .now() + bufferFlushInterval) { [weak self] in
            self?.flushBuffer()
            self?.startPeriodicFlush()
        }
    }

    private func flushBuffer() {
        guard !writeBuffer.isEmpty, fileHandle != nil else { return }

        let bufferToFlush = writeBuffer
        writeBuffer.removeAll(keepingCapacity: true)

        // Write all buffered rows in a single operation
        for row in bufferToFlush {
            if let data = row.data(using: .utf8) {
                fileHandle.write(data)
            }
        }
    }

    /// Closes the file handle and flushes any remaining buffered data.
    func close() {
        // Final flush of any remaining data
        flushBuffer()
        try? fileHandle?.close()
        fileHandle = nil
    }
}

