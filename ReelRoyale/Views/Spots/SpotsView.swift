import SwiftUI
import MapKit

// MARK: - SearchBarView
// Extracted to a separate view to prevent the expensive SpotMapView from
// re-rendering on every keystroke. This view manages its own local state
// and only propagates changes through the binding when text changes.
struct SearchBarView: View {
    @Binding var searchQuery: String
    @State private var localQuery: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.navyPrimary.opacity(0.7))
            
            ZStack(alignment: .leading) {
                if localQuery.isEmpty {
                    Text("Search spots...")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                }
                TextField("", text: $localQuery)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.navyPrimary)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onChange(of: localQuery) { _, newValue in
                        searchQuery = newValue
                    }
            }
            
            if !localQuery.isEmpty {
                Button {
                    localQuery = ""
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.navyPrimary.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.cardWhite)
                .overlay(
                    Capsule()
                        .stroke(Color.black.opacity(0.7), lineWidth: 1.5)
                )
        )
        .onAppear {
            localQuery = searchQuery
        }
        .onChange(of: searchQuery) { _, newValue in
            // Only update local if it differs (e.g., external clear)
            if localQuery != newValue {
                localQuery = newValue
            }
        }
    }
}

struct SpotsView: View {
    @StateObject private var viewModel = SpotsViewModel()
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            if viewModel.viewMode == .map {
                ZStack(alignment: .top) {
                    SpotMapView(
                        spots: viewModel.filteredSpots,
                        selectedSpot: $viewModel.selectedSpot,
                        region: $viewModel.mapRegion
                    )
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    
                    VStack(spacing: 8) {
                        searchArea
                        controlsRow
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                }
            } else {
                ZStack {
                    Color.creamBackground
                        .ignoresSafeArea()
                        .onTapGesture {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    
                    VStack(spacing: 0) {
                        searchArea
                            .padding(.horizontal)
                            .padding(.top, 12)
                        controlsRow
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .background(Color.creamBackground)
                        
                        SpotListView(spots: viewModel.filteredSpots)
                    }
                }
            }
            
            if viewModel.isLoading {
                LoadingView(message: "Loading spots...")
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
    
    private var dropdownResults: [SpotWithDetails] {
        Array(viewModel.filteredSpots.prefix(6))
    }
    
    private var isDropdownVisible: Bool {
        !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !dropdownResults.isEmpty
    }
    
    private var dropdownAnimationToken: Int {
        isDropdownVisible ? dropdownResults.count : 0
    }
    
    private var searchArea: some View {
        VStack(spacing: 6) {
            SearchBarView(searchQuery: $viewModel.searchQuery)
            
            if isDropdownVisible {
                SpotSearchDropdown(results: dropdownResults) { spotDetails in
                    viewModel.searchQuery = spotDetails.spot.name
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: dropdownAnimationToken)
    }
    
    private var controlsRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 2) {
                ForEach(SpotsViewModel.ViewMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.viewMode = mode
                        }
                    } label: {
                        Image(systemName: mode.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(viewModel.viewMode == mode ? .white : .navyPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(viewModel.viewMode == mode ? Color.navyPrimary : Color.clear)
                            )
                    }
                }
            }
            .padding(4)
            .background(
                Capsule()
                    .fill(Color.cardWhite)
                    .overlay(
                        Capsule()
                            .stroke(Color.black.opacity(0.7), lineWidth: 1.5)
                    )
            )
            
            Spacer()
            
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
                HStack(spacing: 6) {
                    Image(systemName: viewModel.selectedWaterType?.icon ?? "drop.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text(viewModel.selectedWaterType?.displayName ?? "Type")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .foregroundColor(.navyPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.cardWhite)
                        .overlay(
                            Capsule()
                                .stroke(Color.black.opacity(0.7), lineWidth: 1.5)
                        )
                )
            }
            
            Menu {
                ForEach(SpotsViewModel.DistanceFilter.allCases) { filter in
                    Button(filter.rawValue) {
                        viewModel.distanceFilter = filter
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text(viewModel.distanceFilter.rawValue)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .foregroundColor(.navyPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.cardWhite)
                        .overlay(
                            Capsule()
                                .stroke(Color.black.opacity(0.7), lineWidth: 1.5)
                        )
                )
            }
        }
    }
}

struct SpotSearchDropdown: View {
    let results: [SpotWithDetails]
    let onSelect: (SpotWithDetails) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(results) { result in
                Button {
                    onSelect(result)
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.oceanBlue.opacity(0.1))
                                .frame(width: 30, height: 30)
                            
                            Image(systemName: result.spot.waterType?.icon ?? "mappin")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.oceanBlue)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.spot.name)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.navyPrimary)
                            
                            if let region = result.spot.regionName {
                                Text(region)
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                
                if result.id != results.last?.id {
                    Divider()
                        .padding(.leading, 46)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.cardWhite)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.black.opacity(0.7), lineWidth: 1.5)
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
    }
}

#Preview {
    NavigationStack {
        SpotsView()
            .environmentObject(AppState.shared)
    }
}

