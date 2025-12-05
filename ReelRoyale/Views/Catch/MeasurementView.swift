import SwiftUI
import ARKit

struct MeasurementView: View {
    let onCapture: (Double) -> Void
    @StateObject private var viewModel = MeasurementViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // AR View
            if viewModel.isARAvailable {
                ARMeasurementViewRepresentable(viewModel: viewModel)
                    .ignoresSafeArea()
            } else {
                // Fallback for simulator or unsupported devices
                simulatorFallbackView
            }
            
            // Overlay UI
            VStack {
                // Top bar
                HStack {
                    Button {
                        viewModel.stopSession()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    
                    Spacer()
                    
                    if viewModel.measurementState == .completed {
                        Button {
                            viewModel.resetMeasurement()
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(20)
                        }
                    }
                }
                .padding()
                
                Spacer()
                
                // Instructions and measurement display
                VStack(spacing: 16) {
                    // Measurement display
                    if viewModel.currentLength != nil {
                        VStack(spacing: 4) {
                            Text(viewModel.formattedLength)
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text(viewModel.formattedLengthInInches)
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                    }
                    
                    // Instructions
                    Text(viewModel.instructions)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(12)
                    
                    // Capture button
                    if viewModel.canCapture {
                        Button {
                            if let length = viewModel.captureMeasurement() {
                                onCapture(length)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Use This Measurement")
                            }
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color.seafoam, Color.oceanBlue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                        }
                        .padding(.horizontal, 32)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Measure Fish")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
        .task {
            await viewModel.startSession()
        }
        .onDisappear {
            viewModel.stopSession()
        }
    }
    
    @ViewBuilder
    private var simulatorFallbackView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.deepOcean, Color.oceanBlue],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "arkit")
                    .font(.system(size: 60))
                    .foregroundColor(.seafoam)
                
                Text("AR Not Available")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("AR measurement is not available on this device or simulator.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                // Demo slider for simulator testing
                VStack(spacing: 16) {
                    Text("Demo Measurement")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    DemoMeasurementSlider(value: $demoValue)
                    
                    Text(String(format: "%.1f cm", demoValue))
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.seafoam)
                    
                    Button {
                        onCapture(demoValue)
                        dismiss()
                    } label: {
                        Text("Use This Value")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.seafoam)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(16)
                .padding(.horizontal)
            }
        }
    }
    
    @State private var demoValue: Double = 45.0
}

struct DemoMeasurementSlider: View {
    @Binding var value: Double
    
    var body: some View {
        VStack {
            Slider(value: $value, in: 10...150, step: 0.5)
                .accentColor(.seafoam)
            
            HStack {
                Text("10 cm")
                Spacer()
                Text("150 cm")
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal)
    }
}

// MARK: - AR View Representable

struct ARMeasurementViewRepresentable: UIViewRepresentable {
    @ObservedObject var viewModel: MeasurementViewModel
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        arView.delegate = context.coordinator
        arView.debugOptions = [.showFeaturePoints]
        arView.autoenablesDefaultLighting = true
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(context.coordinator.handleTap(_:))
        )
        arView.addGestureRecognizer(tapGesture)
        
        context.coordinator.arView = arView
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
    
    func makeCoordinator() -> ARMeasurementCoordinator {
        ARMeasurementCoordinator(viewModel: viewModel)
    }
}

#Preview {
    MeasurementView { length in
        print("Captured: \(length) cm")
    }
}

