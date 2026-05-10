import SwiftUI

/// Horizontal scroll of spots the user currently rules.
/// Wave 2 mocks empty state ("Claim your first crown") since real user crowns lands in Wave 5.
struct YourCrownsSection: View {
    let crownsHeld: Int                    // 0 in Wave 2
    let onClaimFirst: () -> Void

    @Environment(\.reelTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            SectionHeader(title: "Your Crowns", subtitle: "Spots you rule")
            if crownsHeld == 0 {
                emptyState
            } else {
                Text("Wave 5 wires real crowns.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.text.muted)
            }
        }
    }

    private var emptyState: some View {
        HStack(spacing: theme.spacing.m) {
            ZStack {
                Circle()
                    .fill(theme.colors.surface.elevatedAlt)
                    .frame(width: 56, height: 56)
                Image(systemName: "crown")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(theme.colors.brand.brassGold.opacity(0.55))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Claim your first crown")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.colors.text.primary)
                Text("Catch the biggest fish at a spot to rule it.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.text.secondary)
            }
            Spacer()
            GhostButton(title: "Find Spot", icon: "mappin", action: onClaimFirst)
        }
        .padding(theme.spacing.m)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                .fill(theme.colors.surface.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                .strokeBorder(theme.colors.brand.brassGold.opacity(0.2), lineWidth: 1)
        )
    }
}
