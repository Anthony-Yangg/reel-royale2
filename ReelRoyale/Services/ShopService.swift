import Foundation

/// Domain-level shop errors, keyed off the strings returned from the
/// `purchase_shop_item` RPC.
enum ShopError: LocalizedError, Equatable {
    case itemNotFound
    case userNotFound
    case insufficientCoins
    case rankTooLow
    case releaseCountTooLow
    case trophyCountTooLow
    case alreadyOwned
    case notOwned
    case unknown(String)

    init(rpcError: String) {
        switch rpcError {
        case "item_not_found":     self = .itemNotFound
        case "user_not_found":     self = .userNotFound
        case "insufficient_coins": self = .insufficientCoins
        case "rank_too_low":       self = .rankTooLow
        case "release_count_too_low": self = .releaseCountTooLow
        case "trophy_count_too_low":  self = .trophyCountTooLow
        case "already_owned":      self = .alreadyOwned
        case "not_owned":          self = .notOwned
        default:                   self = .unknown(rpcError)
        }
    }

    var errorDescription: String? {
        switch self {
        case .itemNotFound:     return "That item is no longer available."
        case .userNotFound:     return "Account error - try signing out and back in."
        case .insufficientCoins:return "Not enough Lure Coins."
        case .rankTooLow:       return "Your rank is too low to equip this."
        case .releaseCountTooLow:return "Catch-and-release requirement not met yet."
        case .trophyCountTooLow: return "Trophy fish requirement not met yet."
        case .alreadyOwned:     return "You already own this item."
        case .notOwned:         return "You don't own this item yet."
        case .unknown(let m):   return "Shop error: \(m)"
        }
    }
}

protocol ShopServiceProtocol {
    /// Returns catalog items with ownership + eligibility decoration for `user`.
    func getCatalog(for user: User, stats: UserStats) async throws -> [ShopItemWithOwnership]
    func purchase(itemId: String, for user: User) async throws
    func equip(itemId: String, for user: User) async throws
}

final class ShopService: ShopServiceProtocol {
    private let shopRepository: ShopRepositoryProtocol

    init(shopRepository: ShopRepositoryProtocol) {
        self.shopRepository = shopRepository
    }

    func getCatalog(for user: User, stats: UserStats) async throws -> [ShopItemWithOwnership] {
        async let catalogTask = shopRepository.getCatalog()
        async let inventoryTask = shopRepository.getInventory(forUser: user.id)
        let (catalog, inventory) = try await (catalogTask, inventoryTask)

        let inventoryByItem = Dictionary(uniqueKeysWithValues: inventory.map { ($0.itemId, $0) })

        return catalog.map { item in
            let owned = inventoryByItem[item.id]
            let block = owned == nil ? item.purchaseBlock(for: user, stats: stats) : nil
            return ShopItemWithOwnership(
                item: item,
                owned: owned != nil,
                isEquipped: owned?.isEquipped ?? false,
                block: block
            )
        }
    }

    func purchase(itemId: String, for user: User) async throws {
        let result = try await shopRepository.purchase(itemId: itemId, userId: user.id)
        if !result.ok {
            throw ShopError(rpcError: result.error ?? "unknown")
        }
    }

    func equip(itemId: String, for user: User) async throws {
        let result = try await shopRepository.equip(itemId: itemId, userId: user.id)
        if !result.ok {
            throw ShopError(rpcError: result.error ?? "unknown")
        }
    }
}
