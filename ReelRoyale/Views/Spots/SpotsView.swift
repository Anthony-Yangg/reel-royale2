import SwiftUI
import MapKit

struct SpotsView: View {
    @StateObject private var viewModel = SpotsViewModel()
    @EnvironmentObject var appState: AppState
    @Environment(\.reelTheme) private var theme
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            theme.colors.surface.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                if viewModel.viewMode == .map {
                    PirateMapView(
                        spots: viewModel.filteredSpots,
                        regions: viewModel.regionControls,
                        selectedSpot: $viewModel.selectedSpot,
                        cameraPosition: $cameraPosition,
                        currentUserId: appState.currentUser?.id,
                        userLocation: viewModel.userLocation,
                        showsRegions: viewModel.showsRegions
                    )
                } else {
                    SpotListView(spots: viewModel.filteredSpots)
                }
            }

            if viewModel.isLoading {
                LoadingView(message: "Charting nearby waters...")
                    .background(theme.colors.surface.scrim)
            }
        }
        .task {
            viewModel.currentUserId = appState.currentUser?.id
            await viewModel.loadSpots()
            // Set initial camera to map region
            cameraPosition = .region(viewModel.mapRegion)
        }
        .onChange(of: appState.currentUser?.id) { _, newId in
            viewModel.currentUserId = newId
        }
        .refreshable {
            await viewModel.loadSpots()
        }
        .onChange(of: viewModel.selectedSpot) { _, spot in
            if let spot = spot {
                appState.spotsNavigationPath.append(NavigationDestination.spotDetail(spotId: spot.id))
                viewModel.selectedSpot = nil
            }
        }
    }

    private var headerView: some View {
        VStack(spacing: theme.spacing.s) {
            HStack(spacing: theme.spacing.xs) {
                PirateSearchBar(text: $viewModel.searchQuery, placeholder: "Search waters...")
                IconButton(systemName: "plus", size: 44, fillStyle: .brass) {
                    appState.spotsNavigationPath.append(NavigationDestination.logCatch(spotId: nil))
                }
            }

            HStack(spacing: theme.spacing.xs) {
                // Map / List segmented
                HStack(spacing: 0) {
                    ForEach(SpotsViewModel.ViewMode.allCases, id: \.self) { mode in
                        Button {
                            appState.haptics?.tap()
                            withAnimation(theme.motion.fast) { viewModel.viewMode = mode }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 12, weight: .heavy))
                                Text(mode.rawValue)
                                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                            }
                            .foregroundStyle(viewModel.viewMode == mode ? Color.white : theme.colors.text.primary)
                            .padding(.horizontal, theme.spacing.s)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(viewModel.viewMode == mode ? theme.colors.text.primary : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(
                    Capsule(style: .continuous)
                        .fill(theme.colors.surface.elevatedAlt)
                )

                Spacer()

                Button {
                    appState.haptics?.tap()
                    withAnimation(theme.motion.fast) {
                        viewModel.showsRegions.toggle()
                    }
                } label: {
                    FilterChip(
                        label: "Control",
                        icon: "hexagon.fill",
                        isSelected: viewModel.showsRegions
                    ) {}
                        .allowsHitTesting(false)
                }
                .buttonStyle(.plain)

                Menu {
                    Button("All Types") { viewModel.selectedWaterType = nil }
                    ForEach(WaterType.allCases) { type in
                        Button { viewModel.selectedWaterType = type } label: {
                            Label(type.displayName, systemImage: type.icon)
                        }
                    }
                } label: {
                    FilterChip(
                        label: viewModel.selectedWaterType?.displayName ?? "Type",
                        icon: viewModel.selectedWaterType?.icon ?? "drop.fill",
                        isSelected: viewModel.selectedWaterType != nil
                    ) {}
                        .allowsHitTesting(false)
                }
                Menu {
                    ForEach(SpotsViewModel.DistanceFilter.allCases) { filter in
                        Button(filter.rawValue) { viewModel.distanceFilter = filter }
                    }
                } label: {
                    FilterChip(
                        label: viewModel.distanceFilter.rawValue,
                        icon: "location.circle.fill",
                        isSelected: viewModel.distanceFilter != .all
                    ) {}
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.top, theme.spacing.s)
        .padding(.bottom, theme.spacing.s)
        .background(theme.colors.surface.canvas)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 0.75)
        }
    }
}

#Preview {
    NavigationStack {
        SpotsView()
            .environmentObject(AppState.shared)
            .environment(\.reelTheme, .default)
            .preferredColorScheme(.light)
    }
}
