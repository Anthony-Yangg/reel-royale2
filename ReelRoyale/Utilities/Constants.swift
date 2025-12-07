import Foundation
import SwiftUI

struct EnvConfig {
    private let values: [String: String]
    
    init() {
        values = EnvConfig.load()
    }
    
    var supabaseURL: String {
        values["SUPABASE_URL"] ?? "https://dtteukpeqgnfaccwjxme.supabase.co"
    }
    
    var supabaseAnonKey: String {
        values["SUPABASE_ANON_KEY"] ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR0dGV1a3BlcWduZmFjY3dqeG1lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5Mzg0MjcsImV4cCI6MjA4MDUxNDQyN30.1BCEAsWBfgNlCej9vk2-foATxSFkiQTqwixNbKfxt-E"
    }
    
    var weatherApiKey: String {
        values["OPENWEATHER_API_KEY"] ?? "your-openweathermap-api-key"
    }
    
    var fishIdApiKey: String {
        values["OPENROUTER_API_KEY"] ?? values["FISHID_API_KEY"] ?? ""
    }
    
    var fishIdModel: String {
        values["OPENROUTER_MODEL"] ?? "google/gemini-2.5-flash"
    }
    
    var fishIdReferer: String {
        values["OPENROUTER_REFERER"] ?? ""
    }
    
    var fishIdSite: String {
        values["OPENROUTER_SITE"] ?? ""
    }
    
    var communityBucket: String {
        values["COMMUNITY_POST_BUCKET"] ?? "community-posts"
    }
    
    private static func load() -> [String: String] {
        let bundle = Bundle.main
        guard let url = bundle.url(forResource: ".env", withExtension: nil),
              let contents = try? String(contentsOf: url) else {
            return [:]
        }
        
        var result: [String: String] = [:]
        for line in contents.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1).map {
                String($0).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            }
            guard parts.count == 2 else { continue }
            result[parts[0]] = parts[1]
        }
        return result
    }
}

enum AppConstants {
    private static let env = EnvConfig()
    
    enum Supabase {
        static let projectURL = env.supabaseURL
        static let anonKey = env.supabaseAnonKey
        
        enum Buckets {
            static let avatars = "avatars"
            static let catchPhotos = "catch-photos"
            static let spotImages = "spot-images"
            static let communityPosts = env.communityBucket
        }
        
        enum Tables {
            static let profiles = "profiles"
            static let spots = "spots"
            static let catches = "catches"
            static let territories = "territories"
            static let likes = "likes"
            static let regulations = "regulations"
            static let communityPosts = "community_posts"
            static let postLikes = "community_post_likes"
            static let postComments = "community_post_comments"
            static let follows = "user_follows"
        }
    }
    
    enum Weather {
        static let apiKey = env.weatherApiKey
        static let baseURL = "https://api.openweathermap.org/data/2.5"
    }
    
    enum FishID {
        static let baseURL = "https://openrouter.ai/api/v1"
        static let apiKey = env.fishIdApiKey
        static let model = env.fishIdModel
        static let referer = env.fishIdReferer
        static let site = env.fishIdSite
    }
    
    enum UI {
        static let cornerRadius: CGFloat = 12
        static let smallCornerRadius: CGFloat = 8
        static let padding: CGFloat = 16
        static let smallPadding: CGFloat = 8
        static let avatarSize: CGFloat = 44
        static let largeAvatarSize: CGFloat = 80
        static let thumbnailSize: CGFloat = 60
        static let iconSize: CGFloat = 24
        static let quickAnimation: Double = 0.2
        static let standardAnimation: Double = 0.3
        static let slowAnimation: Double = 0.5
    }
    
    enum Game {
        static let minimumSizeDifferenceToWin: Double = 0.1
        static let minimumSpotsForTerritoryControl: Int = 1
    }
    
    enum Feed {
        static let pageSize: Int = 20
        static let maxCacheAge: TimeInterval = 300
    }
}

extension Color {
    static let deepOcean = Color(red: 0.05, green: 0.15, blue: 0.25)
    static let oceanBlue = Color(red: 0.10, green: 0.35, blue: 0.55)
    static let seafoam = Color(red: 0.35, green: 0.75, blue: 0.70)
    static let coral = Color(red: 0.95, green: 0.45, blue: 0.35)
    static let sunset = Color(red: 0.95, green: 0.65, blue: 0.30)
    static let sand = Color(red: 0.96, green: 0.93, blue: 0.85)
    static let driftwood = Color(red: 0.55, green: 0.45, blue: 0.35)
    static let kelp = Color(red: 0.25, green: 0.45, blue: 0.35)
    static let crown = Color(red: 0.95, green: 0.75, blue: 0.20)
}

enum CommonFishSpecies: String, CaseIterable {
    case largemouthBass = "Largemouth Bass"
    case smallmouthBass = "Smallmouth Bass"
    case stripedBass = "Striped Bass"
    case rainbowTrout = "Rainbow Trout"
    case brownTrout = "Brown Trout"
    case brookTrout = "Brook Trout"
    case walleye = "Walleye"
    case northernPike = "Northern Pike"
    case muskellunge = "Muskellunge"
    case channelCatfish = "Channel Catfish"
    case bluegill = "Bluegill"
    case crappie = "Crappie"
    case perch = "Yellow Perch"
    case carp = "Common Carp"
    case salmon = "Salmon"
    case steelhead = "Steelhead"
    case redfish = "Redfish"
    case snook = "Snook"
    case tarpon = "Tarpon"
    case bonefish = "Bonefish"
    case flounder = "Flounder"
    case halibut = "Halibut"
    case other = "Other"
}

