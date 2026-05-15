import SwiftUI
import MapKit
import UIKit
import simd

/// Pokémon-GO-style map surface. We render real OpenStreetMap geography via
/// Apple's `MKMapView` with the base layer replaced by bright stylized raster
/// tiles, then layer two game-meaningful overlays on top:
///
///   1. `WaterRegion` polygons — procedural ~3 km hex cells, one per
///      contestable region. Filled with the ruling player's color (or a
///      vacant teal). Tapping one reveals the region info card.
///   2. Floating fishing markers — one per `Spot`, the action point you fish at
///      to take a king crown (and through that, regions).
///
/// The camera is pitched ~55° for the canonical tilted-world Niantic feel.
struct PirateMapView: View {
    let spots: [SpotWithDetails]
    let regions: [WaterRegionControl]
    @Binding var selectedSpot: Spot?
    @Binding var cameraPosition: MapCameraPosition
    var currentUserId: String? = nil
    var userLocation: CLLocationCoordinate2D? = nil
    var showsRegions: Bool = true

    @Environment(\.reelTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var appState: AppState

    @State private var recenterToken = 0
    @State private var selectedRegionId: String?

    var body: some View {
        ZStack {
            mapSurface
                .ignoresSafeArea()

            mapAtmosphereLayer
                .allowsHitTesting(false)

            playerAvatarLayer
                .allowsHitTesting(false)

            VStack {
                HStack {
                    Spacer()
                    locateButton
                }
                Spacer()
                attributionLabel
            }
            .padding(.horizontal, theme.spacing.m)
            .padding(.top, theme.spacing.s)
            .padding(.bottom, theme.spacing.s)

            if let selectedControl = currentSelectedControl {
                VStack {
                    Spacer()
                    RegionInfoCard(
                        control: selectedControl,
                        currentUserId: currentUserId,
                        rulerName: rulerName(for: selectedControl.rulerUserId),
                        leadingSpotName: leadingSpot(for: selectedControl)?.name,
                        onChallengeRuler: {
                            guard let rulerId = selectedControl.rulerUserId else { return }
                            AppFeedback.confirm.play(appState: appState)
                            appState.spotsNavigationPath.append(NavigationDestination.userProfile(userId: rulerId))
                        },
                        onOpenSpot: {
                            guard let spot = leadingSpot(for: selectedControl) else { return }
                            selectedSpot = spot
                        },
                        onDismiss: { selectedRegionId = nil }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal, theme.spacing.m)
                    .padding(.bottom, theme.spacing.lg)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selectedRegionId)
                .allowsHitTesting(true)
            }
        }
        .background(Color(hex: 0x9DE7D8).ignoresSafeArea())
    }

    /// Picks the rendering backend at runtime. If UnityFramework.framework
    /// is embedded in the build, we render through the Unity engine — that's
    /// the route to true Pokémon-GO-style stylized geometry (procedural
    /// terrain, low-poly buildings, animated water, atmosphere). Otherwise we
    /// fall through to the MapKit + recolored-tile path so the app still
    /// ships a stylized map without Unity.
    @ViewBuilder
    private var mapSurface: some View {
        if UnityRuntime.shared.isAvailable {
            UnityMapHostView(
                spots: spots,
                regions: showsRegions ? regions : [],
                playerLocation: userLocation,
                currentUserId: currentUserId,
                recenterToken: recenterToken,
                selectedSpot: $selectedSpot,
                selectedRegionId: $selectedRegionId
            )
        } else {
            StylizedRealMapView(
                spots: spots,
                regions: showsRegions ? regions : [],
                selectedSpot: $selectedSpot,
                selectedRegionId: $selectedRegionId,
                currentUserId: currentUserId,
                recenterToken: recenterToken,
                fallbackCenter: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            )
        }
    }

    private var currentSelectedControl: WaterRegionControl? {
        guard let id = selectedRegionId else { return nil }
        return regions.first { $0.region.id == id }
    }

    private func rulerName(for userId: String?) -> String? {
        guard let userId else { return nil }
        return spots
            .compactMap(\.kingUser)
            .first { $0.id == userId }?
            .username
    }

    private func leadingSpot(for control: WaterRegionControl) -> Spot? {
        spots
            .filter { control.region.spotIds.contains($0.spot.id) }
            .sorted {
                let lhsMine = $0.spot.currentKingUserId == currentUserId
                let rhsMine = $1.spot.currentKingUserId == currentUserId
                if lhsMine != rhsMine { return lhsMine }
                return $0.spot.name < $1.spot.name
            }
            .first?
            .spot
    }

    private var playerAvatarLayer: some View {
        GeometryReader { proxy in
            playerPulse
                .position(x: proxy.size.width / 2, y: proxy.size.height * 0.68)
        }
    }

    private var mapAtmosphereLayer: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1 / 24)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                ZStack {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.42),
                            Color(hex: 0xB9F2FF).opacity(0.18),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )

                    Circle()
                        .stroke(Color.white.opacity(0.58), lineWidth: 2)
                        .frame(width: min(proxy.size.width * 1.45, 560),
                               height: min(proxy.size.width * 1.45, 560))
                        .position(x: proxy.size.width / 2, y: proxy.size.height * 0.78)
                        .shadow(color: Color(hex: 0x59D8FF).opacity(0.22), radius: 8)

                    ForEach(0..<9, id: \.self) { index in
                        MapShard(index: index, time: t, size: proxy.size)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var playerPulse: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1 / 30)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let pulse = 0.5 + 0.35 * sin(t * 2.2)
            ZStack {
                Circle()
                    .fill(Color(hex: 0x7DE9D5).opacity(0.22))
                    .frame(width: 138 + pulse * 28, height: 138 + pulse * 28)
                    .blur(radius: 12)
                Circle()
                    .stroke(Color.white.opacity(0.72), lineWidth: 2.5)
                    .frame(width: 112, height: 112)
                Circle()
                    .stroke(Color(hex: 0x2CC6D8).opacity(0.5), lineWidth: 1.5)
                    .frame(width: 82, height: 82)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white, Color(hex: 0x4AE1C3), Color(hex: 0x168BA5)],
                            center: .topLeading,
                            startRadius: 2,
                            endRadius: 34
                        )
                    )
                    .frame(width: 58, height: 58)
                    .overlay {
                        ZStack {
                            Image(systemName: "person.fill")
                                .font(.system(size: 31, weight: .black))
                                .foregroundStyle(Color(hex: 0x08384A))
                                .offset(y: 2)
                            Image(systemName: "fish.fill")
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(theme.colors.brand.crown)
                                .offset(x: 15, y: -14)
                        }
                    }
                    .shadow(color: Color(hex: 0x0A7BA0).opacity(0.3), radius: 16, y: 8)
            }
        }
        .accessibilityHidden(true)
    }

    private var locateButton: some View {
        Button {
            AppFeedback.tap.play(appState: appState)
            recenterToken &+= 1
        } label: {
            Image(systemName: "location.north.fill")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color(hex: 0x17627C))
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.92))
                        .shadow(color: Color(hex: 0x199DB5).opacity(0.25), radius: 18)
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color(hex: 0x6DDEF0).opacity(0.55), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Recenter map")
    }

    private var attributionLabel: some View {
        HStack {
            Spacer()
            Text("© OpenStreetMap · CARTO")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: 0x245268).opacity(0.78))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule(style: .continuous).fill(Color.white.opacity(0.68)))
        }
    }
}

