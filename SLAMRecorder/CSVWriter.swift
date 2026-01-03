import Foundation

/// A helper class to manage CSV file writing.
///
/// This class abstracts the `FileHandle` operations for writing text data to a file.
/// It handles file creation, header writing, and appending rows efficiently.
class CSVWriter {
    private var fileHandle: FileHandle?
    private let fileURL: URL
    
    /// Initializes the CSVWriter with a file URL and header.
    ///
    /// This initializer creates the file at the specified URL and writes the header immediately.
    /// If file creation fails or the handle cannot be opened, initialization returns `nil`.
    ///
    /// - Parameters:
    ///   - url: The destination URL for the CSV file.
    ///   - header: The initial header row to write (e.g., "timestamp,x,y,z\n").
    init?(url: URL, header: String) {
        self.fileURL = url
        
        // Create file with header
        guard let data = header.data(using: .utf8) else { return nil }
        if !FileManager.default.createFile(atPath: url.path, contents: data) {
            return nil
        }
        
        do {
            self.fileHandle = try FileHandle(forWritingTo: url)
            self.fileHandle?.seekToEndOfFile()
        } catch {
            print("Failed to create file handle for \(url.lastPathComponent): \(error)")
            return nil
        }
    }
    
    /// Writes a row to the CSV file.
    /// - Parameter row: The string content of the row.
    func write(row: String) {
        guard let data = row.data(using: .utf8) else { return }
        fileHandle?.write(data)
    }
    
    /// Closes the file handle.
    func close() {
        try? fileHandle?.close()
        fileHandle = nil
    }
}
