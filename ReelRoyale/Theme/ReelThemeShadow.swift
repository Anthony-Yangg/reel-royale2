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
        card:     Shadow(color: Color.black.opacity(0.09), radius: 18, x: 0, y: 8),
        heroCard: Shadow(color: Color.black.opacity(0.14), radius: 28, x: 0, y: 14),
        modal:    Shadow(color: Color.black.opacity(0.18), radius: 34, x: 0, y: 18)
    )
}

extension View {
    /// Apply a `ReelThemeShadow.Shadow`.
    func reelShadow(_ shadow: ReelThemeShadow.Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