private struct MapShard: View {
    let index: Int
    let time: TimeInterval
    let size: CGSize

    var body: some View {
        let baseX = CGFloat((index * 73) % 100) / 100
        let baseY = CGFloat((index * 41 + 16) % 70) / 100
        let bob = CGFloat(sin(time * (0.7 + Double(index) * 0.08) + Double(index))) * 8
        let side = CGFloat(8 + (index % 4) * 3)
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(index.isMultiple(of: 3) ? Color(hex: 0x2BB7FF) : Color(hex: 0x6EE6FF))
            .frame(width: side, height: side)
            .rotationEffect(.degrees(time * 18 + Double(index * 23)))
            .opacity(0.28)
            .position(x: size.width * baseX, y: size.height * baseY + bob)
            .shadow(color: Color(hex: 0x33BFFF).opacity(0.3), radius: 6)
    }
}

// MARK: - Region info card

private struct RegionInfoCard: View {
    let control: WaterRegionControl
    let currentUserId: String?
    let rulerName: String?
    let leadingSpotName: String?
    let onChallengeRuler: () -> Void
    let onOpenSpot: () -> Void
    let onDismiss: () -> Void

    @Environment(\.reelTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                rulerSwatch
                VStack(alignment: .leading, spacing: 2) {
                    Text(control.region.name)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(theme.colors.text.primary)
                        .lineLimit(1)
                    Text(rulerLabel)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(rulerTextColor)
                        .lineLimit(1)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(theme.colors.text.muted)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(theme.colors.surface.elevatedAlt.opacity(0.82)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss region info")
            }

            // Crown progress bar
            crownBar

            HStack(spacing: 12) {
                statTile(value: "\(control.totalSpots)", label: "Spots")
                statTile(value: "\(control.rulerCrownCount)", label: "Top crowns")
                statTile(value: "\(control.currentUserCrowns)", label: "Yours")
            }

            Text(callToActionText)
                .font(.caption)
                .foregroundStyle(theme.colors.text.secondary)
                .multilineTextAlignment(.leading)

            HStack(spacing: 10) {
                if canChallengeRuler {
                    Button(action: onChallengeRuler) {
                        Label("Challenge Rival", systemImage: "scope")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(theme.colors.text.primary)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onOpenSpot) {
                    Label(control.rulerUserId == currentUserId ? "Defend Spot" : "Fish Spot", systemImage: "fish.fill")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(theme.colors.text.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(theme.colors.surface.elevatedAlt.opacity(0.72))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.black.opacity(0.07), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.colors.surface.elevated.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.07), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.13), radius: 22, y: 10)
    }

    private var rulerSwatch: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(PlayerColor.color(forRuler: control.rulerUserId, currentUserId: currentUserId))
            .frame(width: 36, height: 36)
            .overlay(
                Image(systemName: control.rulerUserId == nil ? "questionmark" :
                        (control.rulerUserId == currentUserId ? "crown.fill" : "flag.fill"))
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(theme.colors.text.primary)
            )
            .shadow(color: PlayerColor.color(forRuler: control.rulerUserId, currentUserId: currentUserId).opacity(0.55), radius: 10)
    }

    private var rulerLabel: String {
        if let ruler = control.rulerUserId {
            if ruler == currentUserId { return "RULED BY YOU" }
            if let rulerName, !rulerName.isEmpty {
                return "RULED BY \(rulerName)"
            }
            return "RULED BY #\(String(ruler.prefix(8)).uppercased())"
        }
        return "OPEN WATER · UP FOR GRABS"
    }

    private var rulerTextColor: Color {
        PlayerColor.color(forRuler: control.rulerUserId, currentUserId: currentUserId)
    }

    private var borderColor: Color {
        PlayerColor.color(forRuler: control.rulerUserId, currentUserId: currentUserId)
    }

    private var callToActionText: String {
        let need = control.crownsNeededForCurrentUser
        if control.rulerUserId == currentUserId {
            return "Defend \(leadingSpotName ?? "this water") - any rival who beats your size at one of these spots steals a crown back."
        }
        if control.rulerUserId == nil {
            return "Land a king-sized catch at \(leadingSpotName ?? "any spot here") to claim this water."
        }
        let plural = need == 1 ? "crown" : "crowns"
        let owner = rulerName?.isEmpty == false ? rulerName! : "the ruler"
        return "Take \(need) more spot \(plural) inside this region to flip control from \(owner) to you."
    }

    private var canChallengeRuler: Bool {
        guard let ruler = control.rulerUserId else { return false }
        return ruler != currentUserId
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.colors.text.primary)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(theme.colors.text.muted)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.colors.surface.elevatedAlt.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                )
        )
    }

    private var crownBar: some View {
        let total = max(control.totalSpots, 1)
        let segments = control.contenders.prefix(6)
        return HStack(spacing: 2) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, entry in
                let frac = CGFloat(entry.crowns) / CGFloat(total)
                Rectangle()
                    .fill(PlayerColor.color(forUser: entry.userId, currentUserId: currentUserId))
                    .frame(maxWidth: .infinity)
                    .frame(height: 6)
                    .layoutPriority(Double(frac))
            }
            if control.contenders.isEmpty {
                Rectangle()
                    .fill(Color(hex: 0x3FB8AE).opacity(0.35))
                    .frame(height: 6)
            }
        }
        .clipShape(Capsule())
    }
}

