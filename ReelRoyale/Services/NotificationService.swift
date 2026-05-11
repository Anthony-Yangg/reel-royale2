import Foundation
import UserNotifications

protocol NotificationServiceProtocol {
    func getRecent(forUser userId: String, limit: Int) async throws -> [AppNotification]
    func unreadCount(forUser userId: String) async throws -> Int
    func markRead(id: String) async throws
    func markAllRead(forUser userId: String) async throws
    /// Inserts an in-app notification for another user (e.g. when they failed to dethrone).
    func notifyDefendedSpot(previousChallengerId: String, spotId: String, spotName: String) async throws
    /// Local push for the current user, used when the server emits a dethrone event.
    func presentLocal(title: String, body: String, payload: [String: Any]?)
    /// Requests user permission for push. Idempotent.
    func requestAuthorization() async -> Bool
}

final class NotificationService: NotificationServiceProtocol {
    private let notificationRepository: NotificationRepositoryProtocol
    private let center: UNUserNotificationCenter

    init(
        notificationRepository: NotificationRepositoryProtocol,
        center: UNUserNotificationCenter = .current()
    ) {
        self.notificationRepository = notificationRepository
        self.center = center
    }

    func getRecent(forUser userId: String, limit: Int = 50) async throws -> [AppNotification] {
        try await notificationRepository.getNotifications(forUser: userId, limit: limit)
    }

    func unreadCount(forUser userId: String) async throws -> Int {
        try await notificationRepository.getUnreadCount(forUser: userId)
    }

    func markRead(id: String) async throws {
        try await notificationRepository.markRead(id: id)
    }

    func markAllRead(forUser userId: String) async throws {
        try await notificationRepository.markAllRead(forUser: userId)
    }

    func notifyDefendedSpot(previousChallengerId: String, spotId: String, spotName: String) async throws {
        // Build a notification record. The DB trigger handles dethroned;
        // defended is purely client-side because it requires GameService context.
        let payload: [String: AnyJSONValue] = [
            "spot_id": .string(spotId),
            "spot_name": .string(spotName)
        ]
        let record = AppNotification(
            id: UUID().uuidString,
            userId: previousChallengerId,
            type: .defended,
            title: "Spot defended",
            body: "Someone tried to take your crown at \(spotName) and failed. Your reign continues.",
            payload: payload,
            read: false,
            createdAt: Date()
        )
        try await notificationRepository.insert(record)
    }

    func presentLocal(title: String, body: String, payload: [String: Any]?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let payload {
            content.userInfo = payload
        }
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        )
        center.add(request, withCompletionHandler: nil)
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }
}
