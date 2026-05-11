import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.reelTheme) private var theme
    @AppStorage("intro.shown") private var introShown = false
    @State private var introComplete = false

    var body: some View {
        Group {
            if !introShown && !introComplete {
                IntroCinematicView {
                    introShown = true
                    introComplete = true
                }
            } else if appState.isLoading {
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

/// Initial loading screen shown while AppState resolves auth state.
struct LaunchScreen: View {
    @Environment(\.reelTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 0.85
    @State private var opacity: Double = 0.4

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.colors.brand.deepSea, theme.colors.surface.canvas],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: theme.spacing.m) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 72, weight: .black))
                    .foregroundStyle(
                        LinearGradient(colors: [theme.colors.brand.crown, theme.colors.brand.brassGold], startPoint: .top, endPoint: .bottom)
                    )
                    .scaleEffect(scale)
                Text("Reel Royale")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(theme.colors.text.primary)
                Text("King of the Seven Seas")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.colors.brand.brassGold)
                    .tracking(2)
                ShipWheelSpinner(size: 36)
                    .padding(.top, theme.spacing.m)
            }
            .opacity(opacity)
        }
        .onAppear {
            guard !reduceMotion else {
                scale = 1
                opacity = 1
                return
            }
            withAnimation(.easeOut(duration: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState.shared)
        .environment(\.reelTheme, .default)
        .preferredColorScheme(.dark)
}
