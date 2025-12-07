import SwiftUI

/// User avatar with optional crown overlay
struct UserAvatarView: View {
    let user: User?
    var size: CGFloat = 44
    var showCrown: Bool = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            avatarImage
            
            if showCrown {
                CrownBadge(size: .small)
                    .offset(x: 6, y: -6)
            }
        }
    }
    
    @ViewBuilder
    private var avatarImage: some View {
        if let urlString = user?.avatarURL,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholderAvatar
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                case .failure:
                    placeholderAvatar
                @unknown default:
                    placeholderAvatar
                }
            }
        } else {
            placeholderAvatar
        }
    }
    
    private var placeholderAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.navyPrimary, Color.aquaHighlight],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            )
    }
    
    private var initials: String {
        guard let username = user?.username, !username.isEmpty else {
            return "?"
        }
        return String(username.prefix(2)).uppercased()
    }
}

/// Avatar for anonymous/unknown users
struct AnonymousAvatarView: View {
    var size: CGFloat = 44
    
    var body: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundColor(.gray)
            )
    }
}

#Preview {
    VStack(spacing: 24) {
        UserAvatarView(user: nil, size: 44)
        
        UserAvatarView(
            user: User(id: "1", username: "FishKing"),
            size: 60
        )
        
        UserAvatarView(
            user: User(id: "2", username: "AngleMaster"),
            size: 80,
            showCrown: true
        )
        
        AnonymousAvatarView(size: 44)
    }
    .padding()
}

