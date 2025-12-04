import SwiftUI
import PhotosUI

struct FishIDView: View {
    var initialImage: UIImage?
    var onSpeciesSelected: ((String) -> Void)?
    
    @StateObject private var viewModel = FishIDViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var photoItem: PhotosPickerItem?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
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
                    
                    Text("Take or select a photo to identify the species")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 16)
                
                // Image section
                VStack(spacing: 16) {
                    if let image = viewModel.selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                            )
                        
                        HStack {
                            PhotosPicker(selection: $photoItem, matching: .images) {
                                Label("Change Photo", systemImage: "photo")
                                    .font(.caption)
                            }
                            
                            Spacer()
                            
                            Button {
                                viewModel.reset()
                            } label: {
                                Label("Clear", systemImage: "xmark.circle")
                                    .font(.caption)
                                    .foregroundColor(.coral)
                            }
                        }
                    } else {
                        VStack(spacing: 16) {
                            PhotosPicker(selection: $photoItem, matching: .images) {
                                VStack(spacing: 16) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.purple)
                                    
                                    Text("Add a Photo")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text("Take or select a clear photo of your fish")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(16)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Identify button
                if viewModel.selectedImage != nil {
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
                }
                
                // Result section
                if let result = viewModel.identificationResult {
                    resultSection(result)
                }
                
                // Tips section
                tipsSection
                
                Spacer(minLength: 32)
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
        .onChange(of: photoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    viewModel.setImage(image)
                }
            }
        }
        .onAppear {
            if let image = initialImage {
                viewModel.setImage(image)
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
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

