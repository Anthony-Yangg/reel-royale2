import Foundation

/// Rarity tier controls XP multiplier and codex visualization.
/// Mirrors the `rarity_tier` CHECK on the species table.
enum FishRarity: String, Codable, CaseIterable, Identifiable, Comparable {
    case common
    case uncommon
    case rare
    case trophy

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var xpMultiplier: Double {
        switch self {
        case .common: return 1.0
        case .uncommon: return 1.5
        case .rare: return 2.5
        case .trophy: return 5.0
        }
    }

    /// Sort order - higher tier sorts first.
    private var rank: Int {
        switch self {
        case .common: return 0
        case .uncommon: return 1
        case .rare: return 2
        case .trophy: return 3
        }
    }

    static func < (lhs: FishRarity, rhs: FishRarity) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// Species reference data (catalog).
/// Maps to Supabase 'species' table. Read-mostly.
struct Species: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var name: String
    var commonName: String?
    var rarityTier: FishRarity
    var xpMultiplier: Double
    var description: String?
    var habitat: String?
    var averageSize: Double?
    var family: String?
    var imageURL: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case commonName = "common_name"
        case rarityTier = "rarity_tier"
        case xpMultiplier = "xp_multiplier"
        case description
        case habitat
        case averageSize = "average_size"
        case family
        case imageURL = "image_url"
        case createdAt = "created_at"
    }

    var displayName: String { commonName ?? name }
}

extension Species {
    /// Built-in catalog used when the remote `species` table has not been fully seeded yet.
    /// These are real fish slots, not user progress. A user's `user_species` rows and
    /// catches still decide which slots unlock and turn from grayscale to color.
    static let defaultCatalog: [Species] = {
        BundledFishCatalog.load() ?? curatedFallbackCatalog
    }()

