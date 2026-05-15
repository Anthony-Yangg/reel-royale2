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
        BrawlProfileHero(
            user: user,
            stats: viewModel.stats,
            fishMasteryPoints: viewModel.fishMasteryPoints,
            fishLogStatus: viewModel.fishLogStatus,
            topFishMastery: viewModel.topFishMastery,
            isCurrentUser: viewModel.isCurrentUser,
            onEdit: { viewModel.startEditing() },
            onChallenge: {
                AppFeedback.confirm.play(appState: appState)
                appState.selectedTab = .spots
            }
        )
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

    // MARK: - Trophy Case

    private var trophyCase: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            SectionHeader(title: "Trophy Case", subtitle: "Derived from your live stats")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: theme.spacing.s) {
                AchievementTile(title: "First Catch",   icon: "checkmark.seal.fill", unlocked: viewModel.stats.totalCatches >= 1, rarity: .bronze)
                AchievementTile(title: "Crown Thief",   icon: "crown.fill",          unlocked: viewModel.stats.crownedSpots >= 1, rarity: .silver)
                AchievementTile(title: "Cartographer",  icon: "mappin.and.ellipse",  unlocked: viewModel.stats.totalCatches >= 5, rarity: .silver)
                AchievementTile(title: "10-Crown Pirate", icon: "rosette",           unlocked: viewModel.stats.crownedSpots >= 10, rarity: .gold)
                AchievementTile(title: "Apex Predator", icon: "trophy.fill",         unlocked: (viewModel.stats.largestCatch ?? 0) >= 60, rarity: .gold)
                AchievementTile(title: "Species Hunter", icon: "fish.fill",          unlocked: viewModel.stats.speciesDiscovered >= 10, rarity: .silver)
                AchievementTile(title: "Streak Master", icon: "flame.fill",          unlocked: viewModel.isCurrentUser && appState.dailyStreak >= 7, rarity: .gold)
                AchievementTile(title: "Pirate Lord",   icon: "crown.fill",          unlocked: (viewModel.user?.rankTier ?? .minnow) == .legend, rarity: .legendary)
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

private struct BrawlProfileHero: View {
    let user: User
    let stats: UserStats
    let fishMasteryPoints: Int
    let fishLogStatus: FishLogStatus
    let topFishMastery: FishMasteryTier
    let isCurrentUser: Bool
    let onEdit: () -> Void
    let onChallenge: () -> Void

    @Environment(\.reelTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: theme.spacing.s) {
            ZStack {
                HStack(spacing: 0) {
                    characterPanel
                        .frame(maxWidth: .infinity)
                    statsPanel
                        .frame(maxWidth: .infinity)
                }

                Text("PROFILE")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(theme.colors.text.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .offset(y: -112)
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.07), lineWidth: 1.2)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 24, x: 0, y: 14)

            if isCurrentUser {
                GhostButton(title: "Edit Captain", icon: "pencil", fullWidth: true, action: onEdit)
            } else {
                PirateButton(title: "Challenge for Control", icon: "scope", fullWidth: true, action: onChallenge)
            }
        }
    }

    private var characterPanel: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color.white, theme.colors.surface.elevated, Color(hex: 0xDDEEE9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            WaveStrip(amplitude: 12, frequency: 0.015, color: theme.colors.brand.tideTeal.opacity(0.24))
                .frame(height: 80)
                .opacity(0.35)
                .offset(y: 14)

            VStack(spacing: theme.spacing.xs) {
                Spacer()
                ShipAvatar(
                    imageURL: user.avatarURL.flatMap(URL.init),
                    initial: user.username,
                    tier: CaptainTier.from(rankTier: user.rankTier),
                    size: .hero,
                    showCrown: stats.crownedSpots > 0,
                    waveBob: !reduceMotion
                )
                .scaleEffect(1.22)
                .shadow(color: theme.colors.brand.crown.opacity(0.36), radius: 18, x: 0, y: 8)

                VStack(spacing: 2) {
                    Text("FAVORITE FISH")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(theme.colors.text.secondary)
                    Text(stats.favoriteSpecies ?? "Not Set")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(theme.colors.text.primary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.78))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                        )
                )
                .padding(.bottom, theme.spacing.s)
            }
            .padding(.horizontal, theme.spacing.s)
        }
    }

    private var statsPanel: some View {
        ZStack {
            LinearGradient(
                colors: [theme.colors.surface.elevated, Color(hex: 0xF7F3EE), theme.colors.surface.elevatedAlt],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "crown.fill")
                .font(.system(size: 132, weight: .black))
                .foregroundStyle(Color.black.opacity(0.035))
                .rotationEffect(.degrees(-16))
                .offset(x: 45, y: 36)

            VStack(alignment: .leading, spacing: theme.spacing.s) {
                Spacer().frame(height: 42)

                HStack(spacing: theme.spacing.xs) {
                    ProfileRankBadge(rankTier: user.rankTier)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.username.isEmpty ? "Captain" : user.username)
                            .font(.system(size: 21, weight: .black, design: .rounded))
                            .foregroundStyle(theme.colors.text.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("#\(String(user.id.prefix(8)).uppercased())")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(theme.colors.text.secondary)
                    }
                }

                TierEmblem(tier: CaptainTier.from(rankTier: user.rankTier), division: 1, size: .small)

                HStack(spacing: theme.spacing.xs) {
                    ProfileMetricTile(label: "Points", value: "\(user.xp)", icon: "bolt.fill", tint: theme.colors.brand.crown)
                    ProfileMetricTile(label: "Coins", value: "\(user.lureCoins)", icon: "circle.hexagongrid.fill", tint: theme.colors.brand.brassGold)
                }

                HStack(spacing: theme.spacing.xs) {
                    ProfileMetricTile(label: "Crowns", value: "\(stats.crownedSpots)", icon: "crown.fill", tint: theme.colors.brand.crown)
                    ProfileMetricTile(label: "Regions", value: "\(stats.ruledTerritories)", icon: "flag.fill", tint: theme.colors.brand.seafoam)
                }

                HStack(spacing: theme.spacing.xs) {
                    FishLogStatusChip(status: fishLogStatus, points: fishMasteryPoints)
                    MasteryBadge(tier: topFishMastery)
                }
            }
            .padding(.horizontal, theme.spacing.m)
            .padding(.bottom, theme.spacing.m)
        }
    }
}

