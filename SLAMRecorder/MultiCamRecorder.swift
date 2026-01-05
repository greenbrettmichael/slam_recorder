import AVFoundation
import CoreVideo

/// Represents a camera that can be used in a multi-camera recording.
/// Each camera is mapped to a device type and a stable filename suffix.
enum CameraID: CaseIterable, Hashable {
    case backWide
    case backUltraWide
    case backTelephoto
    case front

    var fileNameComponent: String {
        switch self {
        case .backWide: "back_wide"
        case .backUltraWide: "back_ultrawide"
        case .backTelephoto: "back_tele"
        case .front: "front"
        }
    }

    var displayName: String {
        switch self {
        case .backWide: "Back Wide"
        case .backUltraWide: "Back Ultra-Wide"
        case .backTelephoto: "Back Telephoto"
        case .front: "Front"
        }
    }

    var position: AVCaptureDevice.Position {
        switch self {
        case .front: .front
        default: .back
        }
    }

    /// Resolves the appropriate capture device for this camera identifier.
    func resolveDevice() -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType] = switch self {
        case .backWide:
            [.builtInWideAngleCamera]
        case .backUltraWide:
            [.builtInUltraWideCamera]
        case .backTelephoto:
            [.builtInTelephotoCamera]
        case .front:
            [.builtInWideAngleCamera]
        }
        return AVCaptureDevice.default(deviceTypes.first!, for: .video, position: position)
    }
}

/// Protocol abstraction for multi-camera recording to enable testing with mocks.
protocol MultiCamRecording {
    var isRecording: Bool { get }
    func makePreviewLayers() -> [CameraID: AVCaptureVideoPreviewLayer]
    func startRecording(cameras: Set<CameraID>, directory: URL) -> Bool
    func stopRecording()
}

