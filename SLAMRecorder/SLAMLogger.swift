import ARKit
import AVFoundation
import CoreMotion
import OSLog
import SceneKit
import SwiftUI

/// The main controller for SLAM data recording.
/// This class manages the ARSession, captures IMU data, and coordinates writing to CSV and Video files.
class SLAMLogger: NSObject, ObservableObject, ARSessionDelegate {
    // MARK: - Public Properties

    /// The ARSCNView that hosts the AR session.
    let sceneView = ARSCNView()

    /// Indicates whether recording is currently active.
    @Published var isRecording = false

    /// Determines whether we are recording ARKit or a multi-camera session.
    @Published var recordingMode: RecordingMode = .arkit

    /// Selected cameras when using multi-camera recording.
    @Published var selectedCameras: Set<CameraID> = [.backWide, .front]

    /// The number of video frames captured in the current session.
    @Published var sampleCount = 0

    // MARK: - Private Properties

    private let motionManager = CMMotionManager()

    // Diagnostic Logging
    private let logger: Logger = .init(subsystem: "com.bmgvisualtech.slamrecorder", category: "SLAMLogger")

    // Helpers
    private var imuWriter: CSVWriter?
    private var poseWriter: CSVWriter?
    private let videoRecorder = VideoRecorder()
    private let multiCamRecorder: MultiCamRecording

    private var recordingURL: URL?

    // MARK: - Initialization

