import SwiftUI

/// Captain progression tier (Deckhand → Pirate Lord).
enum CaptainTier: Int, Codable, CaseIterable, Identifiable {
    case deckhand   = 0
    case sailor     = 1
    case firstMate  = 2
    case captain    = 3
    case commodore  = 4
    case admiral    = 5
    case pirateLord = 6

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .deckhand:   return "Deckhand"
        case .sailor:     return "Sailor"
        case .firstMate:  return "First Mate"
        case .captain:    return "Captain"
        case .commodore:  return "Commodore"
        case .admiral:    return "Admiral"
        case .pirateLord: return "Pirate Lord"
        }
    }

    /// Number of chevrons shown on the emblem.
    var chevronCount: Int { rawValue + 1 }

    /// Map the database-backed `RankTier` (6 tiers) onto the captain progression (7 tiers).
    /// We skip `commodore` as a reserved "elite-plus" slot; legend → pirate lord.
    static func from(rankTier: RankTier) -> CaptainTier {
        switch rankTier {
        case .minnow:  return .deckhand
        case .angler:  return .sailor
        case .veteran: return .firstMate
        case .elite:   return .captain
        case .master:  return .admiral
        case .legend:  return .pirateLord
        }
    }
}

extension ReelThemeColors.TierColors {
    func color(for tier: CaptainTier) -> Color {
        switch tier {
        case .deckhand:   return deckhand
        case .sailor:     return sailor
        case .firstMate:  return firstMate
        case .captain:    return captain
        case .commodore:  return commodore
        case .admiral:    return admiral
        case .pirateLord: return pirateLord
        }
    }
}

/// Tier emblem badge: chevrons + name, tinted by tier color.
struct TierEmblem: View {
    let tier: CaptainTier
    var division: Int = 1
    var size: Size = .medium

    enum Size {
        case small, medium, large
        var fontSize: CGFloat {
            switch self { case .small: 11; case .medium: 13; case .large: 17 }
        }
        var chevronSize: CGFloat {
            switch self { case .small: 8; case .medium: 10; case .large: 14 }
        }
        var hPad: CGFloat {
            switch self { case .small: 6; case .medium: 10; case .large: 14 }
        }
        var vPad: CGFloat {
            switch self { case .small: 3; case .medium: 4; case .large: 6 }
        }
    }

    @Environment(\.reelTheme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 1) {
                ForEach(0..<min(tier.chevronCount, 5), id: \.self) { _ in
                    Image(systemName: "chevron.up")
                        .font(.system(size: size.chevronSize, weight: .black))
                }
            }
            Text("\(tier.displayName)\(division > 1 ? " \(romanNumeral(division))" : "")")
                .font(.system(size: size.fontSize, weight: .heavy, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(theme.colors.tier.color(for: tier))
        .padding(.horizontal, size.hPad)
        .padding(.vertical, size.vPad)
        .background(
            Capsule(style: .continuous)
                .fill(theme.colors.surface.elevatedAlt)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(theme.colors.tier.color(for: tier).opacity(0.5), lineWidth: 1)
        )
    }

    private func romanNumeral(_ n: Int) -> String {
        switch n { case 1: "I"; case 2: "II"; case 3: "III"; default: "" }
    }
}

#Preview {
    VStack(spacing: 12) {
        ForEach(CaptainTier.allCases) { tier in
            TierEmblem(tier: tier, division: 1, size: .medium)
        }
        TierEmblem(tier: .captain, division: 2, size: .small)
        TierEmblem(tier: .admiral, division: 3, size: .large)
    }
    .padding()
    .background(ReelTheme.default.colors.surface.canvas)
    .environment(\.reelTheme, .default)
    .preferredColorScheme(.dark)
}
