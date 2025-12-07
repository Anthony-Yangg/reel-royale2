import SwiftUI

struct CatchDetailView: View {
    let catchId: String
    @State private var fishCatch: FishCatch?
    @State private var user: User?
    @State private var spot: Spot?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollView {
            if isLoading && fishCatch == nil {
                LoadingView(message: "Loading catch...")
                    .frame(height: 400)
            } else if let fishCatch = fishCatch {
                VStack(spacing: 24) {
                    // Photo
                    CatchPhotoView(photoURL: fishCatch.photoURL)
                        .frame(maxHeight: 350)
                        .padding(.horizontal)
                    
                    // Details card
                    catchDetailsCard(fishCatch)
                    
                    // User info
                    if let user = user {
                        userSection(user, fishCatch: fishCatch)
                    }
                    
                    // Spot info
                    if let spot = spot, !fishCatch.hideExactLocation {
                        spotSection(spot)
                    }
                    
                    // Notes
                    if let notes = fishCatch.notes, !notes.isEmpty {
                        notesSection(notes)
                    }
                    
                    // Metadata
                    metadataSection(fishCatch)
                    
                    Spacer(minLength: 32)
                }
            } else if let error = errorMessage {
                ErrorStateView(message: error) {
                    Task { await loadCatch() }
                }
            }
        }
        .navigationTitle("Catch Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadCatch()
        }
    }
    
    @ViewBuilder
    private func catchDetailsCard(_ fishCatch: FishCatch) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(fishCatch.species)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 8) {
                        Label(fishCatch.sizeDisplay, systemImage: "ruler")
                            .font(.title3)
                            .foregroundColor(.oceanBlue)
                        
                        if fishCatch.measuredWithAR {
                            Label("AR Measured", systemImage: "arkit")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.seafoam)
                                .cornerRadius(8)
                        }
                    }
                }
                
                Spacer()
                
                // Check if this is the current king at the spot
                if spot?.currentBestCatchId == fishCatch.id {
                    VStack(spacing: 4) {
                        CrownBadge(size: .large, isAnimated: true, showGlow: true)
                        Text("King")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.crown)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func userSection(_ user: User, fishCatch: FishCatch) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Caught by")
                    .font(.headline)
                Spacer()
            }
            
            Button {
                appState.profileNavigationPath.append(NavigationDestination.userProfile(userId: user.id))
            } label: {
                HStack(spacing: 16) {
                    UserAvatarView(user: user, size: 50, showCrown: spot?.currentKingUserId == user.id)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.username)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("on \(fishCatch.createdAt.formattedDateTime)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func spotSection(_ spot: Spot) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Location")
                    .font(.headline)
                Spacer()
            }
            
            Button {
                appState.profileNavigationPath.append(NavigationDestination.spotDetail(spotId: spot.id))
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.oceanBlue)
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: spot.waterType?.icon ?? "mappin")
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(spot.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let region = spot.regionName {
                            Text(region)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if spot.hasKing {
                        CrownBadge(size: .small)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func notesSection(_ notes: String) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Notes")
                    .font(.headline)
                Spacer()
            }
            
            Text(notes)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func metadataSection(_ fishCatch: FishCatch) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Details")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 8) {
                metadataRow(label: "Date", value: fishCatch.createdAt.formattedDateTime)
                metadataRow(label: "Visibility", value: fishCatch.visibility.displayName, icon: fishCatch.visibility.icon)
                metadataRow(label: "Location Hidden", value: fishCatch.hideExactLocation ? "Yes" : "No")
                metadataRow(label: "Measured with AR", value: fishCatch.measuredWithAR ? "Yes" : "No")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    private func metadataRow(label: String, value: String, icon: String? = nil) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
    
    private func loadCatch() async {
        isLoading = true
        errorMessage = nil
        
        do {
            fishCatch = try await AppState.shared.catchRepository.getCatch(byId: catchId)
            
            if let fishCatch = fishCatch {
                user = try await AppState.shared.userRepository.getUser(byId: fishCatch.userId)
                if let spotId = fishCatch.spotId {
                    spot = try await AppState.shared.spotRepository.getSpot(byId: spotId)
                } else {
                    spot = nil
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        CatchDetailView(catchId: "test-catch")
            .environmentObject(AppState.shared)
    }
}