    private static let curatedFallbackCatalog: [Species] = {
        struct Seed {
            let name: String
            let rarity: FishRarity
            let habitat: String
            let family: String
            let averageSize: Double
        }

        func s(_ name: String, _ rarity: FishRarity, _ habitat: String, _ family: String, _ averageSize: Double) -> Seed {
            Seed(name: name, rarity: rarity, habitat: habitat, family: family, averageSize: averageSize)
        }

        let seeds: [Seed] = [
            s("Largemouth Bass", .common, "Freshwater lakes, ponds, and slow rivers", "Black Bass", 16),
            s("Smallmouth Bass", .common, "Clear rivers, rocky lakes, and reservoirs", "Black Bass", 15),
            s("Spotted Bass", .common, "Warm reservoirs, rivers, and rocky points", "Black Bass", 14),
            s("Guadalupe Bass", .rare, "Clear Texas hill country rivers", "Black Bass", 12),
            s("Shoal Bass", .rare, "Rocky shoals and fast southern rivers", "Black Bass", 15),
            s("Rock Bass", .common, "Rocky creeks, lakes, and shaded rivers", "Sunfish", 8),
            s("White Bass", .common, "Reservoirs, open water, and river runs", "Temperate Bass", 13),
            s("Yellow Bass", .common, "Warm lowland rivers, lakes, and backwaters", "Temperate Bass", 9),
            s("Striped Bass", .uncommon, "Coastal bays, rivers, and reservoirs", "Temperate Bass", 28),
            s("Hybrid Striped Bass", .uncommon, "Reservoirs, tailwaters, and open lake schools", "Temperate Bass", 22),
            s("Peacock Bass", .rare, "Warm canals, lagoons, and tropical freshwater", "Cichlid", 19),
            s("Bluegill", .common, "Ponds, lakes, docks, and weed edges", "Sunfish", 7),
            s("Redear Sunfish", .common, "Warm lakes, shell beds, and quiet ponds", "Sunfish", 9),
            s("Green Sunfish", .common, "Creeks, ponds, and shallow cover", "Sunfish", 6),
            s("Pumpkinseed", .common, "Vegetated lakes, ponds, and slow streams", "Sunfish", 6),
            s("Warmouth", .common, "Swamps, backwaters, and brushy ponds", "Sunfish", 8),
            s("Longear Sunfish", .common, "Clear streams, rocky runs, and small rivers", "Sunfish", 5),
            s("Redbreast Sunfish", .common, "Warm creeks, rivers, and sandy runs", "Sunfish", 6),
            s("Black Crappie", .common, "Brush piles, docks, and quiet lake coves", "Sunfish", 10),
            s("White Crappie", .common, "Reservoirs, timber, brush, and quiet water", "Sunfish", 10),
            s("Yellow Perch", .common, "Cool lakes, weed beds, and sandy flats", "Perch", 9),
            s("White Perch", .common, "Brackish rivers, reservoirs, and coastal ponds", "Temperate Bass", 9),
            s("Walleye", .uncommon, "Cool lakes, reservoirs, and larger rivers", "Perch", 20),
            s("Sauger", .uncommon, "Turbid rivers, tailwaters, and current seams", "Perch", 16),
            s("Saugeye", .uncommon, "Stocked reservoirs and turbid lake flats", "Perch", 18),
            s("Northern Pike", .rare, "Weedy lakes, bays, and slow northern rivers", "Pike", 26),
            s("Muskellunge", .trophy, "Large northern lakes and river systems", "Pike", 42),
            s("Tiger Muskie", .trophy, "Stocked lakes, weed edges, and reservoirs", "Pike", 38),
            s("Chain Pickerel", .uncommon, "Weedy ponds, swamps, and slow creeks", "Pike", 20),
            s("Grass Pickerel", .rare, "Small vegetated streams and marshy ponds", "Pike", 12),
            s("Rainbow Trout", .common, "Cold rivers, streams, and stocked lakes", "Trout", 14),
            s("Brown Trout", .uncommon, "Cold streams, tailwaters, and deep lakes", "Trout", 18),
            s("Brook Trout", .uncommon, "Cold creeks, spring ponds, and mountain streams", "Trout", 11),
            s("Lake Trout", .rare, "Deep cold lakes and northern reservoirs", "Trout", 28),
            s("Cutthroat Trout", .rare, "Cold western rivers, alpine lakes, and creeks", "Trout", 16),
            s("Golden Trout", .trophy, "High alpine lakes and cold mountain streams", "Trout", 10),
            s("Tiger Trout", .rare, "Cold stocked waters and spring-fed lakes", "Trout", 15),
            s("Bull Trout", .trophy, "Cold wild rivers and mountain lakes", "Trout", 25),
            s("Dolly Varden", .rare, "Cold coastal streams and northern lakes", "Char", 18),
            s("Arctic Char", .rare, "Arctic lakes, rivers, and cold coastal water", "Char", 22),
            s("Arctic Grayling", .rare, "Cold northern rivers, clear creeks, and tundra lakes", "Grayling", 14),
            s("King Salmon", .trophy, "Pacific coastal rivers and open water", "Salmon", 34),
            s("Coho Salmon", .rare, "Pacific coastal rivers, bays, and nearshore water", "Salmon", 26),
            s("Sockeye Salmon", .rare, "Cold lakes, rivers, and Pacific coastal water", "Salmon", 24),
            s("Chum Salmon", .uncommon, "Pacific coastal rivers and estuaries", "Salmon", 25),
            s("Pink Salmon", .common, "Pacific coastal rivers and nearshore schools", "Salmon", 20),
            s("Atlantic Salmon", .trophy, "Cold Atlantic rivers and coastal water", "Salmon", 30),
            s("Kokanee Salmon", .uncommon, "Deep cold lakes and reservoir schools", "Salmon", 14),
            s("Steelhead", .rare, "Coastal rivers and cold tributaries", "Trout", 25),
            s("Channel Catfish", .common, "Warm rivers, reservoirs, and farm ponds", "Catfish", 22),
            s("Blue Catfish", .rare, "Large rivers, reservoirs, and deep channels", "Catfish", 34),
            s("Flathead Catfish", .rare, "Deep river holes, timber, and reservoirs", "Catfish", 30),
            s("White Catfish", .common, "Brackish rivers, ponds, and warm reservoirs", "Catfish", 14),
            s("Black Bullhead", .common, "Muddy ponds, ditches, and backwaters", "Catfish", 10),
            s("Brown Bullhead", .common, "Warm ponds, lakes, and slow rivers", "Catfish", 11),
            s("Yellow Bullhead", .common, "Weedy ponds, backwaters, and quiet creeks", "Catfish", 11),
            s("Common Carp", .common, "Warm lakes, canals, and slow rivers", "Carp", 24),
            s("Grass Carp", .uncommon, "Vegetated ponds, reservoirs, and canals", "Carp", 30),
            s("Silver Carp", .uncommon, "Large rivers, backwaters, and reservoirs", "Carp", 28),
            s("Bighead Carp", .rare, "Large lowland rivers and reservoirs", "Carp", 34),
            s("Mirror Carp", .rare, "Warm lakes, park ponds, and canals", "Carp", 26),
            s("Bigmouth Buffalo", .uncommon, "Large rivers, reservoirs, and backwaters", "Buffalo", 24),
            s("Smallmouth Buffalo", .uncommon, "Muddy rivers, oxbows, and reservoirs", "Buffalo", 22),
            s("Black Buffalo", .rare, "Large rivers and deep current breaks", "Buffalo", 28),
            s("Freshwater Drum", .common, "Large lakes, rivers, and rocky flats", "Drum", 18),
            s("Bowfin", .uncommon, "Swamps, weed beds, and slow backwaters", "Bowfin", 24),
            s("Longnose Gar", .uncommon, "Clear rivers, lakes, and backwaters", "Gar", 32),
            s("Shortnose Gar", .uncommon, "Big rivers, oxbows, and quiet sloughs", "Gar", 24),
            s("Spotted Gar", .rare, "Vegetated backwaters, bayous, and clear pools", "Gar", 28),
            s("Alligator Gar", .trophy, "Large southern rivers, reservoirs, and bayous", "Gar", 72),
            s("Paddlefish", .trophy, "Large rivers, reservoirs, and deep channels", "Paddlefish", 42),
            s("Lake Sturgeon", .trophy, "Large cold lakes and deep river channels", "Sturgeon", 52),
            s("White Sturgeon", .trophy, "Pacific rivers, estuaries, and deep channels", "Sturgeon", 72),
            s("Green Sturgeon", .trophy, "Pacific coastal rivers and estuaries", "Sturgeon", 60),
            s("American Eel", .rare, "Coastal rivers, estuaries, and muddy creeks", "Eel", 24),
            s("Burbot", .rare, "Deep cold lakes and northern river pools", "Cod", 24),
            s("Snakehead", .rare, "Warm canals, backwaters, and vegetated shallows", "Snakehead", 24),
            s("Tilapia", .common, "Warm ponds, canals, and urban lakes", "Cichlid", 12),
            s("Oscar", .uncommon, "Warm canals, ponds, and tropical freshwater", "Cichlid", 11),
            s("Freshwater Peacock Bass", .rare, "Tropical canals, lagoons, and warm reservoirs", "Cichlid", 20),
            s("Redfish", .uncommon, "Saltwater flats, marshes, and coastal bays", "Drum", 27),
            s("Speckled Trout", .uncommon, "Grass flats, marshes, and coastal bays", "Drum", 19),
            s("Black Drum", .uncommon, "Bays, bridge pilings, oyster bars, and surf", "Drum", 28),
            s("Weakfish", .uncommon, "Atlantic estuaries, beaches, and tidal creeks", "Drum", 20),
            s("Atlantic Croaker", .common, "Sandy bays, surf, and muddy channels", "Drum", 12),
            s("Spot", .common, "Atlantic surf, estuaries, and tidal rivers", "Drum", 9),
            s("Sheepshead", .uncommon, "Jetties, docks, reefs, and bridge pilings", "Porgy", 16),
            s("Pinfish", .common, "Grass flats, docks, and shallow bays", "Porgy", 7),
            s("Spadefish", .uncommon, "Reefs, buoys, wrecks, and nearshore structure", "Spadefish", 16),
            s("Flounder", .uncommon, "Sandy bottoms, channels, and coastal inlets", "Flatfish", 18),
            s("Summer Flounder", .uncommon, "Atlantic bays, channels, and sandy flats", "Flatfish", 19),
            s("Gulf Flounder", .uncommon, "Gulf bays, sandy passes, and nearshore reefs", "Flatfish", 16),
            s("California Halibut", .rare, "Pacific sandy beaches, bays, and kelp edges", "Flatfish", 28),
            s("Halibut", .trophy, "Cold ocean shelves and deep sandy bottoms", "Flatfish", 40),
            s("Snook", .rare, "Mangroves, inlets, beaches, and warm estuaries", "Snook", 28),
            s("Tarpon", .trophy, "Warm coastal flats, passes, and back bays", "Tarpon", 60),
            s("Bonefish", .rare, "Tropical saltwater flats and sandy shallows", "Bonefish", 22),
            s("Permit", .trophy, "Tropical flats, channels, and nearshore wrecks", "Permit", 26),
            s("Florida Pompano", .uncommon, "Surf troughs, sandy beaches, and passes", "Jack", 13),
            s("Jack Crevalle", .uncommon, "Bays, beaches, jetties, and nearshore schools", "Jack", 25),
            s("African Pompano", .rare, "Deep reefs, wrecks, and offshore structure", "Jack", 30),
            s("Giant Trevally", .trophy, "Tropical reefs, lagoons, and surf edges", "Jack", 44),
            s("Bluefish", .uncommon, "Surf, inlets, bays, and nearshore schools", "Bluefish", 22),
            s("Ladyfish", .common, "Warm bays, flats, and sandy shorelines", "Ladyfish", 20),
            s("Spanish Mackerel", .uncommon, "Nearshore reefs, beaches, and bait schools", "Mackerel", 22),
            s("King Mackerel", .rare, "Coastal reefs, ledges, and offshore bait schools", "Mackerel", 38),
            s("Cero Mackerel", .uncommon, "Tropical reefs, channels, and clear flats", "Mackerel", 20),
            s("Cobia", .rare, "Buoys, rays, wrecks, and nearshore structure", "Cobia", 36),
            s("Tripletail", .rare, "Floating debris, crab traps, and coastal markers", "Tripletail", 22),
            s("Great Barracuda", .rare, "Tropical reefs, flats, and bluewater edges", "Barracuda", 36),
            s("Mangrove Snapper", .uncommon, "Mangroves, docks, reefs, and wrecks", "Snapper", 16),
            s("Red Snapper", .rare, "Offshore reefs, wrecks, and hard bottom", "Snapper", 24),
            s("Yellowtail Snapper", .uncommon, "Tropical reefs, wrecks, and clear current", "Snapper", 18),
            s("Mutton Snapper", .rare, "Reefs, wrecks, and sandy reef edges", "Snapper", 24),
            s("Lane Snapper", .common, "Reefs, grass edges, and sandy bottom", "Snapper", 12),
            s("Vermilion Snapper", .uncommon, "Deep reefs and offshore ledges", "Snapper", 14),
            s("Cubera Snapper", .trophy, "Tropical reefs, wrecks, and deep ledges", "Snapper", 40),
            s("Schoolmaster Snapper", .common, "Mangroves, reefs, and shallow tropical structure", "Snapper", 12),
            s("Dog Snapper", .rare, "Tropical reefs, mangroves, and rocky drop-offs", "Snapper", 22),
            s("Gag Grouper", .rare, "Offshore reefs, wrecks, and rocky ledges", "Grouper", 28),
            s("Black Grouper", .rare, "Tropical reefs, wrecks, and ledges", "Grouper", 32),
            s("Red Grouper", .uncommon, "Gulf reefs, live bottom, and offshore ledges", "Grouper", 24),
            s("Scamp Grouper", .rare, "Deep reefs, ledges, and offshore hard bottom", "Grouper", 24),
            s("Snowy Grouper", .rare, "Deep offshore reefs and continental shelf edges", "Grouper", 30),
            s("Goliath Grouper", .trophy, "Reefs, wrecks, bridges, and tropical structure", "Grouper", 70),
            s("Nassau Grouper", .trophy, "Caribbean reefs, ledges, and coral heads", "Grouper", 36),
            s("Hogfish", .uncommon, "Reefs, sandy patches, and coral rubble", "Wrasse", 18),
            s("Gray Triggerfish", .uncommon, "Reefs, wrecks, and offshore hard bottom", "Triggerfish", 15),
            s("Queen Triggerfish", .rare, "Tropical reefs and coral structure", "Triggerfish", 18),
            s("Golden Tilefish", .rare, "Deep mud slopes and offshore canyon edges", "Tilefish", 30),
            s("Blueline Tilefish", .uncommon, "Deep reefs, ledges, and muddy bottom", "Tilefish", 22),
            s("Amberjack", .rare, "Deep wrecks, reefs, and offshore towers", "Jack", 38),
            s("Almaco Jack", .uncommon, "Deep reefs, wrecks, and offshore structure", "Jack", 24),
            s("Mahi Mahi", .rare, "Warm offshore water, weed lines, and floating structure", "Dolphinfish", 35),
            s("Wahoo", .trophy, "Warm offshore ledges, current edges, and bluewater", "Mackerel", 48),
            s("Blackfin Tuna", .rare, "Warm offshore schools, reefs, and current edges", "Tuna", 28),
            s("Yellowfin Tuna", .trophy, "Warm offshore blue water and current edges", "Tuna", 48),
            s("Bluefin Tuna", .trophy, "Cold bluewater, offshore banks, and bait schools", "Tuna", 70),
            s("Albacore Tuna", .rare, "Open ocean temperature breaks and offshore schools", "Tuna", 34),
            s("Bigeye Tuna", .trophy, "Deep offshore water, canyons, and night schools", "Tuna", 55),
            s("Skipjack Tuna", .uncommon, "Warm offshore schools and surface bait", "Tuna", 24),
            s("Swordfish", .trophy, "Deep offshore canyons, slopes, and bluewater", "Billfish", 70),
            s("Sailfish", .trophy, "Warm bluewater, current edges, and bait schools", "Billfish", 66),
            s("Blue Marlin", .trophy, "Tropical offshore bluewater and deep ledges", "Billfish", 96),
            s("White Marlin", .trophy, "Atlantic offshore canyons and warm current edges", "Billfish", 66),
            s("Black Marlin", .trophy, "Indo-Pacific reefs, bluewater, and current edges", "Billfish", 100),
            s("Striped Marlin", .trophy, "Pacific bluewater, banks, and temperature breaks", "Billfish", 84),
            s("Atlantic Cod", .uncommon, "Cold reefs, wrecks, and offshore banks", "Cod", 24),
            s("Pacific Cod", .uncommon, "Cold Pacific shelves, reefs, and deep flats", "Cod", 24),
            s("Haddock", .common, "Cold offshore banks and gravel bottom", "Cod", 20),
            s("Pollock", .common, "Cold Atlantic ledges, kelp, and offshore schools", "Cod", 24),
            s("Lingcod", .rare, "Pacific reefs, rocky pinnacles, and kelp edges", "Greenling", 32),
            s("Cabezon", .uncommon, "Pacific kelp, reefs, and rocky bottom", "Sculpin", 18),
            s("Kelp Greenling", .common, "Pacific kelp beds, reefs, and rocky shorelines", "Greenling", 14),
            s("Black Rockfish", .common, "Pacific reefs, kelp edges, and rocky points", "Rockfish", 18),
            s("Yelloweye Rockfish", .trophy, "Deep Pacific reefs and rocky ledges", "Rockfish", 28),
            s("Canary Rockfish", .rare, "Pacific offshore reefs and rocky slopes", "Rockfish", 22),
            s("Vermilion Rockfish", .rare, "Deep Pacific reefs and hard bottom", "Rockfish", 22),
            s("Bocaccio Rockfish", .uncommon, "Pacific reefs, kelp, and deep slopes", "Rockfish", 20),
            s("Black Sea Bass", .uncommon, "Atlantic wrecks, reefs, and hard bottom", "Sea Bass", 16),
            s("Giant Sea Bass", .trophy, "Pacific kelp forests, reefs, and deep structure", "Sea Bass", 72),
            s("White Seabass", .rare, "Pacific kelp beds, islands, and sandy edges", "Croaker", 42),
            s("California Yellowtail", .rare, "Pacific kelp, islands, and offshore schools", "Jack", 36),
            s("Kelp Bass", .common, "Pacific kelp forests, reefs, and harbors", "Sea Bass", 14),
            s("Barred Sand Bass", .common, "Pacific sandy flats, harbors, and reefs", "Sea Bass", 14),
            s("Spotted Bay Bass", .common, "Pacific bays, eelgrass, and docks", "Sea Bass", 11),
            s("Surfperch", .common, "Pacific surf zones, beaches, and rocky shorelines", "Surfperch", 10),
            s("Opaleye", .common, "Pacific rocky shorelines, kelp, and harbors", "Chub", 12),
            s("Sheephead", .uncommon, "Pacific reefs, kelp forests, and rocky islands", "Wrasse", 22),
            s("Roosterfish", .trophy, "Pacific surf edges, rocky points, and bait schools", "Jack", 44),
            s("Cubera Jack", .rare, "Tropical reefs, rocky points, and coastal drop-offs", "Jack", 32),
            s("Arapaima", .trophy, "Amazon floodplains, oxbows, and jungle lagoons", "Arapaima", 80),
            s("Golden Dorado", .trophy, "South American rivers, rapids, and current seams", "Dorado", 28),
            s("Payara", .trophy, "Amazon rivers, rapids, and deep current breaks", "Payara", 32),
            s("Pacu", .rare, "Tropical rivers, floodplains, and jungle lagoons", "Pacu", 24),
            s("Red-Bellied Piranha", .rare, "Amazon rivers, lagoons, and backwaters", "Piranha", 12),
            s("Nile Perch", .trophy, "African lakes, river mouths, and deep channels", "Perch", 60),
            s("Tigerfish", .trophy, "African rivers, rapids, and clear current", "Tigerfish", 30),
            s("Barramundi", .trophy, "Tropical estuaries, rivers, and mangroves", "Perch", 36),
            s("Murray Cod", .trophy, "Australian rivers, snags, and deep pools", "Cod", 42),
            s("Giant Snakehead", .trophy, "Tropical rivers, lakes, and flooded forests", "Snakehead", 34),
            s("Siamese Carp", .trophy, "Large Asian rivers and reservoirs", "Carp", 48),
            s("Mekong Giant Catfish", .trophy, "Large Mekong River channels and deep pools", "Catfish", 72),
            s("Taimen", .trophy, "Cold Siberian rivers and remote mountain streams", "Salmon", 48),
            s("Golden Mahseer", .trophy, "Fast Himalayan rivers and rocky pools", "Carp", 34),
            s("Goonch Catfish", .trophy, "Deep Asian river pools and rocky current", "Catfish", 54),
            s("Clown Knife Fish", .rare, "Warm canals, slow rivers, and tropical lakes", "Knife Fish", 24),
            s("Oscar Fish", .uncommon, "Tropical canals, ponds, and slow rivers", "Cichlid", 12),
            s("Arowana", .trophy, "Tropical rivers, flooded forests, and jungle channels", "Arowana", 30),
            s("Giant Gourami", .rare, "Tropical lakes, canals, and slow rivers", "Gourami", 22),
            s("Clown Triggerfish", .rare, "Tropical reefs and coral lagoons", "Triggerfish", 16),
            s("Parrotfish", .uncommon, "Coral reefs, lagoons, and tropical flats", "Parrotfish", 18),
            s("Napoleon Wrasse", .trophy, "Indo-Pacific reefs, drop-offs, and coral slopes", "Wrasse", 60),
            s("Queen Angelfish", .rare, "Caribbean reefs, coral heads, and ledges", "Angelfish", 14),
            s("French Angelfish", .rare, "Tropical reefs, wrecks, and coral walls", "Angelfish", 14),
            s("Blue Tang", .common, "Tropical reefs, coral gardens, and clear lagoons", "Surgeonfish", 10),
            s("Yellow Tang", .common, "Pacific reefs, coral slopes, and clear lagoons", "Surgeonfish", 8),
            s("Clownfish", .common, "Coral reefs and anemone gardens", "Damselfish", 4),
            s("Lionfish", .uncommon, "Reefs, wrecks, and tropical ledges", "Scorpionfish", 13),
            s("Moray Eel", .rare, "Reefs, caves, and rocky tropical structure", "Eel", 36),
            s("Needlefish", .common, "Warm flats, bays, and surface schools", "Needlefish", 24),
            s("Flying Fish", .common, "Warm offshore surface water and bluewater edges", "Flying Fish", 12),
            s("Atlantic Herring", .common, "Cold coastal schools and offshore banks", "Herring", 10),
            s("Pacific Herring", .common, "Pacific bays, kelp edges, and nearshore schools", "Herring", 10),
            s("American Shad", .uncommon, "Atlantic rivers, estuaries, and spring runs", "Herring", 18),
            s("Gizzard Shad", .common, "Lakes, reservoirs, and slow rivers", "Herring", 12),
            s("Threadfin Shad", .common, "Reservoirs, open water, and warm schools", "Herring", 6),
            s("Anchovy", .common, "Coastal schools, bays, and bait balls", "Anchovy", 5),
            s("Sardine", .common, "Coastal schools and offshore bait balls", "Herring", 8),
            s("Atlantic Mackerel", .common, "Cold coastal schools and offshore water", "Mackerel", 14),
            s("Pacific Mackerel", .common, "Pacific piers, bays, and nearshore schools", "Mackerel", 14),
            s("Bonito", .uncommon, "Nearshore reefs, kelp, and fast bait schools", "Tuna", 20),
            s("Little Tunny", .uncommon, "Atlantic beaches, inlets, and offshore bait schools", "Tuna", 24),
            s("Barracuda", .rare, "Warm reefs, flats, and clear bluewater edges", "Barracuda", 36),
            s("Dogfish", .common, "Cold coastal shelves, bays, and sandy bottom", "Dogfish", 28),
            s("Smoothhound", .common, "Coastal surf, bays, and sandy flats", "Houndshark", 30),
            s("Leopard Shark", .uncommon, "Pacific bays, sandy flats, and eelgrass", "Houndshark", 42),
            s("Blacktip Shark", .rare, "Warm beaches, passes, and nearshore bait schools", "Requiem Shark", 54),
            s("Mako Shark", .trophy, "Offshore bluewater, temperature breaks, and canyons", "Mackerel Shark", 72),
            s("Thresher Shark", .trophy, "Offshore banks, deep edges, and bait schools", "Thresher Shark", 84)
        ]

        let baseDate = Date(timeIntervalSince1970: 1_704_067_200)
        return seeds.enumerated().map { index, seed in
            Species(
                id: "fallback-\(index + 1)-\(seed.name.lowercased().replacingOccurrences(of: " ", with: "-"))",
                name: seed.name,
                commonName: seed.name,
                rarityTier: seed.rarity,
                xpMultiplier: seed.rarity.xpMultiplier,
                description: "A \(seed.rarity.displayName.lowercased()) \(seed.family.lowercased()) species found in \(seed.habitat.lowercased()).",
                habitat: seed.habitat,
                averageSize: seed.averageSize,
                family: seed.family,
                imageURL: nil,
                createdAt: baseDate.addingTimeInterval(Double(index) * 60)
            )
        }
    }()
}

