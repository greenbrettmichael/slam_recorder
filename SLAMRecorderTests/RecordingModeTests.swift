@testable import SLAMRecorder
import XCTest

final class RecordingModeTests: XCTestCase {
    func testRecordingModeDisplayNames() {
        XCTAssertEqual(RecordingMode.arkit.displayName, "ARKit")
        XCTAssertEqual(RecordingMode.multiCamera.displayName, "Multi-Cam")
    }

    func testRecordingModeRawValues() {
        XCTAssertEqual(RecordingMode.arkit.rawValue, "arkit")
        XCTAssertEqual(RecordingMode.multiCamera.rawValue, "multiCamera")
    }

    func testRecordingModeCaseIterable() {
        let allCases = RecordingMode.allCases
        XCTAssertEqual(allCases.count, 2)
        XCTAssertTrue(allCases.contains(.arkit))
        XCTAssertTrue(allCases.contains(.multiCamera))
    }

    func testNoopMultiCamRecorderInitialState() {
        let noop = NoopMultiCamRecorder()
        XCTAssertFalse(noop.isRecording)
        XCTAssertTrue(noop.makePreviewLayers().isEmpty)
    }

    func testNoopMultiCamRecorderStartFails() {
        let noop = NoopMultiCamRecorder()
        let dir = FileManager.default.temporaryDirectory
        let success = noop.startRecording(cameras: [.backWide], directory: dir)
        XCTAssertFalse(success)
        XCTAssertFalse(noop.isRecording)
    }

    func testNoopMultiCamRecorderStop() {
        var noop = NoopMultiCamRecorder()
        noop.isRecording = true
        noop.stopRecording()
        XCTAssertFalse(noop.isRecording)
    }
}
