import AVFoundation
import CoreVideo

/// A helper class to manage video recording using AVAssetWriter.
///
/// This class encapsulates the complexity of setting up the `AVAssetWriter`, `AVAssetWriterInput`,
/// and `AVAssetWriterInputPixelBufferAdaptor`. It handles the session lifecycle (start/finish)
/// and provides a simple interface for appending pixel buffers.
class VideoRecorder {
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var isSessionStarted = false
    
    /// Checks if the recorder is currently in a writing state.
    var isWriting: Bool {
        return assetWriter?.status == .writing
    }
    
    /// Configures and prepares the video writer for recording.
    ///
    /// - Parameters:
    ///   - url: The file URL where the video will be saved. Must be a valid file path.
    ///   - width: The width of the video in pixels.
    ///   - height: The height of the video in pixels.
    /// - Returns: `true` if the writer was successfully initialized and started; `false` otherwise.
    func setup(url: URL, width: Int, height: Int) -> Bool {
        do {
            assetWriter = try AVAssetWriter(outputURL: url, fileType: .mov)
        } catch {
            print("Failed to create asset writer: \(error)")
            return false
        }
        
        let outputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]
        
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        guard let videoInput = videoInput else { return false }
        
        videoInput.expectsMediaDataInRealTime = true
        
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: nil)
        
        if assetWriter?.canAdd(videoInput) == true {
            assetWriter?.add(videoInput)
            return assetWriter?.startWriting() ?? false
        }
        
        return false
    }
    
    /// Appends a frame to the video.
    /// - Parameters:
    ///   - pixelBuffer: The image buffer.
    ///   - timestamp: The presentation timestamp.
    func append(pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) {
        guard let writer = assetWriter, writer.status == .writing,
              let input = videoInput, input.isReadyForMoreMediaData,
              let adaptor = pixelBufferAdaptor else { return }
        
        let cmTime = CMTime(seconds: timestamp, preferredTimescale: 600)
        
        if !isSessionStarted {
            writer.startSession(atSourceTime: cmTime)
            isSessionStarted = true
        }
        
        adaptor.append(pixelBuffer, withPresentationTime: cmTime)
    }
    
    /// Finishes writing the video.
    /// - Parameter completion: Called when writing is finished.
    func finish(completion: @escaping () -> Void) {
        guard let writer = assetWriter, writer.status == .writing else {
            completion()
            return
        }
        
        videoInput?.markAsFinished()
        writer.finishWriting { [weak self] in
            self?.assetWriter = nil
            self?.videoInput = nil
            self?.pixelBufferAdaptor = nil
            self?.isSessionStarted = false
            completion()
        }
    }
}
