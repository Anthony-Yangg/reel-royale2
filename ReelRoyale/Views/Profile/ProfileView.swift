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
                VStack(spacing: 16) {
                    // Always-on progression header (XP, rank, coins)
                    progressionHeader(user)
                        .padding(.horizontal)

                    // Quick-access shortcuts (codex/shop/challenges/notifications)
                    if viewModel.isCurrentUser {
                        shortcutGrid
                            .padding(.horizontal)
                    }

                    // Rich profile (bio, stats, crowned spots, recent catches)
                    profileBlock(user)
                }
                .padding(.bottom, 32)
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
                    Button { viewModel.startEditing() } label: {
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

    // MARK: - Progression header

    @ViewBuilder
    private func progressionHeader(_ user: User) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                UserAvatarView(user: user, size: 80, showCrown: viewModel.stats.crownedSpots > 0)
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.username.isEmpty ? "Set username" : user.username)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    HStack(spacing: 8) {
                        Image(systemName: user.rankTier.icon)
                            .foregroundColor(.crown)
                        Text(user.rankTier.rawValue)
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    if let location = user.homeLocation {
                        Label(location, systemImage: "location.fill")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                Spacer()
            }

            // XP progress bar
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(user.xp) XP")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    if let toNext = user.rankTier.xpToNext(currentXP: user.xp) {
                        Text("\(toNext) to next rank")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    } else {
                        Text("Top tier reached")
                            .font(.caption)
                            .foregroundColor(.crown)
                    }
                }
                ProgressView(value: user.rankTier.progress(xp: user.xp))
                    .tint(.crown)
            }

            // Coins + season score chips
            HStack(spacing: 12) {
                statChip(icon: "circle.hexagongrid.fill", value: "\(user.lureCoins)", label: "Coins", color: .crown)
                statChip(icon: "flag.checkered", value: "\(user.seasonScore)", label: "Season", color: .seafoam)
                statChip(icon: "crown.fill", value: "\(viewModel.stats.crownedSpots)", label: "Crowns", color: .crown)
            }
        }
        .padding(20)
        .background(LinearGradient(colors: [.deepOcean, .oceanBlue], startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(20)
    }

    private func statChip(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.headline)
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
    }

    // MARK: - Shortcuts grid

    private var shortcutGrid: some View {
        let badge = appState.unreadNotifications
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            shortcutTile(title: "Challenges", icon: "checkmark.seal.fill", color: .kelp, destination: .challenges)
            shortcutTile(title: "Codex", icon: "books.vertical.fill", color: .seafoam, destination: .codex)
            shortcutTile(title: "Tackle Shop", icon: "tag.fill", color: .crown, destination: .shop)
            shortcutTile(title: "Notifications", icon: "bell.fill", color: .coral, destination: .notifications, badgeCount: badge)
        }
    }

    private func shortcutTile(title: String, icon: String, color: Color, destination: NavigationDestination, badgeCount: Int = 0) -> some View {
        Button {
            appState.profileNavigationPath.append(destination)
        } label: {
            HStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Circle().fill(color.opacity(0.18)).frame(width: 44, height: 44)
                        Image(systemName: icon).font(.title3).foregroundColor(color)
                    }
                    if badgeCount > 0 {
                        Text("\(badgeCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.coral)
                            .clipShape(Capsule())
                            .offset(x: 4, y: -4)
                    }
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Below-the-fold profile

    @ViewBuilder
    private func profileBlock(_ user: User) -> some View {
        VStack(spacing: 24) {
            if let bio = user.bio, !bio.isEmpty {
                Text(bio)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            statsRow

            crownedSpotsSection
            recentCatchesSection

            if viewModel.isCurrentUser {
                signOutButton
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            statTile(value: "\(viewModel.stats.totalCatches)", label: "Catches", icon: "fish.fill", color: .oceanBlue)
            statTile(value: "\(viewModel.stats.speciesDiscovered)", label: "Species", icon: "books.vertical.fill", color: .seafoam)
            statTile(value: "\(viewModel.stats.ruledTerritories)", label: "Territories", icon: "flag.fill", color: .kelp)
        }
        .padding(.horizontal)
    }

    private func statTile(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundColor(color)
            Text(value).font(.title2).fontWeight(.bold)
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var crownedSpotsSection: some View {
        if !viewModel.crownedSpots.isEmpty {
            VStack(spacing: 12) {
                HStack {
                    Text("Crowned Spots").font(.headline)
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
                                    appState.profileNavigationPath.append(NavigationDestination.spotDetail(spotId: spot.id))
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
                Text("Recent Catches").font(.headline)
                Spacer()
            }
            if viewModel.recentCatches.isEmpty {
                emptyCatchesState
            } else {
                CatchLogView(catches: viewModel.recentCatches)
            }
        }
        .padding(.horizontal)
    }

    private var emptyCatchesState: some View {
        VStack(spacing: 12) {
            Image(systemName: "fish.fill")
                .font(.system(size: 32))
                .foregroundColor(.oceanBlue.opacity(0.5))
            Text(viewModel.isCurrentUser ? "No catches yet" : "No public catches")
                .font(.subheadline)
                .foregroundColor(.secondary)
            if viewModel.isCurrentUser {
                Button {
                    appState.selectedTab = .spots
                } label: {
                    Text("Find your first spot")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.seafoam)
                        .cornerRadius(10)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var signOutButton: some View {
        Button {
            Task { await viewModel.signOut() }
        } label: {
            Text("Sign Out")
                .fontWeight(.medium)
                .foregroundColor(.coral)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.coral.opacity(0.1))
                .cornerRadius(12)
        }
        .padding(.horizontal)
    }
}

struct CrownedSpotCard: View {
    let spot: Spot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [Color.oceanBlue, Color.seafoam],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 140, height: 100)
                    .overlay(
                        Image(systemName: spot.waterType?.icon ?? "drop.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.5))
                    )
                CrownBadge(size: .small)
                    .padding(8)
            }
            Text(spot.name).font(.subheadline).fontWeight(.medium).lineLimit(1)
            if let size = spot.bestCatchDisplay {
                Text(size).font(.caption).foregroundColor(.secondary)
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
                        Text("Bio").font(.caption).foregroundColor(.secondary)
                        TextEditor(text: $viewModel.editBio).frame(minHeight: 80)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { viewModel.cancelEditing() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task { await viewModel.saveProfile() }
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
