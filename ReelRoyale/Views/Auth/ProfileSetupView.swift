import SwiftUI
import PhotosUI

struct ProfileSetupView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color.deepOcean, Color.oceanBlue],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Text("Set Up Your Profile")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Let other anglers know who you are")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 40)
                    
                    // Avatar picker
                    VStack(spacing: 16) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            if let image = viewModel.avatarImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.seafoam, lineWidth: 3)
                                    )
                            } else {
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        VStack(spacing: 8) {
                                            Image(systemName: "camera.fill")
                                                .font(.title)
                                            Text("Add Photo")
                                                .font(.caption)
                                        }
                                        .foregroundColor(.white.opacity(0.5))
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                                    )
                            }
                        }
                        .onChange(of: selectedPhotoItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    viewModel.avatarImage = image
                                }
                            }
                        }
                        
                        Text("Tap to add a profile photo")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    // Form fields
                    VStack(spacing: 20) {
                        // Username
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Username")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Text("*")
                                    .foregroundColor(.coral)
                            }
                            
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white.opacity(0.5))
                                
                                TextField("", text: $viewModel.username)
                                    .autocapitalization(.none)
                                    .foregroundColor(.white)
                                    .accentColor(.seafoam)
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        viewModel.username.isEmpty || viewModel.isUsernameValid
                                            ? Color.white.opacity(0.2)
                                            : Color.coral,
                                        lineWidth: 1
                                    )
                            )
                            
                            if !viewModel.username.isEmpty && !viewModel.isUsernameValid {
                                Text("Username must be 3-20 characters")
                                    .font(.caption2)
                                    .foregroundColor(.coral)
                            }
                        }
                        
                        // Home location
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Home Location (optional)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.white.opacity(0.5))
                                
                                TextField("", text: $viewModel.homeLocation)
                                    .foregroundColor(.white)
                                    .accentColor(.seafoam)
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                        
                        // Bio
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bio (optional)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            
                            TextEditor(text: $viewModel.bio)
                                .foregroundColor(.white)
                                .accentColor(.seafoam)
                                .scrollContentBackground(.hidden)
                                .frame(height: 80)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    // Complete button
                    Button {
                        Task {
                            await viewModel.completeProfileSetup()
                        }
                    } label: {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Start Fishing")
                                    .fontWeight(.semibold)
                                Image(systemName: "arrow.right")
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.coral, Color.sunset],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoading || !viewModel.canCompleteProfile)
                    .opacity(viewModel.canCompleteProfile ? 1 : 0.6)
                    .padding(.horizontal, 32)
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

#Preview {
    ProfileSetupView()
}

