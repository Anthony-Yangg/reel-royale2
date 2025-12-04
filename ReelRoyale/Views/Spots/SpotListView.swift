import SwiftUI

struct SpotListView: View {
    let spots: [SpotWithDetails]
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        if spots.isEmpty {
            EmptyStateView(
                icon: "map",
                title: "No Spots Found",
                message: "Try adjusting your filters or search query"
            )
        } else {
            List {
                ForEach(spots) { spotDetails in
                    SpotRowView(spotDetails: spotDetails)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            appState.spotsNavigationPath.append(
                                NavigationDestination.spotDetail(spotId: spotDetails.spot.id)
                            )
                        }
                }
            }
            .listStyle(.plain)
        }
    }
}

#Preview {
    SpotListView(spots: [])
        .environmentObject(AppState.shared)
}