private enum BundledFishCatalog {
    private struct Catalog: Decodable {
        let species: [Record]
    }

    private struct Record: Decodable {
        let id: String
        let name: String
        let commonName: String?
        let rarity: String
        let habitat: String?
        let family: String?
        let averageSize: Double?
    }

    static func load() -> [Species]? {
        guard let url = Bundle.main.url(forResource: "FishSpeciesCatalog", withExtension: "json") else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let catalog = try JSONDecoder().decode(Catalog.self, from: data)
            let baseDate = Date(timeIntervalSince1970: 1_704_067_200)

            return catalog.species.enumerated().map { index, record in
                let rarity = FishRarity(rawValue: record.rarity) ?? .common
                return Species(
                    id: record.id,
                    name: record.name,
                    commonName: record.commonName,
                    rarityTier: rarity,
                    xpMultiplier: rarity.xpMultiplier,
                    description: description(for: record, rarity: rarity),
                    habitat: record.habitat,
                    averageSize: record.averageSize,
                    family: record.family,
                    imageURL: nil,
                    createdAt: baseDate.addingTimeInterval(Double(index) * 60)
                )
            }
        } catch {
            return nil
        }
    }

    private static func description(for record: Record, rarity: FishRarity) -> String {
        let family = record.family ?? "fish"
        let habitat = record.habitat ?? "aquatic habitats"
        return "A \(rarity.displayName.lowercased()) \(family.lowercased()) species from the FishBase catalog, found in \(habitat.lowercased())."
    }
}

