import SwiftUI

struct SpotPickerView: View {
    let spots: [Spot]
    let onSelect: (Spot) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    private var filteredSpots: [Spot] {
        if searchText.isEmpty {
            return spots
        }
        return spots.filter { spot in
            spot.name.localizedCaseInsensitiveContains(searchText) ||
            spot.regionName?.localizedCaseInsensitiveContains(searchText) == true
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredSpots) { spot in
                    Button {
                        onSelect(spot)
                        dismiss()
                    } label: {
                        SpotPickerRow(spot: spot)
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "Search spots")
            .navigationTitle("Select Spot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SpotPickerRow: View {
    let spot: Spot
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.oceanBlue)
                    .frame(width: 40, height: 40)
                
                Image(systemName: spot.waterType?.icon ?? "mappin")
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(spot.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if spot.hasKing {
                        CrownBadge(size: .small)
                    }
                }
                
                if let region = spot.regionName {
                    Text(region)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let bestSize = spot.bestCatchDisplay {
                Text(bestSize)
                    .font(.caption)
                    .foregroundColor(.oceanBlue)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SpotPickerView(spots: [
        Spot(id: "1", name: "Lake Evergreen", latitude: 0, longitude: 0, waterType: .lake, regionName: "Northern California"),
        Spot(id: "2", name: "Crystal River", latitude: 0, longitude: 0, waterType: .river, currentKingUserId: "user1")
    ]) { spot in
        print("Selected: \(spot.name)")
    }
}

