import SwiftUI
import MapKit

struct SpotsView: View {
    @StateObject private var viewModel = SpotsViewModel()
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                // View mode toggle and filters
                headerView
                
                // Map or List view
                if viewModel.viewMode == .map {
                    SpotMapView(
                        spots: viewModel.filteredSpots,
                        selectedSpot: $viewModel.selectedSpot,
                        region: $viewModel.mapRegion
                    )
                } else {
                    SpotListView(spots: viewModel.filteredSpots)
                }
            }
            
            // Loading overlay
            if viewModel.isLoading {
                LoadingView(message: "Loading spots...")
            }
        }
        .navigationTitle("Fishing Spots")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    appState.spotsNavigationPath.append(NavigationDestination.logCatch(spotId: nil))
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.seafoam)
                }
            }
        }
        .task {
            await viewModel.loadSpots()
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
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search spots...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                
                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // View mode and filters
            HStack {
                // View mode picker
                Picker("View", selection: $viewModel.viewMode) {
                    ForEach(SpotsViewModel.ViewMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                
                Spacer()
                
                // Water type filter
                Menu {
                    Button("All Types") {
                        viewModel.selectedWaterType = nil
                    }
                    ForEach(WaterType.allCases) { type in
                        Button {
                            viewModel.selectedWaterType = type
                        } label: {
                            Label(type.displayName, systemImage: type.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.selectedWaterType?.icon ?? "drop.fill")
                        Text(viewModel.selectedWaterType?.displayName ?? "Type")
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // Distance filter
                Menu {
                    ForEach(SpotsViewModel.DistanceFilter.allCases) { filter in
                        Button(filter.rawValue) {
                            viewModel.distanceFilter = filter
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "location.circle")
                        Text(viewModel.distanceFilter.rawValue)
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

#Preview {
    NavigationStack {
        SpotsView()
            .environmentObject(AppState.shared)
    }
}

