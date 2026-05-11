import SwiftUI

/// Motion tokens. Honor `reduceMotion` env at call sites.
struct ReelThemeMotion {
    let fast: Animation       // 180ms easeOut — taps
    let standard: Animation   // 320ms spring — transitions
    let hero: Animation       // 600ms spring — page transitions, podium
    let cinematic: Animation  // 1200ms — dethrone, tier-up
    let ambientDuration: Double  // base loop duration for ambient anims (seconds)

    static let `default` = ReelThemeMotion(
        fast:      .easeOut(duration: 0.18),
        standard:  .spring(response: 0.32, dampingFraction: 0.78),
        hero:      .spring(response: 0.60, dampingFraction: 0.72),
        cinematic: .easeInOut(duration: 1.20),
        ambientDuration: 6.0
    )
}
