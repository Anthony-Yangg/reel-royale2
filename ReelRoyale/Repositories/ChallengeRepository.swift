import Foundation

protocol ChallengeRepositoryProtocol {
    func getCatalog() async throws -> [Challenge]
    func getChallenges(byType type: ChallengeType) async throws -> [Challenge]
    func getUserChallenges(forUser userId: String, on date: Date) async throws -> [UserChallenge]
    func getActiveUserChallenges(forUser userId: String) async throws -> [UserChallenge]
    func updateUserChallenge(_ record: UserChallenge) async throws
    func markRewarded(id: String) async throws
    func assignDaily(forUser userId: String) async throws -> Int
    func assignWeekly(forUser userId: String) async throws -> Int
}

final class SupabaseChallengeRepository: ChallengeRepositoryProtocol {
    private let supabase: SupabaseService
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC") ?? .current
        return c
    }()
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    init(supabase: SupabaseService) {
        self.supabase = supabase
    }

    func getCatalog() async throws -> [Challenge] {
        try await supabase.database
            .from(AppConstants.Supabase.Tables.challenges)
            .select()
            .eq("is_active", value: true)
            .execute()
            .value
    }

    func getChallenges(byType type: ChallengeType) async throws -> [Challenge] {
        try await supabase.database
            .from(AppConstants.Supabase.Tables.challenges)
            .select()
            .eq("is_active", value: true)
            .eq("type", value: type.rawValue)
            .execute()
            .value
    }

    func getUserChallenges(forUser userId: String, on date: Date) async throws -> [UserChallenge] {
        let dateString = dateFormatter.string(from: date)
        return try await supabase.database
            .from(AppConstants.Supabase.Tables.userChallenges)
            .select()
            .eq("user_id", value: userId)
            .eq("assigned_date", value: dateString)
            .execute()
            .value
    }

    /// Today's daily + this week's weekly. Convenience for the challenges UI.
    func getActiveUserChallenges(forUser userId: String) async throws -> [UserChallenge] {
        let today = dateFormatter.string(from: Date())
        let weekStart = dateFormatter.string(from: calendar.startOfWeek(for: Date()))

        return try await supabase.database
            .from(AppConstants.Supabase.Tables.userChallenges)
            .select()
            .eq("user_id", value: userId)
            .in("assigned_date", values: [today, weekStart])
            .execute()
            .value
    }

    func updateUserChallenge(_ record: UserChallenge) async throws {
        struct UpdatePayload: Encodable {
            let progress: [String: AnyJSONValue]
            let completed: Bool
            let completed_at: Date?
        }
        let payload = UpdatePayload(
            progress: record.progress,
            completed: record.completed,
            completed_at: record.completedAt
        )
        try await supabase.database
            .from(AppConstants.Supabase.Tables.userChallenges)
            .update(payload)
            .eq("id", value: record.id)
            .execute()
    }

    func markRewarded(id: String) async throws {
        struct Payload: Encodable { let rewarded: Bool = true }
        try await supabase.database
            .from(AppConstants.Supabase.Tables.userChallenges)
            .update(Payload())
            .eq("id", value: id)
            .execute()
    }

    func assignDaily(forUser userId: String) async throws -> Int {
        struct Params: Encodable { let p_user_id: String }
        let count: Int = try await supabase.database
            .rpc(AppConstants.Supabase.RPC.assignDailyChallenges, params: Params(p_user_id: userId))
            .execute()
            .value
        return count
    }

    func assignWeekly(forUser userId: String) async throws -> Int {
        struct Params: Encodable { let p_user_id: String }
        let count: Int = try await supabase.database
            .rpc(AppConstants.Supabase.RPC.assignWeeklyChallenge, params: Params(p_user_id: userId))
            .execute()
            .value
        return count
    }
}

private extension Calendar {
    /// Monday-anchored start of week, matching Postgres `date_trunc('week', ...)`.
    func startOfWeek(for date: Date) -> Date {
        var c = self
        c.firstWeekday = 2 // Monday
        let components = c.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return c.date(from: components) ?? date
    }
}
