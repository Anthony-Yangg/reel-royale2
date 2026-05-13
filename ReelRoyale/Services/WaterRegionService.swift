import Foundation
import CoreLocation

/// Pure, deterministic builder for `WaterRegion` + `WaterRegionControl`.
///
/// Geometry: spots are projected to Web Mercator meters and bucketed into a
/// flat hex grid with `cellEdgeMeters` edge length (~1.5 km → ~3 km
/// corner-to-corner). One hex containing at least one spot becomes one
/// region. Ruler logic mirrors `TerritoryWithControl.calculateRuler`.
enum WaterRegionService {
    /// Web-Mercator earth radius in meters.
    private static let earthRadius: Double = 6_378_137.0

    /// Hex edge length in mercator meters. 1500 m edge ≈ 3 km corner-to-corner.
    static let cellEdgeMeters: Double = 1500.0

    // MARK: - Public API

    /// Build regions for the supplied spots.
    static func regions(from spots: [Spot]) -> [WaterRegion] {
        guard !spots.isEmpty else { return [] }
        var buckets: [HexCoord: [Spot]] = [:]
        for spot in spots {
            let coord = cell(for: spot.coordinate)
            buckets[coord, default: []].append(spot)
        }
        return buckets
            .map { (coord, members) in
                WaterRegion(
                    id: coord.id,
                    polygon: polygon(for: coord),
                    center: center(for: coord),
                    spotIds: members.map(\.id),
                    name: displayName(for: members, fallback: cardinalLabel(for: coord))
                )
            }
            .sorted { $0.id < $1.id }
    }

    /// Build the control snapshot for a single region from a spot pool.
    static func control(
        for region: WaterRegion,
        spots: [Spot],
        currentUserId: String?
    ) -> WaterRegionControl {
        let lookup = Set(region.spotIds)
        let regionSpots = spots.filter { lookup.contains($0.id) }
        return control(forSpotsInRegion: regionSpots, region: region, currentUserId: currentUserId)
    }

    /// Build region controls for every region derived from the spot pool.
    static func controls(from spots: [Spot], currentUserId: String?) -> [WaterRegionControl] {
        regions(from: spots).map { region in
            let members = spots.filter { region.spotIds.contains($0.id) }
            return control(forSpotsInRegion: members, region: region, currentUserId: currentUserId)
        }
    }

    /// Find the region a given coordinate falls into, given an existing set
    /// of regions. Returns nil if the coordinate's hex cell isn't one of the
    /// supplied regions.
    static func region(at coord: CLLocationCoordinate2D, in regions: [WaterRegion]) -> WaterRegion? {
        let cellId = cell(for: coord).id
        return regions.first { $0.id == cellId }
    }

    /// Build a region for a single spot — used by server-side flows (e.g.
    /// `GameService.processCatch`) that don't already have all regions in
    /// memory. The resulting region only knows about the spots passed in.
    static func region(forSpotAt coord: CLLocationCoordinate2D, fromSpots spots: [Spot]) -> WaterRegion {
        let target = cell(for: coord)
        let members = spots.filter { cell(for: $0.coordinate) == target }
        return WaterRegion(
            id: target.id,
            polygon: polygon(for: target),
            center: center(for: target),
            spotIds: members.map(\.id),
            name: displayName(for: members, fallback: cardinalLabel(for: target))
        )
    }

    // MARK: - Ruler computation

