import Foundation
import AVFoundation

/// High level recording modes supported by the app.
enum RecordingMode: String, CaseIterable {
    case arkit
    case multiCamera
    
    var displayName: String {
        switch self {
        case .arkit: return "ARKit"
        case .multiCamera: return "Multi-Cam"
        }
    }
}

/// Fallback recorder used on platforms that do not support multi-camera recording.
final class NoopMultiCamRecorder: MultiCamRecording {
    var isRecording: Bool = false
    func makePreviewLayer() -> AVCaptureVideoPreviewLayer? { return nil }
    func startRecording(cameras: Set<CameraID>, directory: URL) -> Bool { return false }
    func stopRecording() { isRecording = false }
}
