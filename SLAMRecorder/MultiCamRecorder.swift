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
    func makePreviewLayer() -> AVCaptureVideoPreviewLayer?
    func startRecording(cameras: Set<CameraID>, directory: URL) -> Bool
    func stopRecording()
}

/// Concrete implementation that records multiple camera feeds to individual video files.
@available(iOS 13.0, *)
final class MultiCamRecorder: NSObject, MultiCamRecording, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var session: AVCaptureMultiCamSession?
    private var outputMap: [AVCaptureVideoDataOutput: CameraID] = [:]
    private var recorders: [CameraID: VideoRecorder] = [:]
    private var outputURLs: [CameraID: URL] = [:]
    private let queue = DispatchQueue(label: "multicam.capture.queue")
    private(set) var isRecording: Bool = false
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var sessionStartTime: CMTime?
    private var recordingDirectory: URL?

    func makePreviewLayer() -> AVCaptureVideoPreviewLayer? {
        previewLayer
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
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.videoGravity = .resizeAspectFill
        session.beginConfiguration()

        for camera in limited {
            guard let device = camera.resolveDevice(), let input = try? AVCaptureDeviceInput(device: device) else { continue }
            if session.canAddInput(input) { session.addInput(input) }
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
        recorders.removeAll()
        outputMap.removeAll()
        outputURLs.removeAll()
        previewLayer = nil
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
