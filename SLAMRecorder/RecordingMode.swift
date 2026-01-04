import AVFoundation
import Foundation

/// High level recording modes supported by the app.
enum RecordingMode: String, CaseIterable {
    case arkit
    case multiCamera

    var displayName: String {
        switch self {
        case .arkit: "ARKit"
        case .multiCamera: "Multi-Cam"
        }
    }
}

/// Fallback recorder used on platforms that do not support multi-camera recording.
final class NoopMultiCamRecorder: MultiCamRecording {
    var isRecording: Bool = false
    func makePreviewLayers() -> [CameraID: AVCaptureVideoPreviewLayer] { [:] }
    func startRecording(cameras _: Set<CameraID>, directory _: URL) -> Bool { false }
    func stopRecording() { isRecording = false }
}
