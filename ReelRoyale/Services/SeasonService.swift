import Foundation

protocol SeasonServiceProtocol {
    func getActiveSeason() async throws -> Season?
    func getSeasonLeaderboard(limit: Int) async throws -> [SeasonLeaderboardEntry]
    /// Finds where the user ranks on the global season leaderboard, or nil if unranked.
    func userStanding(userId: String) async throws -> Int?
    func getChampions(forSeason seasonId: String) async throws -> [SeasonChampion]
    func getChampions(forUser userId: String) async throws -> [SeasonChampion]
    /// Admin operation: ends current season, archives top 10 per territory,
    /// resets season scores, opens a new 30-day season. Idempotent in that
    /// re-running it just creates the next season number.
    func startNewSeason(lengthDays: Int) async throws -> Season?
}

final class SeasonService: SeasonServiceProtocol {
    private let seasonRepository: SeasonRepositoryProtocol
    private let userRepository: UserRepositoryProtocol

    init(seasonRepository: SeasonRepositoryProtocol, userRepository: UserRepositoryProtocol) {
        self.seasonRepository = seasonRepository
        self.userRepository = userRepository
    }

    func getActiveSeason() async throws -> Season? {
        try await seasonRepository.getActiveSeason()
    }

    func getSeasonLeaderboard(limit: Int = 50) async throws -> [SeasonLeaderboardEntry] {
        let topUsers = try await userRepository.getTopUsersBySeasonScore(limit: limit)
        return topUsers
            .filter { $0.seasonScore > 0 }
            .enumerated()
            .map { idx, user in
                SeasonLeaderboardEntry(rank: idx + 1, user: user, seasonScore: user.seasonScore)
            }
    }

    func userStanding(userId: String) async throws -> Int? {
        // Pull a wider window than the regular leaderboard to find the user's slot.
        let top = try await userRepository.getTopUsersBySeasonScore(limit: 500)
        guard let idx = top.firstIndex(where: { $0.id == userId }) else { return nil }
        return idx + 1
    }

    func getChampions(forSeason seasonId: String) async throws -> [SeasonChampion] {
        try await seasonRepository.getChampions(forSeason: seasonId)
    }

    func getChampions(forUser userId: String) async throws -> [SeasonChampion] {
        try await seasonRepository.getChampions(forUser: userId)
    }

    func startNewSeason(lengthDays: Int = 30) async throws -> Season? {
        let newId = try await seasonRepository.startNewSeason(lengthDays: lengthDays)
        return try await seasonRepository.getSeason(byId: newId)
    }
}
