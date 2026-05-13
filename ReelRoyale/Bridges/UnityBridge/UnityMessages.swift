import Foundation
import CoreLocation

/// JSON payload shapes that travel from Swift to Unity. Field names MUST
/// match the C# `[Serializable]` structs in
/// `unity-engine/Assets/Scripts/NativeBridge/NativeBridgePayloads.cs` — Unity's
/// `JsonUtility` is name-sensitive and silently drops mismatches.
///
/// Each top-level payload is a wrapper because Unity's JsonUtility cannot
/// deserialize a top-level array.
enum UnityMessages {
    struct PlayerPosition: Encodable {
        let lat: Double
        let lng: Double
        let headingDeg: Float
        let speedMps: Float
        let accuracyM: Float

        init(coordinate: CLLocationCoordinate2D,
             heading: CLLocationDirection = -1,
             speed: CLLocationSpeed = -1,
             accuracy: CLLocationAccuracy = -1) {
            self.lat = coordinate.latitude
            self.lng = coordinate.longitude
            self.headingDeg = Float(max(heading, 0))
            self.speedMps = Float(max(speed, 0))
            self.accuracyM = Float(max(accuracy, 0))
        }
    }

    struct Spot: Encodable {
        let id: String
        let name: String
        let lat: Double
        let lng: Double
        let kingId: String
        let kingColorHex: String
        let isCurrentUserKing: Bool
        let crowns: Int
    }

    struct Spots: Encodable {
        let spots: [Spot]
    }

    struct RegionVertex: Encodable {
        let lat: Double
        let lng: Double
    }

    struct Region: Encodable {
        let id: String
        let name: String
        let rulerId: String
        let rulerColorHex: String
        let isCurrentUserRuler: Bool
        let isVacant: Bool
        let polygon: [RegionVertex]
    }

    struct Regions: Encodable {
        let regions: [Region]
    }

    struct User: Encodable {
        let userId: String
        let userColorHex: String
    }

    struct Recenter: Encodable {
        let animate: Bool
    }
}

extension Encodable {
    /// Serialize to a single-line JSON string. Returns the literal string
    /// "{}" on encoding failure rather than throwing — the bridge prefers
    /// "we tried" over "we crashed" semantics.
    func toUnityJSON() -> String {
        do {
            let data = try JSONEncoder().encode(self)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return "{}"
        }
    }
}
