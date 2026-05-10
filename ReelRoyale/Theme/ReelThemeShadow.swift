import SwiftUI

/// Shadow tokens for elevation.
struct ReelThemeShadow {
    let card: Shadow
    let heroCard: Shadow
    let modal: Shadow

    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    static let `default` = ReelThemeShadow(
        card:     Shadow(color: Color.black.opacity(0.30), radius: 16, x: 0, y: 4),
        heroCard: Shadow(color: Color.black.opacity(0.45), radius: 24, x: 0, y: 8),
        modal:    Shadow(color: Color.black.opacity(0.60), radius: 32, x: 0, y: 12)
    )
}

extension View {
    /// Apply a `ReelThemeShadow.Shadow`.
    func reelShadow(_ shadow: ReelThemeShadow.Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
