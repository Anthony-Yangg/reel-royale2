import SwiftUI

/// Drifting gold sparkles for ambient depth. Cheap Canvas-based.
struct FloatingSparkles: View {
    var count: Int = 32

    @Environment(\.reelTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { ctx in
            Canvas { context, size in
                let t = ctx.date.timeIntervalSince1970.truncatingRemainder(dividingBy: 1000)
                for i in 0..<count {
                    let dx = Double(i) * 0.211
                    let dy = Double(i) * 0.487
                    let x = size.width * CGFloat((dx + t * 0.012).truncatingRemainder(dividingBy: 1.0))
                    let yBase = size.height * CGFloat((dy + t * 0.008).truncatingRemainder(dividingBy: 1.0))
                    let drift = 4 * CGFloat(sin(t * 0.6 + Double(i)))
                    let alpha = 0.20 + 0.45 * abs(sin(t * 0.8 + Double(i)))
                    let r: CGFloat = i % 6 == 0 ? 3 : 2
                    let rect = CGRect(x: x, y: yBase + drift, width: r, height: r)
                    context.fill(Path(ellipseIn: rect),
                                 with: .color(theme.colors.brand.crown.opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
