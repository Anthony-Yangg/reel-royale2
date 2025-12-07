import SwiftUI

struct FeedItemView: View {
    let item: CatchWithDetails
    let onLikeTapped: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header - User info
            HStack(spacing: 12) {
                UserAvatarView(user: item.user, size: 44, showCrown: item.isCurrentKing)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.user?.username ?? "Anonymous")
                            .font(.headline)
                        
                        if item.isCurrentKing {
                            CrownBadge(size: .small)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        if let spot = item.spot {
                            Text(spot.name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(item.fishCatch.createdAt.relativeTime)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Privacy indicator
                Image(systemName: item.fishCatch.visibility.icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Catch photo
            if let photoURL = item.fishCatch.photoURL {
                CatchPhotoView(photoURL: photoURL)
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Catch details
            HStack(spacing: 16) {
                // Species and size
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.fishCatch.species)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 8) {
                        Label(item.fishCatch.sizeDisplay, systemImage: "ruler")
                            .font(.subheadline)
                            .foregroundColor(.oceanBlue)
                        
                        if item.fishCatch.measuredWithAR {
                            Image(systemName: "arkit")
                                .font(.caption)
                                .foregroundColor(.seafoam)
                        }
                    }
                }
                
                Spacer()
                
                // New King badge
                if item.isCurrentKing {
                    NewKingBadge()
                }
            }
            
            // Notes
            if let notes = item.fishCatch.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            Divider()
            
            // Actions
            HStack(spacing: 24) {
                // Like button
                Button(action: onLikeTapped) {
                    HStack(spacing: 6) {
                        Image(systemName: item.isLikedByCurrentUser ? "heart.fill" : "heart")
                            .foregroundColor(item.isLikedByCurrentUser ? .coral : .secondary)
                        
                        if item.likeCount > 0 {
                            Text("\(item.likeCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                
                // Comment placeholder
                HStack(spacing: 6) {
                    Image(systemName: "bubble.right")
                        .foregroundColor(.secondary)
                    Text("0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Share placeholder
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Spot link
                if let spot = item.spot {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                        Text(item.fishCatch.hideExactLocation ? "Location hidden" : spot.name)
                    }
                    .font(.caption)
                    .foregroundColor(.oceanBlue)
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    ScrollView {
        FeedItemView(
            item: CatchWithDetails(
                fishCatch: FishCatch(
                    id: "1",
                    userId: "1",
                    spotId: "1",
                    latitude: 0,
                    longitude: 0,
                    species: "Largemouth Bass",
                    sizeValue: 52.5,
                    sizeUnit: "cm",
                    notes: "Great catch today! The weather was perfect and the fish were biting."
                ),
                user: User(id: "1", username: "FishMaster"),
                spot: Spot(id: "1", name: "Lake Evergreen", latitude: 0, longitude: 0),
                likeCount: 12,
                isLikedByCurrentUser: true,
                isCurrentKing: true
            )
        ) {
            print("Like tapped")
        }
        .padding()
    }
    .background(Color(.systemGray6))
}