/// Per-user species capture record (codex).
/// Maps to Supabase 'user_species' table.
struct UserSpecies: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let userId: String
    let speciesId: String
    var personalBestSize: Double?
    var personalBestUnit: String?
    var personalBestCatchId: String?
    var totalCaught: Int
    let firstCaughtAt: Date
    var firstCaughtSpotId: String?
    var lastCaughtAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case speciesId = "species_id"
        case personalBestSize = "personal_best_size"
        case personalBestUnit = "personal_best_unit"
        case personalBestCatchId = "personal_best_catch_id"
        case totalCaught = "total_caught"
        case firstCaughtAt = "first_caught_at"
        case firstCaughtSpotId = "first_caught_spot_id"
        case lastCaughtAt = "last_caught_at"
    }
}

/// Combined codex entry for display: pairs catalog data with user record.
/// `userRecord == nil` means the species is "undiscovered" by this user.
struct CodexEntry: Identifiable, Equatable {
    let species: Species
    let userRecord: UserSpecies?

    var id: String { species.id }
    var isDiscovered: Bool { userRecord != nil }
    var totalCaught: Int { userRecord?.totalCaught ?? 0 }
    var masteryTier: FishMasteryTier { FishMasteryTier.tier(forCaught: totalCaught) }
    var masteryPoints: Int { masteryTier.points + min(totalCaught, 100) * 2 }

