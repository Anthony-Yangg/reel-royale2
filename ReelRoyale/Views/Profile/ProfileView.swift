import SwiftUI

/// Captain profile — a maritime "commission card" layout custom to Reel Royale.
/// Brass nameplates, wax seal, sea-chart grid and wood-plank trophies replace the
/// generic mobile-game profile tropes.
struct ProfileView: View {
    let userId: String?
    @StateObject private var viewModel: ProfileViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.reelTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var sealSpin: Double = 0

    init(userId: String? = nil) {
        self.userId = userId
        _viewModel = StateObject(wrappedValue: ProfileViewModel(userId: userId))
    }

    var body: some View {
        ZStack {
            chartBackground

            ScrollView(showsIndicators: false) {
                if viewModel.isLoading && viewModel.user == nil {
                    LoadingView(message: "Loading captain’s log…")
                        .frame(height: 400)
                } else if let user = viewModel.user {
                    VStack(spacing: theme.spacing.lg) {
                        commissionCard(user: user)
                        standingRibbon
                        captainActions(user: user)
                        voyageLog
                        signaturePlank
                        trophyShelf
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
            startSealSpin()
        }
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Background (sea chart)

    private var chartBackground: some View {
        ZStack {
            theme.colors.surface.canvas
            LinearGradient(
                colors: [
                    theme.colors.brand.deepSea.opacity(0.6),
                    theme.colors.surface.canvas
                ],
                startPoint: .top, endPoint: .bottom
            )
            ChartGridOverlay()
                .stroke(theme.colors.brand.brassGold.opacity(0.08), lineWidth: 0.5)
            FloatingSparkles(count: 14)
                .opacity(0.45)
        }
        .ignoresSafeArea()
    }

    // MARK: - Commission Card

    private func commissionCard(user: User) -> some View {
        VStack(spacing: 0) {
            commissionBanner

            HStack(alignment: .top, spacing: theme.spacing.m) {
                portholeAvatar(user: user)

                VStack(alignment: .leading, spacing: 6) {
                    Text("CAPTAIN")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(theme.colors.brand.brassGold)

                    Text(user.username.uppercased())
                        .font(.system(size: 24, weight: .heavy, design: .serif))
                        .tracking(1.5)
                        .foregroundStyle(theme.colors.text.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)

                    rankPlate

                    if let home = user.homeLocation, !home.isEmpty {
                        HStack(spacing: 5) {
                            Image(systemName: "location.north.line.fill")
                                .font(.system(size: 10, weight: .black))
                            Text("Sailing under \(home)")
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .italic()
                                .lineLimit(1)
                        }
                        .foregroundStyle(theme.colors.text.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, theme.spacing.m)
            .padding(.top, theme.spacing.m)
            .padding(.bottom, theme.spacing.m + 4)

            commissionFooter(user: user)
        }
        .background(commissionFill)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
        .overlay(brassFrame)
        .overlay(alignment: .topTrailing) {
            waxSeal(user: user)
                .padding(.top, 36)
                .padding(.trailing, 14)
        }
        .reelShadow(theme.shadow.heroCard)
    }

    private var commissionBanner: some View {
        ZStack {
            LinearGradient(
                colors: [theme.colors.brand.walnut, Color(hex: 0x2C1A0E)],
                startPoint: .top, endPoint: .bottom
            )
            HStack(spacing: 8) {
                Image(systemName: "compass.drawing")
                    .font(.system(size: 11, weight: .black))
                Text("THE CAPTAIN'S COMMISSION")
                    .font(.system(size: 11, weight: .heavy, design: .serif))
                    .tracking(3)
                Image(systemName: "compass.drawing")
                    .font(.system(size: 11, weight: .black))
            }
            .foregroundStyle(theme.colors.brand.brassGold)
        }
        .frame(height: 28)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.colors.brand.brassGold.opacity(0.7))
                .frame(height: 1)
        }
    }

    private func portholeAvatar(user: User) -> some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [theme.colors.brand.brassGold, theme.colors.brand.walnut, theme.colors.brand.brassGold],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 5
                )
                .frame(width: 108, height: 108)

            ForEach(0..<8, id: \.self) { i in
                Circle()
                    .fill(theme.colors.brand.walnut)
                    .frame(width: 6, height: 6)
                    .offset(y: -54)
                    .rotationEffect(.degrees(Double(i) * 45 + 22.5))
            }

            ShipAvatar(
                imageURL: user.avatarURL.flatMap(URL.init),
                initial: user.username,
                tier: captainTier,
                size: .large,
                showCrown: viewModel.stats.crownedSpots > 0,
                waveBob: !reduceMotion
            )
            .shadow(color: theme.colors.brand.crown.opacity(0.4), radius: 12)
        }
        .frame(width: 110, height: 110)
    }

    private var rankPlate: some View {
        HStack(spacing: 6) {
            chevrons
            Text("\(captainTier.displayName.uppercased()) · \(romanNumeral(tierDivision))")
                .font(.system(size: 12, weight: .heavy, design: .serif))
                .tracking(1.5)
        }
        .foregroundStyle(theme.colors.tier.color(for: captainTier))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x14222F), Color(hex: 0x0A1822)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(theme.colors.brand.brassGold.opacity(0.5), lineWidth: 0.75)
            }
        )
    }

    private var chevrons: some View {
        HStack(spacing: 1) {
            ForEach(0..<min(captainTier.chevronCount, 4), id: \.self) { _ in
                Image(systemName: "chevron.up")
                    .font(.system(size: 8, weight: .black))
            }
        }
    }

    private func commissionFooter(user: User) -> some View {
        HStack(spacing: 0) {
            footerCell(label: "MANIFEST", value: "#\(playerTag(for: user))", monospaced: true)
            divider
            footerCell(label: "SINCE", value: yearJoined(user: user))
            divider
            footerCell(label: "FLEET", value: fleetCode(user: user))
        }
        .background(
            LinearGradient(
                colors: [
                    Color(hex: 0x14222F),
                    Color(hex: 0x0A1822)
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.colors.brand.brassGold.opacity(0.5))
                .frame(height: 0.75)
        }
        .frame(height: 46)
    }

    private func footerCell(label: String, value: String, monospaced: Bool = false) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .black, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(theme.colors.brand.brassGold.opacity(0.85))
            Text(value)
                .font(monospaced
                      ? .system(size: 13, weight: .heavy, design: .monospaced)
                      : .system(size: 13, weight: .heavy, design: .serif))
                .foregroundStyle(theme.colors.text.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.colors.brand.brassGold.opacity(0.35))
            .frame(width: 0.75, height: 28)
    }

    private var commissionFill: some View {
        ZStack {
            theme.colors.surface.elevated
            LinearGradient(
                colors: [
                    theme.colors.brand.deepSea.opacity(0.4),
                    theme.colors.surface.elevated
                ],
                startPoint: .top, endPoint: .bottom
            )
            CompassRose()
                .stroke(theme.colors.brand.brassGold.opacity(0.06), lineWidth: 0.75)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(0.9)
                .offset(x: 60, y: 20)
        }
    }

    private var brassFrame: some View {
        RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        theme.colors.brand.brassGold,
                        theme.colors.brand.walnut.opacity(0.6),
                        theme.colors.brand.brassGold
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
    }

    private func waxSeal(user: User) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            theme.colors.brand.coralRed,
                            Color(hex: 0x6B1A12)
                        ],
                        center: .topLeading,
                        startRadius: 2, endRadius: 40
                    )
                )
                .frame(width: 50, height: 50)
                .overlay(
                    Circle()
                        .strokeBorder(Color(hex: 0x4A0A06).opacity(0.7), lineWidth: 1.5)
                )
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                        .scaleEffect(0.78)
                )
                .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
                .rotationEffect(.degrees(sealSpin))

            Image(systemName: sealIcon)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(theme.colors.brand.crown.opacity(0.95))
                .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
        }
        .accessibilityLabel("Standing seal")
    }

    private var sealIcon: String {
        switch captainTier {
        case .deckhand, .sailor:   return "anchor"
        case .firstMate, .captain: return "rosette"
        case .commodore, .admiral: return "crown"
        case .pirateLord:          return "crown.fill"
        }
    }

    private func startSealSpin() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true)) {
            sealSpin = 4
        }
    }

    // MARK: - Standing ribbon

    private var standingRibbon: some View {
        HStack(spacing: 10) {
            ribbonTip
            Text(standingTitle.uppercased())
                .font(.system(size: 13, weight: .heavy, design: .serif))
                .tracking(2.5)
                .foregroundStyle(theme.colors.brand.parchment)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            Image(systemName: standingIcon)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(theme.colors.brand.crown)
            Text(standingSubtitle)
                .font(.system(size: 11, weight: .heavy, design: .serif))
                .italic()
                .foregroundStyle(theme.colors.brand.parchment.opacity(0.85))
            ribbonTip.scaleEffect(x: -1, y: 1)
        }
        .padding(.horizontal, theme.spacing.s)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: 0x4A1612),
                    theme.colors.brand.coralRed.opacity(0.85),
                    Color(hex: 0x4A1612)
                ],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .overlay(
            Rectangle()
                .strokeBorder(theme.colors.brand.brassGold.opacity(0.6), lineWidth: 1)
        )
        .reelShadow(theme.shadow.card)
    }

    private var ribbonTip: some View {
        Image(systemName: "triangle.fill")
            .rotationEffect(.degrees(-90))
            .foregroundStyle(theme.colors.brand.crown)
            .font(.system(size: 9, weight: .black))
    }

    private var standingTitle: String {
        switch captainTier {
        case .deckhand:   return "Greenhorn at the docks"
        case .sailor:     return "Hand on the bowline"
        case .firstMate:  return "First mate of the line"
        case .captain:    return "Captain of the deck"
        case .commodore:  return "Commodore of the bay"
        case .admiral:    return "Admiral of the fleet"
        case .pirateLord: return "Lord of the seven seas"
        }
    }

    private var standingSubtitle: String {
        let crowns = viewModel.stats.crownedSpots
        if crowns == 0 { return "uncrowned" }
        if crowns == 1 { return "1 crown" }
        return "\(crowns) crowns"
    }

    private var standingIcon: String {
        viewModel.stats.crownedSpots > 0 ? "crown.fill" : "anchor"
    }

    // MARK: - Actions

    @ViewBuilder
    private func captainActions(user: User) -> some View {
        HStack(spacing: theme.spacing.s) {
            if viewModel.isCurrentUser {
                GhostButton(title: "Amend Commission", icon: "pencil.line", fullWidth: true) {
                    viewModel.startEditing()
                }
            } else {
                PirateButton(title: "Hoist Challenge", icon: "flag.checkered", fullWidth: true) {
                    appState.haptics?.tap()
                    appState.profileNavigationPath.append(NavigationDestination.leaderboard)
                }
                GhostButton(title: "Their Waters", icon: "map.fill", fullWidth: true) {
                    appState.selectedTab = .spots
                }
            }
        }
    }

    // MARK: - Voyage Log (stats)

    private var voyageLog: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            engravedHeader(title: "Voyage Log", subtitle: "Career engraved in brass")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: theme.spacing.s),
                    GridItem(.flexible(), spacing: theme.spacing.s),
                    GridItem(.flexible(), spacing: theme.spacing.s)
                ],
                spacing: theme.spacing.s
            ) {
                nameplate(label: "TROPHIES",  value: shortInt(viewModel.user?.xp ?? 0))
                nameplate(label: "STANDING",  value: ordinal(appState.seasonRank))
                nameplate(label: "CROWNS",    value: "\(viewModel.stats.crownedSpots)")
                nameplate(label: "CATCHES",   value: "\(viewModel.stats.totalCatches)")
                nameplate(label: "STREAK",    value: "\(streakValue)d")
                nameplate(label: "DOUBLOONS", value: shortInt(viewModel.user?.lureCoins ?? 0))
                nameplate(label: "REGIONS",   value: "\(viewModel.stats.ruledTerritories)")
                nameplate(label: "MASTERY",   value: "\(viewModel.stats.speciesDiscovered)")
                nameplate(label: "PB",        value: bestCatchString)
            }
        }
    }

    private func nameplate(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .serif))
                .foregroundStyle(theme.colors.text.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Rectangle()
                .fill(theme.colors.brand.brassGold.opacity(0.45))
                .frame(height: 0.75)
                .padding(.horizontal, 2)
            Text(label)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .tracking(2)
                .foregroundStyle(theme.colors.brand.brassGold)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, minHeight: 70)
        .background(brassNameplateFill)
        .overlay(brassNameplateNotches)
        .reelShadow(theme.shadow.card)
    }

    private var brassNameplateFill: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(theme.colors.surface.elevated)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x1B2D3D).opacity(0.4), Color.clear],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        }
    }

    private var brassNameplateNotches: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .strokeBorder(theme.colors.brand.brassGold.opacity(0.55), lineWidth: 1)
            .allowsHitTesting(false)
    }

    // MARK: - Signature Catch (wood plank)

    private var signaturePlank: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            engravedHeader(title: "Signature Catch", subtitle: "Mounted in the captain's quarters")

            HStack(alignment: .center, spacing: 0) {
                fishPlankArt
                plankInfo
            }
            .background(woodGrainFill)
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                    .strokeBorder(theme.colors.brand.walnut, lineWidth: 1.5)
            )
            .overlay(alignment: .topLeading)   { brassBolt }
            .overlay(alignment: .topTrailing)  { brassBolt }
            .overlay(alignment: .bottomLeading)  { brassBolt }
            .overlay(alignment: .bottomTrailing) { brassBolt }
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
            .reelShadow(theme.shadow.card)
        }
    }

    private var brassBolt: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [theme.colors.brand.crown, theme.colors.brand.walnut],
                        center: .topLeading, startRadius: 1, endRadius: 8
                    )
                )
                .frame(width: 10, height: 10)
            Rectangle()
                .fill(Color(hex: 0x3E2410).opacity(0.75))
                .frame(width: 5, height: 1)
                .rotationEffect(.degrees(35))
        }
        .padding(8)
    }

    private var fishPlankArt: some View {
        ZStack {
            Rectangle()
                .fill(.clear)
                .frame(width: 130, height: 140)
            Image(systemName: "fish.fill")
                .font(.system(size: 70, weight: .black))
                .rotationEffect(.degrees(-15))
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.colors.brand.seafoam, theme.colors.brand.tideTeal],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.55), radius: 6, x: 0, y: 4)
            FishMasteryBadge(tier: signatureMastery, size: .small)
                .offset(x: 38, y: -42)
        }
    }

    private var plankInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LATEST HAUL")
                .font(.system(size: 9, weight: .black, design: .rounded))
                .tracking(2)
                .foregroundStyle(theme.colors.brand.parchment.opacity(0.85))
            Text(signatureSpeciesName)
                .font(.system(size: 18, weight: .heavy, design: .serif))
                .foregroundStyle(theme.colors.brand.parchment)
                .lineLimit(2)
            Text(bestCatchString)
                .font(.system(size: 14, weight: .heavy, design: .serif))
                .foregroundStyle(theme.colors.brand.crown)
            Text("\(viewModel.stats.totalCatches) catches logged")
                .font(.system(size: 11, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(theme.colors.brand.parchment.opacity(0.75))
        }
        .padding(.vertical, theme.spacing.m)
        .padding(.trailing, theme.spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var woodGrainFill: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0x4A2E1D),
                    Color(hex: 0x2C1A0E),
                    Color(hex: 0x4A2E1D)
                ],
                startPoint: .top, endPoint: .bottom
            )
            ForEach(0..<6, id: \.self) { i in
                Rectangle()
                    .fill(Color.black.opacity(0.13))
                    .frame(height: 0.5)
                    .offset(y: CGFloat(i) * 24 - 60)
            }
        }
    }

    // MARK: - Trophy Shelf (mastery)

    private var trophyShelf: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            engravedHeader(
                title: "Trophy Shelf",
                subtitle: "Species mastery — hung on the wall",
                trailingActionTitle: viewModel.isCurrentUser ? "Open Log" : nil,
                trailingAction: viewModel.isCurrentUser ? { appState.selectedTab = .fishLog } : nil
            )

            ZStack {
                woodGrainFill
                VStack(spacing: 0) {
                    Spacer()
                    HStack(spacing: 0) {
                        ForEach(FishMasteryTier.allCases.dropFirst()) { tier in
                            trophyHang(tier: tier)
                        }
                    }
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [theme.colors.brand.brassGold.opacity(0.7),
                                         theme.colors.brand.walnut],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(height: 6)
                    Spacer().frame(height: 6)
                }
            }
            .frame(height: 134)
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                    .strokeBorder(theme.colors.brand.walnut, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
            .reelShadow(theme.shadow.card)
        }
    }

    private func trophyHang(tier: FishMasteryTier) -> some View {
        let count = approximateTierCount(tier)
        return VStack(spacing: 2) {
            Rectangle()
                .fill(theme.colors.brand.brassGold.opacity(0.65))
                .frame(width: 1.5, height: 14)
            FishMasteryBadge(tier: tier, size: .medium, animated: count > 0)
                .opacity(count > 0 ? 1 : 0.4)
                .saturation(count > 0 ? 1 : 0.2)
            Text("\(count)")
                .font(.system(size: 12, weight: .heavy, design: .serif))
                .foregroundStyle(count > 0 ? theme.colors.brand.parchment : theme.colors.brand.parchment.opacity(0.5))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    /// Best-effort tier count derived from the user's loaded catches.
    private func approximateTierCount(_ tier: FishMasteryTier) -> Int {
        let grouped = Dictionary(grouping: viewModel.recentCatches.map { $0.fishCatch.species }, by: { $0 })
        let speciesCounts = grouped.mapValues { $0.count }
        return speciesCounts.values.filter { FishMasteryTier.from(totalCaught: $0) == tier }.count
    }

    private var signatureSpeciesName: String {
        viewModel.stats.favoriteSpecies ?? "No catches yet"
    }

    private var signatureMastery: FishMasteryTier {
        let n = viewModel.recentCatches.filter { $0.fishCatch.species == viewModel.stats.favoriteSpecies }.count
        return FishMasteryTier.from(totalCaught: n)
    }

    // MARK: - Crowned spots

    @ViewBuilder
    private var crownedSpotsSection: some View {
        if !viewModel.crownedSpots.isEmpty {
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                engravedHeader(title: "Conquered Waters", subtitle: "Spots flying your colors")
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
                    .font(.system(size: 13, weight: .heavy, design: .serif))
                    .foregroundStyle(theme.colors.text.primary)
                    .lineLimit(1)
            }
            if let bestDisplay = spot.bestCatchDisplay {
                Text(bestDisplay)
                    .font(.system(size: 11, weight: .regular, design: .serif))
                    .italic()
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

    // MARK: - Logbook

    @ViewBuilder
    private var recentCatchesSection: some View {
        if !viewModel.recentCatches.isEmpty {
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                engravedHeader(title: "The Logbook", subtitle: "Recent entries")
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
                                .overlay(
                                    RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                                        .strokeBorder(theme.colors.brand.brassGold.opacity(0.4), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Sign out

    private var signOutButton: some View {
        PirateButton(title: "Furl the Colors · Sign Out", icon: "flag.slash.fill", fullWidth: true, isDestructive: true) {
            Task { await appState.signOut() }
        }
        .padding(.top, theme.spacing.s)
    }

    // MARK: - Engraved header

    private func engravedHeader(
        title: String,
        subtitle: String? = nil,
        trailingActionTitle: String? = nil,
        trailingAction: (() -> Void)? = nil
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 7, weight: .black))
                        .foregroundStyle(theme.colors.brand.brassGold)
                    Text(title.uppercased())
                        .font(.system(size: 13, weight: .heavy, design: .serif))
                        .tracking(2.5)
                        .foregroundStyle(theme.colors.text.primary)
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 7, weight: .black))
                        .foregroundStyle(theme.colors.brand.brassGold)
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(theme.colors.text.secondary)
                }
            }
            Spacer()
            if let actionTitle = trailingActionTitle, let action = trailingAction {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(actionTitle.uppercased())
                            .font(.system(size: 11, weight: .heavy, design: .serif))
                            .tracking(1.5)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .heavy))
                    }
                    .foregroundStyle(theme.colors.brand.brassGold)
                }
            }
        }
    }

    // MARK: - Helpers

    private var captainTier: CaptainTier {
        guard let rank = viewModel.user?.rankTier else { return .deckhand }
        return CaptainTier.from(rankTier: rank)
    }

    private var tierDivision: Int {
        let xp = viewModel.user?.xp ?? 0
        let progress = (viewModel.user?.rankTier ?? .minnow).progress(xp: xp)
        if progress > 0.66 { return 3 }
        if progress > 0.33 { return 2 }
        return 1
    }

    private var streakValue: Int {
        viewModel.isCurrentUser ? appState.dailyStreak : 0
    }

    private var bestCatchString: String {
        if let s = viewModel.stats.largestCatch, let u = viewModel.stats.largestCatchUnit {
            return String(format: "%.1f%@", s, u)
        }
        return "—"
    }

    private func shortInt(_ value: Int) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", Double(value) / 1_000_000) }
        if value >= 1_000     { return String(format: "%.1fK", Double(value) / 1_000) }
        return "\(value)"
    }

    private func ordinal(_ n: Int?) -> String {
        guard let n else { return "—" }
        let suffix: String
        switch n % 100 {
        case 11, 12, 13: suffix = "th"
        default:
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }

    private func romanNumeral(_ n: Int) -> String {
        switch n {
        case 1: return "I"
        case 2: return "II"
        case 3: return "III"
        case 4: return "IV"
        default: return ""
        }
    }

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

    private func yearJoined(user: User) -> String {
        let comps = Calendar.current.dateComponents([.year], from: user.createdAt)
        return comps.year.map(String.init) ?? "—"
    }

    private func fleetCode(user: User) -> String {
        let raw = (user.homeLocation ?? user.username)
            .uppercased()
            .filter { $0.isLetter }
        if raw.count >= 3 { return String(raw.prefix(3)) }
        return "RRA"
    }
}

/// Subtle nautical chart grid drawn behind the profile background.
private struct ChartGridOverlay: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 36
        var x: CGFloat = 0
        while x < rect.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
            x += step
        }
        var y: CGFloat = 0
        while y < rect.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
            y += step
        }
        return path
    }
}

/// Decorative compass rose used as a watermark on the commission card.
private struct CompassRose: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) * 0.42
        var path = Path()
        path.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        path.addEllipse(in: CGRect(x: center.x - r * 0.6, y: center.y - r * 0.6, width: r * 1.2, height: r * 1.2))
        for i in 0..<8 {
            let angle = Double(i) * .pi / 4
            let outer = CGPoint(x: center.x + r * CGFloat(cos(angle)), y: center.y + r * CGFloat(sin(angle)))
            path.move(to: center)
            path.addLine(to: outer)
        }
        return path
    }
}

/// Profile edit sheet — kept compact for now.
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
            .navigationTitle("Amend Commission")
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