    init(multiCamRecorder: MultiCamRecording? = nil) {
        if let recorder = multiCamRecorder {
            self.multiCamRecorder = recorder
        } else if #available(iOS 13.0, *) {
            self.multiCamRecorder = MultiCamRecorder()
        } else {
            self.multiCamRecorder = NoopMultiCamRecorder()
        }
        super.init()
        // Configure the session hosted by the view
        sceneView.session.delegate = self
    }

    // MARK: - Public Methods

    /// Starts the AR session monitoring.
    ///
    /// This method configures and runs the ARWorldTrackingConfiguration for the current AR session.
    /// Call this when the AR view appears to begin session tracking. This does not start recording;
    /// call `startRecording()` separately to begin capturing data.
    ///
    /// - Note: If recording mode is not .arkit, the session will be paused instead.
    func startMonitoring() {
        guard recordingMode == .arkit else {
            sceneView.session.pause()
            return
        }
        let config = ARWorldTrackingConfiguration()
        sceneView.session.run(config, options: [])
    }

    /// Provides preview layers for multi-camera mode if available.
    ///
    /// This method returns a dictionary mapping camera identifiers to their corresponding
    /// AVCaptureVideoPreviewLayer objects for display in the UI.
    ///
    /// - Returns: A dictionary of camera ID to preview layer mappings. Empty if multi-camera is unavailable.
    func multiCamPreviewLayers() -> [CameraID: AVCaptureVideoPreviewLayer] {
        multiCamRecorder.makePreviewLayers()
    }

    /// Starts a new recording session.
    ///
    /// This method creates a timestamped session directory, initializes CSV writers for IMU and pose data,
    /// starts IMU capture at 200Hz, and begins video recording if in ARKit mode.
    /// The recording state is published via the `isRecording` property.
    ///
    /// - Note: Validates camera selection for multi-camera mode and logs errors to the console if recording fails.
    func startRecording() {
        guard !isRecording else { return }

        // Validate camera selection for multi-camera mode
        if recordingMode == .multiCamera {
            guard !selectedCameras.isEmpty, selectedCameras.count <= 2 else {
                print("Invalid camera selection. Please select 1-2 cameras.")
                return
            }
        }

        if setupFiles() {
            startIMU()
            switch recordingMode {
            case .arkit:
                isRecording = true
                sampleCount = 0
                logger.info("AR mode: recording started")
            case .multiCamera:
                guard let dir = recordingURL else { return }
                let success = multiCamRecorder.startRecording(cameras: selectedCameras, directory: dir)
                isRecording = success
                logger.info("Multi-camera mode: recording \(success ? "started" : "failed")")
                if !success {
                    print("Multi-camera recording not supported or failed to start.")
                    motionManager.stopDeviceMotionUpdates()
                    imuWriter?.close()
                    imuWriter = nil
                }
            }
        } else {
            print("Failed to setup files for recording.")
        }
    }

    /// Stops the current recording session.
    ///
    /// This method halts all data capture (IMU, video, and pose data), closes file handles,
    /// flushes buffered writes to disk, and cleans up resources. Call this when you want to
    /// end the current recording and save all data.
    func stopRecording() {
        guard isRecording else { return }

        isRecording = false
        motionManager.stopDeviceMotionUpdates()

        // Close CSVs
        imuWriter?.close()
        poseWriter?.close()
        imuWriter = nil
        poseWriter = nil

        switch recordingMode {
        case .arkit:
            videoRecorder.finish {
                print("Video recording finished.")
            }
        case .multiCamera:
            multiCamRecorder.stopRecording()
        }
    }

    // MARK: - Private Methods

    /// Sets up the directory and files for the new session.
    ///
    /// Creates a timestamped session directory and initializes CSV writers for IMU and pose data.
    /// The session directory path is stored in `recordingURL` for use by video and other recording modes.
    ///
    /// - Returns: `true` if the directory and all necessary file writers were created successfully; `false` otherwise.
    private func setupFiles() -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss-SSS"
        let timestamp = formatter.string(from: Date())

        guard let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            logger.error("Could not get Documents directory")
            return false
        }
        let sessionDir = docDir.appendingPathComponent("session_\(timestamp)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
            recordingURL = sessionDir
            logger.info("Created session directory: \(sessionDir.path)")

            // Setup CSV Writers
            let imuURL = sessionDir.appendingPathComponent("imu_data.csv")
            imuWriter = CSVWriter(url: imuURL, header: "timestamp,acc_x,acc_y,acc_z,gyro_x,gyro_y,gyro_z,att_qx,att_qy,att_qz,att_qw\n")

            if recordingMode == .arkit {
                let poseURL = sessionDir.appendingPathComponent("arkit_groundtruth.csv")
                poseWriter = CSVWriter(url: poseURL, header: "timestamp,tx,ty,tz,qx,qy,qz,qw\n")
            } else {
                poseWriter = nil
            }

            return imuWriter != nil && (recordingMode == .multiCamera || poseWriter != nil)
        } catch {
            print("Error creating session directory: \(error)")
            return false
        }
    }

    /// Starts the IMU data capture.
    ///
    /// Configures the device motion manager to capture accelerometer, gyroscope, and attitude filter data at 200Hz.
    /// Data is written to the CSV file via the buffered background queue, minimizing main thread impact.
    /// Total acceleration (user acceleration + gravity) and attitude quaternions from the device motion filter are captured.
    private func startIMU() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 200.0

        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data, isRecording else { return }

            let csvLine = String(format: "%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
                                 data.timestamp,
                                 data.userAcceleration.x + data.gravity.x,
                                 data.userAcceleration.y + data.gravity.y,
                                 data.userAcceleration.z + data.gravity.z,
                                 data.rotationRate.x,
                                 data.rotationRate.y,
                                 data.rotationRate.z,
                                 data.attitude.quaternion.x,
                                 data.attitude.quaternion.y,
                                 data.attitude.quaternion.z,
                                 data.attitude.quaternion.w)

            imuWriter?.write(row: csvLine)
        }
    }

    // MARK: - ARSessionDelegate

    /// Called when the AR session captures a new frame.
    ///
    /// This is the primary data capture callback that executes at the AR frame rate (typically 30-60 Hz).
    /// For each frame, it captures and writes pose data (camera transform) and video frames.
    /// Operations are optimized to minimize main thread blocking:
    /// - CSV writes are buffered on a background queue with periodic flushing
    /// - Video encoding handles pixel buffers with minimal overhead
    ///
    /// - Parameters:
    ///   - session: The ARSession that updated the frame.
    ///   - frame: The ARFrame containing camera pose, transform matrix, and pixel data.
    func session(_: ARSession, didUpdate frame: ARFrame) {
        guard isRecording, recordingMode == .arkit, let dir = recordingURL else { return }

        if sampleCount == 0 {
            logger.info("First AR frame received, starting to record")
        }

        // Log Pose - offload CSV write to background to reduce main thread load
        let tf = frame.camera.transform
        let poseLine = String(format: "%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
                              frame.timestamp,
                              tf.columns.0.x, tf.columns.0.y, tf.columns.0.z, tf.columns.0.w,
                              tf.columns.1.x, tf.columns.1.y, tf.columns.1.z, tf.columns.1.w,
                              tf.columns.2.x, tf.columns.2.y, tf.columns.2.z, tf.columns.2.w,
                              tf.columns.3.x, tf.columns.3.y, tf.columns.3.z, tf.columns.3.w)

        // CSV write is now buffered on background queue, so this is very fast
        poseWriter?.write(row: poseLine)

        // Handle Video Recording (must be on main thread for pixel buffer handling)
        if !videoRecorder.isWriting {
            let videoURL = dir.appendingPathComponent("video.mov")
            let width = Int(frame.camera.imageResolution.width)
            let height = Int(frame.camera.imageResolution.height)

            if videoRecorder.setup(url: videoURL, width: width, height: height) {
                // Save the start timestamp to a separate file for synchronization
                let startURL = dir.appendingPathComponent("video_start_time.txt")
                try? String(format: "%.6f", frame.timestamp).write(to: startURL, atomically: true, encoding: .utf8)
            }
        }

        videoRecorder.append(pixelBuffer: frame.capturedImage, timestamp: frame.timestamp)
        sampleCount += 1
    }
}
