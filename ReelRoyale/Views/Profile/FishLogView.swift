import SwiftUI

/// Pokemon-Go-style fish log / library tab.
/// Shows every species the player has ever encountered, grouped by mastery tier
/// (Bronze → Diamond), with a live discovery counter and filterable grid.
struct FishLogView: View {
    @StateObject private var viewModel = FishLogViewModel()
    @EnvironmentObject var appState: AppState
    @Environment(\.reelTheme) private var theme

    @State private var filter: TierFilter = .all
    @State private var selectedEntry: CodexEntry?
    @State private var query: String = ""

    enum TierFilter: Hashable, Identifiable {
        case all
        case discovered
        case undiscovered
        case tier(FishMasteryTier)

        var id: String {
            switch self {
            case .all:          return "all"
            case .discovered:   return "discovered"
            case .undiscovered: return "undiscovered"
            case .tier(let t):  return "tier-\(t.rawValue)"
            }
        }

        var label: String {
            switch self {
            case .all:          return "All"
            case .discovered:   return "Caught"
            case .undiscovered: return "Locked"
            case .tier(let t):  return t.displayName
            }
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            theme.colors.surface.canvas.ignoresSafeArea()
            backgroundOcean

            ScrollView(showsIndicators: false) {
                VStack(spacing: theme.spacing.lg) {
                    libraryHero
                    masteryRail
                    filterRail
                    searchField
                    contentGrid
                }
                .padding(.horizontal, theme.spacing.m)
                .padding(.top, theme.spacing.s)
                .padding(.bottom, 140)
            }
            .refreshable { await viewModel.load() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedEntry) { entry in
            FishLogDetailSheet(entry: entry)
                .environment(\.reelTheme, theme)
                .environmentObject(appState)
        }
        .task { await viewModel.load() }
    }

    // MARK: - Background

