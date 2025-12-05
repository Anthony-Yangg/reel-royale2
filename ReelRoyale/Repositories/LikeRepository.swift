import Foundation

/// Protocol for like data operations
protocol LikeRepositoryProtocol {
    /// Add like to a catch
    func addLike(catchId: String, userId: String) async throws -> Like
    
    /// Remove like from a catch
    func removeLike(catchId: String, userId: String) async throws
    
    /// Check if user has liked a catch
    func hasUserLiked(catchId: String, userId: String) async throws -> Bool
    
    /// Get like count for a catch
    func getLikeCount(for catchId: String) async throws -> Int
    
    /// Get like info for multiple catches
    func getLikeInfo(for catchIds: [String], currentUserId: String) async throws -> [String: LikeInfo]
    
    /// Get all likes for a catch
    func getLikes(for catchId: String) async throws -> [Like]
    
    /// Toggle like (add if not liked, remove if liked)
    func toggleLike(catchId: String, userId: String) async throws -> Bool
}

/// Supabase implementation of LikeRepository
final class SupabaseLikeRepository: LikeRepositoryProtocol {
    private let supabase: SupabaseService
    
    init(supabase: SupabaseService) {
        self.supabase = supabase
    }
    
    func addLike(catchId: String, userId: String) async throws -> Like {
        let like = Like(
            catchId: catchId,
            userId: userId
        )
        
        return try await supabase.insertAndReturn(like, into: AppConstants.Supabase.Tables.likes)
    }
    
    func removeLike(catchId: String, userId: String) async throws {
        try await supabase.client
            .from(AppConstants.Supabase.Tables.likes)
            .delete()
            .eq("catch_id", value: catchId)
            .eq("user_id", value: userId)
            .execute()
    }
    
    func hasUserLiked(catchId: String, userId: String) async throws -> Bool {
        let likes: [Like] = try await supabase.client
            .from(AppConstants.Supabase.Tables.likes)
            .select()
            .eq("catch_id", value: catchId)
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        
        return !likes.isEmpty
    }
    
    func getLikeCount(for catchId: String) async throws -> Int {
        let likes: [Like] = try await supabase.client
            .from(AppConstants.Supabase.Tables.likes)
            .select()
            .eq("catch_id", value: catchId)
            .execute()
            .value
        
        return likes.count
    }
    
    func getLikeInfo(for catchIds: [String], currentUserId: String) async throws -> [String: LikeInfo] {
        guard !catchIds.isEmpty else { return [:] }
        
        // Get all likes for the given catches
        let likes: [Like] = try await supabase.client
            .from(AppConstants.Supabase.Tables.likes)
            .select()
            .in("catch_id", values: catchIds)
            .execute()
            .value
        
        // Build like info dictionary
        var likeInfo: [String: LikeInfo] = [:]
        
        for catchId in catchIds {
            let catchLikes = likes.filter { $0.catchId == catchId }
            let isLikedByCurrentUser = catchLikes.contains { $0.userId == currentUserId }
            
            likeInfo[catchId] = LikeInfo(
                catchId: catchId,
                totalCount: catchLikes.count,
                isLikedByCurrentUser: isLikedByCurrentUser
            )
        }
        
        return likeInfo
    }
    
    func getLikes(for catchId: String) async throws -> [Like] {
        try await supabase.client
            .from(AppConstants.Supabase.Tables.likes)
            .select()
            .eq("catch_id", value: catchId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }
    
    func toggleLike(catchId: String, userId: String) async throws -> Bool {
        let isLiked = try await hasUserLiked(catchId: catchId, userId: userId)
        
        if isLiked {
            try await removeLike(catchId: catchId, userId: userId)
            return false
        } else {
            _ = try await addLike(catchId: catchId, userId: userId)
            return true
        }
    }
}

