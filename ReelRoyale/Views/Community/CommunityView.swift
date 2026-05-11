import SwiftUI

/// Tavern Hub. Bounty Board → Dethrone Ticker → Feed.
struct CommunityView: View {
    @StateObject private var viewModel = CommunityViewModel()
    @EnvironmentObject var appState: AppState
    @Environment(\.reelTheme) private var theme

    @State private var bounties: [Bounty] = []
    @State private var dethrones: [DethroneEvent] = []
    @State private var feedScope: FeedScope = .global

    enum FeedScope: String, CaseIterable, Identifiable {
        case following = "Following"
        case region    = "Region"
        case global    = "Global"
        case hot       = "Hot"

        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            theme.colors.surface.canvas.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.lg) {
                    title

                    bountyBoard

                    dethroneTicker

                    feedScopePicker

                    feed
                }
                .padding(.horizontal, theme.spacing.m)
                .padding(.top, theme.spacing.s)
                .padding(.bottom, 140)
            }
            .refreshable {
                await load()
                await viewModel.refresh()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
    }

    private var title: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("The Tavern")
                    .font(theme.typography.title1)
                    .foregroundStyle(theme.colors.text.primary)
                Text("Bounties · Battles · Boasts")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.text.secondary)
            }
            Spacer()
            Image(systemName: "mug.fill")
                .font(.system(size: 28))
                .foregroundStyle(theme.colors.brand.brassGold)
        }
    }

    private var bountyBoard: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            SectionHeader(title: "Bounty Board", subtitle: "Active rewards")
            if bounties.isEmpty {
                Text("No active bounties.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.text.muted)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: theme.spacing.s) {
                        ForEach(bounties) { bounty in
                            BountyCard(bounty: bounty, compact: false) {}
                                .frame(width: 300)
                        }
                    }
                }
            }
        }
    }

    private var dethroneTicker: some View {
        DethroneTickerSection(events: dethrones) { event in
            appState.communityNavigationPath.append(NavigationDestination.spotDetail(spotId: event.spotId))
        }
    }

    private var feedScopePicker: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            SectionHeader(title: "Crew Catches", subtitle: "Recent posts from the seas")
            HStack(spacing: 6) {
                ForEach(FeedScope.allCases) { s in
                    FilterChip(label: s.rawValue, icon: nil, isSelected: feedScope == s) {
                        appState.haptics?.tap()
                        feedScope = s
                    }
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var feed: some View {
        if viewModel.isLoading && viewModel.feedItems.isEmpty {
            LoadingView(message: "Listening to the docks...")
                .frame(height: 220)
        } else if viewModel.feedItems.isEmpty {
            EmptyStateView(
                icon: "person.3",
                title: "Quiet harbor",
                message: "Be the first to share a catch with the community.",
                actionTitle: "Log a Catch"
            ) {
                appState.communityNavigationPath.append(NavigationDestination.logCatch(spotId: nil))
            }
            .frame(height: 280)
        } else {
            LazyVStack(spacing: theme.spacing.s) {
                ForEach(viewModel.feedItems) { item in
                    Button {
                        appState.communityNavigationPath.append(NavigationDestination.catchDetail(catchId: item.fishCatch.id))
                    } label: {
                        FeedItemView(item: item) {
                            Task { await viewModel.toggleLike(for: item) }
                        }
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        Task { await viewModel.loadMoreIfNeeded(currentItem: item) }
                    }
                }
                if viewModel.isLoadingMore {
                    ShipWheelSpinner(size: 28).padding()
                }
            }
        }
    }

    private func load() async {
        async let b: [Bounty] = (try? appState.bountyService.fetchActive()) ?? []
        async let d: [DethroneEvent] = (try? appState.dethroneEventService.fetchRecent(limit: 8)) ?? []
        bounties = await b
        dethrones = await d
        await viewModel.loadFeed()
    }
}

#Preview {
    NavigationStack {
        CommunityView()
            .environmentObject(AppState.shared)
            .environment(\.reelTheme, .default)
            .preferredColorScheme(.dark)
    }
}