// MARK: - MKMapView host

private struct StylizedRealMapView: UIViewRepresentable {
    let spots: [SpotWithDetails]
    let regions: [WaterRegionControl]
    @Binding var selectedSpot: Spot?
    @Binding var selectedRegionId: String?
    let currentUserId: String?
    let recenterToken: Int
    let fallbackCenter: CLLocationCoordinate2D

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.pointOfInterestFilter = .excludingAll
        map.showsCompass = false
        map.showsScale = false
        map.showsTraffic = false
        map.showsBuildings = false
        map.showsUserLocation = false
        map.isPitchEnabled = true
        map.isRotateEnabled = true
        map.isZoomEnabled = true
        map.isScrollEnabled = true
        map.overrideUserInterfaceStyle = .light

        // Replace Apple's base map with bright OSM raster tiles and recolor
        // them into a playful AR-game palette: mint ground, warm road ribbons,
        // saturated water, and soft cream edge highlights.
        let urlTemplate = "https://cartodb-basemaps-{s}.global.ssl.fastly.net/rastertiles/voyager_nolabels/{z}/{x}/{y}@2x.png"
        let overlay = PokemonStyleTileOverlay(urlTemplate: urlTemplate)
        overlay.canReplaceMapContent = true
        overlay.maximumZ = 19
        overlay.minimumZ = 1
        map.addOverlay(overlay, level: .aboveLabels)

