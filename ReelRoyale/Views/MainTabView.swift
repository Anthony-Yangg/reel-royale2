import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.reelTheme) private var theme
    @State private var showLogCatch = false

    var body: some View {
        TabBarShell(
            content: { tab in
                tabContent(for: tab)
            },
            onFABTap: { showLogCatch = true }
        )
        .fullScreenCover(isPresented: $showLogCatch) {
            CatchFlowView(preselectedSpotId: nil)
        }
    }

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            homeTab
        case .spots:
            spotsTab
        case .community:
            communityTab
        case .profile:
            profileTab
        case .more:
            moreTab
        }
    }

    private var homeTab: some View {
        NavigationStack(path: $appState.homeNavigationPath) {
            VStack(spacing: 0) {
                IdentityHeader()
                HomeView()
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationView(for: destination)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var spotsTab: some View {
        NavigationStack(path: $appState.spotsNavigationPath) {
            VStack(spacing: 0) {
                IdentityHeader()
                SpotsView()
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationView(for: destination)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var communityTab: some View {
        NavigationStack(path: $appState.communityNavigationPath) {
            VStack(spacing: 0) {
                IdentityHeader()
                CommunityView()
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationView(for: destination)
            }
        }
    }

    private var profileTab: some View {
        NavigationStack(path: $appState.profileNavigationPath) {
            VStack(spacing: 0) {
                IdentityHeader()
                ProfileView()
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationView(for: destination)
            }
        }
    }

    private var moreTab: some View {
        NavigationStack {
            VStack(spacing: 0) {
                IdentityHeader()
                MoreView()
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationView(for: destination)
            }
        }
    }

    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .spotDetail(let spotId):    SpotDetailView(spotId: spotId)
        case .catchDetail(let catchId):  CatchDetailView(catchId: catchId)
        case .logCatch(let spotId):      LogCatchView(preselectedSpotId: spotId)
        case .userProfile(let userId):   ProfileView(userId: userId)
        case .territory(let tId):        TerritoryView(territoryId: tId)
        case .regulations(let sId):      RegulationsView(spotId: sId)
        case .fishID:                    FishIDView()
        case .measureFish:               MeasurementView(onCapture: { _ in })
        case .leaderboard:               LeaderboardView()
        case .settings:                  SettingsView()
        }
    }
}

// Settings placeholder retained from previous version.
struct SettingsView: View {
    var body: some View {
        List {
            Section("Account") {
                NavigationLink("Edit Profile") { Text("Edit Profile") }
                NavigationLink("Privacy Settings") { Text("Privacy Settings") }
            }
            Section("App") {
                NavigationLink("Notifications") { Text("Notifications") }
                NavigationLink("Units & Measurements") { Text("Units & Measurements") }
            }
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0").foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState.shared)
        .environment(\.reelTheme, .default)
        .preferredColorScheme(.dark)
}
