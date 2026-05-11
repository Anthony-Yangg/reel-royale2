import SwiftUI

/// Crown badge — used wherever someone is currently a king.
struct CrownBadge: View {
    let size: Size
    var isAnimated: Bool = false
    var showGlow: Bool = false

    enum Size {
        case small, medium, large
        var iconSize: CGFloat {
            switch self { case .small: 16; case .medium: 24; case .large: 36 }
        }
    }

    @Environment(\.reelTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            if showGlow {
                Image(systemName: "crown.fill")
                    .font(.system(size: size.iconSize * 1.3))
                    .foregroundStyle(theme.colors.brand.crown.opacity(0.55))
                    .blur(radius: 10)
            }
            Image(systemName: "crown.fill")
                .font(.system(size: size.iconSize))
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.colors.brand.crown, theme.colors.brand.brassGold],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .rotationEffect(.degrees(rotation))
                .scaleEffect(scale)
        }
        .onAppear {
            guard isAnimated, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                rotation = 5
                scale = 1.08
            }
        }
    }
}

/// "New King!" celebration badge.
struct NewKingBadge: View {
    @Environment(\.reelTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            CrownBadge(size: .medium, isAnimated: true, showGlow: true)
            Text("NEW KING!")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.colors.text.onLight)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.colors.brand.crown, theme.colors.brand.coralRed],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
        )
        .scaleEffect(pulse ? 1.04 : 1.0)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

/// Territory ruler badge.
struct TerritoryRulerBadge: View {
    let spotCount: Int
    let totalSpots: Int

    @Environment(\.reelTheme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flag.fill")
                .font(.caption)
                .foregroundStyle(theme.colors.brand.seafoam)
            Text("\(spotCount)/\(totalSpots)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.colors.text.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(theme.colors.brand.tideTeal.opacity(0.35))
        )
    }
}

#Preview {
    VStack(spacing: 24) {
        HStack(spacing: 20) {
            CrownBadge(size: .small)
            CrownBadge(size: .medium)
            CrownBadge(size: .large)
        }
        CrownBadge(size: .large, isAnimated: true, showGlow: true)
        NewKingBadge()
        TerritoryRulerBadge(spotCount: 3, totalSpots: 5)
    }
    .padding()
    .background(ReelTheme.default.colors.surface.canvas)
    .environment(\.reelTheme, .default)
    .preferredColorScheme(.dark)
}
