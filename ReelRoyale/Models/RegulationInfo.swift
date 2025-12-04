import Foundation

/// Fishing regulation information
/// Maps to Supabase 'regulations' table
struct RegulationInfo: Identifiable, Codable, Equatable {
    let id: String
    var spotId: String?
    var territoryId: String?
    var regionName: String
    var title: String
    var content: String
    var seasonStart: Date?
    var seasonEnd: Date?
    var sizeLimits: [SpeciesSizeLimit]?
    var bagLimits: [SpeciesBagLimit]?
    var specialRules: [String]?
    var licenseRequired: Bool
    var licenseInfo: String?
    var sourceURL: String?
    var lastUpdated: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case spotId = "spot_id"
        case territoryId = "territory_id"
        case regionName = "region_name"
        case title
        case content
        case seasonStart = "season_start"
        case seasonEnd = "season_end"
        case sizeLimits = "size_limits"
        case bagLimits = "bag_limits"
        case specialRules = "special_rules"
        case licenseRequired = "license_required"
        case licenseInfo = "license_info"
        case sourceURL = "source_url"
        case lastUpdated = "last_updated"
    }
    
    init(
        id: String = UUID().uuidString,
        spotId: String? = nil,
        territoryId: String? = nil,
        regionName: String,
        title: String,
        content: String,
        seasonStart: Date? = nil,
        seasonEnd: Date? = nil,
        sizeLimits: [SpeciesSizeLimit]? = nil,
        bagLimits: [SpeciesBagLimit]? = nil,
        specialRules: [String]? = nil,
        licenseRequired: Bool = true,
        licenseInfo: String? = nil,
        sourceURL: String? = nil,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.spotId = spotId
        self.territoryId = territoryId
        self.regionName = regionName
        self.title = title
        self.content = content
        self.seasonStart = seasonStart
        self.seasonEnd = seasonEnd
        self.sizeLimits = sizeLimits
        self.bagLimits = bagLimits
        self.specialRules = specialRules
        self.licenseRequired = licenseRequired
        self.licenseInfo = licenseInfo
        self.sourceURL = sourceURL
        self.lastUpdated = lastUpdated
    }
    
    var isInSeason: Bool {
        let now = Date()
        if let start = seasonStart, let end = seasonEnd {
            return now >= start && now <= end
        }
        return true // No season restrictions
    }
}

/// Size limit for a specific species
struct SpeciesSizeLimit: Codable, Equatable, Identifiable {
    var id: String { species }
    let species: String
    let minSize: Double?
    let maxSize: Double?
    let unit: String
    
    var displayText: String {
        if let min = minSize, let max = maxSize {
            return "\(species): \(Int(min))-\(Int(max)) \(unit)"
        } else if let min = minSize {
            return "\(species): min \(Int(min)) \(unit)"
        } else if let max = maxSize {
            return "\(species): max \(Int(max)) \(unit)"
        }
        return "\(species): No size limit"
    }
}

/// Daily bag limit for a specific species
struct SpeciesBagLimit: Codable, Equatable, Identifiable {
    var id: String { species }
    let species: String
    let dailyLimit: Int
    let possessionLimit: Int?
    
    var displayText: String {
        if let possession = possessionLimit {
            return "\(species): \(dailyLimit)/day, \(possession) possession"
        }
        return "\(species): \(dailyLimit)/day"
    }
}

/// Fish species information for AI identification
struct FishSpecies: Identifiable, Codable, Equatable {
    let id: String
    let commonName: String
    let scientificName: String?
    let family: String?
    let description: String?
    let habitat: String?
    let imageURL: String?
    let averageSize: String?
    let recordSize: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case commonName = "common_name"
        case scientificName = "scientific_name"
        case family
        case description
        case habitat
        case imageURL = "image_url"
        case averageSize = "average_size"
        case recordSize = "record_size"
    }
}

/// Result from AI fish identification
struct FishIDResult: Equatable {
    let species: String
    let confidence: Double
    let alternativeSpecies: [(species: String, confidence: Double)]
    let timestamp: Date
    
    var confidencePercentage: String {
        "\(Int(round(confidence * 100)))%"
    }
    
    var isHighConfidence: Bool {
        confidence >= 0.8
    }
    
    static func == (lhs: FishIDResult, rhs: FishIDResult) -> Bool {
        lhs.species == rhs.species &&
        lhs.confidence == rhs.confidence &&
        lhs.timestamp == rhs.timestamp
    }
}

