@testable import SLAMRecorder
import XCTest

final class CSVWriterTests: XCTestCase {
    var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".csv")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    func testInitializationCreatesFileWithHeader() {
        let header = "timestamp,x,y,z\n"
        let writer = CSVWriter(url: tempURL, header: header)

        XCTAssertNotNil(writer)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))

        let content = try? String(contentsOf: tempURL, encoding: .utf8)
        XCTAssertEqual(content, header)
    }

    func testWritingRows() {
        let header = "col1,col2\n"
        let writer = CSVWriter(url: tempURL, header: header)

        let row1 = "1,2\n"
        let row2 = "3,4\n"

        writer?.write(row: row1)
        writer?.write(row: row2)
        writer?.close()

        let content = try? String(contentsOf: tempURL, encoding: .utf8)
        let expected = header + row1 + row2
        XCTAssertEqual(content, expected)
    }

    func testInitializationFailsWithInvalidURL() {
        // Using a directory path as a file path usually fails or using an empty path
        // However, FileManager.createFile might just fail if the directory doesn't exist.
        let invalidURL = URL(fileURLWithPath: "/invalid/path/to/file.csv")
        let writer = CSVWriter(url: invalidURL, header: "header")
        XCTAssertNil(writer)
    }

    func testMultipleWrites() {
        let header = "a,b,c\n"
        let writer = CSVWriter(url: tempURL, header: header)
        XCTAssertNotNil(writer)
        for i in 1 ... 100 {
            writer?.write(row: "\(i),\(i * 2),\(i * 3)\n")
        }
        writer?.close()
        let content = try? String(contentsOf: tempURL, encoding: .utf8)
        let lines = content?.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines?.count, 101)
    }

    func testCloseMultipleTimes() {
        let header = "test\n"
        let writer = CSVWriter(url: tempURL, header: header)
        writer?.write(row: "data\n")
        writer?.close()
        writer?.close()
        let content = try? String(contentsOf: tempURL, encoding: .utf8)
        XCTAssertEqual(content, "test\ndata\n")
    }

    func testWriteAfterClose() {
        let header = "test\n"
        let writer = CSVWriter(url: tempURL, header: header)
        writer?.write(row: "before\n")
        writer?.close()
        writer?.write(row: "after\n")
        let content = try? String(contentsOf: tempURL, encoding: .utf8)
        XCTAssertEqual(content, "test\nbefore\n")
    }
}
