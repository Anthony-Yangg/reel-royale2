import SwiftUI

/// Inline coin + amount chip used in headers and stats.
struct DoubloonChip: View {
    let amount: Int
    var size: Size = .medium
    var compact: Bool = false

    enum Size {
        case small, medium, large
        var fontSize: CGFloat { switch self { case .small: 12; case .medium: 15; case .large: 22 } }
        var coinSize: CGFloat { switch self { case .small: 12; case .medium: 16; case .large: 24 } }
        var hPad: CGFloat { switch self { case .small: 6; case .medium: 10; case .large: 14 } }
        var vPad: CGFloat { switch self { case .small: 3; case .medium: 5; case .large: 8 } }
    }

    @Environment(\.reelTheme) private var theme

    var body: some View {
        HStack(spacing: 5) {
            CoinIcon(size: size.coinSize)
            Text(amount.formatted(.number.notation(.compactName)))
                .font(.system(size: size.fontSize, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.colors.brand.crown)
                .monospacedDigit()
        }
        .padding(.horizontal, compact ? 0 : size.hPad)
        .padding(.vertical, compact ? 0 : size.vPad)
        .background(
            Group {
                if !compact {
                    Capsule(style: .continuous)
                        .fill(theme.colors.surface.elevatedAlt)
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(theme.colors.brand.brassGold.opacity(0.35), lineWidth: 1)
                        )
                }
            }
        )
    }
}

/// The little doubloon coin glyph used inside DoubloonChip.
struct CoinIcon: View {
    let size: CGFloat
    @Environment(\.reelTheme) private var theme

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [theme.colors.brand.crown, theme.colors.brand.brassGold],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            Circle()
                .strokeBorder(theme.colors.brand.walnut.opacity(0.8), lineWidth: max(1, size * 0.06))
            Image(systemName: "dollarsign")
                .font(.system(size: size * 0.55, weight: .black))
                .foregroundStyle(theme.colors.brand.walnut)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 12) {
        DoubloonChip(amount: 234)
        DoubloonChip(amount: 12_450, size: .large)
        DoubloonChip(amount: 1_250_000, size: .small)
        DoubloonChip(amount: 5_678, compact: true)
    }
    .padding()
    .background(ReelTheme.default.colors.surface.canvas)
    .environment(\.reelTheme, .default)
    .preferredColorScheme(.dark)
}
