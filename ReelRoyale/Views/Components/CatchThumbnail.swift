import SwiftUI

/// Thumbnail view for a catch photo
struct CatchThumbnail: View {
    let photoURL: String?
    var size: CGFloat = 60
    var cornerRadius: CGFloat = 8
    var showPlaceholder: Bool = true
    
    var body: some View {
        if let urlString = photoURL,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    loadingView
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                case .failure:
                    if showPlaceholder {
                        placeholderView
                    } else {
                        EmptyView()
                    }
                @unknown default:
                    placeholderView
                }
            }
        } else if showPlaceholder {
            placeholderView
        }
    }
    
    private var loadingView: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.2))
            .frame(width: size, height: size)
            .overlay(
                ProgressView()
                    .scaleEffect(0.8)
            )
    }
    
    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [Color.oceanBlue.opacity(0.3), Color.seafoam.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "fish.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundColor(Color.oceanBlue.opacity(0.5))
            )
    }
}

/// Larger catch photo for detail views
struct CatchPhotoView: View {
    let photoURL: String?
    var aspectRatio: CGFloat = 4/3
    var cornerRadius: CGFloat = 12
    
    var body: some View {
        if let urlString = photoURL,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    loadingView
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .aspectRatio(aspectRatio, contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                case .failure:
                    placeholderView
                @unknown default:
                    placeholderView
                }
            }
        } else {
            placeholderView
        }
    }
    
    private var loadingView: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.2))
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay(
                ProgressView()
            )
    }
    
    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [Color.deepOcean, Color.oceanBlue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                    Text("No photo")
                        .font(.caption)
                }
                .foregroundColor(.white.opacity(0.5))
            )
    }
}

#Preview {
    VStack(spacing: 24) {
        HStack(spacing: 16) {
            CatchThumbnail(photoURL: nil, size: 60)
            CatchThumbnail(photoURL: nil, size: 80)
            CatchThumbnail(photoURL: nil, size: 100)
        }
        
        CatchPhotoView(photoURL: nil)
            .frame(height: 200)
            .padding(.horizontal)
    }
}

