import SwiftUI

/// Fishing-spot map marker. Variants: vacant / claimed-by-other / claimed-by-you.
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
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(pinTint.opacity(claimed ? 0.32 : 0.22))
                        .frame(width: isSelected ? 66 : 58, height: isSelected ? 66 : 58)
                        .blur(radius: 8)

                    Circle()
                        .stroke(Color.white.opacity(0.82), lineWidth: 3)
                        .frame(width: isSelected ? 50 : 44, height: isSelected ? 50 : 44)
                        .shadow(color: pinTint.opacity(0.35), radius: 7)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white, pinTint, pinTint.opacity(0.72)],
                                center: .topLeading,
                                startRadius: 1,
                                endRadius: 28
                            )
                        )
                        .frame(width: isSelected ? 40 : 34, height: isSelected ? 40 : 34)
                        .overlay {
                            Image(systemName: symbolName)
                                .font(.system(size: claimed ? 17 : 16, weight: .black))
                                .foregroundStyle(symbolColor)
                        }
                        .overlay(alignment: .topTrailing) {
                            if claimed {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundStyle(theme.colors.brand.crown)
                                    .shadow(color: Color(hex: 0x38270B).opacity(0.5), radius: 2)
                                    .offset(x: 5, y: -6)
                            }
                        }
                }
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.82))
                    .frame(width: 9, height: 18)
                    .overlay(Capsule().fill(pinTint.opacity(0.45)).frame(width: 3))
                    .offset(y: -4)
                Ellipse()
                    .fill(Color(hex: 0x174F5E).opacity(0.28))
                    .frame(width: isSelected ? 42 : 34, height: 12)
                    .offset(y: -6)

                if isSelected, let name = spotName {
                    Text(name)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: 0x16475A))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(Color.white.opacity(0.96))
                        )
                        .overlay(
                            Capsule().strokeBorder(pinTint.opacity(0.55), lineWidth: 1)
                        )
                        .padding(.top, -2)
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

    private var pinTint: Color {
        switch variant {
        case .vacant:
            return Color(hex: 0x28CFC6)
        case .claimedByOther(let tier):
            return theme.colors.tier.color(for: tier)
        case .claimedByYou:
            return theme.colors.brand.crown
        }
    }

    private var symbolName: String {
        switch variant {
        case .vacant:
            return "water.waves"
        case .claimedByOther:
            return "fish.fill"
        case .claimedByYou:
            return "crown.fill"
        }
    }

    private var symbolColor: Color {
        switch variant {
        case .claimedByYou:
            return Color(hex: 0x39290D)
        default:
            return Color(hex: 0x08384A)
        }
    }
}
