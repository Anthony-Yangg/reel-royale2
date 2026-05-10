import Foundation

/// 4pt spacing grid.
struct ReelThemeSpacing {
    let xxs: CGFloat   // 4
    let xs: CGFloat    // 8
    let s: CGFloat     // 12
    let m: CGFloat     // 16
    let lg: CGFloat    // 20
    let xl: CGFloat    // 24
    let xxl: CGFloat   // 32
    let xxxl: CGFloat  // 40
    let huge: CGFloat  // 56
    let massive: CGFloat // 80

    static let `default` = ReelThemeSpacing(
        xxs: 4, xs: 8, s: 12, m: 16, lg: 20,
        xl: 24, xxl: 32, xxxl: 40, huge: 56, massive: 80
    )
}
