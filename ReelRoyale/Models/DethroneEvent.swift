import Foundation

/// A denormalized record of a king change, for the recent-dethrones ticker.
struct DethroneEvent: Identifiable, Codable, Hashable {
    let id: String
    let occurredAt: Date
    let spotId: String
    let spotName: String
    let previousKingId: String
    let previousKingName: String
    let newKingId: String
    let newKingName: String
    let newKingTier: CaptainTier
    let newCatchSizeCm: Double

    /// "2m ago", "1h ago", etc. — for ticker display.
    var elapsedShort: String {
        let interval = -occurredAt.timeIntervalSinceNow
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}
