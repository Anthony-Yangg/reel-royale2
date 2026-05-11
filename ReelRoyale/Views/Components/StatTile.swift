import SwiftUI

/// Single stat tile shown in profile/captain card.
struct StatTile: View {
    let label: String
    let value: String
    let icon: String
    var tint: Color? = nil

    @Environment(\.reelTheme) private var theme

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(tint ?? theme.colors.brand.crown)
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(theme.colors.text.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.colors.text.muted)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing.s)
        .padding(.horizontal, theme.spacing.xs)
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

/// Achievement badge tile.
struct AchievementTile: View {
    let title: String
    let icon: String
    let unlocked: Bool
    let rarity: Rarity

    enum Rarity {
        case bronze, silver, gold, legendary
    }

    @Environment(\.reelTheme) private var theme

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(unlocked ? rarityFill : AnyShapeStyle(theme.colors.surface.elevatedAlt))
                    .frame(width: 56, height: 56)
                Circle()
                    .strokeBorder(unlocked ? Color.white.opacity(0.25) : Color.clear, lineWidth: 1)
                    .blendMode(.overlay)
                    .frame(width: 56, height: 56)
                Image(systemName: unlocked ? icon : "lock.fill")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(unlocked ? theme.colors.brand.walnut : theme.colors.text.muted)
            }
            Text(title)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(unlocked ? theme.colors.text.primary : theme.colors.text.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 26)
        }
        .frame(maxWidth: .infinity)
    }

    private var rarityFill: AnyShapeStyle {
        switch rarity {
        case .bronze:    AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xCD7F32), Color(hex: 0x8B5A2B)], startPoint: .top, endPoint: .bottom))
        case .silver:    AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xE0E0E0), Color(hex: 0x9E9E9E)], startPoint: .top, endPoint: .bottom))
        case .gold:      AnyShapeStyle(LinearGradient(colors: [theme.colors.brand.crown, theme.colors.brand.brassGold], startPoint: .top, endPoint: .bottom))
        case .legendary: AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xB47EFF), Color(hex: 0x6FA8E8)], startPoint: .top, endPoint: .bottom))
        }
    }
}
