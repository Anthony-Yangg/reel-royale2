import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if appState.isLoading {
                LaunchScreen()
            } else if !appState.isAuthenticated {
                AuthView()
            } else if appState.needsProfileSetup {
                ProfileSetupView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: appState.needsProfileSetup)
        .alert("Error", isPresented: $appState.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appState.errorMessage ?? "An unknown error occurred")
        }
    }
}

struct LaunchScreen: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.5
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // Background gradient - Navy blue
            LinearGradient(
                colors: [Color.navyDark, Color.navyPrimary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Decorative bubbles
            GeometryReader { geometry in
                Circle()
                    .fill(Color.aquaHighlight.opacity(0.15))
                    .frame(width: 200, height: 200)
                    .offset(x: -50, y: geometry.size.height * 0.2)
                
                Circle()
                    .fill(Color.coralAccent.opacity(0.1))
                    .frame(width: 150, height: 150)
                    .offset(x: geometry.size.width - 80, y: geometry.size.height * 0.6)
                
                Circle()
                    .fill(Color.sunnyYellow.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .offset(x: geometry.size.width * 0.3, y: geometry.size.height * 0.15)
            }
            
            VStack(spacing: 24) {
                // App icon/logo with playful animation
                Image(systemName: "fish.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.aquaHighlight, Color.coralAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(scale)
                    .rotationEffect(.degrees(rotation))
                
                Text("Reel Royale")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("King of the Hill Fishing")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.aquaHighlight)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .aquaHighlight))
                    .scaleEffect(1.2)
                    .padding(.top, 32)
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                scale = 1.0
                opacity = 1.0
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                rotation = 5
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState.shared)
}

