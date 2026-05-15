import Foundation

/// Corner radius scale.
struct ReelThemeRadius {
    let chip: CGFloat      // 6
    let button: CGFloat    // 12
    let card: CGFloat      // 18
    let heroCard: CGFloat  // 24
    let modal: CGFloat     // 32

    static let `default` = ReelThemeRadius(
        chip: 12, button: 18, card: 24, heroCard: 30, modal: 34
    )
}
