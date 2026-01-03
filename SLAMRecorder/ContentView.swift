import SwiftUI
import ARKit
import SceneKit

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
                
                if logger.recordingMode == .multiCamera && !logger.isRecording {
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
        .onChange(of: logger.recordingMode) { _ in
            logger.startMonitoring()
        }
    }
}

// Helper to bridge the ARSCNView from our Logger to SwiftUI
struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var logger: SLAMLogger
    
    func makeUIView(context: Context) -> ARSCNView {
        return logger.sceneView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}

/// Live preview for multi-camera recording using the multi-cam session's preview layer.
struct MultiCamPreviewContainer: UIViewRepresentable {
    @ObservedObject var logger: SLAMLogger
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        if let layer = logger.multiCamPreviewLayer() {
            layer.frame = UIScreen.main.bounds
            view.layer.addSublayer(layer)
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = logger.multiCamPreviewLayer() {
            layer.frame = uiView.bounds
            if layer.superlayer == nil {
                uiView.layer.addSublayer(layer)
            }
        }
    }
}

/// Camera selection view for multi-cam recording.
struct CameraSelectionView: View {
    @Binding var selected: Set<CameraID>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cameras")
                .font(.headline)
                .foregroundColor(.white)
            ForEach(CameraID.allCases, id: \.self) { camera in
                Toggle(camera.displayName, isOn: Binding<Bool>(
                    get: { selected.contains(camera) },
                    set: { isOn in
                        if isOn {
                            selected.insert(camera)
                        } else {
                            selected.remove(camera)
                        }
                    }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .green))
                .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.black.opacity(0.6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}