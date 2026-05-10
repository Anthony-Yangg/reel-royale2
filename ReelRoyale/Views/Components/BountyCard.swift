import SwiftUI

/// Time-limited event card used on Home + Community Tavern hub.
struct BountyCard: View {
    let bounty: Bounty
    var compact: Bool = false
    let onTap: () -> Void

    @Environment(\.reelTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                HStack(spacing: theme.spacing.xs) {
                    Image(systemName: bounty.iconSystemName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(theme.colors.brand.crown)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle().fill(theme.colors.surface.elevatedAlt)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bounty.bountyType.displayName.uppercased())
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(theme.colors.brand.brassGold)
                            .tracking(1.0)
                        Text(bounty.title)
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(theme.colors.text.primary)
                            .lineLimit(1)
                    }
                    Spacer()
                    CountdownPill(endsAt: bounty.endsAt)
                }
                if !compact {
                    Text(bounty.detail)
                        .font(theme.typography.subhead)
                        .foregroundStyle(theme.colors.text.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: theme.spacing.s) {
                    Text(bounty.criteria)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.colors.text.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(theme.colors.surface.elevatedAlt)
                        )
                    Spacer()
                    DoubloonChip(amount: bounty.rewardDoubloons, size: .small)
                }
            }
            .padding(theme.spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                    .fill(theme.colors.surface.elevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                    .strokeBorder(theme.colors.brand.brassGold.opacity(0.35), lineWidth: 1)
            )
            .reelShadow(theme.shadow.card)
        }
        .buttonStyle(.plain)
    }
}

/// Countdown pill — shows time remaining as e.g. "9h 12m left".
struct CountdownPill: View {
    let endsAt: Date

    @Environment(\.reelTheme) private var theme

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            let remaining = endsAt.timeIntervalSince(ctx.date)
            let label = format(remaining)
            HStack(spacing: 4) {
                Image(systemName: "hourglass")
                    .font(.system(size: 10, weight: .black))
                Text(label)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(remaining < 3600 ? theme.colors.brand.coralRed : theme.colors.text.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(theme.colors.surface.elevatedAlt)
            )
        }
    }

    private func format(_ interval: TimeInterval) -> String {
        guard interval > 0 else { return "expired" }
        let h = Int(interval / 3600)
        let m = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        let d = h / 24
        if d > 0 { return "\(d)d \(h % 24)h" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m left"
    }
}
