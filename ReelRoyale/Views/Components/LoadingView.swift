import SwiftUI

/// Loading indicator view
struct LoadingView: View {
    var message: String? = nil
    var size: Size = .medium
    
    enum Size {
        case small
        case medium
        case large
        
        var scale: CGFloat {
            switch self {
            case .small: return 0.8
            case .medium: return 1.0
            case .large: return 1.5
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .navyPrimary))
                .scaleEffect(size.scale)
            
            if let message = message {
                Text(message)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.navyPrimary.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Full screen loading overlay
struct LoadingOverlay: View {
    let isLoading: Bool
    var message: String? = nil
    
    var body: some View {
        if isLoading {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    
                    if let message = message {
                        Text(message)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.navyPrimary.opacity(0.95))
                        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 8)
                )
            }
        }
    }
}

/// Empty state view
struct EmptyStateView: View {
    let icon: String
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.navyPrimary.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(Color.navyPrimary.opacity(0.5))
            }
            
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            if let message = message {
                Text(message)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.coralAccent, Color.sunnyYellow],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: Color.coralAccent.opacity(0.4), radius: 8, x: 0, y: 4)
                        )
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

/// Error state view
struct ErrorStateView: View {
    let message: String
    var retryAction: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.coralAccent.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 35))
                    .foregroundColor(.coralAccent)
            }
            
            Text("Something went wrong")
                .font(.system(size: 20, weight: .bold, design: .rounded))
            
            Text(message)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            if let retryAction = retryAction {
                Button(action: retryAction) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.navyPrimary)
                            .shadow(color: Color.navyPrimary.opacity(0.3), radius: 6, x: 0, y: 3)
                    )
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    VStack {
        LoadingView(message: "Loading spots...")
        
        Divider()
        
        EmptyStateView(
            icon: "fish",
            title: "No Catches Yet",
            message: "Start logging your catches to see them here",
            actionTitle: "Log a Catch"
        ) {
            print("Tapped")
        }
    }
}

