import SwiftUI

/// Pokemon-inspired Fish Log for the user's caught species.
struct CodexView: View {
    @StateObject private var viewModel = CodexViewModel()
    @EnvironmentObject private var appState: AppState
    @Environment(\.reelTheme) private var theme
    @State private var filter: FishLogFilter = .all
    @State private var searchText = ""

    private let columns = [
        GridItem(.adaptive(minimum: 158), spacing: 12)
    ]

    var body: some View {
        ZStack {
            FishLogBackdrop()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: theme.spacing.m) {
                    masteryHeader
                    filterRail
                    PirateSearchBar(
                        text: $searchText,
                        placeholder: viewModel.totalCount > 0 ? "Search your \(viewModel.totalCount.formatted()) species" : "Search your fish"
                    )
                    masteryLadder

                    if viewModel.isLoading && viewModel.entries.isEmpty {
                        LoadingView(message: "Syncing fish log...")
                            .frame(height: 260)
                    } else if viewModel.entries.isEmpty {
                        EmptyStateView(
                            icon: "books.vertical.fill",
                            title: "No fish log yet",
                            message: "Catch your first fish to start filling the library.",
                            actionTitle: "Open map",
                            action: { appState.selectedTab = .spots }
                        )
                        .padding(.top, theme.spacing.xxl)
                    } else if filteredEntries.isEmpty {
                        EmptyStateView(
                            icon: "line.3.horizontal.decrease.circle.fill",
                            title: "No matches",
                            message: "Try another search or filter.",
                            actionTitle: "Clear filters",
                            action: {
                                searchText = ""
                                filter = .all
                            }
                        )
                        .padding(.top, theme.spacing.xxl)
                    } else {
                        LazyVGrid(columns: columns, spacing: theme.spacing.s) {
                            ForEach(filteredEntries) { entry in
                                FishLogSpeciesCard(
                                    entry: entry,
                                    catalogNumber: viewModel.catalogNumber(for: entry.id)
                                )
                            }
                        }
                    }

                    recentCatchLedger
                }
                .padding(.horizontal, theme.spacing.m)
                .padding(.top, theme.spacing.s)
                .padding(.bottom, 130)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private var filteredEntries: [CodexEntry] {
        let entries: [CodexEntry]
        switch filter {
        case .all:
            entries = viewModel.entries
        case .mastered:
            entries = viewModel.entries.filter { $0.masteryTier >= .gold }
        case .diamond:
            entries = viewModel.entries.filter { $0.masteryTier == .diamond }
        }

        let query = searchText.fishLogLookupKey
        guard !query.isEmpty else { return entries }

        return entries.filter { entry in
            entry.species.displayName.fishLogLookupKey.contains(query) ||
            entry.species.name.fishLogLookupKey.contains(query) ||
            (entry.species.family?.fishLogLookupKey.contains(query) ?? false)
        }
    }

    private var masteryHeader: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            HStack(alignment: .top, spacing: theme.spacing.s) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Fish Log")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(theme.colors.text.primary)
                    Text(viewModel.status.rawValue)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(viewModel.statusColor(theme: theme))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(viewModel.masteryPoints)")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(theme.colors.text.primary)
                        .monospacedDigit()
                    Text("Mastery pts")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(theme.colors.text.secondary)
                        .textCase(.uppercase)
                }
            }

            HStack(spacing: theme.spacing.s) {
                FishLogStatPill(value: "\(viewModel.discoveredCount)", label: "Caught", icon: "fish.fill", tint: theme.colors.brand.seafoam)
                FishLogStatPill(value: "\(viewModel.totalCaught)", label: "Total", icon: "checklist", tint: theme.colors.brand.brassGold)
                FishLogStatPill(value: "\(viewModel.diamondCount)", label: "Diamond", icon: "seal.fill", tint: FishMasteryTier.diamond.color(theme: theme))
            }

            ProgressView(value: viewModel.masteryCompletionProgress)
                .tint(theme.colors.text.primary)
                .scaleEffect(y: 1.25)

            Text("\(viewModel.goldPlusCount) gold+ species across \(viewModel.totalCount) logged species")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.colors.text.secondary)
        }
        .padding(theme.spacing.m)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, theme.colors.surface.elevated, Color(hex: 0xDDEEE9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(alignment: .trailing) {
            Image(systemName: "fish.fill")
                .font(.system(size: 106, weight: .black))
                .foregroundStyle(Color.black.opacity(0.035))
                .rotationEffect(.degrees(-14))
                .offset(x: 26, y: 10)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.black.opacity(0.07), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.09), radius: 18, x: 0, y: 10)
    }

    private var filterRail: some View {
        HStack(spacing: theme.spacing.xs) {
            ForEach(FishLogFilter.allCases) { item in
                Button {
                    AppFeedback.tap.play(appState: appState)
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.85)) {
                        filter = item
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: item.icon)
                            .font(.system(size: 11, weight: .black))
                        Text(item.rawValue)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(filter == item ? Color.white : theme.colors.text.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        Capsule(style: .continuous)
                            .fill(filter == item ? theme.colors.text.primary : theme.colors.surface.elevated)
                            .shadow(color: filter == item ? Color.black.opacity(0.12) : Color.clear, radius: 10, x: 0, y: 5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var masteryLadder: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            SectionHeader(title: "Mastery Stages", subtitle: "Per species")
            HStack(spacing: theme.spacing.xs) {
                ForEach(FishMasteryTier.allCases.filter { $0 != .unranked }) { tier in
                    VStack(spacing: 6) {
                        Image(systemName: tier.symbolName)
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(tier.color(theme: theme))
                        Text(tier.shortName)
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(theme.colors.text.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("\(viewModel.count(for: tier))")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(tier.color(theme: theme))
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(theme.colors.surface.elevated.opacity(0.86))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(tier.color(theme: theme).opacity(0.42), lineWidth: 1)
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var recentCatchLedger: some View {
        if !viewModel.recentCatches.isEmpty {
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                SectionHeader(title: "Recent Log", subtitle: "Every catch counts")
                VStack(spacing: theme.spacing.xs) {
                    ForEach(viewModel.recentCatches.prefix(6)) { fishCatch in
                        Button {
                            openCatch(fishCatch.id)
                        } label: {
                            HStack(spacing: theme.spacing.s) {
                                ZStack {
                                    Circle()
                                        .fill(theme.colors.brand.tideTeal.opacity(0.30))
                                        .frame(width: 42, height: 42)
                                    Image(systemName: "fish.fill")
                                        .font(.system(size: 19, weight: .black))
                                        .foregroundStyle(theme.colors.brand.seafoam)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fishCatch.species)
                                        .font(.system(size: 14, weight: .black, design: .rounded))
                                        .foregroundStyle(theme.colors.text.primary)
                                    Text("\(fishCatch.sizeDisplay) - \(fishCatch.createdAt.relativeTime)")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(theme.colors.text.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundStyle(theme.colors.text.muted)
                            }
                            .padding(theme.spacing.s)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(theme.colors.surface.elevated.opacity(0.88))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func openCatch(_ catchId: String) {
        switch appState.selectedTab {
        case .fishLog:
            appState.fishLogNavigationPath.append(NavigationDestination.catchDetail(catchId: catchId))
        case .profile:
            appState.profileNavigationPath.append(NavigationDestination.catchDetail(catchId: catchId))
        case .spots:
            appState.spotsNavigationPath.append(NavigationDestination.catchDetail(catchId: catchId))
        case .community:
            appState.communityNavigationPath.append(NavigationDestination.catchDetail(catchId: catchId))
        case .home, .more:
            appState.homeNavigationPath.append(NavigationDestination.catchDetail(catchId: catchId))
        }
    }
}

private struct FishLogBackdrop: View {
    @Environment(\.reelTheme) private var theme

    var body: some View {
        LinearGradient(
            colors: [Color(hex: 0xFCFAF7), theme.colors.surface.canvas, Color(hex: 0xE6F0ED)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            FishLogDiamondGrid()
                .stroke(Color.black.opacity(0.035), lineWidth: 1)
        }
    }
}

private struct FishLogDiamondGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 74
        let height = rect.height + spacing * 2
        let width = rect.width + spacing * 2

        var x = -width
        while x < width * 1.5 {
            path.move(to: CGPoint(x: x, y: -spacing))
            path.addLine(to: CGPoint(x: x + height, y: height - spacing))
            x += spacing
        }

        x = -width
        while x < width * 1.5 {
            path.move(to: CGPoint(x: x, y: height))
            path.addLine(to: CGPoint(x: x + height, y: -spacing))
            x += spacing
        }

        return path
    }
}

private struct FishLogStatPill: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color

    @Environment(\.reelTheme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(theme.colors.text.primary)
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundStyle(theme.colors.text.muted)
                    .textCase(.uppercase)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                )
        )
    }
}

private struct FishLogSpeciesCard: View {
    let entry: CodexEntry
    let catalogNumber: Int
    @Environment(\.reelTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(iconWellFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(entry.masteryTier.color(theme: theme).opacity(0.34), lineWidth: 1)
                    )

                FishLogSpeciesArtwork(species: entry.species, isDiscovered: true)
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .shadow(color: Color.black.opacity(0.14), radius: 12, x: 0, y: 8)

                VStack(alignment: .trailing, spacing: 7) {
                    masteryBadge
                    rarityBadge
                }
                .padding(8)
            }
            .frame(height: 126)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text("#\(String(format: "%03d", catalogNumber))")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(theme.colors.text.muted)
                        .monospacedDigit()

                    Spacer(minLength: 4)

                    Label("\(entry.totalCaught)x", systemImage: "fish.fill")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(theme.colors.text.secondary)
                        .lineLimit(1)
                }

                Text(entry.species.displayName)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(theme.colors.text.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text(speciesDetail)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.colors.text.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            HStack(spacing: 6) {
                miniStat(icon: "checkmark.seal.fill", value: "\(entry.totalCaught)", label: "Caught")

                if let personalBest = entry.personalBestDisplay {
                    miniStat(icon: "ruler", value: personalBest, label: "Best")
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(nextMasteryLabel)
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(theme.colors.text.muted)
                        .textCase(.uppercase)
                    Spacer()
                    Text("\(Int(entry.masteryProgressToNext * 100))%")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(entry.masteryTier.color(theme: theme))
                        .monospacedDigit()
                }

                ProgressView(value: entry.masteryProgressToNext)
                    .tint(entry.masteryTier.color(theme: theme))
                    .scaleEffect(y: 0.9)
            }
        }
        .padding(10)
        .frame(height: 236)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.96), theme.colors.surface.elevated, entry.masteryTier.color(theme: theme).opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(entry.masteryTier.color(theme: theme).opacity(0.38), lineWidth: 1)
        )
        .shadow(color: entry.masteryTier.color(theme: theme).opacity(0.16), radius: 18, x: 0, y: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.species.displayName), \(entry.totalCaught) caught, \(entry.masteryTier.displayName) mastery")
    }

    private var masteryBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: entry.masteryTier.symbolName)
                .font(.system(size: 10, weight: .black))
            Text(entry.masteryTier.shortName)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(entry.masteryTier == .unranked ? theme.colors.text.muted : theme.colors.text.primary)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(entry.masteryTier.color(theme: theme).opacity(entry.masteryTier == .unranked ? 0.20 : 1))
        )
    }

    private var rarityBadge: some View {
        Text(entry.species.rarityTier.displayName)
            .font(.system(size: 8, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(rarityColor.opacity(0.94))
            )
    }

    private func miniStat(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(entry.masteryTier.color(theme: theme))

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(theme.colors.text.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 7, weight: .black, design: .rounded))
                    .foregroundStyle(theme.colors.text.muted)
                    .textCase(.uppercase)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private var speciesDetail: String {
        if let family = entry.species.family, !family.isEmpty {
            return family
        }
        if entry.species.name != entry.species.displayName {
            return entry.species.name
        }
        return entry.species.habitat ?? entry.species.rarityTier.displayName
    }

    private var nextMasteryLabel: String {
        guard let nextTier = entry.masteryTier.nextTier else { return "Max mastery" }
        return "To \(nextTier.displayName)"
    }

    private var rarityColor: Color {
        switch entry.species.rarityTier {
        case .common: return theme.colors.text.secondary
        case .uncommon: return theme.colors.brand.seafoam
        case .rare: return Color(hex: 0x3F7E97)
        case .trophy: return theme.colors.brand.crown
        }
    }

    private var iconWellFill: LinearGradient {
        LinearGradient(
            colors: [Color.white, entry.masteryTier.color(theme: theme).opacity(0.34), theme.colors.surface.elevatedAlt],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct FishLogSpeciesArtwork: View {
    let species: Species
    let isDiscovered: Bool
    @Environment(\.reelTheme) private var theme

    var body: some View {
        ZStack {
            if let imageURL = species.imageURL.flatMap(URL.init) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFit()
                    default:
                        GeneratedFishIcon(species: species, isDiscovered: isDiscovered)
                    }
                }
                .saturation(isDiscovered ? 1 : 0)
                .contrast(isDiscovered ? 1 : 0.68)
                .brightness(isDiscovered ? 0 : -0.08)
                .opacity(isDiscovered ? 1 : 0.52)
            } else {
                GeneratedFishIcon(species: species, isDiscovered: isDiscovered)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct GeneratedFishIcon: View {
    let species: Species
    let isDiscovered: Bool

    private var profile: FishIconProfile { FishIconProfile(species: species) }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let bodyWidth = size.width * profile.bodyWidth
            let bodyHeight = size.height * profile.bodyHeight
            let bodyX = size.width * 0.55
            let bodyY = size.height * 0.52
            let base = isDiscovered ? profile.base : Color(hex: 0xAFAFAA)
            let belly = isDiscovered ? profile.belly : Color(hex: 0xE5E3DF)
            let accent = isDiscovered ? profile.accent : Color(hex: 0x73736F)
            let detail = isDiscovered ? profile.detail : Color(hex: 0x4E4E4B)

            ZStack {
                FishTailShape()
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(isDiscovered ? 0.95 : 0.60), base.opacity(isDiscovered ? 0.78 : 0.48)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size.width * 0.30, height: bodyHeight * 0.98)
                    .position(x: size.width * 0.23, y: bodyY)

                if profile.hasLongFins {
                    FishFinShape()
                        .fill(accent.opacity(isDiscovered ? 0.76 : 0.38))
                        .frame(width: bodyWidth * 0.38, height: bodyHeight * 0.42)
                        .rotationEffect(.degrees(-7))
                        .position(x: bodyX - bodyWidth * 0.06, y: bodyY + bodyHeight * 0.44)
                }

                FishBodyShape(kind: profile.bodyKind)
                    .fill(
                        LinearGradient(
                            colors: [base, belly],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: bodyWidth, height: bodyHeight)
                    .position(x: bodyX, y: bodyY)
                    .overlay {
                        FishBodyShape(kind: profile.bodyKind)
                            .stroke(detail.opacity(0.18), lineWidth: 1.5)
                            .frame(width: bodyWidth, height: bodyHeight)
                            .position(x: bodyX, y: bodyY)
                    }

                FishFinShape()
                    .fill(accent.opacity(isDiscovered ? 0.88 : 0.48))
                    .frame(width: bodyWidth * 0.26, height: bodyHeight * 0.32)
                    .rotationEffect(.degrees(180 + Double(profile.seed % 18)))
                    .position(x: bodyX - bodyWidth * 0.06, y: bodyY - bodyHeight * 0.44)

                FishPatternLayer(profile: profile, color: detail, bodyWidth: bodyWidth, bodyHeight: bodyHeight)
                    .opacity(isDiscovered ? 0.95 : 0.44)
                    .position(x: bodyX, y: bodyY)

                if profile.hasWhiskers {
                    WhiskerShape()
                        .stroke(detail.opacity(isDiscovered ? 0.72 : 0.46), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                        .frame(width: bodyWidth * 0.25, height: bodyHeight * 0.26)
                        .position(x: bodyX + bodyWidth * 0.46, y: bodyY + bodyHeight * 0.08)
                }

                Circle()
                    .fill(isDiscovered ? Color.white : Color(hex: 0xD8D6D1))
                    .frame(width: bodyHeight * 0.16, height: bodyHeight * 0.16)
                    .position(x: bodyX + bodyWidth * 0.34, y: bodyY - bodyHeight * 0.12)

                Circle()
                    .fill(detail)
                    .frame(width: bodyHeight * 0.075, height: bodyHeight * 0.075)
                    .position(x: bodyX + bodyWidth * 0.36, y: bodyY - bodyHeight * 0.12)
            }
            .frame(width: size.width, height: size.height)
        }
        .saturation(isDiscovered ? 1 : 0)
    }
}

private struct FishPatternLayer: View {
    let profile: FishIconProfile
    let color: Color
    let bodyWidth: CGFloat
    let bodyHeight: CGFloat

    var body: some View {
        ZStack {
            switch profile.patternKind {
            case 0:
                ForEach(0..<profile.stripeCount, id: \.self) { index in
                    Capsule()
                        .fill(color.opacity(0.30))
                        .frame(width: bodyWidth * 0.045, height: bodyHeight * 0.72)
                        .rotationEffect(.degrees(-12))
                        .offset(x: -bodyWidth * 0.18 + CGFloat(index) * bodyWidth * 0.14)
                }
            case 1:
                ForEach(0..<profile.spotCount, id: \.self) { index in
                    Circle()
                        .fill(color.opacity(0.28))
                        .frame(width: bodyHeight * 0.13, height: bodyHeight * 0.13)
                        .offset(
                            x: -bodyWidth * 0.22 + CGFloat((index * 37) % 5) * bodyWidth * 0.11,
                            y: -bodyHeight * 0.18 + CGFloat((index * 19) % 4) * bodyHeight * 0.12
                        )
                }
            case 2:
                Capsule()
                    .fill(color.opacity(0.34))
                    .frame(width: bodyWidth * 0.62, height: bodyHeight * 0.065)
                    .offset(x: -bodyWidth * 0.03, y: bodyHeight * 0.03)
            default:
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(color.opacity(0.20))
                        .frame(width: bodyWidth * 0.18, height: bodyHeight * 0.18)
                        .rotationEffect(.degrees(45))
                        .offset(x: -bodyWidth * 0.18 + CGFloat(index) * bodyWidth * 0.18)
                }
            }
        }
        .frame(width: bodyWidth, height: bodyHeight)
        .clipShape(FishBodyShape(kind: profile.bodyKind))
    }
}

private struct FishIconProfile {
    let seed: Int
    let bodyKind: Int
    let patternKind: Int
    let stripeCount: Int
    let spotCount: Int
    let bodyWidth: CGFloat
    let bodyHeight: CGFloat
    let hasLongFins: Bool
    let hasWhiskers: Bool
    let base: Color
    let belly: Color
    let accent: Color
    let detail: Color

    init(species: Species) {
        let name = species.displayName.lowercased()
        let family = species.family?.lowercased() ?? ""
        let habitat = species.habitat?.lowercased() ?? ""
        let stableSeed = FishIconProfile.stableHash([name, family, habitat, species.rarityTier.rawValue].joined(separator: "|"))
        seed = stableSeed
        bodyKind = stableSeed % 4
        patternKind = (stableSeed / 5) % 4
        stripeCount = 2 + stableSeed % 4
        spotCount = 4 + stableSeed % 5
        bodyWidth = [0.58, 0.66, 0.72, 0.54][stableSeed % 4]
        bodyHeight = [0.42, 0.34, 0.28, 0.50][(stableSeed / 3) % 4]
        hasLongFins = name.contains("trout") || name.contains("salmon") || name.contains("bass") || stableSeed.isMultiple(of: 3)
        hasWhiskers = name.contains("catfish") || family.contains("catfish") || stableSeed.isMultiple(of: 11)

        let palette = FishIconProfile.palette(
            for: species.rarityTier,
            name: name,
            family: family,
            habitat: habitat,
            seed: stableSeed
        )
        base = palette.0
        belly = palette.1
        accent = palette.2
        detail = palette.3
    }

    private static func stableHash(_ text: String) -> Int {
        var hash = 5381
        for scalar in text.unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ Int(scalar.value)
        }
        return abs(hash)
    }

    private static func palette(for rarity: FishRarity, name: String, family: String, habitat: String, seed: Int) -> (Color, Color, Color, Color) {
        let freshwater = habitat.contains("river") || habitat.contains("lake") || habitat.contains("fresh")
        let saltwater = habitat.contains("ocean") || habitat.contains("salt") || habitat.contains("coast") || habitat.contains("sea")
        let warm = name.contains("snapper") || name.contains("perch") || name.contains("sunfish")
        let cool = name.contains("trout") || name.contains("salmon") || saltwater

        let palettes: [(Color, Color, Color, Color)] = [
            (Color(hex: 0x6F9D9A), Color(hex: 0xD9EFE8), Color(hex: 0xD3A44E), Color(hex: 0x1F484A)),
            (Color(hex: 0x4D8BB8), Color(hex: 0xDDECF5), Color(hex: 0xE08A6B), Color(hex: 0x233E5C)),
            (Color(hex: 0x8C9B5A), Color(hex: 0xEEF0D5), Color(hex: 0xC79545), Color(hex: 0x3E4A2F)),
            (Color(hex: 0xC7765E), Color(hex: 0xF7E5D9), Color(hex: 0x6F9D9A), Color(hex: 0x5A2D26)),
            (Color(hex: 0x8E7BC7), Color(hex: 0xECE6FA), Color(hex: 0xD3A44E), Color(hex: 0x3B315E)),
            (Color(hex: 0x3F7E97), Color(hex: 0xD8EEF2), Color(hex: 0xB78D4D), Color(hex: 0x173E4B))
        ]

        let preferredIndex: Int
        if warm {
            preferredIndex = 3
        } else if cool {
            preferredIndex = 1
        } else if freshwater {
            preferredIndex = 0
        } else if family.contains("sunfish") {
            preferredIndex = 2
        } else {
            preferredIndex = seed % palettes.count
        }

        var palette = palettes[preferredIndex]
        switch rarity {
        case .common:
            break
        case .uncommon:
            palette.2 = Color(hex: 0x6F9D9A)
        case .rare:
            palette.2 = Color(hex: 0x8E7BC7)
        case .trophy:
            palette.2 = Color(hex: 0xD3A44E)
            palette.3 = Color(hex: 0x171717)
        }
        return palette
    }
}

private struct FishBodyShape: Shape {
    let kind: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch kind {
        case 1:
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: rect.height * 0.7, height: rect.height * 0.7))
        case 2:
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX * 0.88, y: rect.minY + rect.height * 0.18), control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.10))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.34))
            path.addQuadCurve(to: CGPoint(x: rect.maxX * 0.88, y: rect.maxY - rect.height * 0.18), control: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.34))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY), control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.10))
        default:
            path.addEllipse(in: rect)
        }
        return path
    }
}

