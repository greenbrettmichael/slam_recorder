import ARKit
import AVFoundation
import CoreMotion
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

    // Helpers
    private var imuWriter: CSVWriter?
    private var poseWriter: CSVWriter?
    private let videoRecorder = VideoRecorder()
    private let multiCamRecorder: MultiCamRecording

    private var recordingURL: URL?

    // MARK: - Initialization

    init(multiCamRecorder: MultiCamRecording = if #available(iOS 13.0, *) {
        MultiCamRecorder()
    } else {
        NoopMultiCamRecorder()
    }) {
        self.multiCamRecorder = multiCamRecorder
        super.init()
        // Configure the session hosted by the view
        sceneView.session.delegate = self
        sceneView.showsStatistics = true
    }

    // MARK: - Public Methods

    /// Starts the AR session monitoring.
    /// This should be called when the view appears.
    func startMonitoring() {
        guard recordingMode == .arkit else {
            sceneView.session.pause()
            return
        }
        let config = ARWorldTrackingConfiguration()
        sceneView.session.run(config, options: [])
    }

    /// Provides a preview layer for multi-camera mode if available.
    func multiCamPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        multiCamRecorder.makePreviewLayer()
    }

    /// Starts a new recording session.
    /// Creates a new directory with the current timestamp and initializes file writers.
    func startRecording() {
        guard !isRecording else { return }

        if setupFiles() {
            startIMU()
            switch recordingMode {
            case .arkit:
                isRecording = true
                sampleCount = 0
            case .multiCamera:
                guard let dir = recordingURL else { return }
                let success = multiCamRecorder.startRecording(cameras: selectedCameras, directory: dir)
                isRecording = success
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
    /// Closes all file handles and finishes video writing.
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
    /// - Returns: True if setup was successful.
    private func setupFiles() -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss-SSS"
        let timestamp = formatter.string(from: Date())

        guard let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return false }
        let sessionDir = docDir.appendingPathComponent("session_\(timestamp)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
            recordingURL = sessionDir

            // Setup CSV Writers
            let imuURL = sessionDir.appendingPathComponent("imu_data.csv")
            imuWriter = CSVWriter(url: imuURL, header: "timestamp,acc_x,acc_y,acc_z,gyro_x,gyro_y,gyro_z\n")

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
    private func startIMU() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 200.0

        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data, isRecording else { return }

            let csvLine = String(format: "%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
                                 data.timestamp,
                                 data.userAcceleration.x + data.gravity.x,
                                 data.userAcceleration.y + data.gravity.y,
                                 data.userAcceleration.z + data.gravity.z,
                                 data.rotationRate.x,
                                 data.rotationRate.y,
                                 data.rotationRate.z)

            imuWriter?.write(row: csvLine)
        }
    }

    // MARK: - ARSessionDelegate

    func session(_: ARSession, didUpdate frame: ARFrame) {
        guard isRecording, recordingMode == .arkit, let dir = recordingURL else { return }

        // Log Pose
        let tf = frame.camera.transform
        let poseLine = String(format: "%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
                              frame.timestamp,
                              tf.columns.0.x, tf.columns.0.y, tf.columns.0.z, tf.columns.0.w,
                              tf.columns.1.x, tf.columns.1.y, tf.columns.1.z, tf.columns.1.w,
                              tf.columns.2.x, tf.columns.2.y, tf.columns.2.z, tf.columns.2.w,
                              tf.columns.3.x, tf.columns.3.y, tf.columns.3.z, tf.columns.3.w)

        poseWriter?.write(row: poseLine)

        // Handle Video Recording
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
