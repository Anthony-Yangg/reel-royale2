import SwiftUI

/// Horizontal scroll of spots the user currently rules.
struct YourCrownsSection: View {
    let spots: [Spot]
    let onClaimFirst: () -> Void
    let onSelectSpot: (Spot) -> Void

    @Environment(\.reelTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            SectionHeader(title: "Your Crowns", subtitle: "Spots you rule")
            if spots.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: theme.spacing.s) {
                        ForEach(spots) { spot in
                            Button {
                                onSelectSpot(spot)
                            } label: {
                                CrownSpotTile(spot: spot)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 1)
                }
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

private struct CrownSpotTile: View {
    let spot: Spot
    @Environment(\.reelTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                CrownBadge(size: .small)
                Text(spot.name)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.colors.text.primary)
                    .lineLimit(1)
            }
            Text(spot.bestCatchDisplay ?? "Ruling spot")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.colors.text.secondary)
                .lineLimit(1)
            Text(spot.regionName ?? spot.waterType?.displayName ?? "Open water")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.colors.brand.seafoam)
                .lineLimit(1)
        }
        .padding(.horizontal, theme.spacing.s)
        .padding(.vertical, theme.spacing.xs + 2)
        .frame(width: 170, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.button, style: .continuous)
                .fill(theme.colors.surface.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.button, style: .continuous)
                .strokeBorder(theme.colors.brand.crown.opacity(0.4), lineWidth: 1)
        )
    }
}
