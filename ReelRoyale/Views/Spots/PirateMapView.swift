import SwiftUI
import MapKit
import UIKit
import simd

/// Pokémon-GO-style map surface. We render real OpenStreetMap geography via
/// Apple's `MKMapView` with the base layer replaced by stylized dark raster
/// tiles (CARTO "dark_all"), then layer two game-meaningful overlays on top:
///
///   1. `WaterRegion` polygons — procedural ~3 km hex cells, one per
///      contestable region. Filled with the ruling player's color (or a
///      vacant teal). Tapping one reveals the region info card.
///   2. Treasure-chest pins — one per `Spot`, the action point you fish at
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

            playerPulse
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
        .background(Color(hex: 0x05101D).ignoresSafeArea())
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

    private var playerPulse: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1 / 30)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let pulse = 0.6 + 0.25 * sin(t * 2)
            ZStack {
                Circle()
                    .fill(theme.colors.brand.crown.opacity(0.18))
                    .frame(width: 110 + pulse * 22, height: 110 + pulse * 22)
                    .blur(radius: 10)
                Circle()
                    .stroke(theme.colors.brand.crown.opacity(0.55), lineWidth: 2)
                    .frame(width: 58, height: 58)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [theme.colors.brand.crown, Color(hex: 0x7A4C1C)],
                            center: .topLeading,
                            startRadius: 2,
                            endRadius: 30
                        )
                    )
                    .frame(width: 46, height: 46)
                    .overlay {
                        Image(systemName: "fish.fill")
                            .font(.system(size: 24, weight: .black))
                            .foregroundStyle(Color(hex: 0x2B1A10))
                    }
                    .shadow(color: theme.colors.brand.crown.opacity(0.45), radius: 16)
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
                .foregroundStyle(theme.colors.brand.crown)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(Color(hex: 0x102338).opacity(0.94))
                        .shadow(color: theme.colors.brand.seafoam.opacity(0.25), radius: 18)
                )
                .overlay(
                    Circle()
                        .strokeBorder(theme.colors.brand.seafoam.opacity(0.22), lineWidth: 1)
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
                .foregroundStyle(theme.colors.text.muted)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule(style: .continuous).fill(Color(hex: 0x05101D).opacity(0.7)))
        }
    }
}

// MARK: - Region info card

private struct RegionInfoCard: View {
    let control: WaterRegionControl
    let currentUserId: String?
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
                        .background(Circle().fill(Color.white.opacity(0.06)))
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
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: 0x0E1B26).opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(borderColor.opacity(0.65), lineWidth: 1.2)
        )
        .shadow(color: borderColor.opacity(0.35), radius: 18, y: 6)
    }

    private var rulerSwatch: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(PlayerColor.color(forRuler: control.rulerUserId, currentUserId: currentUserId))
            .frame(width: 36, height: 36)
            .overlay(
                Image(systemName: control.rulerUserId == nil ? "questionmark" :
                        (control.rulerUserId == currentUserId ? "crown.fill" : "flag.fill"))
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Color(hex: 0x0E1B26))
            )
            .shadow(color: PlayerColor.color(forRuler: control.rulerUserId, currentUserId: currentUserId).opacity(0.55), radius: 10)
    }

    private var rulerLabel: String {
        if let ruler = control.rulerUserId {
            if ruler == currentUserId { return "RULED BY YOU" }
            let shortId = String(ruler.prefix(8))
            return "RULED BY @\(shortId)"
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
            return "Defend it — any rival who beats your size at one of these spots steals a crown back."
        }
        if control.rulerUserId == nil {
            return "Land a king-sized catch at any spot here to claim this water."
        }
        let plural = need == 1 ? "crown" : "crowns"
        return "Take \(need) more spot \(plural) inside this region to flip control to you."
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
                .fill(Color.white.opacity(0.04))
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
        map.overrideUserInterfaceStyle = .dark

        // Replace Apple's base map entirely with stylized OSM raster tiles.
        // CARTO "dark_all" encodes land/water/roads mostly as luminance; we
        // remap each pixel to Pokémon GO–night hues (deep blue water, teal
        // land blocks, navy roads with cyan edge bloom).
        let urlTemplate = "https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}@2x.png"
        let overlay = PokemonStyleTileOverlay(urlTemplate: urlTemplate)
        overlay.canReplaceMapContent = true
        overlay.maximumZ = 19
        overlay.minimumZ = 1
        map.addOverlay(overlay, level: .aboveLabels)

        // Tap gesture for region selection. MKMapView doesn't ship a
        // tap-on-overlay event, so we install our own that hit-tests the
        // polygon renderers under the touch point. cancelsTouchesInView is
        // false so map pan/zoom is unaffected; we skip the hit-test entirely
        // when the touch lands on a treasure-chest pin.
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
                // Cranked up from the original timid values so the colored
                // sea actually reads against the recolored cyan tiles.
                let fillAlpha: CGFloat = region.isCurrentUserRuler ? 0.72
                    : (region.isVacant ? 0.32 : 0.58)
                renderer.fillColor = fill.withAlphaComponent(fillAlpha)
                renderer.strokeColor = fill.withAlphaComponent(1.0)
                renderer.lineWidth = region.isCurrentUserRuler ? 3.2 : 2.4
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

            // Skip if the tap landed on (or very near) any treasure pin — MapKit's
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
            return .claimedByOther(tier: .firstMate)
        }
        return .vacant
    }
}

