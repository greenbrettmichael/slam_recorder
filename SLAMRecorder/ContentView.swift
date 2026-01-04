import ARKit
import SceneKit
import SwiftUI

struct ContentView: View {
    // We now initialize SLAMLogger instead of ARManager
    @StateObject var logger = SLAMLogger()

    var body: some View {
        ZStack(alignment: .bottom) {
            if logger.recordingMode == .arkit {
                ARViewContainer(logger: logger)
                    .edgesIgnoringSafeArea(.all)
            } else {
                MultiCamPreviewContainer(logger: logger)
                    .edgesIgnoringSafeArea(.all)
            }

            VStack(spacing: 20) {
                // Mode picker
                Picker("Mode", selection: $logger.recordingMode) {
                    ForEach(RecordingMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                if logger.recordingMode == .multiCamera, !logger.isRecording {
                    CameraSelectionView(selected: $logger.selectedCameras)
                    Text("Up to two cameras are recorded simultaneously (prioritizing Back Wide, then Front).").font(.footnote).foregroundColor(.white).padding(.horizontal)
                }

                // Status Overlay
                VStack {
                    Text(logger.isRecording ? "● RECORDING" : "STANDBY")
                        .font(.headline)
                        .foregroundColor(logger.isRecording ? .red : .yellow)
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(10)
                .padding(.top, 50)

                Spacer()

                // Record Button
                Button(action: {
                    if logger.isRecording {
                        logger.stopRecording()
                    } else {
                        logger.startRecording()
                    }
                }) {
                    Text(logger.isRecording ? "STOP" : "START LOGGING")
                        .font(.title2)
                        .bold()
                        .frame(width: 200, height: 60)
                        .background(logger.isRecording ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(30)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            logger.startMonitoring()
        }
        .onChange(of: logger.recordingMode) {
            logger.startMonitoring()
        }
    }
}

// Helper to bridge the ARSCNView from our Logger to SwiftUI
struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var logger: SLAMLogger

    func makeUIView(context _: Context) -> ARSCNView {
        logger.sceneView
    }

    func updateUIView(_: ARSCNView, context _: Context) {}
}

/// Live preview for multi-camera recording showing all active camera feeds in a grid.
struct MultiCamPreviewContainer: UIViewRepresentable {
    @ObservedObject var logger: SLAMLogger

    func makeUIView(context _: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        updateLayers(in: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context _: Context) {
        updateLayers(in: uiView)
    }

    private func updateLayers(in view: UIView) {
        // Remove existing sublayers
        view.layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        let previewLayers = logger.multiCamPreviewLayers()
        guard !previewLayers.isEmpty else { return }

        let count = previewLayers.count
        let bounds = view.bounds

        // Layout cameras in a grid
        if count == 1 {
            // Single camera: full screen
            if let layer = previewLayers.values.first {
                layer.frame = bounds
                view.layer.addSublayer(layer)
            }
        } else {
            // Multiple cameras: split screen
            let sortedCameras = previewLayers.keys.sorted { $0.displayName < $1.displayName }
            for (index, cameraID) in sortedCameras.enumerated() {
                guard let layer = previewLayers[cameraID] else { continue }

                if count == 2 {
                    // Side by side for 2 cameras
                    let width = bounds.width / 2
                    layer.frame = CGRect(x: CGFloat(index) * width, y: 0, width: width, height: bounds.height)
                } else {
                    // Grid layout for more cameras
                    let cols = 2
                    let rows = (count + cols - 1) / cols
                    let width = bounds.width / CGFloat(cols)
                    let height = bounds.height / CGFloat(rows)
                    let row = index / cols
                    let col = index % cols
                    layer.frame = CGRect(x: CGFloat(col) * width, y: CGFloat(row) * height, width: width, height: height)
                }

                view.layer.addSublayer(layer)

                // Add label for camera identification
                let label = CATextLayer()
                label.string = cameraID.displayName
                label.fontSize = 14
                label.foregroundColor = UIColor.white.cgColor
                label.backgroundColor = UIColor.black.withAlphaComponent(0.6).cgColor
                label.frame = CGRect(x: layer.frame.minX + 8, y: layer.frame.minY + 8, width: 120, height: 24)
                label.contentsScale = UIScreen.main.scale
                view.layer.addSublayer(label)
            }
        }
    }
}

/// Camera selection view for multi-cam recording.
struct CameraSelectionView: View {
    @Binding var selected: Set<CameraID>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cameras (select 1-2)")
                .font(.headline)
                .foregroundColor(.white)
            ForEach(CameraID.allCases, id: \.self) { camera in
                let isSelected = selected.contains(camera)
                let canToggleOn = selected.count < 2 || isSelected
                let canToggleOff = selected.count > 1 || !isSelected

                Toggle(camera.displayName, isOn: Binding<Bool>(
                    get: { isSelected },
                    set: { isOn in
                        if isOn, canToggleOn {
                            selected.insert(camera)
                        } else if !isOn, canToggleOff {
                            selected.remove(camera)
                        }
                    },
                ))
                .toggleStyle(SwitchToggleStyle(tint: .green))
                .foregroundColor(.white)
                .disabled(!canToggleOn && !isSelected)
                .opacity((!canToggleOn && !isSelected) ? 0.5 : 1.0)
            }
            if selected.isEmpty {
                Text("Please select at least one camera")
                    .font(.caption)
                    .foregroundColor(.yellow)
            }
        }
        .padding()
        .background(Color.black.opacity(0.6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}
