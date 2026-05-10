import Foundation

/// Corner radius scale.
struct ReelThemeRadius {
    let chip: CGFloat      // 6
    let button: CGFloat    // 12
    let card: CGFloat      // 18
    let heroCard: CGFloat  // 24
    let modal: CGFloat     // 32

    static let `default` = ReelThemeRadius(
        chip: 6, button: 12, card: 18, heroCard: 24, modal: 32
    )
}
