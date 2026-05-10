import SwiftUI

/// Top-3 podium with gold/silver/bronze plinths and ship-avatars on top.
struct PodiumCard: View {
    let entries: [CaptainRankEntry]   // expects 1..3 items, sorted by rank ascending
    var onSelect: (CaptainRankEntry) -> Void = { _ in }

    @Environment(\.reelTheme) private var theme

    var body: some View {
        let first  = entries.first(where: { $0.rank == 1 }) ?? entries.first
        let second = entries.first(where: { $0.rank == 2 })
        let third  = entries.first(where: { $0.rank == 3 })

        return HStack(alignment: .bottom, spacing: theme.spacing.s) {
            if let second = second {
                podiumPillar(entry: second, plinthHeight: 70, accent: silver, place: 2)
            }
            if let first = first {
                podiumPillar(entry: first, plinthHeight: 100, accent: theme.colors.brand.crown, place: 1)
            }
            if let third = third {
                podiumPillar(entry: third, plinthHeight: 50, accent: bronze, place: 3)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func podiumPillar(entry: CaptainRankEntry, plinthHeight: CGFloat, accent: Color, place: Int) -> some View {
        Button { onSelect(entry) } label: {
            VStack(spacing: 6) {
                PodiumAvatar(entry: entry, place: place, accent: accent)
                Text(entry.captainName)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.colors.text.primary)
                    .lineLimit(1)
                Text(entry.doubloons.formatted(.number.notation(.compactName)) + " 🪙")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.colors.brand.brassGold)
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.95), accent.opacity(0.6)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(height: plinthHeight)
                    Text("\(place)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(theme.colors.brand.walnut)
                        .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Rank \(place): \(entry.captainName), \(entry.doubloons) doubloons")
    }

    private var silver: Color { Color(hex: 0xC9D1D9) }
    private var bronze: Color { Color(hex: 0xCD7F32) }
}

/// Ship avatar with podium-place badge.
private struct PodiumAvatar: View {
    let entry: CaptainRankEntry
    let place: Int
    let accent: Color

    @Environment(\.reelTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bob: CGFloat = 0

    var body: some View {
        ShipAvatar(
            imageURL: entry.avatarURL.flatMap(URL.init),
            initial: entry.captainName,
            tier: entry.tier,
            size: place == 1 ? .large : .medium,
            showCrown: place == 1
        )
        .offset(y: bob)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.8 + Double(place) * 0.4).repeatForever(autoreverses: true)) {
                bob = -4
            }
        }
    }
}