    private var backgroundOcean: some View {
        ZStack {
            LinearGradient(
                colors: [
                    theme.colors.brand.deepSea.opacity(0.55),
                    theme.colors.surface.canvas,
                    theme.colors.surface.canvas
                ],
                startPoint: .top, endPoint: .bottom
            )
            FloatingSparkles(count: 14)
                .opacity(0.55)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Hero

    private var libraryHero: some View {
        VStack(spacing: theme.spacing.s) {
            HStack(alignment: .top, spacing: theme.spacing.m) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Fish Library")
                        .font(theme.typography.title1)
                        .foregroundStyle(theme.colors.text.primary)
                    Text("Every fish you've ever pulled aboard")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.text.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(viewModel.discoveredCount)")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(theme.colors.brand.crown)
                            .monospacedDigit()
                        Text("/ \(viewModel.totalCount)")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(theme.colors.text.secondary)
                            .monospacedDigit()
                        Text("species")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(theme.colors.text.muted)
                            .tracking(1.5)
                            .padding(.leading, 4)
                    }
                    .padding(.top, 2)
                }
                Spacer()
                heroBadge
            }

            progressBar

            HStack(spacing: 14) {
                heroStat(label: "Highest", value: viewModel.highestTier.displayName, color: highestTierColor)
                heroStat(label: "Caught", value: "\(viewModel.totalCaughtCount)", color: theme.colors.brand.seafoam)
                heroStat(label: "Diamond", value: "\(viewModel.tierCount(.diamond))", color: Color(hex: 0x6EE6FF))
            }
        }
        .padding(theme.spacing.m)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: theme.radius.heroCard, style: .continuous)
                    .fill(theme.colors.surface.elevated)
                RoundedRectangle(cornerRadius: theme.radius.heroCard, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [theme.colors.brand.deepSea.opacity(0.45), Color.clear],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.heroCard, style: .continuous)
                .strokeBorder(theme.colors.brand.brassGold.opacity(0.35), lineWidth: 1)
        )
        .reelShadow(theme.shadow.heroCard)
    }

    private var heroBadge: some View {
        ZStack {
            Circle()
                .fill(theme.colors.surface.elevatedAlt)
                .frame(width: 96, height: 96)
            Circle()
                .strokeBorder(theme.colors.brand.brassGold.opacity(0.6), lineWidth: 2)
                .frame(width: 96, height: 96)
            VStack(spacing: -2) {
                Image(systemName: "fish.fill")
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.colors.brand.seafoam, theme.colors.brand.tideTeal],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .shadow(color: theme.colors.brand.seafoam.opacity(0.5), radius: 8)
                Text("LOG")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(theme.colors.brand.brassGold)
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.colors.surface.elevatedAlt)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [theme.colors.brand.seafoam, theme.colors.brand.crown],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * viewModel.discoveryProgress)
                    .animation(theme.motion.standard, value: viewModel.discoveryProgress)
            }
        }
        .frame(height: 10)
        .overlay(
            Capsule()
                .strokeBorder(theme.colors.brand.brassGold.opacity(0.25), lineWidth: 1)
        )
    }

    private func heroStat(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(theme.colors.text.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var highestTierColor: Color {
        switch viewModel.highestTier {
        case .locked:   return theme.colors.text.muted
        case .bronze:   return Color(hex: 0xE3A05A)
        case .silver:   return Color(hex: 0xCDCDCD)
        case .gold:     return theme.colors.brand.crown
        case .platinum: return Color(hex: 0xC2D9F0)
        case .diamond:  return Color(hex: 0x6EE6FF)
        }
    }

    // MARK: - Mastery rail

    private var masteryRail: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            SectionHeader(title: "Mastery", subtitle: "Species at each tier")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: theme.spacing.s) {
                    ForEach(FishMasteryTier.allCases.reversed()) { tier in
                        masteryStat(tier: tier)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func masteryStat(tier: FishMasteryTier) -> some View {
        let count = viewModel.tierCount(tier)
        return Button {
            withAnimation(theme.motion.fast) {
                filter = (filter == .tier(tier)) ? .all : .tier(tier)
            }
            appState.haptics?.tap()
        } label: {
            VStack(spacing: 6) {
                FishMasteryBadge(tier: tier, size: .medium, animated: count > 0)
                Text("\(count)")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(theme.colors.text.primary)
                    .monospacedDigit()
                Text(tier.displayName.uppercased())
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(theme.colors.text.muted)
            }
            .frame(width: 72, height: 110)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                    .fill(theme.colors.surface.elevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                    .strokeBorder(
                        filter == .tier(tier)
                        ? theme.colors.brand.crown
                        : theme.colors.brand.brassGold.opacity(0.18),
                        lineWidth: filter == .tier(tier) ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filter rail

    private var filterRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(.all)
                filterChip(.discovered)
                filterChip(.undiscovered)
                Rectangle()
                    .fill(theme.colors.text.muted.opacity(0.4))
                    .frame(width: 1, height: 22)
                ForEach(FishMasteryTier.allCases.dropFirst()) { tier in
                    filterChip(.tier(tier))
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func filterChip(_ option: TierFilter) -> some View {
        FilterChip(
            label: option.label,
            icon: filterIcon(option),
            isSelected: filter == option
        ) {
            withAnimation(theme.motion.fast) {
                filter = option
            }
            appState.haptics?.tap()
        }
    }

    private func filterIcon(_ option: TierFilter) -> String? {
        switch option {
        case .all:          return "square.grid.2x2.fill"
        case .discovered:   return "checkmark.seal.fill"
        case .undiscovered: return "lock.fill"
        case .tier(let t):  return t.iconName
        }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.colors.text.muted)
            TextField("Search species…", text: $query)
                .textInputAutocapitalization(.never)
                .foregroundStyle(theme.colors.text.primary)
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.colors.text.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, theme.spacing.s)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.colors.surface.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(theme.colors.brand.brassGold.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Grid

    @ViewBuilder
    private var contentGrid: some View {
        if viewModel.isLoading && viewModel.entries.isEmpty {
            LoadingView(message: "Hauling in the logbook…")
                .frame(height: 280)
        } else if filteredEntries.isEmpty {
            emptyState
                .padding(.top, theme.spacing.lg)
        } else {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(filteredEntries) { entry in
                    Button {
                        appState.haptics?.tap()
                        selectedEntry = entry
                    } label: {
                        FishLogCard(entry: entry)
                    }
                    .buttonStyle(PressDownButtonStyle())
                }
            }
        }
    }

    private var filteredEntries: [CodexEntry] {
        viewModel.entries
            .filter { matchesFilter($0) }
            .filter { matchesQuery($0) }
    }

    private func matchesFilter(_ entry: CodexEntry) -> Bool {
        switch filter {
        case .all:          return true
        case .discovered:   return entry.isDiscovered
        case .undiscovered: return !entry.isDiscovered
        case .tier(let t):  return entry.masteryTier == t
        }
    }

    private func matchesQuery(_ entry: CodexEntry) -> Bool {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return true }
        let q = query.lowercased()
        if entry.isDiscovered {
            return entry.species.displayName.lowercased().contains(q)
                || entry.species.name.lowercased().contains(q)
        } else {
            return "???".contains(q)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "fish.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(theme.colors.brand.seafoam.opacity(0.45))
            Text("No fish to show")
                .font(theme.typography.title2)
                .foregroundStyle(theme.colors.text.primary)
            Text("Try a different filter — or get out there and log a catch.")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacing.m)
            PirateButton(title: "Log a Catch", icon: "fish.fill") {
                appState.selectedTab = .spots
            }
            .padding(.top, theme.spacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing.xl)
    }
}

// MARK: - Card

private struct FishLogCard: View {
    let entry: CodexEntry
    @Environment(\.reelTheme) private var theme

    var body: some View {
        VStack(spacing: 10) {
            artwork
            VStack(spacing: 4) {
                Text(entry.isDiscovered ? entry.species.displayName : "???")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(entry.isDiscovered ? theme.colors.text.primary : theme.colors.text.muted)

                Text(rarityLabel)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(rarityColor)
            }
            statBlock
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                    .fill(theme.colors.surface.elevated)
                RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tierAccent.opacity(0.18), Color.clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .opacity(entry.isDiscovered ? 1 : 0)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                .strokeBorder(
                    entry.isDiscovered ? tierAccent.opacity(0.55) : theme.colors.text.muted.opacity(0.18),
                    lineWidth: 1
                )
        )
        .reelShadow(theme.shadow.card)
        .opacity(entry.isDiscovered ? 1 : 0.85)
    }

    private var artwork: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: artworkColors,
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(height: 96)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                        .blendMode(.overlay)
                )

            Image(systemName: "fish.fill")
                .font(.system(size: 56, weight: .black))
                .rotationEffect(.degrees(-12))
                .foregroundStyle(
                    entry.isDiscovered
                    ? AnyShapeStyle(LinearGradient(
                        colors: [.white.opacity(0.95), .white.opacity(0.55)],
                        startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(Color.black.opacity(0.45))
                )
                .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            FishMasteryBadge(tier: entry.masteryTier, size: .small)
                .padding(6)

            if !entry.isDiscovered {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(.ultraThinMaterial, in: Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(6)
            }
        }
    }

    private var statBlock: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "scope")
                    .font(.system(size: 9, weight: .black))
                Text(entry.isDiscovered ? "\(entry.totalCaught) caught" : "Undiscovered")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(theme.colors.text.secondary)

            if let pb = entry.personalBestDisplay {
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 9, weight: .black))
                    Text("PB \(pb)")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(theme.colors.brand.crown)
            } else {
                Text(" ")
                    .font(.system(size: 10))
            }
        }
    }

    private var rarityLabel: String {
        entry.isDiscovered ? entry.species.rarityTier.displayName.uppercased() : "—"
    }

    private var rarityColor: Color {
        switch entry.species.rarityTier {
        case .common:   return theme.colors.text.secondary
        case .uncommon: return theme.colors.brand.seafoam
        case .rare:     return Color(hex: 0x6FA8E8)
        case .trophy:   return theme.colors.brand.crown
        }
    }

    private var tierAccent: Color {
        switch entry.masteryTier {
        case .locked:   return theme.colors.text.muted
        case .bronze:   return Color(hex: 0xCD7F32)
        case .silver:   return Color(hex: 0xCFCFCF)
        case .gold:     return theme.colors.brand.crown
        case .platinum: return Color(hex: 0xC2D9F0)
        case .diamond:  return Color(hex: 0x6EE6FF)
        }
    }

    private var artworkColors: [Color] {
        if !entry.isDiscovered {
            return [
                theme.colors.surface.elevatedAlt,
                theme.colors.surface.canvas
            ]
        }
        switch entry.species.rarityTier {
        case .common:
            return [theme.colors.brand.tideTeal.opacity(0.7), theme.colors.brand.deepSea]
        case .uncommon:
            return [theme.colors.brand.seafoam.opacity(0.85), theme.colors.brand.tideTeal]
        case .rare:
            return [Color(hex: 0x6FA8E8), theme.colors.brand.deepSea]
        case .trophy:
            return [theme.colors.brand.crown, theme.colors.brand.brassGold]
        }
    }
}

