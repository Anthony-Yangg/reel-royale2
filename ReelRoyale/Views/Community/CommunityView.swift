import SwiftUI

struct CommunityView: View {
    @StateObject private var viewModel = CommunityViewModel()
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.feedItems.isEmpty {
                LoadingView(message: "Loading feed...")
            } else if viewModel.feedItems.isEmpty {
                EmptyStateView(
                    icon: "person.3",
                    title: "No Catches Yet",
                    message: "Be the first to share a catch with the community!",
                    actionTitle: "Log a Catch"
                ) {
                    appState.communityNavigationPath.append(NavigationDestination.logCatch(spotId: nil))
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.feedItems) { item in
                            FeedItemView(item: item) {
                                Task {
                                    await viewModel.toggleLike(for: item)
                                }
                            }
                            .onTapGesture {
                                appState.communityNavigationPath.append(
                                    NavigationDestination.catchDetail(catchId: item.fishCatch.id)
                                )
                            }
                            .onAppear {
                                Task {
                                    await viewModel.loadMoreIfNeeded(currentItem: item)
                                }
                            }
                        }
                        
                        if viewModel.isLoadingMore {
                            ProgressView()
                                .padding()
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Community")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    appState.communityNavigationPath.append(NavigationDestination.logCatch(spotId: nil))
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.seafoam)
                }
            }
        }
        .task {
            await viewModel.loadFeed()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}

#Preview {
    NavigationStack {
        CommunityView()
            .environmentObject(AppState.shared)
    }
}