    private static func control(
        forSpotsInRegion regionSpots: [Spot],
        region: WaterRegion,
        currentUserId: String?
    ) -> WaterRegionControl {
        var crownCounts: [String: Int] = [:]
        var totalSizes: [String: Double] = [:]
        for spot in regionSpots {
            guard let kingId = spot.currentKingUserId else { continue }
            crownCounts[kingId, default: 0] += 1
            if let size = spot.currentBestSizeInCm {
                totalSizes[kingId, default: 0] += size
            }
        }
        let sorted = crownCounts.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return (totalSizes[lhs.key] ?? 0) > (totalSizes[rhs.key] ?? 0)
        }
        let rulerId = sorted.first?.key
        let mine = currentUserId.flatMap { crownCounts[$0] } ?? 0
        return WaterRegionControl(
            region: region,
            rulerUserId: rulerId,
            crownCounts: crownCounts,
            currentUserCrowns: mine,
            totalSpots: regionSpots.count
        )
    }

    // MARK: - Hex math (pointy-top axial, flat Web Mercator)

    struct HexCoord: Hashable {
        let q: Int
        let r: Int
        var id: String { "h_\(q)_\(r)" }
    }

    static func cell(for coord: CLLocationCoordinate2D) -> HexCoord {
        let p = mercator(from: coord)
        let s = cellEdgeMeters
        let qf = (sqrt(3.0) / 3.0 * p.x - 1.0 / 3.0 * p.y) / s
        let rf = (2.0 / 3.0 * p.y) / s
        return roundAxial(q: qf, r: rf)
    }

    static func center(for cell: HexCoord) -> CLLocationCoordinate2D {
        let s = cellEdgeMeters
        let x = s * (sqrt(3.0) * (Double(cell.q) + Double(cell.r) / 2.0))
        let y = s * (3.0 / 2.0 * Double(cell.r))
        return latlng(from: (x: x, y: y))
    }

    static func polygon(for cell: HexCoord) -> [CLLocationCoordinate2D] {
        let s = cellEdgeMeters
        let cx = s * (sqrt(3.0) * (Double(cell.q) + Double(cell.r) / 2.0))
        let cy = s * (3.0 / 2.0 * Double(cell.r))
        var pts: [CLLocationCoordinate2D] = []
        pts.reserveCapacity(6)
        // Pointy-top corners at 30°, 90°, 150°, 210°, 270°, 330°.
        for i in 0..<6 {
            let angle = .pi / 180.0 * (60.0 * Double(i) - 30.0)
            let vx = cx + s * cos(angle)
            let vy = cy + s * sin(angle)
            pts.append(latlng(from: (x: vx, y: vy)))
        }
        return pts
    }

    private static func roundAxial(q qf: Double, r rf: Double) -> HexCoord {
        let xf = qf
        let zf = rf
        let yf = -xf - zf
        var rx = xf.rounded()
        var ry = yf.rounded()
        var rz = zf.rounded()
        let dx = abs(rx - xf)
        let dy = abs(ry - yf)
        let dz = abs(rz - zf)
        if dx > dy && dx > dz {
            rx = -ry - rz
        } else if dy > dz {
            ry = -rx - rz
        } else {
            rz = -rx - ry
        }
        return HexCoord(q: Int(rx), r: Int(rz))
    }

    // MARK: - Web Mercator

    private static func mercator(from coord: CLLocationCoordinate2D) -> (x: Double, y: Double) {
        let clamped = max(-85.05112878, min(85.05112878, coord.latitude))
        let x = earthRadius * coord.longitude * .pi / 180.0
        let y = earthRadius * log(tan(.pi / 4.0 + clamped * .pi / 360.0))
        return (x, y)
    }

    private static func latlng(from p: (x: Double, y: Double)) -> CLLocationCoordinate2D {
        let lng = p.x / earthRadius * 180.0 / .pi
        let lat = (2.0 * atan(exp(p.y / earthRadius)) - .pi / 2.0) * 180.0 / .pi
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    // MARK: - Naming

    private static func displayName(for spots: [Spot], fallback: String) -> String {
        let names = spots.compactMap { $0.regionName }.filter { !$0.isEmpty }
        let counts = names.reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        if let mostCommon = counts.sorted(by: { $0.value > $1.value }).first?.key {
            return mostCommon
        }
        if spots.count == 1, let one = spots.first { return one.name }
        return fallback
    }

    private static func cardinalLabel(for cell: HexCoord) -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ"
        let li = ((cell.q % letters.count) + letters.count) % letters.count
        let row = abs(cell.r)
        let idx = letters.index(letters.startIndex, offsetBy: li)
        return "Sector \(letters[idx])-\(row)"
    }
}
