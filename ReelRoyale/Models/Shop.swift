import Foundation
import SwiftUI

/// Tackle Shop item categories.
enum ShopCategory: String, Codable, CaseIterable, Identifiable {
    case rodSkin = "rod_skin"
    case badge
    case flag
    case frame

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rodSkin: return "Rod Skins"
        case .badge:   return "Badges"
        case .flag:    return "Flags"
        case .frame:   return "Frames"
        }
    }

    var icon: String {
        switch self {
        case .rodSkin: return "fishingrod"
        case .badge:   return "rosette"
        case .flag:    return "flag.fill"
        case .frame:   return "square.stack.fill"
        }
    }
}

/// Catalog item available for purchase.
/// Maps to Supabase 'shop_items' table.
struct ShopItem: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let category: ShopCategory
    let costCoins: Int
    let rankRequired: RankTier?
    let description: String?
    let iconName: String?
    let colorHex: String?
    var isActive: Bool
    let sortOrder: Int
    let requiresReleaseCount: Int?
    let requiresTrophyCount: Int?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case costCoins = "cost_coins"
        case rankRequired = "rank_required"
        case description
        case iconName = "icon_name"
        case colorHex = "color_hex"
        case isActive = "is_active"
        case sortOrder = "sort_order"
        case requiresReleaseCount = "requires_release_count"
        case requiresTrophyCount = "requires_trophy_count"
        case createdAt = "created_at"
    }

    /// Returns the reason a user cannot purchase this item, or nil if eligible.
    func purchaseBlock(for user: User, stats: UserStats) -> ShopPurchaseBlock? {
        if user.lureCoins < costCoins { return .insufficientCoins(needs: costCoins - user.lureCoins) }
        if let required = rankRequired, user.rankTier < required { return .rankTooLow(required: required) }
        if let need = requiresReleaseCount, stats.releaseCount < need {
            return .needsReleases(need: need, has: stats.releaseCount)
        }
        if let need = requiresTrophyCount, stats.trophyCount < need {
            return .needsTrophies(need: need, has: stats.trophyCount)
        }
        return nil
    }
}

/// Why a purchase is blocked.
enum ShopPurchaseBlock: Equatable {
    case insufficientCoins(needs: Int)
    case rankTooLow(required: RankTier)
    case needsReleases(need: Int, has: Int)
    case needsTrophies(need: Int, has: Int)

    var message: String {
        switch self {
        case .insufficientCoins(let needs): return "Need \(needs) more Lure Coins."
        case .rankTooLow(let required): return "Reach \(required.rawValue) rank to unlock."
        case .needsReleases(let need, let has): return "Catch & release \(need - has) more fish to unlock."
        case .needsTrophies(let need, let has): return "Catch \(need - has) more trophy fish to unlock."
        }
    }
}

/// Owned item record. Maps to 'user_inventory'.
struct UserInventoryItem: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let userId: String
    let itemId: String
    let purchasedAt: Date
    var isEquipped: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case itemId = "item_id"
        case purchasedAt = "purchased_at"
        case isEquipped = "is_equipped"
    }
}

/// Joined inventory + catalog data for shop UI.
struct ShopItemWithOwnership: Identifiable, Equatable {
    let item: ShopItem
    let owned: Bool
    let isEquipped: Bool
    let block: ShopPurchaseBlock?

    var id: String { item.id }
}
