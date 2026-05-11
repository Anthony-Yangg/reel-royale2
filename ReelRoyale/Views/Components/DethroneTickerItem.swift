import SwiftUI

/// Single dethrone-ticker pill.
struct DethroneTickerItem: View {
    let event: DethroneEvent
    let onTap: () -> Void

    @Environment(\.reelTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(theme.colors.brand.crown)
                Text("\(event.newKingName)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.colors.tier.color(for: event.newKingTier))
                Text("dethroned")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.colors.text.secondary)
                Text("\(event.previousKingName)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.colors.text.primary)
                Text("at \(event.spotName)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.colors.text.secondary)
                Text("· \(event.elapsedShort)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.colors.text.muted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(theme.colors.surface.elevatedAlt)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(theme.colors.brand.brassGold.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
