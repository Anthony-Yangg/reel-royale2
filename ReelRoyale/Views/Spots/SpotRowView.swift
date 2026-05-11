import SwiftUI

/// Themed spot list row.
struct SpotRowView: View {
    let spotDetails: SpotWithDetails

    @Environment(\.reelTheme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.s) {
            // Water type emblem
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.colors.brand.tideTeal, theme.colors.brand.deepSea],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 46)
                Image(systemName: spotDetails.spot.waterType?.icon ?? "drop.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(theme.colors.brand.parchment)
            }
            .overlay(
                Circle().strokeBorder(theme.colors.brand.brassGold.opacity(0.3), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(spotDetails.spot.name)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(theme.colors.text.primary)
                        .lineLimit(1)
                    if spotDetails.spot.hasKing {
                        CrownBadge(size: .small)
                    }
                }

                if let region = spotDetails.spot.regionName {
                    Text(region)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.text.secondary)
                } else {
                    Text(spotDetails.spot.formattedCoordinates)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.text.muted)
                }

                HStack(spacing: theme.spacing.s) {
                    if let king = spotDetails.kingUser {
                        chip(icon: "crown.fill", text: king.username, tint: theme.colors.brand.crown)
                    }
                    if let bestDisplay = spotDetails.spot.bestCatchDisplay {
                        chip(icon: "ruler", text: bestDisplay, tint: theme.colors.brand.seafoam)
                    }
                    if let distance = spotDetails.distance {
                        chip(icon: "location.fill", text: distance.formattedDistance, tint: theme.colors.text.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(spotDetails.catchCount)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(theme.colors.brand.crown)
                    .monospacedDigit()
                Text("catches")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.colors.text.muted)
            }
        }
        .padding(theme.spacing.s + 2)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                .fill(theme.colors.surface.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                .strokeBorder(theme.colors.brand.brassGold.opacity(0.18), lineWidth: 1)
        )
    }

    private func chip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.colors.text.secondary)
                .lineLimit(1)
        }
    }
}