        // Tap gesture for region selection. MKMapView doesn't ship a
        // tap-on-overlay event, so we install our own that hit-tests the
        // polygon renderers under the touch point. cancelsTouchesInView is
        // false so map pan/zoom is unaffected; we skip the hit-test entirely
        // when the touch lands on a spot marker.
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        map.addGestureRecognizer(tap)

        // Pokémon GO-style tilted camera.
        let camera = MKMapCamera(
            lookingAtCenter: fallbackCenter,
            fromDistance: 1200,
            pitch: 55,
            heading: 0
        )
        map.setCamera(camera, animated: false)
        return map
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.parent = self
        syncRegionOverlays(on: uiView, coordinator: context.coordinator)
        syncAnnotations(on: uiView)

        if context.coordinator.lastRecenterToken != recenterToken {
            context.coordinator.lastRecenterToken = recenterToken
            recenter(uiView)
        }

        if !context.coordinator.didInitialFit {
            context.coordinator.didInitialFit = true
            recenter(uiView)
        }
    }

    // MARK: Region overlay diffing

    private func syncRegionOverlays(on mapView: MKMapView, coordinator: Coordinator) {
        // Build new desired set keyed by region id.
        let desired = Dictionary(uniqueKeysWithValues: regions.map { ($0.region.id, $0) })

        // Remove polygons no longer wanted, OR whose ruler color changed.
        var toRemove: [RegionPolygon] = []
        var stillPresentIds = Set<String>()
        for overlay in mapView.overlays {
            guard let poly = overlay as? RegionPolygon else { continue }
            if let next = desired[poly.regionId] {
                let nextColor = PlayerColor.uiColor(forRuler: next.rulerUserId, currentUserId: currentUserId)
                if !poly.matchesColor(nextColor) {
                    toRemove.append(poly)
                } else {
                    stillPresentIds.insert(poly.regionId)
                }
            } else {
                toRemove.append(poly)
            }
        }
        if !toRemove.isEmpty { mapView.removeOverlays(toRemove) }

        // Add new polygons for regions not yet represented.
        let toAdd: [RegionPolygon] = regions.compactMap { control in
            guard !stillPresentIds.contains(control.region.id) else { return nil }
            let coords = control.region.polygon
            guard coords.count >= 3 else { return nil }
            let poly = RegionPolygon(coordinates: coords, count: coords.count)
            poly.regionId = control.region.id
            poly.regionName = control.region.name
            poly.rulerUserId = control.rulerUserId
            poly.fillUIColor = PlayerColor.uiColor(forRuler: control.rulerUserId, currentUserId: currentUserId)
            poly.isCurrentUserRuler = control.rulerUserId != nil && control.rulerUserId == currentUserId
            poly.isVacant = control.rulerUserId == nil
            return poly
        }
        if !toAdd.isEmpty { mapView.addOverlays(toAdd, level: .aboveLabels) }
        coordinator.knownRegionIds = Set(regions.map(\.region.id))
    }

    private func syncAnnotations(on mapView: MKMapView) {
        let desiredIds = Set(spots.map(\.spot.id))
        let existing = mapView.annotations.compactMap { $0 as? SpotAnnotation }

        let toRemove = existing.filter { !desiredIds.contains($0.spot.spot.id) }
        if !toRemove.isEmpty { mapView.removeAnnotations(toRemove) }

        let existingIds = Set(existing.map(\.spot.spot.id))
        let toAdd = spots
            .filter { !existingIds.contains($0.spot.id) }
            .map { SpotAnnotation(spot: $0, currentUserId: currentUserId) }
        if !toAdd.isEmpty { mapView.addAnnotations(toAdd) }
    }

    private func recenter(_ map: MKMapView) {
        let target: CLLocationCoordinate2D = spots.first?.spot.coordinate ?? fallbackCenter
        let camera = MKMapCamera(
            lookingAtCenter: target,
            fromDistance: 1400,
            pitch: 55,
            heading: 0
        )
        map.setCamera(camera, animated: true)
    }

    // MARK: Coordinator / delegate

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: StylizedRealMapView
        var didInitialFit = false
        var lastRecenterToken = Int.min
        var knownRegionIds: Set<String> = []

        init(_ parent: StylizedRealMapView) { self.parent = parent }

        // MARK: Overlay rendering

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let region = overlay as? RegionPolygon {
                let renderer = MKPolygonRenderer(polygon: region)
                let fill = region.fillUIColor ?? UIColor(hex: PlayerColor.vacantHex)
                let fillAlpha: CGFloat = region.isCurrentUserRuler ? 0.42
                    : (region.isVacant ? 0.18 : 0.30)
                renderer.fillColor = fill.withAlphaComponent(fillAlpha)
                renderer.strokeColor = fill.withAlphaComponent(0.82)
                renderer.lineWidth = region.isCurrentUserRuler ? 3.0 : 2.0
                if region.isVacant {
                    renderer.lineDashPattern = [6, 4]
                }
                return renderer
            }
            if let tile = overlay as? MKTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: tile)
                renderer.alpha = 1.0
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        // MARK: Annotations

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let spotAnn = annotation as? SpotAnnotation else { return nil }

            let reuseId = "TreasureChestPin"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: reuseId)

            view.annotation = annotation
            view.canShowCallout = false
            view.bounds = CGRect(x: 0, y: 0, width: 64, height: 80)
            view.centerOffset = CGPoint(x: 0, y: -28)
            view.subviews.forEach { $0.removeFromSuperview() }

            let pin = TreasureChestPin(
                variant: spotAnn.variant,
                spotName: spotAnn.spot.spot.name,
                isSelected: parent.selectedSpot?.id == spotAnn.spot.spot.id,
                onTap: { /* MapKit didSelect drives selection */ }
            )
            let host = UIHostingController(
                rootView: pin
                    .environment(\.reelTheme, .default)
            )
            host.view.backgroundColor = .clear
            host.view.isUserInteractionEnabled = false
            host.view.frame = view.bounds
            view.addSubview(host.view)
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let ann = view.annotation as? SpotAnnotation else { return }
            DispatchQueue.main.async {
                self.parent.selectedSpot = ann.spot.spot
                mapView.deselectAnnotation(ann, animated: false)
            }
        }

        // MARK: Region tap

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let mapView = recognizer.view as? MKMapView else { return }
            let point = recognizer.location(in: mapView)

            // Skip if the tap landed on (or very near) any spot marker — MapKit's
            // own annotation tap will handle it.
            for ann in mapView.annotations {
                if let v = mapView.view(for: ann) {
                    let expanded = v.frame.insetBy(dx: -10, dy: -10)
                    if expanded.contains(point) { return }
                }
            }

            let coord = mapView.convert(point, toCoordinateFrom: mapView)
            let mapPoint = MKMapPoint(coord)
            for overlay in mapView.overlays {
                guard let poly = overlay as? RegionPolygon,
                      let renderer = mapView.renderer(for: poly) as? MKPolygonRenderer else { continue }
                let viewPoint = renderer.point(for: mapPoint)
                if let path = renderer.path, path.contains(viewPoint) {
                    DispatchQueue.main.async { [weak self] in
                        self?.parent.selectedRegionId = poly.regionId
                    }
                    return
                }
            }
            // Tap on empty water → deselect.
            DispatchQueue.main.async { [weak self] in
                self?.parent.selectedRegionId = nil
            }
        }

        // MARK: UIGestureRecognizerDelegate

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            // Coexist with MapKit's built-in pan/zoom/rotation recognizers.
            true
        }
    }
}

