import Foundation

protocol NotificationRepositoryProtocol {
    func getNotifications(forUser userId: String, limit: Int) async throws -> [AppNotification]
    func getUnreadCount(forUser userId: String) async throws -> Int
    func markRead(id: String) async throws
    func markAllRead(forUser userId: String) async throws
    func insert(_ notification: AppNotification) async throws
}

final class SupabaseNotificationRepository: NotificationRepositoryProtocol {
    private let supabase: SupabaseService

    init(supabase: SupabaseService) {
        self.supabase = supabase
    }

    func getNotifications(forUser userId: String, limit: Int = 50) async throws -> [AppNotification] {
        try await supabase.database
            .from(AppConstants.Supabase.Tables.notifications)
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func getUnreadCount(forUser userId: String) async throws -> Int {
        let unread: [AppNotification] = try await supabase.database
            .from(AppConstants.Supabase.Tables.notifications)
            .select()
            .eq("user_id", value: userId)
            .eq("read", value: false)
            .execute()
            .value
        return unread.count
    }

    func markRead(id: String) async throws {
        struct Payload: Encodable { let read: Bool = true }
        try await supabase.database
            .from(AppConstants.Supabase.Tables.notifications)
            .update(Payload())
            .eq("id", value: id)
            .execute()
    }

    func markAllRead(forUser userId: String) async throws {
        struct Payload: Encodable { let read: Bool = true }
        try await supabase.database
            .from(AppConstants.Supabase.Tables.notifications)
            .update(Payload())
            .eq("user_id", value: userId)
            .eq("read", value: false)
            .execute()
    }

    func insert(_ notification: AppNotification) async throws {
        try await supabase.insert(notification, into: AppConstants.Supabase.Tables.notifications)
    }
}
