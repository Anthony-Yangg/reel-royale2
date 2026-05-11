import Foundation

protocol SeasonRepositoryProtocol {
    func getActiveSeason() async throws -> Season?
    func getAllSeasons() async throws -> [Season]
    func getSeason(byId id: String) async throws -> Season?
    func getChampions(forSeason seasonId: String) async throws -> [SeasonChampion]
    func getChampions(forUser userId: String) async throws -> [SeasonChampion]
    /// Calls Postgres RPC `start_new_season(length_days)`. Closes current,
    /// archives champions, resets season scores + spot kings, opens next.
    func startNewSeason(lengthDays: Int) async throws -> String
}

final class SupabaseSeasonRepository: SeasonRepositoryProtocol {
    private let supabase: SupabaseService

    init(supabase: SupabaseService) {
        self.supabase = supabase
    }

    func getActiveSeason() async throws -> Season? {
        let results: [Season] = try await supabase.database
            .from(AppConstants.Supabase.Tables.seasons)
            .select()
            .eq("is_active", value: true)
            .order("start_date", ascending: false)
            .limit(1)
            .execute()
            .value
        return results.first
    }

    func getAllSeasons() async throws -> [Season] {
        try await supabase.database
            .from(AppConstants.Supabase.Tables.seasons)
            .select()
            .order("season_number", ascending: false)
            .execute()
            .value
    }

    func getSeason(byId id: String) async throws -> Season? {
        try await supabase.fetchById(from: AppConstants.Supabase.Tables.seasons, id: id)
    }

    func getChampions(forSeason seasonId: String) async throws -> [SeasonChampion] {
        try await supabase.database
            .from(AppConstants.Supabase.Tables.seasonChampions)
            .select()
            .eq("season_id", value: seasonId)
            .order("rank", ascending: true)
            .execute()
            .value
    }

    func getChampions(forUser userId: String) async throws -> [SeasonChampion] {
        try await supabase.database
            .from(AppConstants.Supabase.Tables.seasonChampions)
            .select()
            .eq("user_id", value: userId)
            .order("awarded_at", ascending: false)
            .execute()
            .value
    }

    func startNewSeason(lengthDays: Int) async throws -> String {
        struct Params: Encodable { let p_length_days: Int }
        let result: String = try await supabase.database
            .rpc(AppConstants.Supabase.RPC.startNewSeason, params: Params(p_length_days: lengthDays))
            .execute()
            .value
        return result
    }
}
