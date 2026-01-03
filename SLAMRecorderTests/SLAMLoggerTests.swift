import XCTest
@testable import SLAMRecorder

final class SLAMLoggerTests: XCTestCase {
    
    var logger: SLAMLogger!

    override func setUp() {
        super.setUp()
        logger = SLAMLogger()
    }

    override func tearDown() {
        if logger.isRecording {
            logger.stopRecording()
        }
        logger = nil
        super.tearDown()
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
}
