import SwiftUI

/// Reusable animated water strip — anchored to its frame's bottom, looping wave.
/// Used as a decorative depth element behind avatars, cards, banners.
struct WaveStrip: View {
    var amplitude: CGFloat = 10
    var frequency: CGFloat = 0.022
    var color: Color? = nil    // nil = use theme tideTeal

    @Environment(\.reelTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Double = 0

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { _ in
            Canvas { context, size in
                let baseY = size.height * 0.5
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: baseY))
                var x: CGFloat = 0
                while x <= size.width {
                    let y = baseY + amplitude * CGFloat(sin(Double(x) * Double(frequency) + phase))
                    path.addLine(to: CGPoint(x: x, y: y))
                    x += 4
                }
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()
                let fillColor = color ?? theme.colors.brand.tideTeal
                context.fill(path, with: .linearGradient(
                    Gradient(colors: [fillColor.opacity(0.55), fillColor.opacity(0.85)]),
                    startPoint: CGPoint(x: 0, y: baseY),
                    endPoint: CGPoint(x: 0, y: size.height)
                ))
                // Crest highlight
                var ridge = Path()
                x = 0
                ridge.move(to: CGPoint(x: 0, y: baseY))
                while x <= size.width {
                    let y = baseY + amplitude * CGFloat(sin(Double(x) * Double(frequency) + phase))
                    ridge.addLine(to: CGPoint(x: x, y: y))
                    x += 4
                }
                context.stroke(ridge, with: .color(.white.opacity(0.18)), lineWidth: 1.2)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}
