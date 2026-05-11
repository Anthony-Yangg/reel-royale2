import SwiftUI

struct SpotListView: View {
    let spots: [SpotWithDetails]
    @EnvironmentObject var appState: AppState
    @Environment(\.reelTheme) private var theme

    var body: some View {
        if spots.isEmpty {
            EmptyStateView(
                icon: "map",
                title: "No Spots Found",
                message: "Try adjusting your filters or search query"
            )
        } else {
            ScrollView {
                LazyVStack(spacing: theme.spacing.s) {
                    ForEach(spots) { spotDetails in
                        Button {
                            appState.haptics?.tap()
                            appState.spotsNavigationPath.append(
                                NavigationDestination.spotDetail(spotId: spotDetails.spot.id)
                            )
                        } label: {
                            SpotRowView(spotDetails: spotDetails)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, theme.spacing.m)
                .padding(.top, theme.spacing.s)
                .padding(.bottom, 120)  // tab bar clearance
            }
            .background(theme.colors.surface.canvas)
        }
    }
}
