import SwiftUI

/// The center catch button that hovers above the tab bar.
/// Tapping opens the catch flow.
struct CenterFAB: View {
    let action: () -> Void

    @Environment(\.reelTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var appState: AppState
    @State private var idleScale: CGFloat = 1.0
    @State private var isPressed = false

    var body: some View {
        Button {
            AppFeedback.heavy.play(appState: appState)
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.22))
                    .frame(width: 82, height: 82)
                    .blur(radius: 18)
                    .offset(y: 8)

                Circle()
                    .fill(Color.black)
                    .frame(width: 72, height: 72)
                    .opacity(0.26)
                    .blur(radius: 8)
                    .offset(y: 3)

                Circle()
                    .fill(Color.white)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.black.opacity(0.92), lineWidth: 3)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.82), lineWidth: 1)
                            .padding(5)
                    )
                    .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 10)

                Image(systemName: "fish.fill")
                    .font(.system(size: 27, weight: .black))
                    .foregroundStyle(Color.black)
            }
            .scaleEffect(isPressed ? 0.92 : idleScale)
        }
        .buttonStyle(PressFeedbackStyle(isPressed: $isPressed))
        .animation(theme.motion.fast, value: isPressed)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: theme.motion.ambientDuration).repeatForever(autoreverses: true)) {
                idleScale = 1.04
            }
        }
        .accessibilityLabel("Log a catch")
    }
}

#Preview {
    CenterFAB(action: {})
        .padding()
        .background(ReelTheme.default.colors.surface.canvas)
        .environment(\.reelTheme, .default)
        .environmentObject(AppState.shared)
        .preferredColorScheme(.light)
}
