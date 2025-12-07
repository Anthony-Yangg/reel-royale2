import SwiftUI
import PhotosUI
import CoreLocation

struct LogCatchView: View {
    let preselectedSpotId: String?
    @StateObject private var viewModel: LogCatchViewModel
    @StateObject private var locationManager = LocationManager() // Use local location manager
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    init(preselectedSpotId: String? = nil) {
        self.preselectedSpotId = preselectedSpotId
        _viewModel = StateObject(wrappedValue: LogCatchViewModel(preselectedSpotId: preselectedSpotId))
    }
    
    var body: some View {
        NavigationStack {
            formContent
        }
        .navigationTitle("Log Catch")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    Task {
                        await viewModel.submitCatch()
                    }
                }
                .disabled(!viewModel.isValid || viewModel.isSubmitting)
            }
        }
        .overlay {
            LoadingOverlay(isLoading: viewModel.isSubmitting, message: "Saving catch...")
        }
        .task {
            await viewModel.loadInitialData()
        }
        .onChange(of: locationManager.location) { _, newLocation in
            if let location = newLocation {
                Task {
                    await viewModel.updateLocation(location)
                }
            }
        }
        .sheet(isPresented: $viewModel.showSpotPicker) {
            spotPickerSheet
        }
        .sheet(isPresented: $viewModel.showMeasurement) {
            NavigationStack {
                MeasurementView { length in
                    viewModel.applyMeasurement(length)
                }
            }
        }
        .sheet(isPresented: $viewModel.showFishID) {
            NavigationStack {
                FishIDView(
                    initialImage: viewModel.catchPhoto,
                    onSpeciesSelected: { species in
                        viewModel.species = species
                        viewModel.showFishID = false
                    }
                )
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onChange(of: viewModel.showSuccess) { _, success in
            if success {
                dismiss()
            }
        }
    }
    
    @ViewBuilder
    private var formContent: some View {
        Form {
            // Spot selection
            spotSection
            
            // Photo
            photoSection
            
            // Fish details
            fishDetailsSection
            
            // Size
            sizeSection
            
            // Privacy
            privacySection
            
            // Notes
            notesSection
        }
    }
    
    @ViewBuilder
    private var spotPickerSheet: some View {
        let spotsToShow: [Spot] = !viewModel.nearbySpots.isEmpty ? viewModel.nearbySpots : []
        SpotPickerView(spots: spotsToShow) { spot in
            viewModel.selectSpot(spot)
        }
    }
    
    // MARK: - Sections
    
    @ViewBuilder
    private var spotSection: some View {
        Section {
            if let spot = viewModel.selectedSpot {
                HStack {
                    Image(systemName: spot.waterType?.icon ?? "mappin") // Fixed: use WaterbodyType icon logic or fallback
                        .foregroundColor(.oceanBlue)
                    
                    VStack(alignment: .leading) {
                        Text(spot.name)
                            .font(.headline)
                        if let region = spot.regionName {
                            Text(region)
                                .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        if let wb = spot.waterbodyId { // Show waterbody info if available
                            Text("Waterbody ID: \(wb)") // Placeholder, ideally fetch name
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if !viewModel.isSpotLocked {
                        Button("Change") {
                            viewModel.showSpotPicker = true
                        }
                        .font(.caption)
                    }
                }
            } else {
                Button {
                    viewModel.showSpotPicker = true
                } label: {
                    HStack {
                        Image(systemName: "mappin.circle")
                            .foregroundColor(.oceanBlue)
                        Text(viewModel.isLoading ? "Locating..." : "Select Fishing Spot")
                            .foregroundColor(.primary)
                        Spacer()
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Show location status
            if viewModel.selectedSpot == nil {
                if locationManager.location == nil {
                    Text("Waiting for location...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
        } header: {
            Text("Location")
        }
    }
    
    @ViewBuilder
    private var photoSection: some View {
        Section {
            if let image = viewModel.catchPhoto {
                VStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    HStack {
                        PhotosPicker(selection: .init(get: { nil }, set: { item in
                            loadPhoto(from: item)
                        })) {
                            Label("Change Photo", systemImage: "photo")
                                .font(.caption)
                        }
                        
                        Spacer()
                        
                        Button {
                            viewModel.catchPhoto = nil
                        } label: {
                            Label("Remove", systemImage: "xmark.circle")
                                .font(.caption)
                                .foregroundColor(.coral)
                        }
                    }
                }
            } else {
                PhotosPicker(selection: .init(get: { nil }, set: { item in
                    loadPhoto(from: item)
                })) {
                    HStack {
                        Image(systemName: "camera.fill")
                            .foregroundColor(.oceanBlue)
                        Text("Add Photo")
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
        } header: {
            Text("Photo")
        }
    }
    
    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                viewModel.catchPhoto = image
            }
        }
    }
    
    @ViewBuilder
    private var fishDetailsSection: some View {
        Section {
            HStack {
                Image(systemName: "fish.fill")
                    .foregroundColor(.oceanBlue)
                
                TextField("Species", text: $viewModel.species)
                
                if viewModel.catchPhoto != nil {
                    Button {
                        viewModel.showFishID = true
                    } label: {
                        Label("ID with AI", systemImage: "sparkles")
                            .font(.caption)
                            .foregroundColor(.seafoam)
                    }
                }
            }
        } header: {
            Text("Fish Details")
        }
    }
    
    @ViewBuilder
    private var sizeSection: some View {
        Section {
            HStack {
                Image(systemName: "ruler")
                    .foregroundColor(.oceanBlue)
                
                TextField("Size", text: $viewModel.sizeValue)
                    .keyboardType(.decimalPad)
                
                Picker("Unit", selection: $viewModel.sizeUnit) {
                    ForEach(SizeUnit.allCases.filter { $0.isLength }) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
            }
            
            Button {
                viewModel.showMeasurement = true
            } label: {
                HStack {
                    Image(systemName: "arkit")
                        .foregroundColor(.seafoam)
                    Text("Measure with Camera")
                        .foregroundColor(.primary)
                    Spacer()
                    if viewModel.measuredWithAR {
                        Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    }
                }
            }
        } header: {
            Text("Size")
        } footer: {
            Text("Use AR measurement for accurate fish length")
        }
    }
    
    @ViewBuilder
    private var privacySection: some View {
        Section {
            Picker("Visibility", selection: $viewModel.visibility) {
                ForEach(CatchVisibility.allCases) { visibility in
                    Label(visibility.displayName, systemImage: visibility.icon)
                        .tag(visibility)
                }
            }
            
            Toggle(isOn: $viewModel.hideExactLocation) {
                HStack {
                    Image(systemName: "location.slash")
                        .foregroundColor(.secondary)
                    Text("Hide Exact Location")
                }
            }
        } header: {
            Text("Privacy")
        } footer: {
            Text("Private catches won't appear on leaderboards or community feed")
        }
    }
    
    @ViewBuilder
    private var notesSection: some View {
        Section {
            TextEditor(text: $viewModel.notes)
                .frame(minHeight: 80)
        } header: {
            Text("Notes (optional)")
        }
    }
}
