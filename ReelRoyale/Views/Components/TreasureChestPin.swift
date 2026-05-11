import SwiftUI

/// Treasure-chest map pin. Variants: vacant (closed) / claimed-by-other / claimed-by-you.
struct TreasureChestPin: View {
    enum Variant {
        case vacant
        case claimedByOther(tier: CaptainTier)
        case claimedByYou
    }

    let variant: Variant
    let spotName: String?
    var isSelected: Bool = false
    var onTap: () -> Void = {}

    @Environment(\.reelTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bob: CGFloat = 0

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    // Glow halo for claimed
                    if case .claimedByYou = variant {
                        Circle()
                            .fill(theme.colors.brand.crown.opacity(0.35))
                            .frame(width: 56, height: 56)
                            .blur(radius: 10)
                    } else if case .claimedByOther(let tier) = variant {
                        Circle()
                            .fill(theme.colors.tier.color(for: tier).opacity(0.3))
                            .frame(width: 52, height: 52)
                            .blur(radius: 8)
                    }

                    // Chest body
                    chestBody
                        .frame(width: isSelected ? 44 : 38, height: isSelected ? 44 : 38)

                    // Crown overlay for claimed
                    if claimed {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(theme.colors.brand.crown)
                            .shadow(color: .black.opacity(0.5), radius: 2)
                            .offset(y: -22)
                    }
                }
                if isSelected, let name = spotName {
                    Text(name)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(theme.colors.text.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(theme.colors.surface.elevated.opacity(0.95))
                        )
                        .overlay(
                            Capsule().strokeBorder(theme.colors.brand.brassGold.opacity(0.5), lineWidth: 1)
                        )
                        .padding(.top, 2)
                }
            }
        }
        .buttonStyle(.plain)
        .offset(y: bob)
        .onAppear {
            guard !reduceMotion, claimed else { return }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                bob = -3
            }
        }
        .animation(theme.motion.standard, value: isSelected)
    }

    private var claimed: Bool {
        switch variant {
        case .vacant: return false
        default: return true
        }
    }

    @ViewBuilder
    private var chestBody: some View {
        switch variant {
        case .vacant:
            chestImage(fillColor: theme.colors.brand.walnut, lidColor: theme.colors.brand.driftwoodish, open: false)
        case .claimedByOther(let tier):
            chestImage(fillColor: theme.colors.brand.walnut, lidColor: theme.colors.tier.color(for: tier), open: true)
        case .claimedByYou:
            chestImage(fillColor: theme.colors.brand.walnut, lidColor: theme.colors.brand.crown, open: true)
        }
    }

    /// Stylized treasure chest icon composited from SF Symbols + a rectangle.
    private func chestImage(fillColor: Color, lidColor: Color, open: Bool) -> some View {
        ZStack {
            // Chest base — a rounded rectangle
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(fillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(theme.colors.brand.walnut.opacity(0.9), lineWidth: 1.5)
                )
            // Lid strap
            Rectangle()
                .fill(lidColor)
                .frame(height: 8)
                .offset(y: -8)
            // Lock
            Circle()
                .fill(theme.colors.brand.brassGold)
                .frame(width: 8, height: 8)
                .offset(y: -2)
            // Sparkle if open
            if open {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(theme.colors.brand.crown)
                    .offset(y: -2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

extension ReelThemeColors.Brand {
    /// Stand-in for a slightly-lighter walnut used as a closed-lid color.
    var driftwoodish: Color { Color(hex: 0x6B4429) }
}
