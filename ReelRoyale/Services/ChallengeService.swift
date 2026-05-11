import Foundation

/// Result of evaluating a fresh catch against a user's active challenges.
struct ChallengeEvaluationResult: Equatable {
    /// Newly-completed challenges (need reward grant).
    let completed: [Challenge]
    /// Challenges whose progress JSON changed but aren't done yet.
    let updated: [UserChallenge]

    static let empty = ChallengeEvaluationResult(completed: [], updated: [])
}

/// Server-truth context the evaluator needs to judge progress.
struct ChallengeContext {
    let userId: String
    let now: Date
    let fishCatch: FishCatch
    let spot: Spot
    let isNewKing: Bool
    /// Distinct spots fished today (to evaluate `visit_n_spots`).
    let distinctSpotsToday: Int
    /// Distinct territories fished this week (to evaluate `catch_in_n_territories`).
    let distinctTerritoriesThisWeek: Int
    /// Catches this week (to evaluate `catch_count_in_window`).
    let catchesInLast7Days: Int
    /// Days held king of any spot (to evaluate `hold_king_n_days`).
    let longestActiveKingStreakDays: Int
    /// True iff this is the first time the user has ever caught this species.
    let isFirstSpecies: Bool
}

protocol ChallengeServiceProtocol {
    /// Ensures today's daily and this week's weekly challenges exist for the user.
    func ensureAssignments(for userId: String) async throws
    /// Same as ensureAssignments but returns total count assigned (0 if already up-to-date).
    func assignedCount(for userId: String) async throws -> Int
    /// Returns currently active (today + this week) challenges with catalog metadata.
    func activeChallenges(for userId: String) async throws -> [UserChallengeWithDetails]
    /// Evaluates a fresh catch against all the user's active challenges. Persists
    /// progress + completion, and returns the deltas for UI/rewards.
    func evaluate(_ context: ChallengeContext) async throws -> ChallengeEvaluationResult
    /// Marks `rewarded = true`, used after the reward animation completes.
    func acknowledgeReward(for userChallengeId: String) async throws
}

final class ChallengeService: ChallengeServiceProtocol {
    private let challengeRepository: ChallengeRepositoryProtocol

    init(challengeRepository: ChallengeRepositoryProtocol) {
        self.challengeRepository = challengeRepository
    }

    func ensureAssignments(for userId: String) async throws {
        _ = try await assignedCount(for: userId)
    }

    func assignedCount(for userId: String) async throws -> Int {
        async let dailyTask = challengeRepository.assignDaily(forUser: userId)
        async let weeklyTask = challengeRepository.assignWeekly(forUser: userId)
        let (daily, weekly) = try await (dailyTask, weeklyTask)
        return daily + weekly
    }

    func activeChallenges(for userId: String) async throws -> [UserChallengeWithDetails] {
        try await ensureAssignments(for: userId)
        async let userRecords = challengeRepository.getActiveUserChallenges(forUser: userId)
        async let catalog = challengeRepository.getCatalog()
        let (records, allChallenges) = try await (userRecords, catalog)

        let challengeMap = Dictionary(uniqueKeysWithValues: allChallenges.map { ($0.id, $0) })

        return records.compactMap { record in
            guard let c = challengeMap[record.challengeId] else { return nil }
            return UserChallengeWithDetails(challenge: c, userRecord: record)
        }
    }

    func evaluate(_ context: ChallengeContext) async throws -> ChallengeEvaluationResult {
        let active = try await activeChallenges(for: context.userId)
        var completed: [Challenge] = []
        var updated: [UserChallenge] = []

        for entry in active where !entry.userRecord.completed {
            let (didComplete, newRecord) = applyContext(context, to: entry)
            if didComplete {
                completed.append(entry.challenge)
                try await challengeRepository.updateUserChallenge(newRecord)
            } else if newRecord != entry.userRecord {
                updated.append(newRecord)
                try await challengeRepository.updateUserChallenge(newRecord)
            }
        }

        return ChallengeEvaluationResult(completed: completed, updated: updated)
    }

    func acknowledgeReward(for userChallengeId: String) async throws {
        try await challengeRepository.markRewarded(id: userChallengeId)
    }

    // MARK: - Pure evaluation

    /// Pure function: given a context and a user-challenge, return updated record + whether it completed.
    /// Exposed `internal` so unit tests can drive it without a repository.
    func applyContext(_ context: ChallengeContext, to entry: UserChallengeWithDetails) -> (Bool, UserChallenge) {
        var record = entry.userRecord
        let challenge = entry.challenge
        var completedNow = false

        switch challenge.conditionType {
        case .catchAny:
            completedNow = true

        case .catchWeightOver:
            if let minKg = challenge.minWeightKg,
               let weight = XPCalculator.weightKg(sizeValue: context.fishCatch.sizeValue, sizeUnit: context.fishCatch.sizeUnit),
               weight >= minKg {
                completedNow = true
            }

        case .catchBeforeNoon:
            let hour = Calendar.current.component(.hour, from: context.fishCatch.createdAt)
            if hour < 12 { completedNow = true }

        case .visitNSpots:
            if let target = challenge.requiredCount, context.distinctSpotsToday >= target {
                completedNow = true
            } else {
                record.progress["spots_visited"] = .int(context.distinctSpotsToday)
            }

        case .catchAndRelease:
            if context.fishCatch.released { completedNow = true }

        case .catchSpeciesFirst:
            if context.isFirstSpecies { completedNow = true }

        case .becomeKing:
            if context.isNewKing { completedNow = true }

        case .catchCountInWindow:
            if let target = challenge.requiredCount, context.catchesInLast7Days >= target {
                completedNow = true
            } else {
                record.progress["catches"] = .int(context.catchesInLast7Days)
            }

        case .catchInNTerritories:
            if let target = challenge.requiredCount, context.distinctTerritoriesThisWeek >= target {
                completedNow = true
            } else {
                record.progress["territories"] = .int(context.distinctTerritoriesThisWeek)
            }

        case .holdKingNDays:
            if let target = challenge.requiredHoldDays, context.longestActiveKingStreakDays >= target {
                completedNow = true
            } else {
                record.progress["streak_days"] = .int(context.longestActiveKingStreakDays)
            }
        }

        if completedNow {
            record.completed = true
            record.completedAt = context.now
        }
        return (completedNow, record)
    }
}
