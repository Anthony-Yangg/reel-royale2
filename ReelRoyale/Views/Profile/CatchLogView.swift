import SwiftUI

struct CatchLogView: View {
    let catches: [CatchWithDetails]
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(catches) { item in
                CatchLogRow(item: item)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.profileNavigationPath.append(
                            NavigationDestination.catchDetail(catchId: item.fishCatch.id)
                        )
                    }
                
                if item.id != catches.last?.id {
                    Divider()
                        .padding(.leading, 76)
                }
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CatchLogRow: View {
    let item: CatchWithDetails
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            CatchThumbnail(photoURL: item.fishCatch.photoURL, size: 60)
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.fishCatch.species)
                        .font(.headline)
                    
                    if item.isCurrentKing {
                        CrownBadge(size: .small)
                    }
                    
                    // Privacy indicator
                    Image(systemName: item.fishCatch.visibility.icon)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 8) {
                    Label(item.fishCatch.sizeDisplay, systemImage: "ruler")
                        .font(.caption)
                        .foregroundColor(.oceanBlue)
                    
                    if item.fishCatch.measuredWithAR {
                        Image(systemName: "arkit")
                            .font(.caption2)
                            .foregroundColor(.seafoam)
                    }
                }
                
                HStack(spacing: 8) {
                    if let spot = item.spot {
                        Text(item.fishCatch.hideExactLocation ? "Hidden location" : spot.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(item.fishCatch.createdAt.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    CatchLogView(catches: [
        CatchWithDetails(
            fishCatch: FishCatch(
                id: "1",
                userId: "1",
                spotId: "1",
                species: "Largemouth Bass",
                sizeValue: 52.5,
                sizeUnit: "cm"
            ),
            user: nil,
            spot: Spot(id: "1", name: "Lake Evergreen", latitude: 0, longitude: 0),
            likeCount: 0,
            isLikedByCurrentUser: false,
            isCurrentKing: true
        ),
        CatchWithDetails(
            fishCatch: FishCatch(
                id: "2",
                userId: "1",
                spotId: "2",
                species: "Rainbow Trout",
                sizeValue: 38.0,
                sizeUnit: "cm",
                visibility: .private
            ),
            user: nil,
            spot: Spot(id: "2", name: "Crystal River", latitude: 0, longitude: 0),
            likeCount: 0,
            isLikedByCurrentUser: false,
            isCurrentKing: false
        )
    ])
    .padding()
    .environmentObject(AppState.shared)
}