// MARK: - Detail sheet

private struct FishLogDetailSheet: View {
    let entry: CodexEntry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.reelTheme) private var theme

    var body: some View {
        ZStack {
            theme.colors.surface.canvas.ignoresSafeArea()
            ScrollView {
                VStack(spacing: theme.spacing.lg) {
                    hero
                    masteryProgress
                    if let desc = entry.species.description, entry.isDiscovered {
                        infoBlock(title: "Field Notes", body: desc)
                    }
                    if let hab = entry.species.habitat, entry.isDiscovered {
                        infoBlock(title: "Habitat", body: hab)
                    }
                    rarityBlock
                }
                .padding(theme.spacing.m)
                .padding(.bottom, theme.spacing.xxl)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(theme.colors.text.secondary)
            }
            .padding(theme.spacing.m)
            .buttonStyle(.plain)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var hero: some View {
        VStack(spacing: theme.spacing.s) {
            ZStack {
                RoundedRectangle(cornerRadius: theme.radius.heroCard, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: heroColors,
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 200)
                Image(systemName: "fish.fill")
                    .font(.system(size: 130, weight: .black))
                    .foregroundStyle(.white.opacity(entry.isDiscovered ? 0.9 : 0.2))
                    .rotationEffect(.degrees(-12))
                    .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
                VStack {
                    HStack {
                        FishMasteryBadge(tier: entry.masteryTier, size: .medium)
                        Spacer()
                        Text(entry.species.rarityTier.displayName.uppercased())
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.black.opacity(0.35)))
                    }
                    Spacer()
                }
                .padding(theme.spacing.s)
            }

            Text(entry.isDiscovered ? entry.species.displayName : "???")
                .font(theme.typography.title1)
                .foregroundStyle(theme.colors.text.primary)
            if let family = entry.species.family, entry.isDiscovered {
                Text(family.capitalized)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.text.secondary)
            }
        }
    }

    private var masteryProgress: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Mastery")
                    .font(theme.typography.title2)
                    .foregroundStyle(theme.colors.text.primary)
                Spacer()
                FishMasteryChip(tier: entry.masteryTier, totalCaught: entry.totalCaught)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.colors.surface.elevatedAlt)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [theme.colors.brand.seafoam, theme.colors.brand.crown],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * entry.masteryTier.progress(catches: entry.totalCaught))
                }
            }
            .frame(height: 10)

            HStack {
                Text("\(entry.totalCaught) caught")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.text.secondary)
                Spacer()
                if let remaining = entry.masteryTier.catchesToNext(current: entry.totalCaught),
                   let next = nextTier {
                    Text("\(remaining) to \(next.displayName)")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.brand.crown)
                } else {
                    Text("Maxed out · Diamond")
                        .font(theme.typography.caption)
                        .foregroundStyle(Color(hex: 0x6EE6FF))
                }
            }

            if let pb = entry.personalBestDisplay {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(theme.colors.brand.crown)
                    Text("Personal Best: \(pb)")
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.text.primary)
                }
                .padding(.top, 4)
            }
        }
        .padding(theme.spacing.m)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                .fill(theme.colors.surface.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                .strokeBorder(theme.colors.brand.brassGold.opacity(0.25), lineWidth: 1)
        )
    }

    private var nextTier: FishMasteryTier? {
        guard let nextRaw = entry.masteryTier.nextTierCatches else { return nil }
        return FishMasteryTier.from(totalCaught: nextRaw)
    }

    private func infoBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(theme.typography.title2)
                .foregroundStyle(theme.colors.text.primary)
            Text(body)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacing.m)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                .fill(theme.colors.surface.elevated)
        )
    }

    private var rarityBlock: some View {
        HStack(spacing: theme.spacing.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Rarity")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(theme.colors.text.muted)
                Text(entry.species.rarityTier.displayName)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(theme.colors.text.primary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("XP Bonus")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(theme.colors.text.muted)
                Text(String(format: "x%.1f", entry.species.xpMultiplier))
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(theme.colors.brand.crown)
            }
        }
        .padding(theme.spacing.m)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                .fill(theme.colors.surface.elevated)
        )
    }

    private var heroColors: [Color] {
        if !entry.isDiscovered {
            return [theme.colors.surface.elevatedAlt, theme.colors.surface.canvas]
        }
        switch entry.species.rarityTier {
        case .common:   return [theme.colors.brand.tideTeal, theme.colors.brand.deepSea]
        case .uncommon: return [theme.colors.brand.seafoam, theme.colors.brand.tideTeal]
        case .rare:     return [Color(hex: 0x6FA8E8), theme.colors.brand.deepSea]
        case .trophy:   return [theme.colors.brand.crown, theme.colors.brand.brassGold]
        }
    }
}

// MARK: - View model

@MainActor
final class FishLogViewModel: ObservableObject {
    @Published var entries: [CodexEntry] = []
    @Published var isLoading = false

    var discoveredCount: Int { entries.filter(\.isDiscovered).count }
    var totalCount: Int { entries.count }
    var totalCaughtCount: Int { entries.reduce(0) { $0 + $1.totalCaught } }

    var discoveryProgress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(discoveredCount) / Double(totalCount)
    }

    var highestTier: FishMasteryTier {
        entries.map(\.masteryTier).max() ?? .locked
    }

    func tierCount(_ tier: FishMasteryTier) -> Int {
        entries.filter { $0.masteryTier == tier }.count
    }

    func load() async {
        guard let userId = AppState.shared.currentUser?.id else { return }
        isLoading = true
        defer { isLoading = false }
        let fetched = (try? await AppState.shared.codexService.getCodex(for: userId)) ?? []
        entries = fetched.sorted { lhs, rhs in
            if lhs.masteryTier != rhs.masteryTier {
                return lhs.masteryTier > rhs.masteryTier
            }
            return lhs.species.displayName < rhs.species.displayName
        }
    }
}

private struct PressDownButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
