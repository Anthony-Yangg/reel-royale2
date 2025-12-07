import SwiftUI

struct FishIDView: View {
    var initialImage: UIImage?
    var onSpeciesSelected: ((String) -> Void)?
    
    @StateObject private var viewModel = FishIDViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let image = viewModel.selectedImage {
                ScrollView {
                    VStack(spacing: 24) {
                        header
                        
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                            )
                            .padding(.horizontal)
                        
                        actionButtons
                        
                        if let result = viewModel.identificationResult {
                            resultSection(result)
                            resultActions(result)
                        }
                        
                        tipsSection
                        
                        Spacer(minLength: 32)
                    }
                }
            }
        }
        .navigationTitle("Fish ID")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if onSpeciesSelected != nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let image = initialImage {
                viewModel.setImage(image)
            }
            viewModel.showCamera = true
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .fullScreenCover(isPresented: $viewModel.showCamera) {
            ZStack {
                CameraPicker(
                    image: Binding(
                        get: { viewModel.selectedImage },
                        set: { newValue in
                            if let image = newValue {
                                viewModel.setImage(image)
                            }
                        }
                    )
                )
                .ignoresSafeArea()
                
                VStack(spacing: 12) {
                    instructionBox(text: "Frame the entire fish within the viewfinder.")
                    instructionBox(text: "Keep the camera steady and avoid glare.")
                    instructionBox(text: "Use good lighting for best accuracy.")
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }
    
    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("AI Fish Identification")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Capture a clear photo to identify the species")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 16)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await viewModel.identifyFish()
                }
            } label: {
                HStack {
                    if viewModel.isIdentifying {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "sparkles")
                        Text("Identify Fish")
                    }
                }
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(viewModel.isIdentifying)
            .padding(.horizontal)
            
            Button {
                viewModel.reset()
                viewModel.showCamera = true
            } label: {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Retake Photo")
                }
                .fontWeight(.semibold)
                .foregroundColor(.purple)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.purple.opacity(0.12))
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private func resultActions(_ result: FishIDResult) -> some View {
        VStack(spacing: 12) {
            Button {
                if let onSelect = onSpeciesSelected {
                    onSelect(result.species)
                } else {
                    viewModel.errorMessage = "Add to log is unavailable here"
                    viewModel.showError = true
                }
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add to Log")
                }
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.green)
                .cornerRadius(12)
            }
            
            Button {
                viewModel.reset()
                viewModel.showCamera = true
            } label: {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Take Another Picture")
                }
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }
    
    private func instructionBox(text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundColor(.white)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.55))
            .cornerRadius(10)
    }
    
    @ViewBuilder
    private func resultSection(_ result: FishIDResult) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Identification Result")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 12) {
                // Main result
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.species)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 4) {
                            Text("Confidence:")
                            Text(result.confidencePercentage)
                                .fontWeight(.semibold)
                                .foregroundColor(viewModel.confidenceColor)
                        }
                        .font(.subheadline)
                    }
                    
                    Spacer()
                    
                    // Confidence indicator
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        
                        Circle()
                            .trim(from: 0, to: result.confidence)
                            .stroke(viewModel.confidenceColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        
                        Image(systemName: result.isHighConfidence ? "checkmark" : "questionmark")
                            .foregroundColor(viewModel.confidenceColor)
                    }
                    .frame(width: 50, height: 50)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Use this species button
                if let onSelect = onSpeciesSelected {
                    Button {
                        onSelect(result.species)
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Use \"\(result.species)\"")
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                }
                
                // Alternative species
                if !result.alternativeSpecies.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Other possibilities:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ForEach(result.alternativeSpecies, id: \.species) { alt in
                            HStack {
                                Text(alt.species)
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                Text("\(Int(alt.confidence * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if onSpeciesSelected != nil {
                                    Button {
                                        onSpeciesSelected?(alt.species)
                                    } label: {
                                        Text("Use")
                                            .font(.caption)
                                            .foregroundColor(.oceanBlue)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tips for Better Results")
                    .font(.headline)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                tipRow(icon: "sun.max", text: "Use good lighting")
                tipRow(icon: "camera.aperture", text: "Get close to the fish")
                tipRow(icon: "arrow.up.forward", text: "Show the full fish if possible")
                tipRow(icon: "paintbrush", text: "Make sure colors are visible")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        FishIDView()
    }
}

