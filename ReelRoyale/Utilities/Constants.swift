import Foundation
import SwiftUI

/// App-wide constants and configuration
enum AppConstants {
    /// Supabase configuration
    /// IMPORTANT: Replace these with your actual Supabase project credentials
    enum Supabase {
        static let projectURL = "url here"
        static let anonKey = "key here"
        
        /// Storage bucket names
        enum Buckets {
            static let avatars = "avatars"
            static let catchPhotos = "catch-photos"
            static let spotImages = "spot-images"
        }
        
        /// Table names
        enum Tables {
            static let profiles = "profiles"
            static let spots = "spots"
            static let catches = "catches"
            static let territories = "territories"
            static let likes = "likes"
            static let regulations = "regulations"
        }
    }
    
    /// OpenWeatherMap API configuration
    enum Weather {
        static let apiKey = "your-openweathermap-api-key"
        static let baseURL = "https://api.openweathermap.org/data/2.5"
    }
    
    /// AI Fish ID configuration (for future cloud ML endpoint)
    enum FishID {
        static let baseURL = "https://your-fish-id-api.com"
        static let apiKey = "your-fish-id-api-key"
    }
    
    /// App UI constants
    enum UI {
        static let cornerRadius: CGFloat = 12
        static let smallCornerRadius: CGFloat = 8
        static let padding: CGFloat = 16
        static let smallPadding: CGFloat = 8
        static let avatarSize: CGFloat = 44
        static let largeAvatarSize: CGFloat = 80
        static let thumbnailSize: CGFloat = 60
        static let iconSize: CGFloat = 24
        
        /// Animation durations
        static let quickAnimation: Double = 0.2
        static let standardAnimation: Double = 0.3
        static let slowAnimation: Double = 0.5
    }
    
    /// Game mechanics constants
    enum Game {
        /// Minimum difference in size (cm) to dethrone current king
        static let minimumSizeDifferenceToWin: Double = 0.1
        
        /// Minimum spots to control for territory ruler
        static let minimumSpotsForTerritoryControl: Int = 1
    }
    
    /// Feed and pagination
    enum Feed {
        static let pageSize: Int = 20
        static let maxCacheAge: TimeInterval = 300 // 5 minutes
    }
}

/// App color palette - Deep ocean/fishing theme
extension Color {
    static let themeBackground = Color("AppBackground")
    static let themePrimary = Color("AppPrimary")
    static let themeSecondary = Color("AppSecondary")
    static let themeAccent = Color("AppAccent")
    
    // Fallback colors if asset catalog colors aren't set
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

/// Common fish species for picker
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

