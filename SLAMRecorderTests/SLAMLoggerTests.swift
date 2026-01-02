import XCTest
@testable import SLAMRecorder

final class SLAMLoggerTests: XCTestCase {
    
    var logger: SLAMLogger!

    override func setUp() {
        super.setUp()
        logger = SLAMLogger()
    }

    override func tearDown() {
        logger = nil
        super.tearDown()
    }

    func testInitialState() {
        // Verify logger starts in a clean state
        XCTAssertFalse(logger.isRecording, "Logger should not be recording initially")
        XCTAssertEqual(logger.sampleCount, 0, "Sample count should be 0")
    }

    func testRecordingToggle() {
        // Simulate start
        logger.startRecording()
        XCTAssertTrue(logger.isRecording, "Logger should be recording after start")
        
        // Simulate stop
        logger.stopRecording()
        XCTAssertFalse(logger.isRecording, "Logger should stop recording")
    }
}