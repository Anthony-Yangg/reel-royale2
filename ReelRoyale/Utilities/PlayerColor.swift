import UIKit
import SwiftUI

/// Deterministic per-player color assignment. Two players with the same id
/// always get the same color globally, so rivals are visually recognizable
/// across the whole map. The current user always gets the brand crown gold
/// so you can pick out your own water at a glance.
enum PlayerColor {
    /// 8-color palette tuned to read well on the dark teal CARTO basemap.
    /// Order is part of the contract — never reshuffle.
    private static let paletteHex: [UInt32] = [
        0xE6533C, // coral
        0x7A5BD5, // violet
        0x9CE074, // lime
        0xE34CB9, // magenta
        0x4FB5FF, // sky
        0xE5A547, // amber
        0x46D6B0, // mint
        0xFF7A8A  // rose
    ]

    /// Brand crown gold, reserved for the current player.
    static let mineHex: UInt32 = 0xF2C95C

    /// Cool seafoam used for vacant / contested regions with no ruler.
    static let vacantHex: UInt32 = 0x3FB8AE

    // MARK: - Resolvers

    static func uiColor(forRuler rulerId: String?, currentUserId: String?) -> UIColor {
        guard let rulerId else { return UIColor(hex: vacantHex) }
        if let me = currentUserId, me == rulerId { return UIColor(hex: mineHex) }
        let idx = stableIndex(for: rulerId, count: paletteHex.count)
        return UIColor(hex: paletteHex[idx])
    }

    static func color(forRuler rulerId: String?, currentUserId: String?) -> Color {
        Color(uiColor: uiColor(forRuler: rulerId, currentUserId: currentUserId))
    }

    static func uiColor(forUser userId: String, currentUserId: String?) -> UIColor {
        uiColor(forRuler: userId, currentUserId: currentUserId)
    }

    static func color(forUser userId: String, currentUserId: String?) -> Color {
        Color(uiColor: uiColor(forUser: userId, currentUserId: currentUserId))
    }

    // MARK: - Hex string helpers (Unity bridge uses string colors)

    /// "#RRGGBB" string for embedding in JSON payloads. Used by the Unity
    /// bridge; SwiftUI/UIKit consumers should prefer the `UIColor`/`Color`
    /// helpers above.
    static func hex(forUserId userId: String, isCurrentUser: Bool) -> String {
        let raw: UInt32
        if isCurrentUser {
            raw = mineHex
        } else if userId.isEmpty {
            raw = vacantHex
        } else {
            let idx = stableIndex(for: userId, count: paletteHex.count)
            raw = paletteHex[idx]
        }
        return Self.format(hex: raw)
    }

    /// "#RRGGBB" for the vacant / unowned color.
    static var vacantHexString: String { format(hex: vacantHex) }

    private static func format(hex raw: UInt32) -> String {
        String(format: "#%06X", raw & 0xFFFFFF)
    }

    // MARK: - Hashing

    /// FNV-1a 64-bit. Stable across processes — `String.hashValue` is not.
    private static func stableIndex(for s: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        var hash: UInt64 = 14695981039346656037
        for byte in s.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return Int(hash % UInt64(count))
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}
