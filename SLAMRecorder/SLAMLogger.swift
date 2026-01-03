import ARKit
import CoreMotion
import SceneKit
import SwiftUI
import AVFoundation

/// The main controller for SLAM data recording.
/// This class manages the ARSession, captures IMU data, and coordinates writing to CSV and Video files.
class SLAMLogger: NSObject, ObservableObject, ARSessionDelegate {
    // MARK: - Public Properties
    
    /// The ARSCNView that hosts the AR session.
    let sceneView = ARSCNView()
    
    /// Indicates whether recording is currently active.
    @Published var isRecording = false
    
    /// The number of video frames captured in the current session.
    @Published var sampleCount = 0
    
    // MARK: - Private Properties
    
    private let motionManager = CMMotionManager()
    
    // Helpers
    private var imuWriter: CSVWriter?
    private var poseWriter: CSVWriter?
    private let videoRecorder = VideoRecorder()
    
    private var recordingURL: URL?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        // Configure the session hosted by the view
        sceneView.session.delegate = self
        sceneView.showsStatistics = true
    }
    
    // MARK: - Public Methods
    
    /// Starts the AR session monitoring.
    /// This should be called when the view appears.
    func startMonitoring() {
        let config = ARWorldTrackingConfiguration()
        sceneView.session.run(config, options: [])
    }
    
    /// Starts a new recording session.
    /// Creates a new directory with the current timestamp and initializes file writers.
    func startRecording() {
        guard !isRecording else { return }
        
        if setupFiles() {
            startIMU()
            isRecording = true
            sampleCount = 0
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
        
        // Finish Video
        videoRecorder.finish {
            print("Video recording finished.")
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
            self.recordingURL = sessionDir
            
            // Setup CSV Writers
            let imuURL = sessionDir.appendingPathComponent("imu_data.csv")
            let poseURL = sessionDir.appendingPathComponent("arkit_groundtruth.csv")
            
            imuWriter = CSVWriter(url: imuURL, header: "timestamp,acc_x,acc_y,acc_z,gyro_x,gyro_y,gyro_z\n")
            poseWriter = CSVWriter(url: poseURL, header: "timestamp,tx,ty,tz,qx,qy,qz,qw\n")
            
            return imuWriter != nil && poseWriter != nil
        } catch {
            print("Error creating session directory: \(error)")
            return false
        }
    }
    
    /// Starts the IMU data capture.
    private func startIMU() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 200.0
        
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (data, error) in
            guard let self = self, let data = data, self.isRecording else { return }
            
            let csvLine = String(format: "%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
                                 data.timestamp,
                                 data.userAcceleration.x + data.gravity.x,
                                 data.userAcceleration.y + data.gravity.y,
                                 data.userAcceleration.z + data.gravity.z,
                                 data.rotationRate.x,
                                 data.rotationRate.y,
                                 data.rotationRate.z)
            
            self.imuWriter?.write(row: csvLine)
        }
    }
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isRecording, let dir = recordingURL else { return }
        
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
        self.sampleCount += 1
    }
}