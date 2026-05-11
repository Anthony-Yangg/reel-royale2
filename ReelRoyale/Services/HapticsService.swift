import UIKit

/// Single source of haptic feedback. Honors a user-toggleable mute state.
protocol HapticsServiceProtocol: AnyObject {
    var isEnabled: Bool { get set }

    func tap()        // .soft  — generic tap
    func confirm()    // .medium — confirmed action
    func heavy()      // .heavy  — big moment (dethrone, tier-up)
    func success()    // notification.success
    func warning()    // notification.warning
    func error()      // notification.error
}

final class HapticsService: HapticsServiceProtocol {
    var isEnabled: Bool = true

    private let softGenerator   = UIImpactFeedbackGenerator(style: .soft)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator  = UIImpactFeedbackGenerator(style: .heavy)
    private let notification    = UINotificationFeedbackGenerator()

    init() {
        // Prime generators for low-latency first hit
        softGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        notification.prepare()
    }

    func tap() {
        guard isEnabled else { return }
        softGenerator.impactOccurred()
        softGenerator.prepare()
    }

    func confirm() {
        guard isEnabled else { return }
        mediumGenerator.impactOccurred()
        mediumGenerator.prepare()
    }

    func heavy() {
        guard isEnabled else { return }
        heavyGenerator.impactOccurred()
        heavyGenerator.prepare()
    }

    func success() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    func warning() {
        guard isEnabled else { return }
        notification.notificationOccurred(.warning)
        notification.prepare()
    }

    func error() {
        guard isEnabled else { return }
        notification.notificationOccurred(.error)
        notification.prepare()
    }
}
