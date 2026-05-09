import Foundation

protocol CodexServiceProtocol {
    func getCodex(for userId: String) async throws -> [CodexEntry]
    /// Total species discovered. Used in profile stats.
    func discoveryCount(for userId: String) async throws -> Int
    /// Returns the species record matching the given catch's species name (catalog lookup).
    func resolveSpecies(named name: String) async throws -> Species?
}

final class CodexService: CodexServiceProtocol {
    private let speciesRepository: SpeciesRepositoryProtocol

    init(speciesRepository: SpeciesRepositoryProtocol) {
        self.speciesRepository = speciesRepository
    }

    func getCodex(for userId: String) async throws -> [CodexEntry] {
        try await speciesRepository.getCodexEntries(forUser: userId)
    }

    func discoveryCount(for userId: String) async throws -> Int {
        let codex = try await speciesRepository.getCodex(forUser: userId)
        return codex.count
    }

    func resolveSpecies(named name: String) async throws -> Species? {
        try await speciesRepository.getSpecies(byName: name)
    }
}
