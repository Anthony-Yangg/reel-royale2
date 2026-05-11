import SwiftUI

/// Themed leaderboard row (rank N+, ship avatar, name+tier, points, trend).
struct LeaderboardRow: View {
    let entry: CaptainRankEntry
    let isYou: Bool
    let onTap: () -> Void

    @Environment(\.reelTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: theme.spacing.s) {
                rankCell
                ShipAvatar(
                    imageURL: entry.avatarURL.flatMap(URL.init),
                    initial: entry.captainName,
                    tier: entry.tier,
                    size: .medium,
                    showCrown: entry.crownsHeld > 0
                )
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(entry.captainName)
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(theme.colors.text.primary)
                            .lineLimit(1)
                        if isYou {
                            Text("YOU")
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .foregroundStyle(theme.colors.text.onLight)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(theme.colors.brand.brassGold))
                        }
                    }
                    HStack(spacing: 6) {
                        TierEmblem(tier: entry.tier, division: entry.division, size: .small)
                        if entry.crownsHeld > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundStyle(theme.colors.brand.crown)
                                Text("\(entry.crownsHeld)")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .foregroundStyle(theme.colors.brand.crown)
                            }
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    DoubloonChip(amount: entry.doubloons, size: .small)
                    trendBadge
                }
            }
            .padding(theme.spacing.s + 2)
            .background(
                RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                    .fill(isYou ? theme.colors.brand.brassGold.opacity(0.18) : theme.colors.surface.elevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                    .strokeBorder(isYou ? theme.colors.brand.brassGold : theme.colors.brand.brassGold.opacity(0.18), lineWidth: isYou ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var rankCell: some View {
        Text("#\(entry.rank)")
            .font(.system(size: 18, weight: .black, design: .rounded))
            .foregroundStyle(rankColor)
            .monospacedDigit()
            .frame(minWidth: 44, alignment: .leading)
    }

    private var rankColor: Color {
        switch entry.rank {
        case 1: theme.colors.brand.crown
        case 2: Color(hex: 0xC9D1D9)
        case 3: Color(hex: 0xCD7F32)
        default: theme.colors.text.primary
        }
    }

    private var trendBadge: some View {
        Group {
            if entry.weeklyDelta > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up").font(.system(size: 9, weight: .heavy))
                    Text("\(entry.weeklyDelta)").font(.system(size: 10, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(theme.colors.state.success)
            } else if entry.weeklyDelta < 0 {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.down").font(.system(size: 9, weight: .heavy))
                    Text("\(abs(entry.weeklyDelta))").font(.system(size: 10, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(theme.colors.brand.coralRed)
            } else {
                Text("—")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.colors.text.muted)
            }
        }
    }
}
