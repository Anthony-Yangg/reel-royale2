import Foundation

/// Result of attempting a purchase via the `purchase_shop_item` RPC.
struct PurchaseResult: Decodable, Equatable {
    let ok: Bool
    let error: String?
    let itemId: String?
    let cost: Int?

    enum CodingKeys: String, CodingKey {
        case ok
        case error
        case itemId = "item_id"
        case cost
    }
}

protocol ShopRepositoryProtocol {
    func getCatalog() async throws -> [ShopItem]
    func getInventory(forUser userId: String) async throws -> [UserInventoryItem]
    func purchase(itemId: String, userId: String) async throws -> PurchaseResult
    func equip(itemId: String, userId: String) async throws -> PurchaseResult
}

final class SupabaseShopRepository: ShopRepositoryProtocol {
    private let supabase: SupabaseService

    init(supabase: SupabaseService) {
        self.supabase = supabase
    }

    func getCatalog() async throws -> [ShopItem] {
        try await supabase.database
            .from(AppConstants.Supabase.Tables.shopItems)
            .select()
            .eq("is_active", value: true)
            .order("category", ascending: true)
            .order("sort_order", ascending: true)
            .execute()
            .value
    }

    func getInventory(forUser userId: String) async throws -> [UserInventoryItem] {
        try await supabase.database
            .from(AppConstants.Supabase.Tables.userInventory)
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
    }

    func purchase(itemId: String, userId: String) async throws -> PurchaseResult {
        struct Params: Encodable {
            let p_user_id: String
            let p_item_id: String
        }

        let result: PurchaseResult = try await supabase.database
            .rpc(
                AppConstants.Supabase.RPC.purchaseShopItem,
                params: Params(p_user_id: userId, p_item_id: itemId)
            )
            .execute()
            .value
        return result
    }

    func equip(itemId: String, userId: String) async throws -> PurchaseResult {
        struct Params: Encodable {
            let p_user_id: String
            let p_item_id: String
        }

        let result: PurchaseResult = try await supabase.database
            .rpc(
                AppConstants.Supabase.RPC.equipInventoryItem,
                params: Params(p_user_id: userId, p_item_id: itemId)
            )
            .execute()
            .value
        return result
    }
}