// MARK: - Tile overlay

/// Tile overlay that downloads CARTO `dark_all` basemap and remaps pixels by
/// luminance + local gradient into a Pokémon GO–style night palette (not a
/// flat aqua wash). Cached in-memory after remap.
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
    private static let paletteRevision = "v2"

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

    /// Map CARTO `dark_all` luminance bands into Pokémon GO–night colors:
    /// deep saturated water, dark teal blocks for land, navy road fills,
    /// cyan bloom on luminance discontinuities (street outlines).
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

        let waterDeep = SIMD3<Float>(0.00, 0.145, 0.355)
        let land = SIMD3<Float>(Float(16) / 255, Float(42) / 255, Float(45) / 255)
        let roadCore = SIMD3<Float>(Float(10) / 255, Float(25) / 255, Float(49) / 255)
        let cyanEdge = SIMD3<Float>(0.0, 0.898, 1.0)
        let labelHi = SIMD3<Float>(0.78, 0.93, 1.0)

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
            let n = Float(((ix & 15) ^ (iy & 15)) & 7) / 220
            return SIMD3<Float>(n * 0.35, n * 0.55, n * 0.45)
        }

        var outRaw = raw
        for y in 0..<h {
            for x in 0..<w {
                let i = y * w + x
                let L = lum[i]
                let o = i * bytesPerPixel

                let baseCol: SIMD3<Float>
                if L < 0.078 {
                    let t = L / 0.078
                    baseCol = mix(waterDeep * 0.72, waterDeep, t)
                } else if L < 0.265 {
                    let t = (L - 0.078) / (0.265 - 0.078)
                    baseCol = mix(waterDeep * 0.92, land + microTint(ix: x, iy: y), t)
                } else if L < 0.58 {
                    let t = (L - 0.265) / (0.58 - 0.265)
                    baseCol = mix(land * 1.05 + microTint(ix: x, iy: y) * 0.35, roadCore, t)
                } else {
                    let t = min((L - 0.58) / (0.92 - 0.58), 1)
                    baseCol = mix(roadCore * 1.12, labelHi, t)
                }

                let rim = edgeStrength(x, y)
                let rimWeight = rim * (L > 0.11 && L < 0.82 ? 1 : 0.38)
                let rgb = mix(baseCol, cyanEdge, rimWeight * 0.62)

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
