import SwiftUI

/// Top-3 podium — dramatic depth, glow on #1, big idle bob.
struct PodiumCard: View {
    let entries: [CaptainRankEntry]
    var onSelect: (CaptainRankEntry) -> Void = { _ in }

    @Environment(\.reelTheme) private var theme

    var body: some View {
        let first  = entries.first(where: { $0.rank == 1 }) ?? entries.first
        let second = entries.first(where: { $0.rank == 2 })
        let third  = entries.first(where: { $0.rank == 3 })

        return HStack(alignment: .bottom, spacing: theme.spacing.s) {
            if let second = second {
                podiumPillar(entry: second, plinthHeight: 86, accent: silver, place: 2)
            }
            if let first = first {
                podiumPillar(entry: first, plinthHeight: 130, accent: theme.colors.brand.crown, place: 1)
            }
            if let third = third {
                podiumPillar(entry: third, plinthHeight: 62, accent: bronze, place: 3)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func podiumPillar(entry: CaptainRankEntry, plinthHeight: CGFloat, accent: Color, place: Int) -> some View {
        Button { onSelect(entry) } label: {
            VStack(spacing: 6) {
                PodiumAvatar(entry: entry, place: place, accent: accent)
                Text(entry.captainName)
                    .font(.system(size: place == 1 ? 14 : 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.colors.text.primary)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.7), radius: 2)
                HStack(spacing: 3) {
                    Text(entry.doubloons.formatted(.number.notation(.compactName)))
                        .font(.system(size: place == 1 ? 13 : 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(theme.colors.brand.crown)
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(theme.colors.brand.brassGold)
                }
                plinth(height: plinthHeight, accent: accent, place: place)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Rank \(place): \(entry.captainName), \(entry.doubloons) doubloons")
    }

    private func plinth(height: CGFloat, accent: Color, place: Int) -> some View {
        ZStack(alignment: .top) {
            // 3D-feel plinth: gradient face + side highlight + bottom shadow
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.75), accent.opacity(0.45)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                        .blendMode(.overlay)
                )
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(LinearGradient(colors: [Color.white.opacity(0.18), .clear], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 6)
                        .blendMode(.overlay)
                }
                .shadow(color: accent.opacity(place == 1 ? 0.6 : 0.3), radius: place == 1 ? 18 : 8, x: 0, y: 6)

            Text("\(place)")
                .font(.system(size: place == 1 ? 36 : 28, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [Color(hex: 0x3A1E0A), Color(hex: 0x1A0A03)], startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: Color.white.opacity(0.3), radius: 0.5, x: 0, y: 1)
                .padding(.top, 10)
        }
    }

    private var silver: Color { Color(hex: 0xC9D1D9) }
    private var bronze: Color { Color(hex: 0xCD7F32) }
}

/// Ship avatar with podium-place visual emphasis.
private struct PodiumAvatar: View {
    let entry: CaptainRankEntry
    let place: Int
    let accent: Color

    @Environment(\.reelTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bob: CGFloat = 0
    @State private var tilt: Double = 0
    @State private var glowPulse: Double = 0.5

    var body: some View {
        ZStack {
            if place == 1 {
                // Pulsing gold halo behind #1
                Circle()
                    .fill(theme.colors.brand.crown.opacity(glowPulse))
                    .frame(width: 110, height: 110)
                    .blur(radius: 26)
            }
            ShipAvatar(
                imageURL: entry.avatarURL.flatMap(URL.init),
                initial: entry.captainName,
                tier: entry.tier,
                size: place == 1 ? .large : .medium,
                showCrown: place == 1,
                waveBob: false  // we handle bob below for stronger drama
            )
            .scaleEffect(place == 1 ? 1.1 : 1.0)
            .offset(y: bob)
            .rotationEffect(.degrees(tilt), anchor: .bottom)
        }
        .onAppear {
            guard !reduceMotion else { return }
            let baseDur = place == 1 ? 2.6 : 2.2 + Double(place) * 0.3
            withAnimation(.easeInOut(duration: baseDur).repeatForever(autoreverses: true)) {
                bob = -6
                tilt = 3
            }
            if place == 1 {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    glowPulse = 0.85
                }
            }
        }
    }
}
