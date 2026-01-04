import AVFoundation
@testable import SLAMRecorder
import XCTest

final class SLAMLoggerTests: XCTestCase {
    var logger: SLAMLogger!
    var mockMultiCam: MockMultiCamRecorder!

    override func setUp() {
        super.setUp()
        mockMultiCam = MockMultiCamRecorder()
        logger = SLAMLogger(multiCamRecorder: mockMultiCam)
    }

    override func tearDown() {
        if logger.isRecording {
            logger.stopRecording()
        }
        logger = nil
        super.tearDown()
    }

    func testMultiCamModeSkipsPoseWriter() {
        logger.recordingMode = .multiCamera
        logger.selectedCameras = [.backWide]
        logger.startRecording()
        XCTAssertTrue(mockMultiCam.startCalled)
        XCTAssertEqual(mockMultiCam.lastCameras, [.backWide])
        logger.stopRecording()
    }

    func testInitialState() {
        XCTAssertFalse(logger.isRecording, "Logger should not be recording initially")
        XCTAssertEqual(logger.sampleCount, 0, "Sample count should be 0")
    }

    func testRecordingSessionCreation() {
        // Start recording
        logger.startRecording()
        XCTAssertTrue(logger.isRecording)

        // Check if session directory was created
        // We need to access the private recordingURL or infer it.
        // Since recordingURL is private, we can check the Documents directory for a recent folder.

        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: docDir, includingPropertiesForKeys: [.creationDateKey], options: [])
            let sessionFolders = contents.filter { $0.lastPathComponent.starts(with: "session_") }

            XCTAssertFalse(sessionFolders.isEmpty, "Should have created a session folder")

            // Get the most recent one
            if let recentSession = sessionFolders.sorted(by: { $0.path > $1.path }).first {
                let imuPath = recentSession.appendingPathComponent("imu_data.csv")
                let posePath = recentSession.appendingPathComponent("arkit_groundtruth.csv")

                XCTAssertTrue(FileManager.default.fileExists(atPath: imuPath.path), "IMU CSV should exist")
                XCTAssertTrue(FileManager.default.fileExists(atPath: posePath.path), "Pose CSV should exist")
            }
        } catch {
            XCTFail("Failed to list directories: \(error)")
        }

        logger.stopRecording()
        XCTAssertFalse(logger.isRecording)
    }

    func testMultipleSessions() {
        // Session 1
        logger.startRecording()
        XCTAssertTrue(logger.isRecording)
        logger.stopRecording()
        XCTAssertFalse(logger.isRecording)

        // Session 2
        logger.startRecording()
        XCTAssertTrue(logger.isRecording)
        logger.stopRecording()
        XCTAssertFalse(logger.isRecording)

        // Verify we have at least 2 session folders (or more if previous tests ran)
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: docDir, includingPropertiesForKeys: nil, options: [])
            let sessionFolders = contents.filter { $0.lastPathComponent.starts(with: "session_") }
            XCTAssertTrue(sessionFolders.count >= 2, "Should have created multiple session folders")
        } catch {
            XCTFail("Failed to list directories: \(error)")
        }
    }

    func testMultipleStartCalls() {
        logger.recordingMode = .multiCamera
        logger.selectedCameras = [.backWide]
        logger.startRecording()
        XCTAssertTrue(mockMultiCam.startCalled)
        XCTAssertTrue(logger.isRecording)

        // Create a new mock to verify second start is ignored
        let secondMock = MockMultiCamRecorder()
        logger = SLAMLogger(multiCamRecorder: secondMock)
        logger.recordingMode = .multiCamera
        logger.selectedCameras = [.backWide]
        logger.startRecording()
        logger.startRecording()
        XCTAssertTrue(logger.isRecording)
        logger.stopRecording()
    }

    func testStopWithoutStart() {
        XCTAssertFalse(logger.isRecording)
        logger.stopRecording()
        XCTAssertFalse(logger.isRecording)
    }

    func testMultipleStopCalls() {
        logger.recordingMode = .multiCamera
        logger.selectedCameras = [.backWide]
        logger.startRecording()
        XCTAssertTrue(logger.isRecording)
        logger.stopRecording()
        XCTAssertFalse(logger.isRecording)
        logger.stopRecording()
        XCTAssertFalse(logger.isRecording)
    }

    func testSwitchRecordingModeBetweenSessions() {
        logger.recordingMode = .arkit
        logger.startRecording()
        XCTAssertTrue(logger.isRecording)
        logger.stopRecording()
        XCTAssertFalse(logger.isRecording)
        logger.recordingMode = .multiCamera
        logger.selectedCameras = [.backWide]
        logger.startRecording()
        XCTAssertTrue(logger.isRecording)
        logger.stopRecording()
        XCTAssertFalse(logger.isRecording)
    }

    func testMultiCamFailureHandling() {
        mockMultiCam.shouldStartSucceed = false
        logger.recordingMode = .multiCamera
        logger.selectedCameras = [.backWide]
        logger.startRecording()
        XCTAssertFalse(logger.isRecording)
    }
}

// MARK: - Test Doubles

final class MockMultiCamRecorder: MultiCamRecording {
    private(set) var startCalled = false
    private(set) var stopCalled = false
    private(set) var lastCameras: Set<CameraID> = []
    private(set) var lastDirectory: URL?
    var isRecording: Bool = false
    var shouldStartSucceed: Bool = true

    func reset() {
        startCalled = false
        stopCalled = false
        lastCameras = []
        lastDirectory = nil
        isRecording = false
        shouldStartSucceed = true
    }

    func makePreviewLayer() -> AVCaptureVideoPreviewLayer? { nil }

    func startRecording(cameras: Set<CameraID>, directory: URL) -> Bool {
        startCalled = true
        lastCameras = cameras
        lastDirectory = directory
        isRecording = shouldStartSucceed
        return shouldStartSucceed
    }

    func stopRecording() {
        stopCalled = true
        isRecording = false
    }
}
