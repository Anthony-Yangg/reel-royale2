import Foundation

/// Like model for catch appreciation
/// Maps to Supabase 'likes' table
struct Like: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let catchId: String
    let userId: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case catchId = "catch_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
    
    init(
        id: String = UUID().uuidString,
        catchId: String,
        userId: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.catchId = catchId
        self.userId = userId
        self.createdAt = createdAt
    }
}

/// Aggregated like information for a catch
struct LikeInfo: Equatable {
    let catchId: String
    let totalCount: Int
    let isLikedByCurrentUser: Bool
    
    static func empty(for catchId: String) -> LikeInfo {
        LikeInfo(catchId: catchId, totalCount: 0, isLikedByCurrentUser: false)
    }
}

