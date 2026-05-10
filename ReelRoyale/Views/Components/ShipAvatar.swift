import SwiftUI

/// Avatar in a ship-frame medallion. Frame ring is tinted by tier color.
struct ShipAvatar: View {
    let imageURL: URL?
    let initial: String
    var tier: CaptainTier = .deckhand
    var size: Size = .medium
    var showCrown: Bool = false

    enum Size {
        case small, medium, large, hero

        var diameter: CGFloat {
            switch self {
            case .small: 36
            case .medium: 48
            case .large: 72
            case .hero: 112
            }
        }
        var ringWidth: CGFloat {
            switch self {
            case .small: 2
            case .medium: 2.5
            case .large: 3.5
            case .hero: 5
            }
        }
        var initialFont: Font {
            switch self {
            case .small:  .system(size: 14, weight: .heavy, design: .rounded)
            case .medium: .system(size: 18, weight: .heavy, design: .rounded)
            case .large:  .system(size: 26, weight: .heavy, design: .rounded)
            case .hero:   .system(size: 42, weight: .heavy, design: .rounded)
            }
        }
    }

    @Environment(\.reelTheme) private var theme

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            theme.colors.tier.color(for: tier),
                            theme.colors.tier.color(for: tier).opacity(0.6)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: size.ringWidth
                )
                .frame(width: size.diameter, height: size.diameter)

            Circle()
                .fill(theme.colors.surface.elevatedAlt)
                .frame(width: size.diameter - size.ringWidth * 2, height: size.diameter - size.ringWidth * 2)

            if let url = imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView().tint(theme.colors.text.secondary)
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        initialView
                    @unknown default:
                        initialView
                    }
                }
                .frame(width: size.diameter - size.ringWidth * 2, height: size.diameter - size.ringWidth * 2)
                .clipShape(Circle())
            } else {
                initialView
            }

            if showCrown {
                Image(systemName: "crown.fill")
                    .font(.system(size: size.diameter * 0.28, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.colors.brand.crown, theme.colors.brand.brassGold],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                    .offset(y: -size.diameter * 0.48)
            }
        }
        .frame(width: size.diameter, height: size.diameter + (showCrown ? size.diameter * 0.18 : 0), alignment: .bottom)
    }

    private var initialView: some View {
        Text(initial.prefix(1).uppercased())
            .font(size.initialFont)
            .foregroundStyle(theme.colors.text.primary)
    }
}

#Preview {
    HStack(spacing: 16) {
        ShipAvatar(imageURL: nil, initial: "B", tier: .deckhand, size: .small)
        ShipAvatar(imageURL: nil, initial: "K", tier: .captain, size: .medium)
        ShipAvatar(imageURL: nil, initial: "R", tier: .admiral, size: .large, showCrown: true)
        ShipAvatar(imageURL: nil, initial: "P", tier: .pirateLord, size: .hero, showCrown: true)
    }
    .padding()
    .background(ReelTheme.default.colors.surface.canvas)
    .environment(\.reelTheme, .default)
    .preferredColorScheme(.dark)
}
