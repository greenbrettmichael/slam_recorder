import ARKit
import CoreMotion
import SceneKit
import SwiftUI
import AVFoundation

class SLAMLogger: NSObject, ObservableObject, ARSessionDelegate {
    // We hold the actual AR View here so we can pass it to the UI
    let sceneView = ARSCNView()
    private let motionManager = CMMotionManager()
    
    // File Handles
    private var imuFileHandle: FileHandle?
    private var poseFileHandle: FileHandle?
    private var recordingURL: URL?
    
    // Video Recording
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var isWriterSessionStarted = false
    
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
        
        if let assetWriter = assetWriter, assetWriter.status == .writing {
            videoInput?.markAsFinished()
            assetWriter.finishWriting { [weak self] in
                self?.assetWriter = nil
                self?.videoInput = nil
                self?.pixelBufferAdaptor = nil
                self?.isWriterSessionStarted = false
            }
        }
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
        
        // Video Recording
        if assetWriter == nil {
            setupVideoWriter(frame: frame, dir: dir)
            
            // Save the start timestamp to a separate file for synchronization
            let startURL = dir.appendingPathComponent("video_start_time.txt")
            try? String(format: "%.6f", frame.timestamp).write(to: startURL, atomically: true, encoding: .utf8)
        }
        
        if let writer = assetWriter, writer.status == .writing, let input = videoInput, input.isReadyForMoreMediaData {
            let timestamp = CMTime(seconds: frame.timestamp, preferredTimescale: 600)
            
            if !isWriterSessionStarted {
                writer.startSession(atSourceTime: timestamp)
                isWriterSessionStarted = true
            }
            
            pixelBufferAdaptor?.append(frame.capturedImage, withPresentationTime: timestamp)
            self.sampleCount += 1
        }
    }
    
    private func setupVideoWriter(frame: ARFrame, dir: URL) {
        let videoURL = dir.appendingPathComponent("video.mov")
        let width = Int(frame.camera.imageResolution.width)
        let height = Int(frame.camera.imageResolution.height)
        
        do {
            assetWriter = try AVAssetWriter(outputURL: videoURL, fileType: .mov)
        } catch {
            print("Failed to create asset writer: \(error)")
            return
        }
        
        let outputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]
        
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        videoInput?.expectsMediaDataInRealTime = true
        
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput!, sourcePixelBufferAttributes: nil)
        
        if assetWriter?.canAdd(videoInput!) == true {
            assetWriter?.add(videoInput!)
        }
        
        assetWriter?.startWriting()
    }
}