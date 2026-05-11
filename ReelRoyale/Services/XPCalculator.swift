import Foundation

/// Bonus types used for the post-catch celebration screen.
enum XPBonus: String, Equatable, Hashable, CaseIterable {
    case firstSpecies        // +100, first time catching this species
    case catchAndRelease     // +50,  user marked the catch as released
    case dethrone            // +200, took crown from previous king
    case defended            // +75,  someone tried to take your spot and lost
    case dailyChallenge      // variable, completed a daily challenge
    case weeklyChallenge     // variable, completed a weekly challenge
    case streakDayOne        // +25 first catch of the day
    case newTerritory        // +50 first catch in a new territory
    case kingOfSpot          // +100 coin bonus when you become king

    var label: String {
        switch self {
        case .firstSpecies:     return "First Blood"
        case .catchAndRelease:  return "Conservation"
        case .dethrone:         return "Crown Taken"
        case .defended:         return "Spot Defended"
        case .dailyChallenge:   return "Daily Challenge"
        case .weeklyChallenge:  return "Weekly Challenge"
        case .streakDayOne:     return "First Catch Today"
        case .newTerritory:     return "New Territory"
        case .kingOfSpot:       return "King of the Hill"
        }
    }

    var icon: String {
        switch self {
        case .firstSpecies:     return "star.fill"
        case .catchAndRelease:  return "arrow.triangle.2.circlepath"
        case .dethrone:         return "crown.fill"
        case .defended:         return "shield.fill"
        case .dailyChallenge:   return "checkmark.circle.fill"
        case .weeklyChallenge:  return "checkmark.seal.fill"
        case .streakDayOne:     return "sun.max.fill"
        case .newTerritory:     return "map.fill"
        case .kingOfSpot:       return "crown"
        }
    }
}

/// One contributing line on the post-catch reward summary.
struct XPLineItem: Identifiable, Equatable, Hashable {
    let id = UUID()
    let label: String
    let xp: Int
    let coins: Int
    let bonus: XPBonus?
}

/// Full breakdown of a single catch's progression rewards.
struct XPBreakdown: Equatable {
    let baseXP: Int
    let speciesMultiplier: Double
    let bonusItems: [XPLineItem]
    let totalXP: Int
    let totalCoins: Int
    let firstSpecies: Bool
    let dethroned: Bool

    static let zero = XPBreakdown(
        baseXP: 0,
        speciesMultiplier: 1.0,
        bonusItems: [],
        totalXP: 0,
        totalCoins: 0,
        firstSpecies: false,
        dethroned: false
    )
}

/// Inputs needed for XP calculation. Pure data, no I/O.
struct XPInput {
    let weightKg: Double?              // nil if size was length-only
    let sizeUnit: String               // "kg", "lbs", "cm", "in"
    let species: Species?              // nil if species not in catalog
    let isReleased: Bool
    let isDethrone: Bool               // catch beat the previous king
    let previouslyHeldKing: Bool       // user already owned this spot
    let firstSpeciesForUser: Bool
    let firstCatchOfDay: Bool
    let firstCatchInTerritory: Bool
    let isPublic: Bool                 // private catches earn nothing
}

/// Computes XP and Lure Coin awards for a catch.
/// Must mirror the SQL trigger `update_spot_king()`. If you change one,
/// change both. The server is authoritative; client uses this for instant UI.
struct XPCalculator {

    /// Compute base XP from catch size.
    /// Weight catches: weight (g) / 10. Length-only: flat 100.
    static func baseXP(weightKg: Double?, sizeUnit: String) -> Int {
        guard let weightKg = weightKg, weightKg > 0 else { return 100 }
        return max(10, Int(floor(weightKg * 100.0))) // (weight_kg * 1000g) / 10 = weight_kg * 100
    }

    /// Convert size to kilograms if the unit is a weight unit, else nil.
    static func weightKg(sizeValue: Double, sizeUnit: String) -> Double? {
        switch sizeUnit.lowercased() {
        case "kg":  return sizeValue
        case "lbs": return sizeValue * 0.453_592
        default:    return nil
        }
    }

    /// Coin formula: 10 coins per 100 XP earned + flat bonuses.
    static func coinAward(totalXP: Int, dethroned: Bool, firstCatchOfDay: Bool, firstCatchInTerritory: Bool, holdingStreak7Days: Bool, season3SecondTopFinish: Bool = false) -> Int {
        var coins = (totalXP / 100) * 10
        if dethroned          { coins += 100 }
        if firstCatchOfDay    { coins += 25 }
        if firstCatchInTerritory { coins += 50 }
        if holdingStreak7Days { coins += 200 }
        return coins
    }

    /// Compute the full breakdown for a single catch.
    static func compute(input: XPInput) -> XPBreakdown {
        guard input.isPublic else {
            return .zero
        }

        let multiplier = input.species?.xpMultiplier ?? 1.0
        let base = baseXP(weightKg: input.weightKg, sizeUnit: input.sizeUnit)
        var lineItems: [XPLineItem] = []
        var bonusXP = 0

        if input.firstSpeciesForUser, input.species != nil {
            bonusXP += 100
            lineItems.append(.init(label: "First Blood", xp: 100, coins: 0, bonus: .firstSpecies))
        }
        if input.isReleased {
            bonusXP += 50
            lineItems.append(.init(label: "Catch & Release", xp: 50, coins: 0, bonus: .catchAndRelease))
        }
        if input.isDethrone {
            bonusXP += 200
            lineItems.append(.init(label: "Crown Taken", xp: 200, coins: 100, bonus: .dethrone))
        }

        let scaledBase = Int(floor(Double(base) * multiplier))
        let totalXP = scaledBase + bonusXP

        let coins = coinAward(
            totalXP: totalXP,
            dethroned: input.isDethrone,
            firstCatchOfDay: input.firstCatchOfDay,
            firstCatchInTerritory: input.firstCatchInTerritory,
            holdingStreak7Days: false
        )

        if input.firstCatchOfDay {
            lineItems.append(.init(label: "First Catch Today", xp: 0, coins: 25, bonus: .streakDayOne))
        }
        if input.firstCatchInTerritory {
            lineItems.append(.init(label: "New Territory", xp: 0, coins: 50, bonus: .newTerritory))
        }

        return XPBreakdown(
            baseXP: scaledBase,
            speciesMultiplier: multiplier,
            bonusItems: lineItems,
            totalXP: totalXP,
            totalCoins: coins,
            firstSpecies: input.firstSpeciesForUser,
            dethroned: input.isDethrone
        )
    }

    /// Return the new RankTier and XP-to-next, given prior + earned XP.
    static func rankAfter(priorXP: Int, gained: Int) -> (newRank: RankTier, leveledUp: Bool, xpToNext: Int?) {
        let oldRank = RankTier.from(xp: priorXP)
        let newXP = priorXP + gained
        let newRank = RankTier.from(xp: newXP)
        return (newRank, newRank > oldRank, newRank.xpToNext(currentXP: newXP))
    }
}
