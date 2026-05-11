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
        let canvas: Color          // primary background (near-black navy)
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
            canvas:       Color(hex: 0x0A1822),
            elevated:     Color(hex: 0x14222F),
            elevatedAlt:  Color(hex: 0x1B2D3D),
            parchment:    Color(hex: 0xF4E8D0),
            scrim:        Color.black.opacity(0.55)
        ),
        brand: Brand(
            deepSea:    Color(hex: 0x0E2C44),
            tideTeal:   Color(hex: 0x1F6F7A),
            seafoam:    Color(hex: 0x3FB8AE),
            brassGold:  Color(hex: 0xC9A24B),
            crown:      Color(hex: 0xF2C95C),
            coralRed:   Color(hex: 0xD8553C),
            walnut:     Color(hex: 0x4A2E1D),
            parchment:  Color(hex: 0xE8D9B0)
        ),
        text: TextColors(
            primary:   Color(hex: 0xF0E6D2),
            secondary: Color(hex: 0xA99E83),
            muted:     Color(hex: 0x6E6353),
            onLight:   Color(hex: 0x1B2D3D),
            accent:    Color(hex: 0xF2C95C)
        ),
        state: StateColors(
            success: Color(hex: 0x4FC28A),
            danger:  Color(hex: 0xD8553C),
            warning: Color(hex: 0xE5A547)
        ),
        tier: TierColors(
            deckhand:   Color(hex: 0x8B7355),
            sailor:     Color(hex: 0xB0925E),
            firstMate:  Color(hex: 0xC9A24B),
            captain:    Color(hex: 0xE5C04A),
            commodore:  Color(hex: 0x6FA8E8),
            admiral:    Color(hex: 0xB47EFF),
            pirateLord: Color(hex: 0xF2C95C)
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
