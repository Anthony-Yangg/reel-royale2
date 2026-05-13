import Foundation
import UIKit
import Combine
import CoreLocation

/// Singleton Swift facade over the C-API in `UnityBridgeC.h`. Owns Unity's
/// lifecycle (start exactly once per process, never re-instantiate), exposes
/// typed inbound-from-Unity events, and converts Swift model types to the
/// JSON payloads Unity expects.
///
/// Designed so the rest of the app never imports UnityFramework — the only
/// surface is this class. If `isAvailable` returns false, callers must fall
/// back to a non-Unity renderer (MKMapView).
final class UnityRuntime: NSObject {
    static let shared = UnityRuntime()

    // MARK: - Inbound topics (mirror unity-engine/.../NativeNotify constants)

    /// All notifications posted on the main queue.
    let messages = PassthroughSubject<UnityInbound, Never>()

    // MARK: - Lifecycle

    private(set) var isStarted = false

    /// True iff UnityFramework.framework is embedded in this build of the
    /// host app AND its principal class loads cleanly.
    var isAvailable: Bool { ReelUnityIsAvailable() }

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onUnityMessage(_:)),
            name: Notification.Name("ReelRoyaleUnityBridgeMessage"),
            object: nil
        )
    }

    /// Start Unity. Safe to call multiple times — only the first call has an
    /// effect. Returns `true` if Unity is running after the call.
    @discardableResult
    func start(launchOptions: [AnyHashable: Any]? = nil) -> Bool {
        if isStarted { return true }
        guard isAvailable else { return false }
        let ok = ReelUnityStart(launchOptions)
        isStarted = ok
        return ok
    }

    /// Pause/resume the Unity main loop. Call `setPaused(true)` when the
    /// map screen is off-screen to keep mobile battery sane.
    func setPaused(_ paused: Bool) {
        guard isStarted else { return }
        ReelUnitySetPaused(paused)
    }

    /// Unity's root UIView. Caller should add as a subview of a host view.
    var rootView: UIView? { ReelUnityRootView() }

    // MARK: - Outbound (Swift → Unity)

    private static let bridgeGO = "ReelRoyale.NativeBridge"

    func send(player: CLLocationCoordinate2D,
              heading: CLLocationDirection = -1,
              speed: CLLocationSpeed = -1,
              accuracy: CLLocationAccuracy = -1) {
        sendJSON(
            method: "SetPlayerPosition",
            payload: UnityMessages.PlayerPosition(
                coordinate: player,
                heading: heading,
                speed: speed,
                accuracy: accuracy
            )
        )
    }

    func send(spots: UnityMessages.Spots) {
        sendJSON(method: "SetSpots", payload: spots)
    }

    func send(regions: UnityMessages.Regions) {
        sendJSON(method: "SetRegions", payload: regions)
    }

    func send(user: UnityMessages.User) {
        sendJSON(method: "SetUser", payload: user)
    }

    func recenter(animate: Bool = true) {
        sendJSON(method: "RecenterToPlayer",
                 payload: UnityMessages.Recenter(animate: animate))
    }

    private func sendJSON<T: Encodable>(method: String, payload: T) {
        guard isStarted else { return }
        ReelUnitySendMessage(Self.bridgeGO, method, payload.toUnityJSON())
    }

    // MARK: - Inbound (Unity → Swift)

    @objc private func onUnityMessage(_ note: Notification) {
        guard
            let info = note.userInfo,
            let topic = info["topic"] as? String,
            let payload = info["payload"] as? String
        else { return }

        let event: UnityInbound
        switch topic {
        case "engine.ready":
            event = .engineReady
        case "spot.tapped":
            event = .spotTapped(id: payload)
        case "region.tapped":
            event = .regionTapped(id: payload)
        case "nativebridge.pong":
            event = .pong(nonce: payload)
        default:
            event = .unknown(topic: topic, payload: payload)
        }
        messages.send(event)
    }
}

/// Typed events the iOS host can observe from `UnityRuntime.shared.messages`.
enum UnityInbound: Equatable {
    case engineReady
    case spotTapped(id: String)
    case regionTapped(id: String)
    case pong(nonce: String)
    case unknown(topic: String, payload: String)
}
