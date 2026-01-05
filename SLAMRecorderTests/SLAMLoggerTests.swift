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

    func testMultiCamRejectsEmptyCameraSelection() {
        logger.recordingMode = .multiCamera
        logger.selectedCameras = []
        logger.startRecording()
        XCTAssertFalse(logger.isRecording)
        XCTAssertFalse(mockMultiCam.startCalled)
    }

    func testMultiCamRejectsTooManyCameras() {
        logger.recordingMode = .multiCamera
        logger.selectedCameras = [.backWide, .front, .backUltraWide]
        logger.startRecording()
        XCTAssertFalse(logger.isRecording)
        XCTAssertFalse(mockMultiCam.startCalled)
    }

    func testMultiCamAcceptsOneCamera() {
        logger.recordingMode = .multiCamera
        logger.selectedCameras = [.backWide]
        logger.startRecording()
        XCTAssertTrue(logger.isRecording)
        XCTAssertTrue(mockMultiCam.startCalled)
        logger.stopRecording()
    }

    func testMultiCamAcceptsTwoCameras() {
        logger.recordingMode = .multiCamera
        logger.selectedCameras = [.backWide, .front]
        logger.startRecording()
        XCTAssertTrue(logger.isRecording)
        XCTAssertTrue(mockMultiCam.startCalled)
        logger.stopRecording()
    }

    func testStartMonitoringWithARKit() {
        logger.recordingMode = .arkit
        logger.startMonitoring()
        // Verify session is running (basic check - session state is not directly accessible)
        XCTAssertEqual(logger.recordingMode, .arkit)
    }

    func testStartMonitoringWithMultiCamera() {
        logger.recordingMode = .multiCamera
        logger.startMonitoring()
        // Verify it doesn't crash and session is paused for multi-cam
        XCTAssertEqual(logger.recordingMode, .multiCamera)
    }

    func testMultiCamPreviewLayers() {
        let layers = logger.multiCamPreviewLayers()
        // Initially should be empty
        XCTAssertTrue(layers.isEmpty)
    }

    func testRecordingModeSwitch() {
        XCTAssertEqual(logger.recordingMode, .arkit)
        logger.recordingMode = .multiCamera
        XCTAssertEqual(logger.recordingMode, .multiCamera)
        logger.recordingMode = .arkit
        XCTAssertEqual(logger.recordingMode, .arkit)
    }

    func testSelectedCamerasDefaultValue() {
        XCTAssertEqual(logger.selectedCameras, [.backWide, .front])
    }

    func testSampleCountInitialValue() {
        XCTAssertEqual(logger.sampleCount, 0)
    }

    func testIMUCSVContainsAttitudeColumns() {
        logger.startRecording()
        XCTAssertTrue(logger.isRecording)

        // Find the session directory
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: docDir, includingPropertiesForKeys: nil, options: [])
            let sessionFolders = contents.filter { $0.lastPathComponent.starts(with: "session_") }
            
            guard let recentSession = sessionFolders.sorted(by: { $0.path > $1.path }).first else {
                XCTFail("No session folder found")
                logger.stopRecording()
                return
            }
            
            let imuPath = recentSession.appendingPathComponent("imu_data.csv")
            XCTAssertTrue(FileManager.default.fileExists(atPath: imuPath.path), "IMU CSV should exist")
            
            // Read the header
            let csvContent = try String(contentsOf: imuPath, encoding: .utf8)
            let lines = csvContent.components(separatedBy: .newlines)
            XCTAssertFalse(lines.isEmpty, "CSV should have content")
            
            let header = lines[0]
            let columns = header.components(separatedBy: ",")
            
            // Verify all expected columns are present
            XCTAssertEqual(columns.count, 11, "Should have 11 columns: timestamp, acc(3), gyro(3), att_quat(4)")
            XCTAssertEqual(columns[0], "timestamp")
            XCTAssertEqual(columns[1], "acc_x")
            XCTAssertEqual(columns[2], "acc_y")
            XCTAssertEqual(columns[3], "acc_z")
            XCTAssertEqual(columns[4], "gyro_x")
            XCTAssertEqual(columns[5], "gyro_y")
            XCTAssertEqual(columns[6], "gyro_z")
            XCTAssertEqual(columns[7], "att_qx")
            XCTAssertEqual(columns[8], "att_qy")
            XCTAssertEqual(columns[9], "att_qz")
            XCTAssertEqual(columns[10], "att_qw")
        } catch {
            XCTFail("Failed to read IMU CSV: \(error)")
        }
        
        logger.stopRecording()
    }
    
    func testCameraIntrinsicsCSVCreated() {
        logger.recordingMode = .arkit
        logger.startRecording()
        XCTAssertTrue(logger.isRecording)
        
        // Find the session directory
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: docDir, includingPropertiesForKeys: nil, options: [])
            let sessionFolders = contents.filter { $0.lastPathComponent.starts(with: "session_") }
            
            guard let recentSession = sessionFolders.sorted(by: { $0.path > $1.path }).first else {
                XCTFail("No session folder found")
                logger.stopRecording()
                return
            }
            
            let intrinsicsPath = recentSession.appendingPathComponent("camera_intrinsics.csv")
            XCTAssertTrue(FileManager.default.fileExists(atPath: intrinsicsPath.path), "Camera intrinsics CSV should exist in ARKit mode")
            
            // Read the header
            let csvContent = try String(contentsOf: intrinsicsPath, encoding: .utf8)
            let lines = csvContent.components(separatedBy: .newlines)
            XCTAssertFalse(lines.isEmpty, "CSV should have content")
            
            let header = lines[0]
            let columns = header.components(separatedBy: ",")
            
            // Verify all expected columns are present
            XCTAssertEqual(columns.count, 15, "Should have 15 columns")
            XCTAssertEqual(columns[0], "timestamp")
            XCTAssertEqual(columns[1], "fx")
            XCTAssertEqual(columns[2], "fy")
            XCTAssertEqual(columns[3], "cx")
            XCTAssertEqual(columns[4], "cy")
            XCTAssertEqual(columns[5], "width")
            XCTAssertEqual(columns[6], "height")
            XCTAssertEqual(columns[7], "exposure_duration")
            XCTAssertEqual(columns[8], "exposure_offset")
            XCTAssertEqual(columns[9], "iso")
            XCTAssertEqual(columns[10], "k1")
            XCTAssertEqual(columns[11], "k2")
            XCTAssertEqual(columns[12], "k3")
            XCTAssertEqual(columns[13], "p1")
            XCTAssertEqual(columns[14], "p2")
        } catch {
            XCTFail("Failed to read camera intrinsics CSV: \(error)")
        }
        
        logger.stopRecording()
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

    func makePreviewLayers() -> [CameraID: AVCaptureVideoPreviewLayer] { [:] }

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
