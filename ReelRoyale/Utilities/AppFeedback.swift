import SwiftUI

/// Unified interaction feedback. One call fires haptic + sound + animation hooks together,
/// so every button across the app feels consistent — Pokémon-style press response.
///
/// Bundled SFX play when present; otherwise `SoundService` uses lightweight system sounds.
enum AppFeedback {
    case tap            // generic taps, chip selection, nav rows
    case confirm        // primary CTAs (Cast Your Claim, Save, Continue)
    case heavy          // FAB, big modal opens, log-catch start
    case success        // catch logged, challenge complete, login bonus
    case warning        // unverified action, soft-error
    case error          // hard failures
    case dethrone       // king toppled — used by celebration screens
    case levelUp        // tier advance
    case coinShower     // doubloon reward

    /// Fire the feedback. Safe to call with a nil/unconfigured `AppState`.
    /// Main-actor isolated to match `AppState`.
    @MainActor
    func play(appState: AppState?) {
        guard let appState else { return }
        appState.haptics?.run(self)
        if let sfx = sound {
            appState.sounds?.play(sfx)
        }
    }

    /// Sound effect, if one is mapped. Returning nil keeps the call truly silent.
    private var sound: SoundEffect? {
        switch self {
        case .tap:         return .tap
        case .confirm:     return .confirm
        case .heavy:       return .lowThud
        case .success:     return .brassChime
        case .warning:     return .ropeCreak
        case .error:       return .lowThud
        case .dethrone:    return .crownShatter
        case .levelUp:     return .bellRing
        case .coinShower:  return .coinShower
        }
    }
}

private extension HapticsServiceProtocol {
    /// Map an `AppFeedback` case onto an existing haptic.
    func run(_ feedback: AppFeedback) {
        switch feedback {
        case .tap:        tap()
        case .confirm:    confirm()
        case .heavy:      heavy()
        case .success:    success()
        case .warning:    warning()
        case .error:      error()
        case .dethrone:   heavy()
        case .levelUp:    success()
        case .coinShower: confirm()
        }
    }
}
