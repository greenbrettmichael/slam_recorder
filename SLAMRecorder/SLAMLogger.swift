import ARKit
import CoreMotion
import SceneKit
import SwiftUI

class SLAMLogger: NSObject, ObservableObject, ARSessionDelegate {
    // We hold the actual AR View here so we can pass it to the UI
    let sceneView = ARSCNView()
    private let motionManager = CMMotionManager()
    
    // File Handles
    private var imuFileHandle: FileHandle?
    private var poseFileHandle: FileHandle?
    private var recordingURL: URL?
    
    @Published var isRecording = false
    @Published var sampleCount = 0
    
    override init() {
        super.init()
        // Configure the session hosted by the view
        sceneView.session.delegate = self
        sceneView.showsStatistics = true
    }
    
    func startMonitoring() {
        // Start ARKit so we can see the camera
        let config = ARWorldTrackingConfiguration()
        sceneView.session.run(config, options: [])
    }
    
    func startRecording() {
        setupFiles()
        startIMU()
        isRecording = true
    }
    
    func stopRecording() {
        isRecording = false
        motionManager.stopDeviceMotionUpdates()
        closeFiles()
    }
    
    // MARK: - File Setup (Same as before)
    private func setupFiles() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let sessionDir = docDir.appendingPathComponent("session_\(timestamp)", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        self.recordingURL = sessionDir
        
        // Create CSV Headers
        let imuURL = sessionDir.appendingPathComponent("imu_data.csv")
        let poseURL = sessionDir.appendingPathComponent("arkit_groundtruth.csv")
        
        FileManager.default.createFile(atPath: imuURL.path, contents: "timestamp,acc_x,acc_y,acc_z,gyro_x,gyro_y,gyro_z\n".data(using: .utf8))
        FileManager.default.createFile(atPath: poseURL.path, contents: "timestamp,tx,ty,tz,qx,qy,qz,qw\n".data(using: .utf8))
        
        imuFileHandle = try? FileHandle(forWritingTo: imuURL)
        poseFileHandle = try? FileHandle(forWritingTo: poseURL)
        
        imuFileHandle?.seekToEndOfFile()
        poseFileHandle?.seekToEndOfFile()
    }
    
    private func closeFiles() {
        try? imuFileHandle?.close()
        try? poseFileHandle?.close()
    }
    
    // MARK: - IMU Capture
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
            
            if let bytes = csvLine.data(using: .utf8) {
                self.imuFileHandle?.write(bytes)
            }
        }
    }
    
    // MARK: - Camera & Pose Capture
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isRecording, let dir = recordingURL else { return }
        
        let tf = frame.camera.transform
        let poseLine = String(format: "%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
                              frame.timestamp,
                              tf.columns.0.x, tf.columns.0.y, tf.columns.0.z, tf.columns.0.w,
                              tf.columns.1.x, tf.columns.1.y, tf.columns.1.z, tf.columns.1.w,
                              tf.columns.2.x, tf.columns.2.y, tf.columns.2.z, tf.columns.2.w,
                              tf.columns.3.x, tf.columns.3.y, tf.columns.3.z, tf.columns.3.w)
        
        if let bytes = poseLine.data(using: .utf8) {
            poseFileHandle?.write(bytes)
        }
        
        self.sampleCount += 1
        if self.sampleCount % 5 == 0 {
            saveImage(frame.capturedImage, timestamp: frame.timestamp, dir: dir)
        }
    }
    
    private func saveImage(_ pixelBuffer: CVPixelBuffer, timestamp: TimeInterval, dir: URL) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
            if let data = uiImage.jpegData(compressionQuality: 0.7) {
                let filename = String(format: "frame_%.6f.jpg", timestamp)
                let fileURL = dir.appendingPathComponent(filename)
                try? data.write(to: fileURL)
            }
        }
    }
}