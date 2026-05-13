import SwiftUI

/// Brawl-Stars-styled captain profile. Cinematic battle-card hero on top,
/// dense stat grid in the middle, "Favorite Catch" battle card, then logbook.
struct ProfileView: View {
    let userId: String?
    @StateObject private var viewModel: ProfileViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.reelTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var heroPulse: CGFloat = 0

    init(userId: String? = nil) {
        self.userId = userId
        _viewModel = StateObject(wrappedValue: ProfileViewModel(userId: userId))
    }

    var body: some View {
        ZStack {
            backgroundLayer

            ScrollView(showsIndicators: false) {
                if viewModel.isLoading && viewModel.user == nil {
                    LoadingView(message: "Loading captain’s log…")
                        .frame(height: 400)
                } else if let user = viewModel.user {
                    VStack(spacing: theme.spacing.lg) {
                        captainBattleCard(user: user)
                        actionRow(user: user)
                        statsGrid
                        battleCardSection
                        masteryRibbon
                        crownedSpotsSection
                        recentCatchesSection
                        if viewModel.isCurrentUser {
                            signOutButton
                        }
                    }
                    .padding(.horizontal, theme.spacing.m)
                    .padding(.top, theme.spacing.s)
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
        .task {
            await viewModel.loadProfile()
            startHeroPulse()
        }
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            theme.colors.surface.canvas
            LinearGradient(
                colors: [
                    captainTierColor.opacity(0.45),
                    theme.colors.brand.deepSea.opacity(0.55),
                    theme.colors.surface.canvas
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            FloatingSparkles(count: 18)
                .opacity(0.7)
                .ignoresSafeArea()
        }
    }

    // MARK: - Hero Battle Card

    private func captainBattleCard(user: User) -> some View {
        ZStack {
            heroBackdrop

            HStack(alignment: .center, spacing: theme.spacing.m) {
                ZStack {
                    Circle()
                        .fill(captainTierColor.opacity(0.35))
                        .frame(width: 150, height: 150)
                        .blur(radius: 28)
                        .scaleEffect(1 + heroPulse * 0.06)

                    ShipAvatar(
                        imageURL: user.avatarURL.flatMap(URL.init),
                        initial: user.username,
                        tier: captainTier,
                        size: .hero,
                        showCrown: viewModel.stats.crownedSpots > 0,
                        waveBob: !reduceMotion
                    )
                    .shadow(color: captainTierColor.opacity(0.5), radius: 20)
                }
                .frame(width: 130)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(user.username)
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(theme.colors.text.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(theme.colors.brand.brassGold)
                            .opacity(captainTier.rawValue >= CaptainTier.captain.rawValue ? 1 : 0)
                    }

                    playerTagPill(user: user)

                    HStack(spacing: 6) {
                        TierEmblem(tier: captainTier, division: tierDivision, size: .small)
                        roleBadge
                    }

                    if let home = user.homeLocation, !home.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(theme.colors.brand.seafoam)
                            Text(home)
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundStyle(theme.colors.text.secondary)
                                .lineLimit(1)
                        }
                        .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(theme.spacing.m)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.heroCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.heroCard, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [theme.colors.brand.crown.opacity(0.6), theme.colors.brand.brassGold.opacity(0.2)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .reelShadow(theme.shadow.heroCard)
    }

    private var heroBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [
                    captainTierColor.opacity(0.55),
                    theme.colors.brand.deepSea.opacity(0.95),
                    theme.colors.surface.elevatedAlt
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack {
                Spacer()
                WaveStrip()
                    .frame(height: 70)
                    .opacity(0.55)
            }
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(captainTierColor.opacity(0.15))
                    .frame(width: 80 + CGFloat(i) * 32, height: 80 + CGFloat(i) * 32)
                    .offset(x: -120 + CGFloat(i) * 18, y: -40 + CGFloat(i) * 6)
                    .blur(radius: 18)
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func playerTagPill(user: User) -> some View {
        let tag = playerTag(for: user)
        return HStack(spacing: 4) {
            Image(systemName: "number")
                .font(.system(size: 10, weight: .black))
            Text(tag)
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
        }
        .foregroundStyle(theme.colors.brand.brassGold)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(.black.opacity(0.35))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(theme.colors.brand.brassGold.opacity(0.45), lineWidth: 1)
        )
    }

    private var roleBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: roleIcon)
                .font(.system(size: 9, weight: .black))
            Text(roleLabel.uppercased())
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.colors.brand.coralRed, Color(hex: 0x8B2C1A)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        )
    }

    private var roleLabel: String {
        switch captainTier {
        case .deckhand, .sailor:    return "Rookie"
        case .firstMate, .captain:  return "Captain"
        case .commodore, .admiral:  return "Admiral"
        case .pirateLord:           return "President"
        }
    }
    private var roleIcon: String {
        switch captainTier {
        case .deckhand, .sailor:    return "person.fill"
        case .firstMate, .captain:  return "person.bust.fill"
        case .commodore, .admiral:  return "rosette"
        case .pirateLord:           return "crown.fill"
        }
    }

    // MARK: - Action row

    @ViewBuilder
    private func actionRow(user: User) -> some View {
        HStack(spacing: theme.spacing.s) {
            if viewModel.isCurrentUser {
                GhostButton(title: "Edit Captain", icon: "pencil", fullWidth: true) {
                    viewModel.startEditing()
                }
            } else {
                PirateButton(title: "Challenge", icon: "flag.checkered", fullWidth: true) {
                    appState.haptics?.tap()
                    appState.profileNavigationPath.append(NavigationDestination.leaderboard)
                }
                GhostButton(title: "Spots", icon: "map.fill", fullWidth: true) {
                    appState.selectedTab = .spots
                }
            }
        }
    }

    // MARK: - Stats grid (Brawl Stars style)

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            SectionHeader(title: "Captain’s Log", subtitle: "Career snapshot")
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: theme.spacing.s),
                    GridItem(.flexible(), spacing: theme.spacing.s)
                ],
                spacing: theme.spacing.s
            ) {
                statCell(
                    icon: "trophy.fill",
                    iconTint: theme.colors.brand.crown,
                    title: "Trophies",
                    value: trophyFormatted(viewModel.user?.xp ?? 0),
                    sub: "Season high \(trophyFormatted(seasonHighXP))"
                )
                statCell(
                    icon: captainTier.iconName,
                    iconTint: captainTierColor,
                    title: "Ranked",
                    value: "\(viewModel.user?.seasonScore ?? 0)",
                    sub: "Highest \(captainTier.displayName)"
                )
                statCell(
                    icon: "fish.fill",
                    iconTint: theme.colors.brand.seafoam,
                    title: "Victories",
                    value: "\(viewModel.stats.totalCatches)",
                    sub: "\(viewModel.stats.publicCatches) public"
                )
                statCell(
                    icon: "crown.fill",
                    iconTint: theme.colors.brand.crown,
                    title: "Crowns",
                    value: "\(viewModel.stats.crownedSpots)",
                    sub: "\(viewModel.stats.ruledTerritories) regions"
                )
                statCell(
                    icon: "diamond.fill",
                    iconTint: Color(hex: 0x6EE6FF),
                    title: "Points",
                    value: "\(viewModel.user?.seasonScore ?? 0)",
                    sub: "Season score"
                )
                statCell(
                    icon: "flame.fill",
                    iconTint: theme.colors.brand.coralRed,
                    title: "Win Streak",
                    value: "\(streakValue)",
                    sub: "Days in a row"
                )
                statCell(
                    icon: "books.vertical.fill",
                    iconTint: theme.colors.brand.tideTeal,
                    title: "Prestige",
                    value: "\(viewModel.stats.speciesDiscovered)",
                    sub: "Species mastered"
                )
                statCell(
                    icon: "ruler.fill",
                    iconTint: theme.colors.brand.brassGold,
                    title: "Best Catch",
                    value: bestCatchString,
                    sub: viewModel.stats.favoriteSpecies ?? "—"
                )
            }
        }
    }

    private func statCell(icon: String, iconTint: Color, title: String, value: String, sub: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(iconTint.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(iconTint)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(theme.colors.text.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(theme.colors.text.muted)
                Text(sub)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.colors.text.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                .fill(theme.colors.surface.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                .strokeBorder(theme.colors.brand.brassGold.opacity(0.18), lineWidth: 1)
        )
    }

    private var bestCatchString: String {
        if let s = viewModel.stats.largestCatch, let u = viewModel.stats.largestCatchUnit {
            return String(format: "%.1f%@", s, u)
        }
        return "—"
    }

    private var streakValue: Int {
        viewModel.isCurrentUser ? appState.dailyStreak : 0
    }

    private var seasonHighXP: Int {
        viewModel.user?.xp ?? 0
    }

    // MARK: - Battle Card section (Favorite Fish)

    private var battleCardSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            SectionHeader(title: "Battle Card", subtitle: "Signature catch")
            battleCardView
        }
    }

    private var battleCardView: some View {
        let speciesName = viewModel.stats.favoriteSpecies ?? "Unknown"
        let totalOfSpecies = viewModel.recentCatches.filter { $0.fishCatch.species == speciesName }.count
        let mastery = FishMasteryTier.from(totalCaught: max(totalOfSpecies, viewModel.stats.totalCatches >= 1 ? 1 : 0))

        return HStack(spacing: theme.spacing.s) {
            ZStack {
                RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [theme.colors.brand.crown, theme.colors.brand.brassGold],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 110, height: 140)
                Image(systemName: "fish.fill")
                    .font(.system(size: 56, weight: .black))
                    .rotationEffect(.degrees(-15))
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                FishMasteryBadge(tier: mastery, size: .small)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .frame(width: 110, height: 140)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("MY FAVORITE")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(theme.colors.brand.brassGold)
                Text(speciesName)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(theme.colors.text.primary)
                    .lineLimit(2)

                FishMasteryChip(tier: mastery, totalCaught: totalOfSpecies)

                HStack(spacing: 10) {
                    statMini(icon: "ruler.fill", value: bestCatchString)
                    statMini(icon: "fish.fill",  value: "\(viewModel.stats.totalCatches)")
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(theme.spacing.s)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                .fill(theme.colors.surface.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                .strokeBorder(theme.colors.brand.crown.opacity(0.45), lineWidth: 1)
        )
        .reelShadow(theme.shadow.card)
    }

    private func statMini(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(theme.colors.brand.brassGold)
            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.colors.text.primary)
                .monospacedDigit()
        }
    }

    // MARK: - Mastery ribbon (recent tier badges)

    private var masteryRibbon: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            SectionHeader(
                title: "Trophy Case",
                subtitle: "Mastery tiers earned",
                trailingActionTitle: viewModel.isCurrentUser ? "Open Log" : nil,
                trailingAction: viewModel.isCurrentUser ? { appState.selectedTab = .fishLog } : nil
            )
            HStack(spacing: theme.spacing.s) {
                masteryPill(.bronze)
                masteryPill(.silver)
                masteryPill(.gold)
                masteryPill(.platinum)
                masteryPill(.diamond)
            }
        }
    }

    private func masteryPill(_ tier: FishMasteryTier) -> some View {
        let count = approximateTierCount(tier)
        return VStack(spacing: 6) {
            FishMasteryBadge(tier: tier, size: .medium, animated: count > 0)
                .opacity(count > 0 ? 1 : 0.45)
            Text("\(count)")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(count > 0 ? theme.colors.text.primary : theme.colors.text.muted)
                .monospacedDigit()
            Text(tier.displayName.uppercased())
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(theme.colors.text.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing.s)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                .fill(theme.colors.surface.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                .strokeBorder(theme.colors.brand.brassGold.opacity(0.15), lineWidth: 1)
        )
    }

    /// Best-effort tier count derived from the user’s loaded catches.
    /// Real fish-log totals live in `FishLogView`; this gives a quick glance here.
    private func approximateTierCount(_ tier: FishMasteryTier) -> Int {
        let grouped = Dictionary(grouping: viewModel.recentCatches.map { $0.fishCatch.species }, by: { $0 })
        let speciesCounts = grouped.mapValues { $0.count }
        return speciesCounts.values.filter { FishMasteryTier.from(totalCaught: $0) == tier }.count
    }

    // MARK: - Crowned spots

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
        .frame(width: 170)
    }

    // MARK: - Recent catches

    @ViewBuilder
    private var recentCatchesSection: some View {
        if !viewModel.recentCatches.isEmpty {
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                SectionHeader(title: "Logbook", subtitle: "Recent catches")
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: theme.spacing.xs),
                        GridItem(.flexible(), spacing: theme.spacing.xs),
                        GridItem(.flexible(), spacing: theme.spacing.xs)
                    ],
                    spacing: theme.spacing.xs
                ) {
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

    // MARK: - Helpers

    private var captainTier: CaptainTier {
        guard let rank = viewModel.user?.rankTier else { return .deckhand }
        return CaptainTier.from(rankTier: rank)
    }

    private var captainTierColor: Color {
        theme.colors.tier.color(for: captainTier)
    }

    private var tierDivision: Int {
        let xp = viewModel.user?.xp ?? 0
        let progress = (viewModel.user?.rankTier ?? .minnow).progress(xp: xp)
        if progress > 0.66 { return 3 }
        if progress > 0.33 { return 2 }
        return 1
    }

    /// Deterministic short tag derived from user id for the "#XXXXXXX" pill.
    private func playerTag(for user: User) -> String {
        let allowed = Array("0123456789ABCDEFGHJKLMNPQRSTUVWXYZ")
        var hash: UInt64 = 5381
        for s in user.id.unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ UInt64(s.value)
        }
        var tag = ""
        for _ in 0..<7 {
            tag.append(allowed[Int(hash % UInt64(allowed.count))])
            hash /= UInt64(allowed.count)
            if hash == 0 { hash = 0xABCDEF }
        }
        return tag
    }

    private func trophyFormatted(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }

    private func startHeroPulse() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            heroPulse = 1
        }
    }
}

extension CaptainTier {
    var iconName: String {
        switch self {
        case .deckhand:   return "circle.grid.cross"
        case .sailor:     return "shield.fill"
        case .firstMate:  return "shield.lefthalf.filled"
        case .captain:    return "rosette"
        case .commodore:  return "star.circle.fill"
        case .admiral:    return "crown"
        case .pirateLord: return "crown.fill"
        }
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