// MARK: - Region polygon (carries gameplay metadata)

private final class RegionPolygon: MKPolygon {
    var regionId: String = ""
    var regionName: String = ""
    var rulerUserId: String?
    var fillUIColor: UIColor?
    var isCurrentUserRuler: Bool = false
    var isVacant: Bool = true

    /// Conservative equality — used by the diffing pass to decide whether
    /// the polygon needs to be recreated because its color changed.
    func matchesColor(_ other: UIColor) -> Bool {
        guard let mine = fillUIColor else { return false }
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        mine.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return abs(r1 - r2) < 0.01 && abs(g1 - g2) < 0.01 && abs(b1 - b2) < 0.01
    }
}

// MARK: - Annotation model

private final class SpotAnnotation: NSObject, MKAnnotation {
    let spot: SpotWithDetails
    let currentUserId: String?

    init(spot: SpotWithDetails, currentUserId: String?) {
        self.spot = spot
        self.currentUserId = currentUserId
    }

    var coordinate: CLLocationCoordinate2D { spot.spot.coordinate }
    var title: String? { spot.spot.name }

    var variant: TreasureChestPin.Variant {
        if let kingId = spot.spot.currentKingUserId, kingId == currentUserId {
            return .claimedByYou
        }
        if spot.spot.hasKing {
            return .claimedByOther(tier: CaptainTier.from(rankTier: spot.kingUser?.rankTier ?? .minnow))
        }
        return .vacant
    }
}

