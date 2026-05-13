import Foundation

protocol LeaderboardServiceProtocol: AnyObject {
    func fetchTop(scope: LeaderboardScope, timeframe: LeaderboardTimeframe, limit: Int) async throws -> [CaptainRankEntry]
    func fetchUserRank(userId: String, scope: LeaderboardScope, timeframe: LeaderboardTimeframe) async throws -> CaptainRankEntry?
}

final class SupabaseLeaderboardService: LeaderboardServiceProtocol {
    private let userRepository: UserRepositoryProtocol
    private let spotRepository: SpotRepositoryProtocol

    init(
        userRepository: UserRepositoryProtocol,
        spotRepository: SpotRepositoryProtocol
    ) {
        self.userRepository = userRepository
        self.spotRepository = spotRepository
    }

    func fetchTop(scope: LeaderboardScope, timeframe: LeaderboardTimeframe, limit: Int) async throws -> [CaptainRankEntry] {
        let users: [User]
        switch timeframe {
        case .season, .week:
            users = try await userRepository.getTopUsersBySeasonScore(limit: limit)
        case .allTime:
            users = try await userRepository.getTopUsersByXP(limit: limit)
        }

        let crowns = try await crownCounts()
        return users.enumerated().map { index, user in
            makeEntry(
                from: user,
                rank: index + 1,
                timeframe: timeframe,
                crownsHeld: crowns[user.id] ?? 0
            )
        }
    }

    func fetchUserRank(userId: String, scope: LeaderboardScope, timeframe: LeaderboardTimeframe) async throws -> CaptainRankEntry? {
        let fetchedUsers = try await userRepository.getAllUsers()
        let allUsers = fetchedUsers.sorted { lhs, rhs in
            score(for: lhs, timeframe: timeframe) > score(for: rhs, timeframe: timeframe)
        }

        guard let index = allUsers.firstIndex(where: { $0.id == userId }) else {
            return nil
        }

        let crowns = try await crownCounts()
        return makeEntry(
            from: allUsers[index],
            rank: index + 1,
            timeframe: timeframe,
            crownsHeld: crowns[userId] ?? 0
        )
    }

    private func crownCounts() async throws -> [String: Int] {
        let spots = try await spotRepository.getAllSpots()
        return spots.reduce(into: [String: Int]()) { counts, spot in
            if let userId = spot.currentKingUserId {
                counts[userId, default: 0] += 1
            }
        }
    }

    private func makeEntry(
        from user: User,
        rank: Int,
        timeframe: LeaderboardTimeframe,
        crownsHeld: Int
    ) -> CaptainRankEntry {
        CaptainRankEntry(
            id: user.id,
            rank: rank,
            captainName: user.username.isEmpty ? "Unnamed Captain" : user.username,
            avatarURL: user.avatarURL,
            tier: CaptainTier.from(rankTier: user.rankTier),
            division: division(for: user),
            doubloons: user.lureCoins,
            glory: score(for: user, timeframe: timeframe),
            crownsHeld: crownsHeld,
            weeklyDelta: 0
        )
    }

    private func score(for user: User, timeframe: LeaderboardTimeframe) -> Int {
        switch timeframe {
        case .season, .week:
            return user.seasonScore
        case .allTime:
            return user.xp
        }
    }

    private func division(for user: User) -> Int {
        guard let next = user.rankTier.nextTierXP else { return 1 }
        let span = max(next - user.rankTier.minXP, 1)
        let progressed = max(user.xp - user.rankTier.minXP, 0)
        let fraction = Double(progressed) / Double(span)
        if fraction >= 0.66 { return 1 }
        if fraction >= 0.33 { return 2 }
        return 3
    }
}