private struct ProfileRankBadge: View {
    let rankTier: RankTier
    @Environment(\.reelTheme) private var theme

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [theme.colors.brand.coralRed, theme.colors.brand.crown],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 54, height: 54)
            Circle()
                .strokeBorder(Color.white.opacity(0.65), lineWidth: 3)
                .frame(width: 46, height: 46)
            Image(systemName: rankTier.icon)
                .font(.system(size: 23, weight: .black))
                .foregroundStyle(Color(hex: 0x24121A))
        }
        .shadow(color: theme.colors.brand.crown.opacity(0.36), radius: 12, x: 0, y: 6)
    }
}

private struct ProfileMetricTile: View {
    let label: String
    let value: String
    let icon: String
    let tint: Color

    @Environment(\.reelTheme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(theme.colors.text.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundStyle(theme.colors.text.secondary)
                    .textCase(.uppercase)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                )
        )
    }
}

private struct FishLogStatusChip: View {
    let status: FishLogStatus
    let points: Int
    @Environment(\.reelTheme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 12, weight: .black))
            VStack(alignment: .leading, spacing: 0) {
                Text(status.rawValue)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(points) pts")
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(theme.colors.text.primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(status.color(theme: theme).opacity(0.24))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(status.color(theme: theme).opacity(0.28), lineWidth: 1)
                )
        )
    }
}

private struct MasteryBadge: View {
    let tier: FishMasteryTier
    @Environment(\.reelTheme) private var theme

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: tier.profileSymbolName)
                .font(.system(size: 12, weight: .black))
            Text(tier.displayName)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .foregroundStyle(Color(hex: 0x091421))
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tier.profileColor(theme: theme))
        )
    }
}

private extension FishLogStatus {
    func color(theme: ReelTheme) -> Color {
        switch self {
        case .beginner: return theme.colors.brand.seafoam
        case .collector: return theme.colors.brand.brassGold
        case .specialist: return theme.colors.brand.crown
        case .master: return Color(hex: 0x8FE8FF)
        case .apex: return Color(hex: 0xA78BFA)
        }
    }
}

private extension FishMasteryTier {
    var profileSymbolName: String {
        switch self {
        case .unranked: return "circle"
        case .bronze, .silver: return "seal.fill"
        case .gold: return "star.circle.fill"
        case .platinum: return "sparkles"
        case .diamond: return "diamond.fill"
        }
    }

    func profileColor(theme: ReelTheme) -> Color {
        switch self {
        case .unranked: return theme.colors.text.muted
        case .bronze: return Color(hex: 0xC27A3A)
        case .silver: return Color(hex: 0xC8D3DE)
        case .gold: return theme.colors.brand.crown
        case .platinum: return Color(hex: 0x8FE8FF)
        case .diamond: return Color(hex: 0xA78BFA)
        }
    }
}

/// Profile edit sheet.
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
