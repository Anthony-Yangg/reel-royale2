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
        .task {
            #if DEBUG
            applyPreviewDeeplink()
            #endif
        }
    }

    #if DEBUG
    /// QA helper: tap RR_PREVIEW_DEEPLINK = "leaderboard|fishID|measure|regulations|catchFlow" in UserDefaults.
    private func applyPreviewDeeplink() {
        guard let raw = UserDefaults.standard.string(forKey: "RR_PREVIEW_DEEPLINK"), !raw.isEmpty else { return }
        UserDefaults.standard.removeObject(forKey: "RR_PREVIEW_DEEPLINK")

        switch raw {
        case "leaderboard":
            appState.selectedTab = .home
            appState.homeNavigationPath.append(NavigationDestination.leaderboard)
        case "fishID":
            appState.selectedTab = .home
            appState.homeNavigationPath.append(NavigationDestination.fishID)
        case "measure":
            appState.selectedTab = .home
            appState.homeNavigationPath.append(NavigationDestination.measureFish)
        case "regulations":
            appState.selectedTab = .home
            appState.homeNavigationPath.append(NavigationDestination.regulations(spotId: nil))
        case "settings":
            appState.selectedTab = .more
        case "catchFlow":
            showLogCatch = true
        default:
            break
        }
    }
    #endif

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
            .toolbar(.hidden, for: .navigationBar)
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
            .toolbar(.hidden, for: .navigationBar)
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
            .toolbar(.hidden, for: .navigationBar)
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
        case .codex:                     CodexView()
        case .shop:                      ShopView()
        case .challenges:                ChallengesView()
        case .notifications:             NotificationsView()
        case .season:                    SeasonView()
        }
    }
}

/// Themed settings — pirate-flavored copy + theme tokens.
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.reelTheme) private var theme
    @AppStorage("haptics.enabled") private var hapticsEnabled = true
    @AppStorage("sounds.enabled")  private var soundsEnabled = true

    var body: some View {
        ZStack {
            theme.colors.surface.canvas.ignoresSafeArea()
            List {
                Section("Captain") {
                    NavigationLink("Edit Profile") { Text("Edit Profile") }
                    NavigationLink("Privacy & Visibility") { Text("Privacy") }
                }
                Section("Feel") {
                    Toggle("Haptics", isOn: $hapticsEnabled)
                        .onChange(of: hapticsEnabled) { _, on in appState.haptics?.isEnabled = on }
                    Toggle("Sound Effects", isOn: $soundsEnabled)
                        .onChange(of: soundsEnabled) { _, on in appState.sounds?.isEnabled = on }
                }
                Section("App") {
                    NavigationLink("Notifications") { Text("Notifications") }
                    NavigationLink("Units & Measurements") { Text("Units") }
                    NavigationLink("How to Play") { Text("Tutorial") }
                }
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0").foregroundStyle(theme.colors.text.secondary)
                    }
                    Link("Privacy Policy", destination: URL(string: "https://reelroyale.app/privacy")!)
                    Link("Terms of Service", destination: URL(string: "https://reelroyale.app/terms")!)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .toolbarBackground(theme.colors.surface.canvas, for: .navigationBar)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState.shared)
        .environment(\.reelTheme, .default)
        .preferredColorScheme(.dark)
}
