import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            // Spots Tab
            NavigationStack(path: $appState.spotsNavigationPath) {
                SpotsView()
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            .tabItem {
                Label(AppTab.spots.rawValue, systemImage: AppTab.spots.icon)
            }
            .tag(AppTab.spots)
            
            // Community Tab
            NavigationStack(path: $appState.communityNavigationPath) {
                CommunityView()
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            .tabItem {
                Label(AppTab.community.rawValue, systemImage: AppTab.community.icon)
            }
            .tag(AppTab.community)
            
            // Profile Tab
            NavigationStack(path: $appState.profileNavigationPath) {
                ProfileView()
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            .tabItem {
                Label(AppTab.profile.rawValue, systemImage: AppTab.profile.icon)
            }
            .tag(AppTab.profile)
            
            // More Tab
            NavigationStack {
                MoreView()
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            .tabItem {
                Label(AppTab.more.rawValue, systemImage: AppTab.more.icon)
            }
            .tag(AppTab.more)
        }
        .tint(Color.seafoam)
    }
    
    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .spotDetail(let spotId):
            SpotDetailView(spotId: spotId)
            
        case .catchDetail(let catchId):
            CatchDetailView(catchId: catchId)
            
        case .logCatch(let spotId):
            LogCatchView(preselectedSpotId: spotId)
            
        case .userProfile(let userId):
            ProfileView(userId: userId)
            
        case .territory(let territoryId):
            TerritoryView(territoryId: territoryId)
            
        case .regulations(let spotId):
            RegulationsView(spotId: spotId)
            
        case .fishID:
            FishIDView()
            
        case .measureFish:
            MeasurementView(onCapture: { _ in })
            
        case .leaderboard:
            LeaderboardView()
            
        case .settings:
            SettingsView()
        }
    }
}

// Settings placeholder
struct SettingsView: View {
    var body: some View {
        List {
            Section("Account") {
                NavigationLink("Edit Profile") {
                    Text("Edit Profile")
                }
                NavigationLink("Privacy Settings") {
                    Text("Privacy Settings")
                }
            }
            
            Section("App") {
                NavigationLink("Notifications") {
                    Text("Notifications")
                }
                NavigationLink("Units & Measurements") {
                    Text("Units & Measurements")
                }
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState.shared)
}

