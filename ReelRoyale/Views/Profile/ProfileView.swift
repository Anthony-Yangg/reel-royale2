import SwiftUI

struct ProfileView: View {
    let userId: String?
    @StateObject private var viewModel: ProfileViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.reelTheme) private var theme

    init(userId: String? = nil) {
        self.userId = userId
        _viewModel = StateObject(wrappedValue: ProfileViewModel(userId: userId))
    }

    var body: some View {
        ZStack {
            theme.colors.surface.canvas.ignoresSafeArea()

            ScrollView {
                if viewModel.isLoading && viewModel.user == nil {
                    LoadingView(message: "Loading captain's log...")
                        .frame(height: 400)
                } else if let user = viewModel.user {
                    VStack(spacing: theme.spacing.lg) {
                        captainHero(user: user)
                        statsRow
                        trophyCase
                        crownedSpotsSection
                        recentCatchesSection
                        if viewModel.isCurrentUser {
                            signOutButton
                        }
                    }
                    .padding(.horizontal, theme.spacing.m)
                    .padding(.top, theme.spacing.m)
                    .padding(.bottom, 140)
                } else if let error = viewModel.errorMessage {
                    ErrorStateView(message: error) {
                        Task { await viewModel.loadProfile() }
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $viewModel.isEditing) {
            ProfileEditSheet(viewModel: viewModel)
        }
        .task { await viewModel.loadProfile() }
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Hero

    private func captainHero(user: User) -> some View {
        VStack(spacing: theme.spacing.m) {
            ZStack {
                LinearGradient(
                    colors: [theme.colors.brand.deepSea, theme.colors.surface.elevatedAlt],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: theme.radius.heroCard, style: .continuous))

                // Animated wave band behind the avatar for depth
                VStack {
                    Spacer()
                    WaveStrip()
                        .frame(height: 60)
                        .opacity(0.6)
                }
                .frame(height: 220)
                .allowsHitTesting(false)

                VStack(spacing: 8) {
                    ShipAvatar(
                        imageURL: user.avatarURL.flatMap(URL.init),
                        initial: user.username,
                        tier: .deckhand,
                        size: .hero,
                        showCrown: viewModel.stats.crownedSpots > 0,
                        waveBob: true
                    )
                    .shadow(color: theme.colors.brand.crown.opacity(0.3), radius: 18)
                    Text(user.username)
                        .font(theme.typography.title1)
                        .foregroundStyle(theme.colors.text.primary)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.7), radius: 2)
                    TierEmblem(tier: .deckhand, division: 1, size: .medium)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.heroCard, style: .continuous)
                    .strokeBorder(theme.colors.brand.brassGold.opacity(0.3), lineWidth: 1)
            )
            .reelShadow(theme.shadow.heroCard)

            if viewModel.isCurrentUser {
                GhostButton(title: "Edit Captain", icon: "pencil", fullWidth: true) {
                    viewModel.startEditing()
                }
            }
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            SectionHeader(title: "Captain's Log", subtitle: "Career stats")
            HStack(spacing: theme.spacing.s) {
                StatTile(label: "Crowns",      value: "\(viewModel.stats.crownedSpots)",                 icon: "crown.fill", tint: theme.colors.brand.crown)
                StatTile(label: "Catches",     value: "\(viewModel.stats.totalCatches)",                 icon: "fish.fill",  tint: theme.colors.brand.seafoam)
                StatTile(label: "Territories", value: "\(viewModel.stats.ruledTerritories)",             icon: "flag.fill",  tint: theme.colors.brand.brassGold)
                StatTile(label: "Best",        value: bestCatchString,                                   icon: "trophy.fill", tint: theme.colors.brand.crown)
            }
        }
    }

    private var bestCatchString: String {
        if let s = viewModel.stats.largestCatch, let u = viewModel.stats.largestCatchUnit {
            return "\(Int(s))\(u)"
        }
        return "—"
    }

    // MARK: - Trophy Case (Wave 5 mock — real persistence Wave 6)

    private var trophyCase: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            SectionHeader(title: "Trophy Case", subtitle: "Achievements")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: theme.spacing.s) {
                AchievementTile(title: "First Catch",   icon: "checkmark.seal.fill", unlocked: viewModel.stats.totalCatches >= 1, rarity: .bronze)
                AchievementTile(title: "Crown Thief",   icon: "crown.fill",          unlocked: viewModel.stats.crownedSpots >= 1, rarity: .silver)
                AchievementTile(title: "Cartographer",  icon: "mappin.and.ellipse",  unlocked: viewModel.stats.totalCatches >= 5, rarity: .silver)
                AchievementTile(title: "10-Crown Pirate", icon: "rosette",           unlocked: viewModel.stats.crownedSpots >= 10, rarity: .gold)
                AchievementTile(title: "Apex Predator", icon: "trophy.fill",         unlocked: (viewModel.stats.largestCatch ?? 0) >= 60, rarity: .gold)
                AchievementTile(title: "Species Hunter", icon: "fish.fill",          unlocked: viewModel.stats.totalCatches >= 10, rarity: .silver)
                AchievementTile(title: "Streak Master", icon: "flame.fill",          unlocked: false, rarity: .gold)
                AchievementTile(title: "Pirate Lord",   icon: "crown.fill",          unlocked: false, rarity: .legendary)
            }
        }
    }

    // MARK: - Crowned Spots

    @ViewBuilder
    private var crownedSpotsSection: some View {
        if !viewModel.crownedSpots.isEmpty {
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                SectionHeader(title: "Your Crowns", subtitle: "Spots you rule")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: theme.spacing.s) {
                        ForEach(viewModel.crownedSpots) { spot in
                            crownedSpotChip(spot)
                        }
                    }
                }
            }
        }
    }

    private func crownedSpotChip(_ spot: Spot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                CrownBadge(size: .small)
                Text(spot.name)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.colors.text.primary)
                    .lineLimit(1)
            }
            if let bestDisplay = spot.bestCatchDisplay {
                Text(bestDisplay)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.colors.text.secondary)
            }
        }
        .padding(.horizontal, theme.spacing.s)
        .padding(.vertical, theme.spacing.xs + 2)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.button)
                .fill(theme.colors.surface.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.button)
                .strokeBorder(theme.colors.brand.crown.opacity(0.4), lineWidth: 1)
        )
        .frame(width: 160)
    }

    // MARK: - Recent Catches

    @ViewBuilder
    private var recentCatchesSection: some View {
        if !viewModel.recentCatches.isEmpty {
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                SectionHeader(title: "Logbook", subtitle: "Recent catches")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: theme.spacing.xs), GridItem(.flexible(), spacing: theme.spacing.xs), GridItem(.flexible(), spacing: theme.spacing.xs)], spacing: theme.spacing.xs) {
                    ForEach(viewModel.recentCatches) { cwd in
                        Button {
                            appState.profileNavigationPath.append(NavigationDestination.catchDetail(catchId: cwd.fishCatch.id))
                        } label: {
                            CatchThumbnail(photoURL: cwd.fishCatch.photoURL, size: 110, cornerRadius: theme.radius.card)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Sign Out

    private var signOutButton: some View {
        PirateButton(title: "Sign Out", icon: "rectangle.portrait.and.arrow.right", fullWidth: true, isDestructive: true) {
            Task { await appState.signOut() }
        }
        .padding(.top, theme.spacing.s)
    }
}

/// Minimal profile edit sheet — Wave 6 expands.
struct ProfileEditSheet: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.reelTheme) private var theme

    var body: some View {
        NavigationStack {
            ZStack {
                theme.colors.surface.canvas.ignoresSafeArea()
                Form {
                    Section("Captain") {
                        TextField("Username", text: $viewModel.editUsername)
                            .textInputAutocapitalization(.never)
                        TextField("Home Waters", text: $viewModel.editHomeLocation)
                        TextField("Bio", text: $viewModel.editBio, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Captain")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.saveProfile()
                            dismiss()
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
    }
}
