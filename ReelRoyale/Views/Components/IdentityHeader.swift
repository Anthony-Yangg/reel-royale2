import SwiftUI

/// Sticky top header shown on every primary tab.
/// Wave 1: data sourced from `AppState.currentUser` with safe fallbacks.
/// Tier / crowns / doubloons / season rank land in Wave 5.
struct IdentityHeader: View {
    @Environment(\.reelTheme) private var theme
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: theme.spacing.s) {
            ShipAvatar(
                imageURL: avatarURL,
                initial: initial,
                tier: tier,
                size: .medium,
                showCrown: crownsHeld > 0
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(captainName)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.colors.text.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    TierEmblem(tier: tier, division: 1, size: .small)
                    Text("S1 #\(seasonRankString)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.colors.text.secondary)
                }
            }

            Spacer(minLength: theme.spacing.xs)

            HStack(spacing: theme.spacing.s) {
                if crownsHeld > 0 {
                    HStack(spacing: 3) {
                        CrownBadge(size: .small)
                        Text("\(crownsHeld)")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(theme.colors.brand.crown)
                            .monospacedDigit()
                    }
                }
                DoubloonChip(amount: doubloons, size: .small)
            }
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.vertical, theme.spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
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
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.colors.brand.brassGold.opacity(0.35))
                .frame(height: 0.75)
        }
    }

    // MARK: Mock values backed by current user (Wave 1)
    private var captainName: String {
        appState.currentUser?.username ?? "Captain"
    }
    private var initial: String { String(captainName.first ?? "C") }
    private var avatarURL: URL? {
        guard let s = appState.currentUser?.avatarURL, !s.isEmpty else { return nil }
        return URL(string: s)
    }
    // Fields not yet on User (Wave 5 adds them). Defaults for Wave 1.
    private var tier: CaptainTier { .deckhand }
    private var doubloons: Int { 0 }
    private var crownsHeld: Int { 0 }
    private var seasonRankString: String { "—" }
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
