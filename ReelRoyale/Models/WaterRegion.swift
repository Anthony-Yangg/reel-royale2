import Foundation
import CoreLocation

/// A procedurally-generated, contestable section of water. Each region is one
/// flat-Web-Mercator hex cell whose existence is anchored to one or more
/// fishing `Spot`s — cells with no spots are dropped so the map only shows
/// regions you can actually contest.
///
/// A region is "ruled" by whichever user is king of the most spots inside it
/// (tiebreak by total catch size — same formula as `TerritoryWithControl`).
struct WaterRegion: Identifiable, Equatable, Hashable {
    /// Deterministic id derived from the cell's axial coordinates.
    let id: String
    /// 6-vertex polygon ring in lat/lng (pointy-top hex, vertices ordered).
    /// First and last vertex are NOT duplicated.
    let polygon: [CLLocationCoordinate2D]
    /// Visual center of the cell — used for label placement.
    let center: CLLocationCoordinate2D
    /// Ids of the `Spot`s that fall inside this region.
    let spotIds: [String]
    /// Best human-readable name we can compute (most-common `regionName`
    /// among contained spots, or a generated "Sector X-N" fallback).
    let name: String

    static func == (lhs: WaterRegion, rhs: WaterRegion) -> Bool { lhs.id == rhs.id }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Computed control snapshot for a region — mirrors `TerritoryWithControl`
/// but at the procedural region level.
struct WaterRegionControl: Identifiable, Equatable {
    let region: WaterRegion
    let rulerUserId: String?
    let crownCounts: [String: Int]
    let currentUserCrowns: Int
    let totalSpots: Int

    var id: String { region.id }

    var rulerCrownCount: Int {
        guard let r = rulerUserId else { return 0 }
        return crownCounts[r] ?? 0
    }

    /// How many more spot-crowns the current user needs to overtake the ruler.
    /// Zero when the current user already rules or when the region is vacant
    /// (any catch wins it).
    var crownsNeededForCurrentUser: Int {
        if rulerUserId == nil { return 1 }
        if currentUserCrowns >= rulerCrownCount { return 0 }
        return rulerCrownCount - currentUserCrowns + 1
    }

    /// Sorted leaderboard of contenders, top first.
    var contenders: [(userId: String, crowns: Int)] {
        crownCounts.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }
}