private struct FishTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.midY), control: CGPoint(x: rect.minX + rect.width * 0.32, y: rect.midY - rect.height * 0.14))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct FishFinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.midX - rect.width * 0.1, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX + rect.width * 0.12, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct WhiskerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.2))
        path.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.12))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.15))
        return path
    }
}

private enum FishLogFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case mastered = "Gold+"
    case diamond = "Diamond"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .mastered: return "trophy.fill"
        case .diamond: return "seal.fill"
        }
    }
}

private extension FishMasteryTier {
    var shortName: String {
        switch self {
        case .unranked: return "New"
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Plat"
        case .diamond: return "Diamond"
        }
    }

    var symbolName: String {
        switch self {
        case .unranked: return "circle"
        case .bronze: return "seal.fill"
        case .silver: return "seal.fill"
        case .gold: return "star.circle.fill"
        case .platinum: return "sparkles"
        case .diamond: return "diamond.fill"
        }
    }

    func color(theme: ReelTheme) -> Color {
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

private extension CodexViewModel {
    func statusColor(theme: ReelTheme) -> Color {
        switch status {
        case .beginner: return theme.colors.brand.seafoam
        case .collector: return theme.colors.brand.brassGold
        case .specialist: return theme.colors.brand.crown
        case .master: return Color(hex: 0x8FE8FF)
        case .apex: return Color(hex: 0xA78BFA)
        }
    }
}

@MainActor
final class CodexViewModel: ObservableObject {
    @Published var entries: [CodexEntry] = []
    @Published var recentCatches: [FishCatch] = []
    @Published var isLoading = false
    private var catalogNumbersBySpeciesId: [String: Int] = [:]

    var discoveredCount: Int { entries.filter(\.isDiscovered).count }
    var totalCount: Int { entries.count }
    var totalCaught: Int { entries.reduce(0) { $0 + $1.totalCaught } }
    var goldPlusCount: Int { entries.filter { $0.masteryTier >= .gold }.count }
    var diamondCount: Int { count(for: .diamond) }
    var masteryPoints: Int { entries.reduce(0) { $0 + $1.masteryPoints } }
    var status: FishLogStatus {
        FishLogStatus.status(for: masteryPoints, discoveredCount: discoveredCount)
    }
    var masteryCompletionProgress: Double {
        guard !entries.isEmpty else { return 0 }
        let diamondTarget = FishMasteryTier.diamond.minCaught
        let completed = entries.reduce(0) { $0 + min($1.totalCaught, diamondTarget) }
        return Double(completed) / Double(entries.count * diamondTarget)
    }

    func count(for tier: FishMasteryTier) -> Int {
        entries.filter { $0.masteryTier == tier }.count
    }

    func catalogNumber(for speciesId: String) -> Int {
        catalogNumbersBySpeciesId[speciesId] ?? 0
    }

    func load() async {
        guard let userId = AppState.shared.currentUser?.id else { return }
        isLoading = true
        defer { isLoading = false }

        async let codexTask = AppState.shared.codexService.getCodex(for: userId)
        async let catchesTask = AppState.shared.catchRepository.getCatches(forUser: userId)

        let catches = ((try? await catchesTask) ?? [])
        entries = ((try? await codexTask) ?? [])
            .mergingCatchHistory(catches, userId: userId)
            .stableCatalogSorted()
        catalogNumbersBySpeciesId = Dictionary(uniqueKeysWithValues: entries.enumerated().map { index, entry in
            (entry.id, index + 1)
        })
        recentCatches = catches.sorted { $0.createdAt > $1.createdAt }
    }
}

private extension Array where Element == CodexEntry {
    func mergingCatchHistory(_ catches: [FishCatch], userId: String) -> [CodexEntry] {
        let catchesByName = Dictionary(grouping: catches) { $0.species.fishLogLookupKey }
        var consumedCatchKeys = Set<String>()

        var merged = map { entry in
            let keys = [
                entry.species.name.fishLogLookupKey,
                entry.species.displayName.fishLogLookupKey
            ].filter { !$0.isEmpty }
            consumedCatchKeys.formUnion(keys)

            guard entry.userRecord == nil else { return entry }

            var matchesById: [String: FishCatch] = [:]
            for key in keys {
                for fishCatch in catchesByName[key] ?? [] {
                    matchesById[fishCatch.id] = fishCatch
                }
            }

            let matches = matchesById.values.map { $0 }
            guard !matches.isEmpty else { return entry }

            return CodexEntry(
                species: entry.species,
                userRecord: makeCatchDerivedRecord(from: matches, speciesId: entry.id, userId: userId)
            )
        }

        for (key, matches) in catchesByName where !key.isEmpty && !consumedCatchKeys.contains(key) {
            let species = Species.fishLogDerived(from: matches, key: key)
            let record = makeCatchDerivedRecord(from: matches, speciesId: species.id, userId: userId)
            merged.append(CodexEntry(species: species, userRecord: record))
        }

        return merged.filter(\.isDiscovered)
    }

    func stableCatalogSorted() -> [CodexEntry] {
        sorted { lhs, rhs in
            if lhs.species.createdAt != rhs.species.createdAt {
                return lhs.species.createdAt < rhs.species.createdAt
            }
            return lhs.species.displayName.localizedStandardCompare(rhs.species.displayName) == .orderedAscending
        }
    }
}

private func makeCatchDerivedRecord(from catches: [FishCatch], speciesId: String, userId: String) -> UserSpecies {
    let first = catches.min { $0.createdAt < $1.createdAt }
    let last = catches.max { $0.createdAt < $1.createdAt }
    let best = catches.max { lhs, rhs in
        lhs.normalizedLengthInCentimeters < rhs.normalizedLengthInCentimeters
    }

    return UserSpecies(
        id: "catch-derived-\(userId)-\(speciesId)",
        userId: userId,
        speciesId: speciesId,
        personalBestSize: best?.sizeValue,
        personalBestUnit: best?.sizeUnit,
        personalBestCatchId: best?.id,
        totalCaught: catches.count,
        firstCaughtAt: first?.createdAt ?? Date(),
        firstCaughtSpotId: first?.spotId,
        lastCaughtAt: last?.createdAt
    )
}

private extension Species {
    static func fishLogDerived(from catches: [FishCatch], key: String) -> Species {
        let name = catches.first?.species.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = name?.isEmpty == false ? name ?? key : key
        let best = catches.max { lhs, rhs in
            lhs.normalizedLengthInCentimeters < rhs.normalizedLengthInCentimeters
        }
        let firstCaughtAt = catches.map(\.createdAt).min() ?? Date()
        let rarity = inferredRarity(for: displayName, bestSizeCentimeters: best?.normalizedLengthInCentimeters)

        return Species(
            id: "catch-derived-\(key.fishLogSlug)",
            name: displayName,
            commonName: displayName,
            rarityTier: rarity,
            xpMultiplier: rarity.xpMultiplier,
            description: "Logged from your catch history.",
            habitat: nil,
            averageSize: best?.normalizedLengthInCentimeters,
            family: inferredFamily(for: displayName),
            imageURL: nil,
            createdAt: firstCaughtAt
        )
    }

    private static func inferredRarity(for name: String, bestSizeCentimeters: Double?) -> FishRarity {
        let key = name.fishLogLookupKey
        if key.contains("marlin") || key.contains("sailfish") || key.contains("sturgeon") || key.contains("muskie") || key.contains("tarpon") || key.contains("shark") {
            return .trophy
        }
        if key.contains("salmon") || key.contains("tuna") || key.contains("pike") || key.contains("catfish") || key.contains("gar") {
            return .rare
        }
        if key.contains("trout") || key.contains("bass") || key.contains("snapper") || key.contains("walleye") || key.contains("redfish") {
            return .uncommon
        }
        if (bestSizeCentimeters ?? 0) >= 100 {
            return .trophy
        }
        if (bestSizeCentimeters ?? 0) >= 60 {
            return .rare
        }
        return .common
    }

    private static func inferredFamily(for name: String) -> String? {
        let key = name.fishLogLookupKey
        let knownFamilies = [
            "bass", "trout", "salmon", "catfish", "sunfish", "carp", "perch",
            "pike", "gar", "snapper", "drum", "tuna", "marlin", "shark"
        ]

        guard let match = knownFamilies.first(where: { key.contains($0) }) else { return nil }
        return match.split(separator: " ").map { $0.capitalized }.joined(separator: " ")
    }
}

private extension FishCatch {
    var normalizedLengthInCentimeters: Double {
        switch sizeUnit.lowercased() {
        case "in", "inch", "inches":
            return sizeValue * 2.54
        case "ft", "foot", "feet":
            return sizeValue * 30.48
        default:
            return sizeValue
        }
    }
}

private extension String {
    var fishLogLookupKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }

    var fishLogSlug: String {
        let components = fishLogLookupKey
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        return components.isEmpty ? "unknown" : components.joined(separator: "-")
    }
}
