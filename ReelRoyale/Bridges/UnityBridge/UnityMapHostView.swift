import SwiftUI
import UIKit
import CoreLocation
import Combine

/// SwiftUI host for Unity's rendering root view. When `UnityRuntime` reports
/// `isAvailable`, this view starts the runtime (once per process), attaches
/// Unity's UIView, and forwards spot/region/player updates to it via JSON
/// messages.
///
/// Callers should only mount this view from a place that's guaranteed to be
/// on-screen (i.e. the Map tab) — Unity occupies the full GPU and shouldn't
/// run when not visible. The view pauses Unity on `dismantleUIView`.
struct UnityMapHostView: UIViewRepresentable {
    let spots: [SpotWithDetails]
    let regions: [WaterRegionControl]
    let playerLocation: CLLocationCoordinate2D?
    let currentUserId: String?
    let recenterToken: Int

    @Binding var selectedSpot: Spot?
    @Binding var selectedRegionId: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            selectedSpot: $selectedSpot,
            selectedRegionId: $selectedRegionId,
            spots: spots.map(\.spot)
        )
    }

    func makeUIView(context: Context) -> UIView {
        let container = UnityContainerView()
        container.backgroundColor = .black

        _ = UnityRuntime.shared.start()
        UnityRuntime.shared.setPaused(false)
        attachUnityIfReady(into: container)

        // Subscribe to inbound Unity events for spot/region taps. We use the
        // container's lifecycle to scope the subscription, so it auto-cancels
        // when the view is dismantled.
        context.coordinator.subscribe()

        // Push initial state.
        pushFullState(context: context)
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Re-attach in case Unity's root view changed (e.g. after backgrounding).
        attachUnityIfReady(into: uiView)

        // Forward latest state to Unity. We rely on the simple-equality
        // check on the coordinator to avoid spamming SendMessage for no-op
        // updates.
        let coord = context.coordinator
        if coord.lastSpotsHash != spots.contentHash {
            coord.lastSpotsHash = spots.contentHash
            UnityRuntime.shared.send(spots: buildSpotsPayload())
        }
        if coord.lastRegionsHash != regions.contentHash {
            coord.lastRegionsHash = regions.contentHash
            UnityRuntime.shared.send(regions: buildRegionsPayload())
        }
        if let loc = playerLocation, !coordEqual(coord.lastPlayer, loc) {
            coord.lastPlayer = loc
            UnityRuntime.shared.send(player: loc)
        }
        if coord.lastRecenterToken != recenterToken {
            coord.lastRecenterToken = recenterToken
            UnityRuntime.shared.recenter(animate: true)
        }
        if coord.lastUserId != currentUserId {
            coord.lastUserId = currentUserId
            if let id = currentUserId {
                UnityRuntime.shared.send(user: UnityMessages.User(
                    userId: id,
                    userColorHex: PlayerColor.hex(forUserId: id, isCurrentUser: true)
                ))
            }
        }
        coord.spots = spots.map(\.spot) // keep tap-resolution map fresh
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        // Pause Unity when the map screen leaves the tree. We intentionally
        // do not unloadApplication — Unity cannot be re-launched in the
        // same process and the user is likely to come back to the map tab.
        UnityRuntime.shared.setPaused(true)
        coordinator.unsubscribe()
    }

    // MARK: - Helpers

    private func attachUnityIfReady(into container: UIView) {
        guard let root = UnityRuntime.shared.rootView else { return }
        if root.superview === container { return }
        root.removeFromSuperview()
        root.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            root.topAnchor.constraint(equalTo: container.topAnchor),
            root.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }

    private func pushFullState(context: Context) {
        if let id = currentUserId {
            UnityRuntime.shared.send(user: UnityMessages.User(
                userId: id,
                userColorHex: PlayerColor.hex(forUserId: id, isCurrentUser: true)
            ))
        }
        UnityRuntime.shared.send(spots: buildSpotsPayload())
        UnityRuntime.shared.send(regions: buildRegionsPayload())
        if let loc = playerLocation {
            UnityRuntime.shared.send(player: loc)
        }
        let coord = context.coordinator
        coord.lastSpotsHash = spots.contentHash
        coord.lastRegionsHash = regions.contentHash
        coord.lastPlayer = playerLocation
        coord.lastUserId = currentUserId
        coord.lastRecenterToken = recenterToken
    }

    private func buildSpotsPayload() -> UnityMessages.Spots {
        let userId = currentUserId
        let mapped = spots.map { d -> UnityMessages.Spot in
            let s = d.spot
            let kingId = s.currentKingUserId ?? ""
            let isMe = userId.map { !kingId.isEmpty && $0 == kingId } ?? false
            let color = kingId.isEmpty ? "" : PlayerColor.hex(forUserId: kingId, isCurrentUser: isMe)
            return UnityMessages.Spot(
                id: s.id,
                name: s.name,
                lat: s.latitude,
                lng: s.longitude,
                kingId: kingId,
                kingColorHex: color,
                isCurrentUserKing: isMe,
                crowns: s.totalCatches
            )
        }
        return UnityMessages.Spots(spots: mapped)
    }

    private func buildRegionsPayload() -> UnityMessages.Regions {
        let userId = currentUserId
        let mapped = regions.map { ctrl -> UnityMessages.Region in
            let ruler = ctrl.rulerUserId ?? ""
            let isMe = userId.map { !ruler.isEmpty && $0 == ruler } ?? false
            let color = ruler.isEmpty
                ? PlayerColor.vacantHexString
                : PlayerColor.hex(forUserId: ruler, isCurrentUser: isMe)
            return UnityMessages.Region(
                id: ctrl.region.id,
                name: ctrl.region.name,
                rulerId: ruler,
                rulerColorHex: color,
                isCurrentUserRuler: isMe,
                isVacant: ruler.isEmpty,
                polygon: ctrl.region.polygon.map {
                    UnityMessages.RegionVertex(lat: $0.latitude, lng: $0.longitude)
                }
            )
        }
        return UnityMessages.Regions(regions: mapped)
    }

    // MARK: - Coordinator

    final class Coordinator {
        @Binding var selectedSpot: Spot?
        @Binding var selectedRegionId: String?
        var spots: [Spot]
        private var cancellable: AnyCancellable?

        var lastSpotsHash: Int = 0
        var lastRegionsHash: Int = 0
        var lastPlayer: CLLocationCoordinate2D?
        var lastUserId: String?
        var lastRecenterToken: Int = -1

        init(selectedSpot: Binding<Spot?>,
             selectedRegionId: Binding<String?>,
             spots: [Spot]) {
            self._selectedSpot = selectedSpot
            self._selectedRegionId = selectedRegionId
            self.spots = spots
        }

        func subscribe() {
            cancellable = UnityRuntime.shared.messages
                .receive(on: DispatchQueue.main)
                .sink { [weak self] event in
                    self?.handle(event)
                }
        }

        func unsubscribe() { cancellable?.cancel() }

        private func handle(_ event: UnityInbound) {
            switch event {
            case .spotTapped(let id):
                if let s = spots.first(where: { $0.id == id }) {
                    selectedSpot = s
                }
            case .regionTapped(let id):
                selectedRegionId = id
            case .engineReady, .pong, .unknown:
                break
            }
        }
    }
}

/// Tiny UIView subclass we use as the container, mostly as a hook for future
/// gesture forwarding / debug overlays.
private final class UnityContainerView: UIView {}

private func coordEqual(_ a: CLLocationCoordinate2D?, _ b: CLLocationCoordinate2D) -> Bool {
    guard let a else { return false }
    return abs(a.latitude - b.latitude) < 1e-7 && abs(a.longitude - b.longitude) < 1e-7
}

// MARK: - Lightweight content hashing

fileprivate extension Array where Element == SpotWithDetails {
    var contentHash: Int {
        var hasher = Hasher()
        for d in self {
            hasher.combine(d.spot.id)
            hasher.combine(d.spot.currentKingUserId ?? "")
            hasher.combine(d.spot.totalCatches)
        }
        return hasher.finalize()
    }
}

fileprivate extension Array where Element == WaterRegionControl {
    var contentHash: Int {
        var hasher = Hasher()
        for r in self {
            hasher.combine(r.region.id)
            hasher.combine(r.rulerUserId ?? "")
            hasher.combine(r.rulerCrownCount)
        }
        return hasher.finalize()
    }
}

// CLLocationCoordinate2D equality is provided by an existing extension in
// ReelRoyale/Utilities/Extensions.swift — don't redeclare here.
