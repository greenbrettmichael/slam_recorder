import XCTest
import AVFoundation
@testable import SLAMRecorder

final class VideoRecorderTests: XCTestCase {
    var tempURL: URL!
    
    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }
    
    func testSetup() {
        let recorder = VideoRecorder()
        let success = recorder.setup(url: tempURL, width: 1920, height: 1080)
        
        XCTAssertTrue(success)
        XCTAssertTrue(recorder.isWriting)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))
    }
    
    func testFinishResetsState() {
        let recorder = VideoRecorder()
        _ = recorder.setup(url: tempURL, width: 640, height: 480)
        
        let expectation = self.expectation(description: "Finish completion called")
        
        recorder.finish {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 2.0, handler: nil)
        XCTAssertFalse(recorder.isWriting)
    }
    
    func testAppendFrame() {
        let recorder = VideoRecorder()
        guard recorder.setup(url: tempURL, width: 640, height: 480) else {
            XCTFail("Setup failed")
            return
        }
        
        // Create a dummy pixel buffer
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault, 640, 480, kCVPixelFormatType_32BGRA, attrs, &pixelBuffer)
        XCTAssertEqual(status, kCVReturnSuccess)
        XCTAssertNotNil(pixelBuffer)
        
        if let buffer = pixelBuffer {
            recorder.append(pixelBuffer: buffer, timestamp: 0.0)
            recorder.append(pixelBuffer: buffer, timestamp: 0.033)
        }
        
        let expectation = self.expectation(description: "Finish completion called")
        recorder.finish {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2.0)
        
        // Verify file exists and has content (basic check)
        let attributes = try? FileManager.default.attributesOfItem(atPath: tempURL.path)
        let fileSize = attributes?[.size] as? Int64 ?? 0
        XCTAssertGreaterThan(fileSize, 0)
    }
}
