import SwiftUI

/// Semantic color tokens for Reel Royale.
/// Never reference these as raw hex outside this file — always via `theme.colors.*`.
struct ReelThemeColors {
    let surface: Surface
    let brand: Brand
    let text: TextColors
    let state: StateColors
    let tier: TierColors

    struct Surface {
        let canvas: Color          // primary background
        let elevated: Color        // cards, sheets
        let elevatedAlt: Color     // nested cards, headers
        let parchment: Color       // light/inverse surfaces — map land, onboarding
        let scrim: Color           // dim overlay behind modals
    }

    struct Brand {
        let deepSea: Color         // primary brand teal
        let tideTeal: Color        // mid teal — interactive accents
        let seafoam: Color         // bright teal — highlights / focus
        let brassGold: Color       // gold — emblems, doubloons, CTAs
        let crown: Color           // bright gold — winning / kings
        let coralRed: Color        // coral — dethrone / danger / alert
        let walnut: Color          // dark wood — frames, banners
        let parchment: Color       // aged paper accent on dark
    }

    struct TextColors {
        let primary: Color
        let secondary: Color
        let muted: Color
        let onLight: Color
        let accent: Color
    }

    struct StateColors {
        let success: Color
        let danger: Color
        let warning: Color
    }

    struct TierColors {
        let deckhand: Color
        let sailor: Color
        let firstMate: Color
        let captain: Color
        let commodore: Color
        let admiral: Color
        let pirateLord: Color
    }

    static let `default` = ReelThemeColors(
        surface: Surface(
            canvas:       Color(hex: 0xF2F0ED),
            elevated:     Color(hex: 0xFBFAF8),
            elevatedAlt:  Color(hex: 0xE8E3DF),
            parchment:    Color(hex: 0xF7F2EA),
            scrim:        Color.black.opacity(0.26)
        ),
        brand: Brand(
            deepSea:    Color(hex: 0x111111),
            tideTeal:   Color(hex: 0x6F9D9A),
            seafoam:    Color(hex: 0xBFD9D2),
            brassGold:  Color(hex: 0xB78D4D),
            crown:      Color(hex: 0xD3A44E),
            coralRed:   Color(hex: 0xD35F4B),
            walnut:     Color(hex: 0x282421),
            parchment:  Color(hex: 0xEEE5DA)
        ),
        text: TextColors(
            primary:   Color(hex: 0x171717),
            secondary: Color(hex: 0x625D58),
            muted:     Color(hex: 0x9C948C),
            onLight:   Color(hex: 0xFFFFFF),
            accent:    Color(hex: 0x111111)
        ),
        state: StateColors(
            success: Color(hex: 0x4E9D79),
            danger:  Color(hex: 0xD35F4B),
            warning: Color(hex: 0xC79545)
        ),
        tier: TierColors(
            deckhand:   Color(hex: 0xA98761),
            sailor:     Color(hex: 0x8FA9A4),
            firstMate:  Color(hex: 0xB78D4D),
            captain:    Color(hex: 0xD3A44E),
            commodore:  Color(hex: 0x6C9FB8),
            admiral:    Color(hex: 0x8E7BC7),
            pirateLord: Color(hex: 0x111111)
        )
    )
}

/// Convenience initializer for hex literals.
extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
