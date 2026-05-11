import SwiftUI

/// Typography tokens. Display/Title use SF Pro Rounded (warmer, game-feel).
/// Body uses standard SF Pro (legibility). Mono for stats.
struct ReelThemeTypography {
    let display: Font     // hero numbers, podium positions
    let title1: Font      // page titles
    let title2: Font      // section titles
    let headline: Font    // card titles
    let body: Font
    let subhead: Font
    let caption: Font
    let mono: Font        // numbers / stats

    static let `default` = ReelThemeTypography(
        display:  .system(size: 56, weight: .black,    design: .rounded),
        title1:   .system(size: 34, weight: .bold,     design: .rounded),
        title2:   .system(size: 22, weight: .bold,     design: .rounded),
        headline: .system(size: 17, weight: .semibold, design: .default),
        body:     .system(size: 17, weight: .regular,  design: .default),
        subhead:  .system(size: 15, weight: .medium,   design: .default),
        caption:  .system(size: 13, weight: .medium,   design: .default),
        mono:     .system(size: 15, weight: .medium,   design: .monospaced)
    )
}