    var personalBestDisplay: String? {
        guard let record = userRecord,
              let size = record.personalBestSize,
              let unit = record.personalBestUnit
        else { return nil }
        return String(format: "%.1f %@", size, unit)
    }

    var masteryProgressToNext: Double {
        guard let next = masteryTier.nextTier else { return 1 }
        let lower = masteryTier.minCaught
        let span = max(next.minCaught - lower, 1)
        return min(1, max(0, Double(totalCaught - lower) / Double(span)))
    }
}

/// Per-species mastery rank. Counts are intentionally simple and legible:
/// the player knows exactly what one more catch does for the Fish Log.
enum FishMasteryTier: String, CaseIterable, Identifiable, Comparable {
    case unranked
    case bronze
    case silver
    case gold
    case platinum
    case diamond

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .unranked: return "Unranked"
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        case .diamond: return "Diamond"
        }
    }

    var minCaught: Int {
        switch self {
        case .unranked: return 0
        case .bronze: return 1
        case .silver: return 3
        case .gold: return 10
        case .platinum: return 25
        case .diamond: return 50
        }
    }

    var points: Int {
        switch self {
        case .unranked: return 0
        case .bronze: return 50
        case .silver: return 150
        case .gold: return 400
        case .platinum: return 900
        case .diamond: return 1_600
        }
    }

    var nextTier: FishMasteryTier? {
        switch self {
        case .unranked: return .bronze
        case .bronze: return .silver
        case .silver: return .gold
        case .gold: return .platinum
        case .platinum: return .diamond
        case .diamond: return nil
        }
    }

    var sortOrder: Int {
        switch self {
        case .unranked: return 0
        case .bronze: return 1
        case .silver: return 2
        case .gold: return 3
        case .platinum: return 4
        case .diamond: return 5
        }
    }

    static func tier(forCaught count: Int) -> FishMasteryTier {
        if count >= FishMasteryTier.diamond.minCaught { return .diamond }
        if count >= FishMasteryTier.platinum.minCaught { return .platinum }
        if count >= FishMasteryTier.gold.minCaught { return .gold }
        if count >= FishMasteryTier.silver.minCaught { return .silver }
        if count >= FishMasteryTier.bronze.minCaught { return .bronze }
        return .unranked
    }

    static func < (lhs: FishMasteryTier, rhs: FishMasteryTier) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

enum FishLogStatus: String {
    case beginner = "Beginner"
    case collector = "Collector"
    case specialist = "Specialist"
    case master = "Master Angler"
    case apex = "Apex Ichthyologist"

    static func status(for points: Int, discoveredCount: Int) -> FishLogStatus {
        if points >= 12_000 || discoveredCount >= 35 { return .apex }
        if points >= 6_000 || discoveredCount >= 25 { return .master }
        if points >= 2_500 || discoveredCount >= 15 { return .specialist }
        if points >= 700 || discoveredCount >= 6 { return .collector }
        return .beginner
    }
}
