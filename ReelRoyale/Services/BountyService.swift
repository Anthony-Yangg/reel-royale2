import Foundation

protocol BountyServiceProtocol: AnyObject {
    func fetchActive(for userId: String?) async throws -> [Bounty]
    func fetchTodaysFeatured(for userId: String?) async throws -> Bounty?
}

final class SupabaseBountyService: BountyServiceProtocol {
    private let challengeService: ChallengeServiceProtocol
    private let challengeRepository: ChallengeRepositoryProtocol
    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        return cal
    }()

    init(
        challengeService: ChallengeServiceProtocol,
        challengeRepository: ChallengeRepositoryProtocol
    ) {
        self.challengeService = challengeService
        self.challengeRepository = challengeRepository
    }

    func fetchActive(for userId: String?) async throws -> [Bounty] {
        let challenges: [Challenge]
        if let userId, !userId.isEmpty {
            challenges = try await challengeService
                .activeChallenges(for: userId)
                .filter { !$0.userRecord.completed }
                .map(\.challenge)
        } else {
            challenges = try await challengeRepository.getCatalog()
        }

        return challenges
            .map(makeBounty)
            .sorted { lhs, rhs in
                if lhs.bountyType == rhs.bountyType {
                    return lhs.rewardGlory > rhs.rewardGlory
                }
                return lhs.bountyType.sortOrder < rhs.bountyType.sortOrder
            }
    }

    func fetchTodaysFeatured(for userId: String?) async throws -> Bounty? {
        let active = try await fetchActive(for: userId)
        return active.first(where: { $0.bountyType == .dailyChallenge }) ?? active.first
    }

    private func makeBounty(from challenge: Challenge) -> Bounty {
        let window = activeWindow(for: challenge.type)
        return Bounty(
            id: challenge.id,
            title: challenge.title,
            detail: challenge.description ?? challenge.conditionType.detailText,
            bountyType: challenge.type == .daily ? .dailyChallenge : .weeklyTournament,
            startsAt: window.start,
            endsAt: window.end,
            criteria: criteria(for: challenge),
            rewardDoubloons: challenge.coinReward,
            rewardGlory: challenge.xpReward,
            regionName: nil,
            iconSystemName: challenge.conditionType.iconSystemName
        )
    }

    private func activeWindow(for type: ChallengeType) -> (start: Date, end: Date) {
        let now = Date()
        switch type {
        case .daily:
            let start = calendar.startOfDay(for: now)
            return (start, calendar.date(byAdding: .day, value: 1, to: start) ?? now)
        case .weekly:
            let start = calendar.startOfWeek(for: now)
            return (start, calendar.date(byAdding: .day, value: 7, to: start) ?? now)
        }
    }

    private func criteria(for challenge: Challenge) -> String {
        switch challenge.conditionType {
        case .catchAny:
            return "Log 1 public catch"
        case .catchWeightOver:
            if let kg = challenge.minWeightKg {
                return "Catch over \(String(format: "%.1f", kg)) kg"
            }
            return "Beat the target weight"
        case .catchBeforeNoon:
            return "Log before noon"
        case .visitNSpots:
            return "Visit \(challenge.requiredCount ?? 2) spots"
        case .catchAndRelease:
            return "Catch and release"
        case .catchSpeciesFirst:
            return "Discover a new species"
        case .becomeKing:
            return "Take any crown"
        case .catchCountInWindow:
            return "Log \(challenge.requiredCount ?? 5) catches"
        case .catchInNTerritories:
            return "Fish \(challenge.requiredCount ?? 3) territories"
        case .holdKingNDays:
            return "Hold a crown \(challenge.requiredHoldDays ?? 3)d"
        }
    }
}

private extension BountyType {
    var sortOrder: Int {
        switch self {
        case .dailyChallenge: return 0
        case .weeklyTournament: return 1
        case .regionalBattle: return 2
        case .seasonalGoal: return 3
        }
    }
}

private extension ChallengeCondition {
    var iconSystemName: String {
        switch self {
        case .catchAny: return "fish.fill"
        case .catchWeightOver: return "scalemass.fill"
        case .catchBeforeNoon: return "sun.max.fill"
        case .visitNSpots: return "mappin.and.ellipse"
        case .catchAndRelease: return "arrow.triangle.2.circlepath"
        case .catchSpeciesFirst: return "sparkles"
        case .becomeKing: return "crown.fill"
        case .catchCountInWindow: return "checklist"
        case .catchInNTerritories: return "map.fill"
        case .holdKingNDays: return "shield.lefthalf.filled"
        }
    }

    var detailText: String {
        switch self {
        case .catchAny: return "Log a public catch to claim the reward."
        case .catchWeightOver: return "Bring in a heavyweight catch."
        case .catchBeforeNoon: return "Beat the daybreak clock."
        case .visitNSpots: return "Move between waters and keep the board alive."
        case .catchAndRelease: return "Release a catch after logging it."
        case .catchSpeciesFirst: return "Add a new species to your codex."
        case .becomeKing: return "Dethrone the current ruler of a spot."
        case .catchCountInWindow: return "Stack catches before the weekly reset."
        case .catchInNTerritories: return "Fish across multiple territories."
        case .holdKingNDays: return "Defend a crown across multiple days."
        }
    }
}

private extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        var cal = self
        cal.firstWeekday = 2
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: components) ?? date
    }
}
