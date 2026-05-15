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
        do {
            let species: [Species] = try await supabase.database
                .from(AppConstants.Supabase.Tables.species)
                .select()
                .order("created_at", ascending: true)
                .order("name", ascending: true)
                .execute()
                .value
            return mergedWithDefaultCatalog(species)
        } catch {
            return Species.defaultCatalog
        }
    }

    func getSpecies(byId id: String) async throws -> Species? {
        if let species: Species = try? await supabase.fetchById(from: AppConstants.Supabase.Tables.species, id: id) {
            return species
        }
        return Species.defaultCatalog.first { $0.id == id }
    }

    func getSpecies(byName name: String) async throws -> Species? {
        let lookup = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let results: [Species] = try? await supabase.database
            .from(AppConstants.Supabase.Tables.species)
            .select()
            .ilike("name", pattern: name)
            .limit(1)
            .execute()
            .value,
           let species = results.first {
            return species
        }
        return Species.defaultCatalog.first {
            $0.name.lowercased() == lookup || $0.commonName?.lowercased() == lookup
        }
    }

    func getCodex(forUser userId: String) async throws -> [UserSpecies] {
        do {
            return try await supabase.database
                .from(AppConstants.Supabase.Tables.userSpecies)
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
        } catch {
            return []
        }
    }

    /// Joined view: only species this user has actually discovered.
    /// The full FishBase catalog stays available for lookup, but Fish Log does
    /// not materialize thousands of locked rows.
    func getCodexEntries(forUser userId: String) async throws -> [CodexEntry] {
        let records = (try? await getCodex(forUser: userId)) ?? []
        guard !records.isEmpty else { return [] }

        var entries: [CodexEntry] = []
        entries.reserveCapacity(records.count)

        for record in records {
            guard let species = try? await getPersistedSpecies(byId: record.speciesId) else { continue }
            entries.append(CodexEntry(species: species, userRecord: record))
        }

        return entries.sorted { lhs, rhs in
            if lhs.species.createdAt != rhs.species.createdAt {
                return lhs.species.createdAt < rhs.species.createdAt
            }
            return lhs.species.displayName < rhs.species.displayName
        }
    }

    private func getPersistedSpecies(byId id: String) async throws -> Species? {
        try? await supabase.fetchById(from: AppConstants.Supabase.Tables.species, id: id)
    }

    private func mergedWithDefaultCatalog(_ remoteSpecies: [Species]) -> [Species] {
        guard !remoteSpecies.isEmpty else { return Species.defaultCatalog }

        let remoteNames = Set(remoteSpecies.flatMap { species in
            [
                normalizedSpeciesName(species.name),
                normalizedSpeciesName(species.displayName)
            ]
        })

        let missingDefaults = Species.defaultCatalog.filter { species in
            !remoteNames.contains(normalizedSpeciesName(species.name)) &&
            !remoteNames.contains(normalizedSpeciesName(species.displayName))
        }

        return remoteSpecies + missingDefaults
    }

    private func normalizedSpeciesName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
