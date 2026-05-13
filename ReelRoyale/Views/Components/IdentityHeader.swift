import SwiftUI

/// Sticky top "trainer card" HUD shown on every primary tab.
///
/// Every element is live and has a single tap purpose:
///   • Avatar + name   → Profile tab
///   • Tier + season # → Season screen
///   • Crowns          → Map (your held spots)
///   • Doubloons       → Shop
///   • Streak flame    → Home (your daily ritual)
struct IdentityHeader: View {
    @Environment(\.reelTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var appState: AppState

    @State private var shimmerPhase: CGFloat = 0

    var body: some View {
        HStack(spacing: theme.spacing.s) {
            avatarButton
            identityBlock
            Spacer(minLength: theme.spacing.xs)
            statsBlock
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.vertical, theme.spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(headerBackground.ignoresSafeArea(.container, edges: .top))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.colors.brand.brassGold.opacity(0.35))
                .frame(height: 0.75)
        }
        .onAppear {
            startShimmer()
            Task { await appState.refreshHUD() }
        }
    }

    // MARK: - Sections

    private var avatarButton: some View {
        Button {
            AppFeedback.tap.play(appState: appState)
            appState.selectedTab = .profile
        } label: {
            ShipAvatar(
                imageURL: avatarURL,
                initial: initial,
                tier: tier,
                size: .medium,
                showCrown: crownsHeld > 0,
                waveBob: !reduceMotion
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open your profile")
    }

    private var identityBlock: some View {
        Button {
            AppFeedback.tap.play(appState: appState)
            // Push the season screen onto the *current* tab's nav stack.
            pushOnCurrentTab(.season)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(captainName)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.colors.text.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    TierEmblem(tier: tier, division: 1, size: .small)
                        .overlay(shimmerOverlay.clipShape(Capsule(style: .continuous)))
                    Text(seasonLabel)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.colors.text.secondary)
                        .monospacedDigit()
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(captainName), \(tier.displayName), \(seasonLabel). Open season.")
    }

    private var statsBlock: some View {
        HStack(spacing: theme.spacing.s) {
            if streak > 0 {
                streakChip
            }
            crownChip
            doubloonsButton
        }
    }

    private var streakChip: some View {
        Button {
            AppFeedback.tap.play(appState: appState)
            appState.selectedTab = .home
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(theme.colors.brand.coralRed)
                Text("\(streak)")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.colors.text.primary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(theme.colors.surface.elevatedAlt)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(theme.colors.brand.coralRed.opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Daily streak: \(streak) days")
    }

    private var crownChip: some View {
        Button {
            AppFeedback.tap.play(appState: appState)
            appState.selectedTab = .spots
        } label: {
            HStack(spacing: 3) {
                CrownBadge(size: .small)
                Text("\(crownsHeld)")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.colors.brand.crown)
                    .monospacedDigit()
            }
            .opacity(crownsHeld == 0 ? 0.55 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Crowns held: \(crownsHeld). Open map.")
    }

    private var doubloonsButton: some View {
        Button {
            AppFeedback.tap.play(appState: appState)
            pushOnCurrentTab(.shop)
        } label: {
            DoubloonChip(amount: doubloons, size: .small)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(doubloons) doubloons. Open shop.")
    }

    private var headerBackground: some View {
        theme.colors.surface.elevated
            .overlay(
                LinearGradient(
                    colors: [
                        theme.colors.brand.deepSea.opacity(0.4),
                        Color.clear
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
    }

    /// Diagonal tier-tinted highlight that drifts across the tier emblem,
    /// the way Pokémon battle-rank badges shimmer between matches.
    private var shimmerOverlay: some View {
        let accent = theme.colors.tier.color(for: tier)
        return LinearGradient(
            stops: [
                .init(color: .clear,                       location: 0.0),
                .init(color: accent.opacity(0.0),          location: max(0, shimmerPhase - 0.18)),
                .init(color: accent.opacity(0.55),         location: shimmerPhase),
                .init(color: accent.opacity(0.0),          location: min(1, shimmerPhase + 0.18)),
                .init(color: .clear,                       location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
        .opacity(reduceMotion ? 0 : 1)
    }

    private func startShimmer() {
        guard !reduceMotion else { return }
        shimmerPhase = -0.2
        withAnimation(
            .easeInOut(duration: 2.4)
            .repeatForever(autoreverses: false)
            .delay(0.6)
        ) {
            shimmerPhase = 1.2
        }
    }

    private func pushOnCurrentTab(_ destination: NavigationDestination) {
        switch appState.selectedTab {
        case .home:      appState.homeNavigationPath.append(destination)
        case .spots:     appState.spotsNavigationPath.append(destination)
        case .fishLog:   appState.fishLogNavigationPath.append(destination)
        case .community: appState.communityNavigationPath.append(destination)
        case .profile:   appState.profileNavigationPath.append(destination)
        case .more:      appState.homeNavigationPath.append(destination); appState.selectedTab = .home
        }
    }

    // MARK: - Derived values

    private var captainName: String {
        appState.currentUser?.username.isEmpty == false
            ? appState.currentUser!.username
            : "Captain"
    }
    private var initial: String { String(captainName.first ?? "C") }
    private var avatarURL: URL? {
        guard let s = appState.currentUser?.avatarURL, !s.isEmpty else { return nil }
        return URL(string: s)
    }
    private var tier: CaptainTier {
        guard let rank = appState.currentUser?.rankTier else { return .deckhand }
        return CaptainTier.from(rankTier: rank)
    }
    private var doubloons: Int { appState.currentUser?.lureCoins ?? 0 }
    private var crownsHeld: Int { appState.crownsHeld }
    private var streak: Int { appState.dailyStreak }
    private var seasonLabel: String {
        let seasonTag: String = {
            if let s = appState.activeSeason { return "S\(s.seasonNumber)" }
            return "S—"
        }()
        if let r = appState.seasonRank {
            return "\(seasonTag) #\(r.formatted(.number))"
        }
        return "\(seasonTag) Unranked"
    }
}

#Preview {
    VStack(spacing: 0) {
        IdentityHeader()
        Spacer()
    }
    .background(ReelTheme.default.colors.surface.canvas)
    .environment(\.reelTheme, .default)
    .environmentObject(AppState.shared)
    .preferredColorScheme(.dark)
}
