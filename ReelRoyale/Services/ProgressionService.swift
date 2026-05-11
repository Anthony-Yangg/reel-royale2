import Foundation

/// Computes doubloons + glory earned for a catch event.
protocol ProgressionServiceProtocol: AnyObject {
    func computeReward(
        sizeCm: Double,
        isDethrone: Bool,
        isRareSpecies: Bool,
        isFirstAtSpot: Bool
    ) -> ProgressionReward
}

/// Reward bundle returned by ProgressionService.
struct ProgressionReward: Equatable {
    let doubloons: Int
    let glory: Int
    let breakdown: [String]   // human-readable lines, e.g. "Base catch: +50"
}

final class ProgressionService: ProgressionServiceProtocol {
    private let baseDoubloons = 50
    private let perCmDoubloons = 1.0
    private let rareSpeciesBonus = 100
    private let firstAtSpotBonus = 25
    private let dethroneBonus = 500
    private let gloryRatio = 0.2
    private let dethroneGloryBonus = 120

    func computeReward(
        sizeCm: Double,
        isDethrone: Bool,
        isRareSpecies: Bool,
        isFirstAtSpot: Bool
    ) -> ProgressionReward {
        var d = baseDoubloons
        var breakdown: [String] = ["Base catch: +\(baseDoubloons)🪙"]

        let sizeBonus = Int(sizeCm * perCmDoubloons)
        if sizeBonus > 0 {
            d += sizeBonus
            breakdown.append("Size (\(Int(sizeCm))cm): +\(sizeBonus)🪙")
        }
        if isRareSpecies {
            d += rareSpeciesBonus
            breakdown.append("Rare species: +\(rareSpeciesBonus)🪙")
        }
        if isFirstAtSpot {
            d += firstAtSpotBonus
            breakdown.append("New spot bonus: +\(firstAtSpotBonus)🪙")
        }
        if isDethrone {
            d += dethroneBonus
            breakdown.append("DETHRONE! +\(dethroneBonus)🪙")
        }

        var glory = Int(Double(d) * gloryRatio)
        if isDethrone {
            glory += dethroneGloryBonus
            breakdown.append("Dethrone glory: +\(dethroneGloryBonus)⚜️")
        }

        return ProgressionReward(doubloons: d, glory: glory, breakdown: breakdown)
    }
}
