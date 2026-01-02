import SwiftUI
import ARKit
import SceneKit

struct ContentView: View {
    // We now initialize SLAMLogger instead of ARManager
    @StateObject var logger = SLAMLogger()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Display the camera feed
            ARViewContainer(logger: logger)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // Status Overlay
                VStack {
                    Text(logger.isRecording ? "● RECORDING" : "STANDBY")
                        .font(.headline)
                        .foregroundColor(logger.isRecording ? .red : .yellow)
                    
                    Text("Frames: \(logger.sampleCount)")
                        .foregroundColor(.white)
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