import SwiftUI

/// Top-level theme bundle. Inject into the environment at app root.
struct ReelTheme {
    let colors: ReelThemeColors
    let typography: ReelThemeTypography
    let spacing: ReelThemeSpacing
    let radius: ReelThemeRadius
    let shadow: ReelThemeShadow
    let motion: ReelThemeMotion

    static let `default` = ReelTheme(
        colors:     .default,
        typography: .default,
        spacing:    .default,
        radius:     .default,
        shadow:     .default,
        motion:     .default
    )
}

private struct ReelThemeKey: EnvironmentKey {
    static let defaultValue: ReelTheme = .default
}

extension EnvironmentValues {
    var reelTheme: ReelTheme {
        get { self[ReelThemeKey.self] }
        set { self[ReelThemeKey.self] = newValue }
    }
}
