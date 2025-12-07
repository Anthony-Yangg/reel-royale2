import SwiftUI

struct ProfileView: View {
    let userId: String?
    @StateObject private var viewModel: ProfileViewModel
    @EnvironmentObject var appState: AppState
    
    init(userId: String? = nil) {
        self.userId = userId
        _viewModel = StateObject(wrappedValue: ProfileViewModel(userId: userId))
    }
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.user == nil {
                LoadingView(message: "Loading profile...")
                    .frame(height: 400)
            } else if let user = viewModel.user {
                VStack(spacing: 24) {
                    // Profile header
                    profileHeader(user)
                    
                    // Stats
                    statsSection
                    
                    // Crowned spots
                    crownedSpotsSection
                    
                    // Recent catches
                    recentCatchesSection
                    
                    // Sign out button (only for current user)
                    if viewModel.isCurrentUser {
                        signOutButton
                    }
                    
                    Spacer(minLength: 32)
                }
            } else if let error = viewModel.errorMessage {
                ErrorStateView(message: error) {
                    Task { await viewModel.loadProfile() }
                }
            }
        }
        .navigationTitle(viewModel.isCurrentUser ? "Profile" : viewModel.displayName)
        .navigationBarTitleDisplayMode(viewModel.isCurrentUser ? .large : .inline)
        .toolbar {
            if viewModel.isCurrentUser {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.startEditing()
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                            .foregroundColor(.seafoam)
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.isEditing) {
            ProfileEditSheet(viewModel: viewModel)
        }
        .task {
            await viewModel.loadProfile()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
    
    @ViewBuilder
    private func profileHeader(_ user: User) -> some View {
        VStack(spacing: 16) {
            UserAvatarView(
                user: user,
                size: 100,
                showCrown: viewModel.stats.crownedSpots > 0
            )
            
            VStack(spacing: 4) {
                Text(user.username)
                    .font(.title)
                    .fontWeight(.bold)
                
                if let location = user.homeLocation {
                    Label(location, systemImage: "location.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let bio = user.bio {
                    Text(bio)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            }
            
            Text("Member since \(user.createdAt.formattedDate)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    @ViewBuilder
    private var statsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Stats")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 16) {
                statCard(
                    value: "\(viewModel.stats.totalCatches)",
                    label: "Catches",
                    icon: "fish.fill",
                    color: .oceanBlue
                )
                
                statCard(
                    value: "\(viewModel.stats.crownedSpots)",
                    label: "Crowns",
                    icon: "crown.fill",
                    color: .crown
                )
                
                statCard(
                    value: "\(viewModel.stats.ruledTerritories)",
                    label: "Territories",
                    icon: "flag.fill",
                    color: .kelp
                )
            }
            
            // Extra stats row
            HStack(spacing: 16) {
                if let size = viewModel.stats.largestCatch,
                   let unit = viewModel.stats.largestCatchUnit {
                    extraStatItem(
                        title: "Largest Catch",
                        value: String(format: "%.1f %@", size, unit)
                    )
                }
                
                if let species = viewModel.stats.favoriteSpecies {
                    extraStatItem(
                        title: "Favorite Species",
                        value: species
                    )
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.cardWhite)
                .shadow(color: color.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(color.opacity(0.2), lineWidth: 2)
        )
    }
    
    private func extraStatItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardWhite)
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
        )
    }
    
    @ViewBuilder
    private var crownedSpotsSection: some View {
        if !viewModel.crownedSpots.isEmpty {
            VStack(spacing: 12) {
                HStack {
                    Text("Crowned Spots")
                        .font(.headline)
                    
                    CrownBadge(size: .small)
                    
                    Spacer()
                    
                    Text("\(viewModel.crownedSpots.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.crownedSpots) { spot in
                            CrownedSpotCard(spot: spot)
                                .onTapGesture {
                                    appState.profileNavigationPath.append(
                                        NavigationDestination.spotDetail(spotId: spot.id)
                                    )
                                }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var recentCatchesSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Recent Catches")
                    .font(.headline)
                Spacer()
            }
            
            if viewModel.recentCatches.isEmpty {
                Text("No catches yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                CatchLogView(catches: viewModel.recentCatches)
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var signOutButton: some View {
        Button {
            Task {
                await viewModel.signOut()
            }
        } label: {
            HStack {
                Image(systemName: "arrow.right.circle.fill")
                Text("Sign Out")
            }
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(.coralAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(Color.coralAccent.opacity(0.12))
            )
        }
        .padding(.horizontal)
    }
}

struct CrownedSpotCard: View {
    let spot: Spot
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                // Spot image or placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.oceanBlue, Color.seafoam],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 100)
                    .overlay(
                        Image(systemName: spot.waterType?.icon ?? "drop.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.5))
                    )
                
                CrownBadge(size: .small)
                    .padding(8)
            }
            
            Text(spot.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            
            if let size = spot.bestCatchDisplay {
                Text(size)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 140)
    }
}

struct ProfileEditSheet: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Profile Info") {
                    TextField("Username", text: $viewModel.editUsername)
                    TextField("Home Location", text: $viewModel.editHomeLocation)
                    
                    VStack(alignment: .leading) {
                        Text("Bio")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $viewModel.editBio)
                            .frame(minHeight: 80)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        viewModel.cancelEditing()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.saveProfile()
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AppState.shared)
    }
}