// MARK: - Tile overlay

/// Tile overlay that downloads CARTO Voyager tiles and remaps pixels by
/// source color + local gradient into a bright location-game palette. Cached
/// in-memory after remap.
private final class PokemonStyleTileOverlay: MKTileOverlay {
    private static let subdomains = ["a", "b", "c", "d"]
    private static let cache: NSCache<NSString, NSData> = {
        let c = NSCache<NSString, NSData>()
        c.countLimit = 768
        c.totalCostLimit = 96 * 1024 * 1024  // ~96 MB of decoded PNG
        return c
    }()
    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.urlCache = URLCache(memoryCapacity: 16 * 1024 * 1024, diskCapacity: 256 * 1024 * 1024)
        cfg.requestCachePolicy = .returnCacheDataElseLoad
        cfg.httpMaximumConnectionsPerHost = 6
        return URLSession(configuration: cfg)
    }()

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        let s = Self.subdomains[(abs(path.x) + abs(path.y)) % Self.subdomains.count]
        let template = self.urlTemplate ?? ""
        let raw = template
            .replacingOccurrences(of: "{s}", with: s)
            .replacingOccurrences(of: "{z}", with: "\(path.z)")
            .replacingOccurrences(of: "{x}", with: "\(path.x)")
            .replacingOccurrences(of: "{y}", with: "\(path.y)")
        return URL(string: raw)!
    }

    /// Bump when tile post-processing changes so cached PNGs are not reused across palettes.
    private static let paletteRevision = "v3-day"

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        let key = "\(Self.paletteRevision)/\(path.z)/\(path.x)/\(path.y)" as NSString
        if let cached = Self.cache.object(forKey: key) {
            result(cached as Data, nil)
            return
        }
        let task = Self.session.dataTask(with: url(forTilePath: path)) { data, _, error in
            guard let data, error == nil else {
                result(data, error)
                return
            }
            if let recolored = Self.recolor(data: data) {
                Self.cache.setObject(recolored as NSData, forKey: key, cost: recolored.count)
                result(recolored, nil)
            } else {
                result(data, nil)
            }
        }
        task.resume()
    }

    /// Map CARTO Voyager pixels into an immediately game-like daylight map:
    /// aqua water, mint/grass land, darker road ribbons, and warm edge
    /// highlights from luminance discontinuities.
    private static func recolor(data: Data) -> Data? {
        guard let cgImage = UIImage(data: data)?.cgImage else { return nil }
        let w = cgImage.width
        let h = cgImage.height
        guard w > 0, h > 0 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = w * bytesPerPixel
        var raw = [UInt8](repeating: 0, count: h * bytesPerRow)

        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        guard let ctx = CGContext(
            data: &raw,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

        let count = w * h
        var lum = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let o = i * bytesPerPixel
            let r = Float(raw[o])
            let g = Float(raw[o + 1])
            let b = Float(raw[o + 2])
            // gamma-expand approximates perceptual luminance separation on dark tiles
            let y = max(0, min(1, pow((0.299 * r + 0.587 * g + 0.114 * b) / 255, 1 / 2.05)))
            lum[i] = y
        }

        let waterDeep = SIMD3<Float>(0.18, 0.60, 0.84)
        let waterShallow = SIMD3<Float>(0.58, 0.88, 0.94)
        let landBase = SIMD3<Float>(0.55, 0.88, 0.76)
        let landCool = SIMD3<Float>(0.42, 0.80, 0.79)
        let park = SIMD3<Float>(0.38, 0.78, 0.38)
        let roadCore = SIMD3<Float>(0.19, 0.43, 0.50)
        let roadEdge = SIMD3<Float>(1.00, 0.86, 0.55)
        let linework = SIMD3<Float>(0.22, 0.52, 0.56)

        func edgeStrength(_ x: Int, _ y: Int) -> Float {
            guard x > 0, x < w - 1, y > 0, y < h - 1 else { return 0 }
            let idx = y * w + x
            let gx = lum[idx + 1] - lum[idx - 1]
            let gy = lum[idx + w] - lum[idx - w]
            let mag = sqrt(gx * gx + gy * gy)
            return simd_clamp(mag * 4.2, 0, 1)
        }

        func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> {
            a + (b - a) * simd_clamp(t, 0, 1)
        }

        func microTint(ix: Int, iy: Int) -> SIMD3<Float> {
            let n = Float(((ix & 15) ^ (iy & 15)) & 7) / 255
            return SIMD3<Float>(n * 0.25, n * 0.35, n * 0.28)
        }

        func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
            if edge1 < edge0 { return 1 - smoothstep(edge1, edge0, x) }
            let t = simd_clamp((x - edge0) / max(edge1 - edge0, 0.0001), 0, 1)
            return t * t * (3 - 2 * t)
        }

        var outRaw = raw
        for y in 0..<h {
            for x in 0..<w {
                let i = y * w + x
                let L = lum[i]
                let o = i * bytesPerPixel
                let r = Float(raw[o]) / 255
                let g = Float(raw[o + 1]) / 255
                let b = Float(raw[o + 2]) / 255
                let mx = max(r, max(g, b))
                let mn = min(r, min(g, b))
                let sat = mx - mn

                let isWater = b > 0.46 && b > r + 0.045 && b >= g - 0.04
                let isPark = g > r + 0.035 && g > b + 0.02 && L < 0.92
                let roadWeight = smoothstep(0.965, 0.998, L) * (1 - smoothstep(0.10, 0.20, sat))
                let waterLineDamp: Float = isWater ? 0.4 : 1
                let darkLineWeight = smoothstep(0.34, 0.08, L) * waterLineDamp

                var baseCol: SIMD3<Float>
                if isWater {
                    let t = simd_clamp((b - 0.46) / 0.34, 0, 1)
                    baseCol = mix(waterDeep, waterShallow, t)
                } else if isPark {
                    baseCol = mix(park * 0.92, park + SIMD3<Float>(0.10, 0.10, 0.03), simd_clamp((g - r) * 2, 0, 1))
                } else {
                    let terrainT = simd_clamp((L - 0.40) / 0.50, 0, 1)
                    baseCol = mix(landCool, landBase, terrainT) + microTint(ix: x, iy: y)
                }

                let rim = edgeStrength(x, y)
                baseCol = mix(baseCol, roadCore, roadWeight * 0.92)
                baseCol = mix(baseCol, linework, darkLineWeight * 0.28)
                let edgeWarmth = rim * (0.36 + roadWeight * 0.34) * (isWater ? 0.35 : 1)
                let rgb = mix(baseCol, roadEdge, edgeWarmth)

                outRaw[o] = UInt8(min(max(Int(rgb.x * 255 + 0.5), 0), 255))
                outRaw[o + 1] = UInt8(min(max(Int(rgb.y * 255 + 0.5), 0), 255))
                outRaw[o + 2] = UInt8(min(max(Int(rgb.z * 255 + 0.5), 0), 255))
                outRaw[o + 3] = 255
            }
        }

        guard let outCtx = CGContext(
            data: &outRaw,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let outCg = outCtx.makeImage() else { return nil }

        return UIImage(cgImage: outCg).pngData()
    }
}
