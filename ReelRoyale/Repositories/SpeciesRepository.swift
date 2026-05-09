import Foundation

/// Read-mostly access to the species catalog and per-user codex.
protocol SpeciesRepositoryProtocol {
    func getAllSpecies() async throws -> [Species]
    func getSpecies(byId id: String) async throws -> Species?
    func getSpecies(byName name: String) async throws -> Species?
    func getCodex(forUser userId: String) async throws -> [UserSpecies]
    func getCodexEntries(forUser userId: String) async throws -> [CodexEntry]
}

final class SupabaseSpeciesRepository: SpeciesRepositoryProtocol {
    private let supabase: SupabaseService

    init(supabase: SupabaseService) {
        self.supabase = supabase
    }

    func getAllSpecies() async throws -> [Species] {
        try await supabase.database
            .from(AppConstants.Supabase.Tables.species)
            .select()
            .order("rarity_tier", ascending: true)
            .order("name", ascending: true)
            .execute()
            .value
    }

    func getSpecies(byId id: String) async throws -> Species? {
        try await supabase.fetchById(from: AppConstants.Supabase.Tables.species, id: id)
    }

    func getSpecies(byName name: String) async throws -> Species? {
        let results: [Species] = try await supabase.database
            .from(AppConstants.Supabase.Tables.species)
            .select()
            .ilike("name", pattern: name)
            .limit(1)
            .execute()
            .value
        return results.first
    }

    func getCodex(forUser userId: String) async throws -> [UserSpecies] {
        try await supabase.database
            .from(AppConstants.Supabase.Tables.userSpecies)
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
    }

    /// Joined view: every species in the catalog, paired with this user's
    /// record (or nil if undiscovered). Sorted: discovered first, then by rarity.
    func getCodexEntries(forUser userId: String) async throws -> [CodexEntry] {
        async let allSpecies = getAllSpecies()
        async let codex = getCodex(forUser: userId)
        let (species, records) = try await (allSpecies, codex)
        let recordsBySpeciesId = Dictionary(uniqueKeysWithValues: records.map { ($0.speciesId, $0) })

        return species.map { sp in
            CodexEntry(species: sp, userRecord: recordsBySpeciesId[sp.id])
        }.sorted { lhs, rhs in
            if lhs.isDiscovered != rhs.isDiscovered { return lhs.isDiscovered }
            if lhs.species.rarityTier != rhs.species.rarityTier {
                return lhs.species.rarityTier > rhs.species.rarityTier
            }
            return lhs.species.displayName < rhs.species.displayName
        }
    }
}
