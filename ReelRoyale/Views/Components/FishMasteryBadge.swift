import SwiftUI

/// Pokemon-Go-style mastery badge for a species. Renders a metallic medallion
/// (bronze → diamond) with the tier icon. Locked tiers fall back to a muted disc.
struct FishMasteryBadge: View {
    let tier: FishMasteryTier
    var size: Size = .medium
    var animated: Bool = true

    enum Size {
        case xsmall, small, medium, large

        var diameter: CGFloat {
            switch self {
            case .xsmall: return 22
            case .small:  return 30
            case .medium: return 44
            case .large:  return 72
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .xsmall: return 10
            case .small:  return 14
            case .medium: return 20
            case .large:  return 34
            }
        }

        var ringWidth: CGFloat {
            switch self {
            case .xsmall: return 1
            case .small:  return 1.5
            case .medium: return 2
            case .large:  return 3
            }
        }
    }

    @Environment(\.reelTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmer: CGFloat = -0.4

    var body: some View {
        ZStack {
            Circle()
                .fill(haloFill)
                .frame(width: size.diameter * 1.35, height: size.diameter * 1.35)
                .blur(radius: size.diameter * 0.18)
                .opacity(tier == .locked ? 0 : 0.55)

            Circle()
                .fill(medallionFill)
                .frame(width: size.diameter, height: size.diameter)

            Circle()
                .strokeBorder(ringStyle, lineWidth: size.ringWidth)
                .frame(width: size.diameter, height: size.diameter)

            Circle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.0),  location: max(0, shimmer - 0.18)),
                            .init(color: .white.opacity(0.45), location: shimmer),
                            .init(color: .white.opacity(0.0),  location: min(1, shimmer + 0.18))
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size.diameter, height: size.diameter)
                .blendMode(.plusLighter)
                .clipShape(Circle())
                .opacity(tier == .locked || reduceMotion ? 0 : 0.9)

            Image(systemName: tier.iconName)
                .font(.system(size: size.iconSize, weight: .black))
                .foregroundStyle(iconColor)
                .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
        }
        .frame(width: size.diameter, height: size.diameter)
        .onAppear {
            guard animated, !reduceMotion, tier != .locked else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: false).delay(Double.random(in: 0...1.5))) {
                shimmer = 1.4
            }
        }
        .accessibilityLabel("\(tier.displayName) mastery")
    }

    // MARK: - Styling

    private var iconColor: Color {
        switch tier {
        case .locked:   return theme.colors.text.muted
        case .bronze:   return Color(hex: 0x3E2410)
        case .silver:   return Color(hex: 0x2A2A2A)
        case .gold:     return theme.colors.brand.walnut
        case .platinum: return Color(hex: 0x1B2D3D)
        case .diamond:  return Color(hex: 0x0A2E3D)
        }
    }

    private var haloFill: Color {
        switch tier {
        case .locked:   return .clear
        case .bronze:   return Color(hex: 0xCD7F32)
        case .silver:   return Color(hex: 0xE0E0E0)
        case .gold:     return theme.colors.brand.crown
        case .platinum: return Color(hex: 0xC2D9F0)
        case .diamond:  return Color(hex: 0x6EE6FF)
        }
    }

    private var medallionFill: AnyShapeStyle {
        switch tier {
        case .locked:
            return AnyShapeStyle(theme.colors.surface.elevatedAlt)
        case .bronze:
            return AnyShapeStyle(LinearGradient(
                colors: [Color(hex: 0xE3A05A), Color(hex: 0x8B5A2B)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .silver:
            return AnyShapeStyle(LinearGradient(
                colors: [Color(hex: 0xF1F1F4), Color(hex: 0x8C8C8C)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .gold:
            return AnyShapeStyle(LinearGradient(
                colors: [theme.colors.brand.crown, theme.colors.brand.brassGold],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .platinum:
            return AnyShapeStyle(LinearGradient(
                colors: [Color(hex: 0xE9F1FF), Color(hex: 0x8AA5C8)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        case .diamond:
            return AnyShapeStyle(LinearGradient(
                colors: [Color(hex: 0xD5F6FF), Color(hex: 0x4FB6D9), Color(hex: 0xB47EFF)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }

    private var ringStyle: AnyShapeStyle {
        switch tier {
        case .locked:
            return AnyShapeStyle(theme.colors.text.muted.opacity(0.4))
        case .bronze:
            return AnyShapeStyle(Color(hex: 0x5A3A20))
        case .silver:
            return AnyShapeStyle(Color(hex: 0x4F4F4F))
        case .gold:
            return AnyShapeStyle(theme.colors.brand.walnut)
        case .platinum:
            return AnyShapeStyle(Color(hex: 0x394A60))
        case .diamond:
            return AnyShapeStyle(LinearGradient(
                colors: [Color(hex: 0xB47EFF), Color(hex: 0x6FA8E8)],
                startPoint: .top, endPoint: .bottom))
        }
    }
}

/// Inline pill version of the mastery badge — used inside list/grid cards.
struct FishMasteryChip: View {
    let tier: FishMasteryTier
    var totalCaught: Int = 0
    var compact: Bool = false

    @Environment(\.reelTheme) private var theme

    var body: some View {
        HStack(spacing: 5) {
            FishMasteryBadge(tier: tier, size: .xsmall, animated: false)
            if !compact {
                Text(tier.displayName.uppercased())
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(textColor)
                if totalCaught > 0 {
                    Text("· \(totalCaught)")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(theme.colors.text.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, compact ? 6 : 7)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(theme.colors.surface.elevatedAlt.opacity(0.95))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(strokeColor, lineWidth: 0.75)
        )
    }

    private var textColor: Color {
        switch tier {
        case .locked:   return theme.colors.text.muted
        case .bronze:   return Color(hex: 0xE3A05A)
        case .silver:   return Color(hex: 0xCDCDCD)
        case .gold:     return theme.colors.brand.crown
        case .platinum: return Color(hex: 0xC2D9F0)
        case .diamond:  return Color(hex: 0x6EE6FF)
        }
    }

    private var strokeColor: Color {
        textColor.opacity(0.45)
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 14) {
            ForEach(FishMasteryTier.allCases) { tier in
                FishMasteryBadge(tier: tier, size: .medium)
            }
        }
        HStack(spacing: 14) {
            ForEach(FishMasteryTier.allCases) { tier in
                FishMasteryChip(tier: tier, totalCaught: tier.minCatches)
            }
        }
        FishMasteryBadge(tier: .diamond, size: .large)
    }
    .padding()
    .background(ReelTheme.default.colors.surface.canvas)
    .environment(\.reelTheme, .default)
    .preferredColorScheme(.dark)
}