/// Concrete implementation that records multiple camera feeds to individual video files.
@available(iOS 13.0, *)
final class MultiCamRecorder: NSObject, MultiCamRecording, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var session: AVCaptureMultiCamSession?
    private var outputMap: [AVCaptureVideoDataOutput: CameraID] = [:]
    private var recorders: [CameraID: VideoRecorder] = [:]
    private var intrinsicsWriters: [CameraID: CSVWriter] = [:]
    private var deviceMap: [CameraID: AVCaptureDevice] = [:]
    private var outputURLs: [CameraID: URL] = [:]
    private let queue = DispatchQueue(label: "multicam.capture.queue")
    private(set) var isRecording: Bool = false
    private var previewLayers: [CameraID: AVCaptureVideoPreviewLayer] = [:]
    private var sessionStartTime: CMTime?
    private var recordingDirectory: URL?

    func makePreviewLayers() -> [CameraID: AVCaptureVideoPreviewLayer] {
        previewLayers
    }

    func startRecording(cameras: Set<CameraID>, directory: URL) -> Bool {
        guard AVCaptureMultiCamSession.isMultiCamSupported else { return false }
        let requested = cameras.isEmpty ? Set(CameraID.allCases) : cameras
        let limited = Self.limitedCameraSet(from: requested)
        guard !limited.isEmpty else { return false }
        let session = AVCaptureMultiCamSession()
        self.session = session
        recordingDirectory = directory
        outputURLs = Self.makeOutputURLs(for: limited, in: directory)
        outputMap.removeAll()
        recorders.removeAll()
        sessionStartTime = nil
        previewLayers.removeAll()
        session.beginConfiguration()

        for camera in limited {
            guard let device = camera.resolveDevice(), let input = try? AVCaptureDeviceInput(device: device) else { continue }
            
            // Configure device format to 1920x1440 if available
            configureDeviceFormat(device, targetWidth: 1920, targetHeight: 1440)
            
            deviceMap[camera] = device
            if session.canAddInput(input) { session.addInput(input) }
            
            // Create intrinsics CSV writer for this camera
            let intrinsicsURL = directory.appendingPathComponent("camera_\(camera.fileNameComponent)_intrinsics.csv")
            let intrinsicsWriter = CSVWriter(url: intrinsicsURL, header: "timestamp,fx,fy,cx,cy,width,height,exposure_duration,iso\n")
            intrinsicsWriters[camera] = intrinsicsWriter

            // Create individual preview layer for this camera
            let previewLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
            previewLayer.videoGravity = .resizeAspectFill
            if let port = input.ports.first {
                let connection = AVCaptureConnection(inputPort: port, videoPreviewLayer: previewLayer)
                if session.canAddConnection(connection) {
                    session.addConnection(connection)
                    previewLayers[camera] = previewLayer
                }
            }
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = false
            output.setSampleBufferDelegate(self, queue: queue)
            if session.canAddOutput(output) {
                session.addOutput(output)
                outputMap[output] = camera
            }
        }
        session.commitConfiguration()
        guard !outputMap.isEmpty else { return false }
        session.startRunning()
        isRecording = true
        return true
    }

    func stopRecording() {
        guard isRecording else { return }
        session?.stopRunning()
        session = nil
        isRecording = false
        let group = DispatchGroup()
        for recorder in recorders.values {
            group.enter()
            recorder.finish {
                group.leave()
            }
        }
        group.wait()
        for writer in intrinsicsWriters.values {
            writer.close()
        }
        recorders.removeAll()
        intrinsicsWriters.removeAll()
        deviceMap.removeAll()
        outputMap.removeAll()
        outputURLs.removeAll()
        previewLayers.removeAll()
        sessionStartTime = nil
        recordingDirectory = nil
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from _: AVCaptureConnection) {
        guard let videoOutput = output as? AVCaptureVideoDataOutput,
              let cameraID = outputMap[videoOutput],
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              isRecording else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let seconds = CMTimeGetSeconds(timestamp)
        if sessionStartTime == nil {
            sessionStartTime = timestamp
            // Persist a single shared start time for all camera files.
            if let dir = recordingDirectory {
                let startFile = dir.appendingPathComponent("video_start_time.txt")
                let content = String(format: "%.6f", CMTimeGetSeconds(timestamp))
                try? content.write(to: startFile, atomically: true, encoding: .utf8)
            }
        }
        if recorders[cameraID] == nil {
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            if let url = outputURLs[cameraID] {
                let recorder = VideoRecorder()
                if recorder.setup(url: url, width: width, height: height) {
                    if let startTime = sessionStartTime {
                        recorder.setPreferredStartTime(startTime)
                    }
                    recorders[cameraID] = recorder
                }
            }
        }
        recorders[cameraID]?.append(pixelBuffer: pixelBuffer, timestamp: seconds)
        
        // Record camera intrinsics
        if let device = deviceMap[cameraID] {
            recordIntrinsics(for: cameraID, device: device, pixelBuffer: pixelBuffer, timestamp: seconds)
        }
    }
    
    private func recordIntrinsics(for cameraID: CameraID, device: AVCaptureDevice, pixelBuffer: CVPixelBuffer, timestamp: Double) {
        guard let writer = intrinsicsWriters[cameraID] else { return }
        
        let width = Float(CVPixelBufferGetWidth(pixelBuffer))
        let height = Float(CVPixelBufferGetHeight(pixelBuffer))
        
        // Calculate focal length in pixels from device field of view
        let fovRadians = device.activeFormat.videoFieldOfView * .pi / 180.0
        let focalLengthPixels = Float(width) / (2.0 * tan(fovRadians / 2.0))
        let fx = focalLengthPixels
        let fy = focalLengthPixels
        
        // Principal point (optical center) - typically at image center
        let cx = width / 2.0
        let cy = height / 2.0
        
        // Exposure duration in seconds
        let exposureDuration = Float(CMTimeGetSeconds(device.exposureDuration))
        
        // ISO from device
        let iso = device.iso
        
        let intrinsicsLine = String(format: "%.6f,%.6f,%.6f,%.6f,%.6f,%.1f,%.1f,%.9f,%.1f\n",
                                     timestamp,
                                     fx, fy, cx, cy,
                                     width, height,
                                     exposureDuration,
                                     iso)
        
        writer.write(row: intrinsicsLine)
    }
    
    private func configureDeviceFormat(_ device: AVCaptureDevice, targetWidth: Int, targetHeight: Int) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            
            // Find the best format matching the target resolution
            var bestFormat: AVCaptureDevice.Format?
            var bestDifference = Int.max
            
            for format in device.formats {
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                let width = Int(dimensions.width)
                let height = Int(dimensions.height)
                
                // Calculate how close this format is to our target
                let widthDiff = abs(width - targetWidth)
                let heightDiff = abs(height - targetHeight)
                let totalDiff = widthDiff + heightDiff
                
                // Prefer exact match or closest match
                if totalDiff < bestDifference {
                    bestDifference = totalDiff
                    bestFormat = format
                }
            }
            
            if let format = bestFormat {
                device.activeFormat = format
                // Set frame rate to max supported for the format
                if let frameRateRange = format.videoSupportedFrameRateRanges.first {
                    let maxFrameRate = frameRateRange.maxFrameRate
                    device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(maxFrameRate))
                    device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(maxFrameRate))
                }
            }
        } catch {
            print("Failed to configure device format: \(error)")
        }
    }

    static func makeOutputURLs(for cameras: Set<CameraID>, in directory: URL) -> [CameraID: URL] {
        var dict: [CameraID: URL] = [:]
        for cam in cameras {
            dict[cam] = directory.appendingPathComponent("camera_\(cam.fileNameComponent).mov")
        }
        return dict
    }

    /// Limit the requested cameras to the maximum supported by AVCaptureMultiCamSession.
    /// On iPhone this is typically 2 active cameras.
    static func limitedCameraSet(from requested: Set<CameraID>) -> Set<CameraID> {
        let priority: [CameraID] = [.backWide, .front, .backUltraWide, .backTelephoto]
        var result: [CameraID] = []
        for cam in priority where requested.contains(cam) {
            result.append(cam)
            if result.count >= 2 { break }
        }
        return Set(result)
    }
}
