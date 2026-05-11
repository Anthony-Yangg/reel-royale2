import SwiftUI

/// Top-3 podium hero with "your rank" slot below.
struct PodiumHeroSection: View {
    let top3: [CaptainRankEntry]
    let yourEntry: CaptainRankEntry?
    let onSelectEntry: (CaptainRankEntry) -> Void
    let onOpenLeaderboard: () -> Void

    @Environment(\.reelTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.m) {
            SectionHeader(
                title: "Top Captains",
                subtitle: "This season",
                trailingActionTitle: "Full Board",
                trailingAction: onOpenLeaderboard
            )

            if top3.isEmpty {
                LoadingView()
                    .frame(height: 220)
            } else {
                PodiumCard(entries: top3, onSelect: onSelectEntry)
                    .padding(.top, theme.spacing.xs)
                    .padding(.bottom, theme.spacing.s)
                    .background(
                        // Wood-plank stage backdrop hint
                        RoundedRectangle(cornerRadius: theme.radius.heroCard, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        theme.colors.brand.deepSea,
                                        theme.colors.surface.elevatedAlt
                                    ],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: theme.radius.heroCard, style: .continuous)
                                    .strokeBorder(theme.colors.brand.brassGold.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .reelShadow(theme.shadow.heroCard)
            }

            if let you = yourEntry {
                YourRankCard(entry: you, onTap: onOpenLeaderboard)
            }
        }
    }
}

private struct YourRankCard: View {
    let entry: CaptainRankEntry
    let onTap: () -> Void

    @Environment(\.reelTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: theme.spacing.s) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("YOU")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(theme.colors.brand.brassGold)
                    Text("Rank #\(entry.rank)")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(theme.colors.text.primary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 6) {
                        TierEmblem(tier: entry.tier, division: entry.division, size: .small)
                        DoubloonChip(amount: entry.doubloons, size: .small)
                    }
                    Text("Tap to view full board")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.colors.text.muted)
                }
            }
            .padding(theme.spacing.m)
            .background(
                RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                    .fill(theme.colors.surface.elevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                    .strokeBorder(theme.colors.brand.brassGold.opacity(0.45), lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }
}
