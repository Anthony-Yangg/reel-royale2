import SwiftUI

struct FeedItemView: View {
    let item: CommunityPostDetails
    let onLikeTapped: () -> Void
    let onCommentTapped: () -> Void
    let onFollowTapped: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                UserAvatarView(user: item.author, size: 44, showCrown: false)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.author?.username ?? "Anonymous")
                        .font(.headline)
                    HStack(spacing: 8) {
                        let hasLocation = !(item.post.locationName ?? "").isEmpty
                        if let location = item.post.locationName, hasLocation {
                            Text(location)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if !(item.post.locationName ?? "").isEmpty {
                            Text("•")
                                .foregroundColor(.secondary)
                        }
                        Text(item.post.createdAt.relativeTime)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if let currentUserId = AppState.shared.currentUser?.id, currentUserId != item.post.userId {
                    Button {
                        onFollowTapped()
                    } label: {
                        Text(item.isFollowingAuthor ? "Following" : "Follow")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(item.isFollowingAuthor ? Color.oceanBlue.opacity(0.15) : Color.seafoam.opacity(0.2))
                            .foregroundColor(item.isFollowingAuthor ? .oceanBlue : .seafoam)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if let photoURL = item.post.mediaURLs.first {
                CatchPhotoView(photoURL: photoURL)
                    .frame(maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(item.post.caption)
                    .font(.subheadline)
                if !item.post.hashtags.isEmpty {
                    Text(item.post.hashtags.map { "#\($0)" }.joined(separator: " "))
                        .font(.caption)
                        .foregroundColor(.oceanBlue)
                }
            }
            
            Divider()
            
            HStack(spacing: 24) {
                Button(action: onLikeTapped) {
                    HStack(spacing: 6) {
                        Image(systemName: item.isLikedByCurrentUser ? "heart.fill" : "heart")
                            .foregroundColor(item.isLikedByCurrentUser ? .coral : .secondary)
                        Text("\(item.likeCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                Button(action: onCommentTapped) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.right")
                            .foregroundColor(.secondary)
                        Text("\(item.commentCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                ShareLink(item: shareItem) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
    
    private var shareItem: String {
        if let first = item.post.mediaURLs.first {
            return "\(item.post.caption)\n\(first)"
        } else {
            return item.post.caption
        }
    }
}

#Preview {
    let post = CommunityPostDetails(
        post: CommunityPost(
            userId: "1",
            mediaURLs: [],
            caption: "Great day on the water",
            locationName: "Lake Evergreen",
            hashtags: ["bass", "fishing"]
        ),
        author: User(id: "1", username: "FishMaster"),
        likeCount: 12,
        commentCount: 3,
        isLikedByCurrentUser: true,
        isFollowingAuthor: false
    )
    FeedItemView(
        item: post,
        onLikeTapped: {},
        onCommentTapped: {},
        onFollowTapped: {}
    )
    .padding()
}

