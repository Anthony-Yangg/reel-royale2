import SwiftUI

/// Crown badge for king/queen status
struct CrownBadge: View {
    let size: Size
    var isAnimated: Bool = false
    var showGlow: Bool = false
    
    enum Size {
        case small
        case medium
        case large
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 24
            case .large: return 36
            }
        }
        
        var padding: CGFloat {
            switch self {
            case .small: return 4
            case .medium: return 6
            case .large: return 8
            }
        }
    }
    
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Glow effect
            if showGlow {
                Image(systemName: "crown.fill")
                    .font(.system(size: size.iconSize * 1.3))
                    .foregroundColor(Color.crown.opacity(0.5))
                    .blur(radius: 8)
            }
            
            // Crown icon
            Image(systemName: "crown.fill")
                .font(.system(size: size.iconSize))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.crown, Color.sunset],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .rotationEffect(.degrees(rotation))
                .scaleEffect(scale)
        }
        .onAppear {
            if isAnimated {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    rotation = 5
                    scale = 1.1
                }
            }
        }
    }
}

/// "New King!" celebration badge
struct NewKingBadge: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 6) {
            CrownBadge(size: .medium, isAnimated: true, showGlow: true)
            
            Text("NEW KING!")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            LinearGradient(
                colors: [Color.coral, Color.sunset],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
        .shadow(color: Color.coral.opacity(0.5), radius: 8)
        .scaleEffect(isAnimating ? 1.05 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

/// Territory ruler badge
struct TerritoryRulerBadge: View {
    let spotCount: Int
    let totalSpots: Int
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flag.fill")
                .font(.caption)
                .foregroundColor(Color.kelp)
            
            Text("\(spotCount)/\(totalSpots)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.kelp.opacity(0.2))
        .cornerRadius(12)
    }
}

#Preview {
    VStack(spacing: 24) {
        HStack(spacing: 20) {
            CrownBadge(size: .small)
            CrownBadge(size: .medium)
            CrownBadge(size: .large)
        }
        
        CrownBadge(size: .large, isAnimated: true, showGlow: true)
        
        NewKingBadge()
        
        TerritoryRulerBadge(spotCount: 3, totalSpots: 5)
    }
    .padding()
}

