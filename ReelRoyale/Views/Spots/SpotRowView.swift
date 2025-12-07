import SwiftUI

struct SpotRowView: View {
    let spotDetails: SpotWithDetails
    
    var body: some View {
        HStack(spacing: 16) {
            // Water type icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.oceanBlue, Color.seafoam],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: spotDetails.spot.waterType?.icon ?? "drop.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            // Spot info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(spotDetails.spot.name)
                        .font(.headline)
                    
                    if spotDetails.spot.hasKing {
                        CrownBadge(size: .small)
                    }
                }
                
                if let region = spotDetails.spot.regionName {
                    Text(region)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text(spotDetails.spot.formattedCoordinates)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 12) {
                    // King info
                    if let king = spotDetails.kingUser {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.caption2)
                                .foregroundColor(.crown)
                            Text(king.username)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Best catch size
                    if let bestDisplay = spotDetails.spot.bestCatchDisplay {
                        HStack(spacing: 4) {
                            Image(systemName: "ruler")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(bestDisplay)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Distance
                    if let distance = spotDetails.distance {
                        HStack(spacing: 4) {
                            Image(systemName: "location")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(distance.formattedDistance)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Catches count
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(spotDetails.catchCount)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.oceanBlue)
                Text("catches")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    List {
        SpotRowView(spotDetails: SpotWithDetails(
            spot: Spot(
                id: "1",
                name: "Lake Evergreen",
                latitude: 37.7749,
                longitude: -122.4194,
                waterType: .lake,
                regionName: "Northern California"
            ),
            kingUser: User(id: "1", username: "FishKing"),
            bestCatch: nil,
            distance: 5000,
            catchCount: 42,
            waterbody: nil
        ))
    }
    .listStyle(.plain)
}

