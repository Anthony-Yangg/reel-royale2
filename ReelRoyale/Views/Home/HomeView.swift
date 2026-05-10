import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.reelTheme) private var theme
    @StateObject private var vm: HomeViewModel
    @State private var didLoad = false

    init() {
        let state = AppState.shared
        _vm = StateObject(wrappedValue: HomeViewModel(
            bountyService: state.bountyService ?? MockBountyService(),
            dethroneService: state.dethroneEventService ?? MockDethroneEventService(),
            leaderboardService: state.leaderboardService ?? MockLeaderboardService()
        ))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: theme.spacing.lg) {
                PodiumHeroSection(
                    top3: vm.top3,
                    yourEntry: vm.yourEntry,
                    onSelectEntry: { _ in openLeaderboard() },
                    onOpenLeaderboard: openLeaderboard
                )

                TodaysBountySection(bounty: vm.todaysBounty, onTap: openLeaderboard)

                CatchPathStrip(currentStep: 1) { step in
                    handleCatchPathStep(step)
                }

                MapPreviewCard(onOpenMap: { appState.selectedTab = .spots })

                YourCrownsSection(crownsHeld: 0) {
                    appState.selectedTab = .spots
                }

                DethroneTickerSection(events: vm.dethrones) { _ in
                    appState.selectedTab = .community
                }

                FeatureCTAGrid(
                    onFishID:       { appState.homeNavigationPath.append(NavigationDestination.fishID) },
                    onMeasure:      { appState.homeNavigationPath.append(NavigationDestination.measureFish) },
                    onRegulations:  { appState.homeNavigationPath.append(NavigationDestination.regulations(spotId: nil)) },
                    onLeaderboard:  openLeaderboard
                )
            }
            .padding(.horizontal, theme.spacing.m)
            .padding(.top, theme.spacing.m)
            .padding(.bottom, 120)  // clearance for tab bar + FAB
        }
        .background(theme.colors.surface.canvas)
        .task {
            guard !didLoad else { return }
            didLoad = true
            await vm.load(currentUserId: appState.currentUser?.id)
        }
        .refreshable {
            await vm.load(currentUserId: appState.currentUser?.id)
        }
    }

    private func openLeaderboard() {
        appState.homeNavigationPath.append(NavigationDestination.leaderboard)
    }

    private func handleCatchPathStep(_ step: Int) {
        // Wave 4 wires steps to the real catch flow. For Wave 2, all jumps go to the existing
        // log-catch path via Community/Map context.
        switch step {
        case 1: appState.selectedTab = .spots
        case 2, 3, 4: appState.homeNavigationPath.append(NavigationDestination.logCatch(spotId: nil))
        default: break
        }
    }
}
