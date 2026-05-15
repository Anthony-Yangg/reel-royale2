import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.reelTheme) private var theme
    @State private var showLogCatch = false
    @State private var moreNavigationPath = NavigationPath()

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
    /// QA helper: tap RR_PREVIEW_DEEPLINK = "leaderboard|fishLog|fishID|measure|regulations|catchFlow" in UserDefaults.
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
        case "fishLog":
            appState.selectedTab = .fishLog
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
        case .fishLog:
            fishLogTab
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
                rootHeader(for: .home)
                HomeView()
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationChrome(for: destination) {
                    popHomePath()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var spotsTab: some View {
        NavigationStack(path: $appState.spotsNavigationPath) {
            VStack(spacing: 0) {
                rootHeader(for: .spots)
                SpotsView()
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationChrome(for: destination) {
                    popSpotsPath()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var communityTab: some View {
        NavigationStack(path: $appState.communityNavigationPath) {
            VStack(spacing: 0) {
                rootHeader(for: .community)
                CommunityView()
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationChrome(for: destination) {
                    popCommunityPath()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var fishLogTab: some View {
        NavigationStack(path: $appState.fishLogNavigationPath) {
            VStack(spacing: 0) {
                rootHeader(for: .fishLog)
                CodexView()
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationChrome(for: destination) {
                    popFishLogPath()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var profileTab: some View {
        NavigationStack(path: $appState.profileNavigationPath) {
            VStack(spacing: 0) {
                rootHeader(for: .profile)
                ProfileView()
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationChrome(for: destination) {
                    popProfilePath()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var moreTab: some View {
        NavigationStack(path: $moreNavigationPath) {
            VStack(spacing: 0) {
                rootHeader(for: .more)
                MoreView()
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationChrome(for: destination) {
                    if moreNavigationPath.count > 0 {
                        moreNavigationPath.removeLast()
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func rootHeader(for tab: AppTab) -> some View {
        ModernPageHeader(
            title: tab.rawValue,
            leadingIcon: tab == .profile ? "house.fill" : "person.crop.circle.fill",
            trailingIcon: "ellipsis",
            showsIndicator: true,
            onLeadingTap: {
                withAnimation(theme.motion.fast) {
                    appState.selectedTab = tab == .profile ? .home : .profile
                }
            },
            onTrailingTap: {
                withAnimation(theme.motion.fast) {
                    appState.selectedTab = .more
                }
            }
        )
    }

    @ViewBuilder
    private func destinationChrome(for destination: NavigationDestination, onBack: @escaping () -> Void) -> some View {
        if case .logCatch = destination {
            destinationView(for: destination)
                .toolbar(.hidden, for: .navigationBar)
                .navigationBarBackButtonHidden(true)
        } else {
            VStack(spacing: 0) {
                ModernPageHeader(
                    title: destination.modernTitle,
                    leadingIcon: "chevron.left",
                    trailingIcon: destination.trailingIcon,
                    showsIndicator: destination.showsHeaderIndicator,
                    onLeadingTap: onBack,
                    onTrailingTap: {
                        withAnimation(theme.motion.fast) {
                            appState.selectedTab = .more
                        }
                    }
                )

                destinationView(for: destination)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
        }
    }

    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .spotDetail(let spotId):    SpotDetailView(spotId: spotId)
        case .catchDetail(let catchId):  CatchDetailView(catchId: catchId)
        case .logCatch(let spotId):      CatchFlowView(preselectedSpotId: spotId)
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

    private func popHomePath() {
        if appState.homeNavigationPath.count > 0 {
            appState.homeNavigationPath.removeLast()
        }
    }

    private func popSpotsPath() {
        if appState.spotsNavigationPath.count > 0 {
            appState.spotsNavigationPath.removeLast()
        }
    }

    private func popCommunityPath() {
        if appState.communityNavigationPath.count > 0 {
            appState.communityNavigationPath.removeLast()
        }
    }

    private func popFishLogPath() {
        if appState.fishLogNavigationPath.count > 0 {
            appState.fishLogNavigationPath.removeLast()
        }
    }

    private func popProfilePath() {
        if appState.profileNavigationPath.count > 0 {
            appState.profileNavigationPath.removeLast()
        }
    }
}

private extension NavigationDestination {
    var modernTitle: String {
        switch self {
        case .spotDetail: return "Spot Details"
        case .catchDetail: return "Catch Details"
        case .logCatch: return "Log Catch"
        case .userProfile: return "Profile"
        case .territory: return "Territory"
        case .regulations: return "Regulations"
        case .fishID: return "Fish ID"
        case .measureFish: return "Measure Fish"
        case .leaderboard: return "Leaderboard"
        case .settings: return "Settings"
        case .codex: return "Fish Log"
        case .shop: return "Tackle Shop"
        case .challenges: return "Challenges"
        case .notifications: return "Notifications"
        case .season: return "Season"
        }
    }

    var trailingIcon: String {
        switch self {
        case .catchDetail: return "heart"
        case .shop: return "bag"
        case .notifications: return "bell"
        case .settings: return "gearshape"
        default: return "ellipsis"
        }
    }

    var showsHeaderIndicator: Bool {
        switch self {
        case .spotDetail, .catchDetail, .territory, .userProfile:
            return false
        default:
            return true
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
