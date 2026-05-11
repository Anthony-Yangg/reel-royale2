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
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: theme.spacing.lg) {
                    PodiumHeroSection(
                        top3: vm.top3,
                        yourEntry: vm.yourEntry,
                        onSelectEntry: { _ in openLeaderboard() },
                        onOpenLeaderboard: openLeaderboard
                    )
                    .id("podium")

                    TodaysBountySection(bounty: vm.todaysBounty, onTap: openLeaderboard)
                        .id("bounty")

                    CatchPathStrip(currentStep: 1) { step in
                        handleCatchPathStep(step)
                    }
                    .id("path")

                    MapPreviewCard(onOpenMap: { appState.selectedTab = .spots })
                        .id("map")

                    YourCrownsSection(crownsHeld: 0) {
                        appState.selectedTab = .spots
                    }
                    .id("crowns")

                    DethroneTickerSection(events: vm.dethrones) { _ in
                        appState.selectedTab = .community
                    }
                    .id("ticker")

                    FeatureCTAGrid(
                        onFishID:       { appState.homeNavigationPath.append(NavigationDestination.fishID) },
                        onMeasure:      { appState.homeNavigationPath.append(NavigationDestination.measureFish) },
                        onRegulations:  { appState.homeNavigationPath.append(NavigationDestination.regulations(spotId: nil)) },
                        onLeaderboard:  openLeaderboard
                    )
                    .id("cta")
                }
                .padding(.horizontal, theme.spacing.m)
                .padding(.top, theme.spacing.m)
                .padding(.bottom, 120)
            }
            .background(animatedBackdrop.ignoresSafeArea())
            .task {
                guard !didLoad else { return }
                didLoad = true
                await vm.load(currentUserId: appState.currentUser?.id)
                #if DEBUG
                if let target = UserDefaults.standard.string(forKey: "RR_PREVIEW_HOME_SCROLL"), !target.isEmpty {
                    UserDefaults.standard.removeObject(forKey: "RR_PREVIEW_HOME_SCROLL")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation { proxy.scrollTo(target, anchor: .top) }
                    }
                }
                #endif
            }
            .refreshable {
                await vm.load(currentUserId: appState.currentUser?.id)
            }
        }
    }

    /// Layered animated backdrop: deep sea radial + drifting wave bands + sparkles.
    private var animatedBackdrop: some View {
        ZStack {
            RadialGradient(
                colors: [theme.colors.brand.deepSea, theme.colors.surface.canvas],
                center: .topLeading, startRadius: 40, endRadius: 700
            )
            // Top-band shimmer
            VStack {
                WaveStrip(amplitude: 14, frequency: 0.012, color: theme.colors.brand.tideTeal.opacity(0.55))
                    .frame(height: 90)
                    .opacity(0.4)
                Spacer()
            }
            // Bottom-band shimmer
            VStack {
                Spacer()
                WaveStrip(amplitude: 18, frequency: 0.015, color: theme.colors.brand.deepSea)
                    .frame(height: 120)
                    .opacity(0.55)
            }
            FloatingSparkles()
                .opacity(0.55)
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
