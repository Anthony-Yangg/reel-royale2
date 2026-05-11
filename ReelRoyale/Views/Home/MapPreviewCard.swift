import SwiftUI
import MapKit

/// Small map preview card on Home. Tap → open Map tab.
struct MapPreviewCard: View {
    let onOpenMap: () -> Void

    @Environment(\.reelTheme) private var theme
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
    )

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            SectionHeader(
                title: "Nearby Waters",
                trailingActionTitle: "Open Map",
                trailingAction: onOpenMap
            )
            Button(action: onOpenMap) {
                ZStack(alignment: .bottomLeading) {
                    Map(initialPosition: .region(region))
                        .frame(height: 170)
                        .disabled(true)
                        .overlay(
                            // Stylized teal tint over water
                            theme.colors.brand.deepSea.opacity(0.25)
                        )
                        .overlay(alignment: .bottom) {
                            WaveStrip(amplitude: 8, frequency: 0.025)
                                .frame(height: 32)
                                .opacity(0.7)
                                .allowsHitTesting(false)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(theme.colors.brand.crown)
                        Text("3 spots within 5mi · 1 vacant")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(theme.colors.text.primary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(theme.colors.surface.elevated.opacity(0.92))
                    )
                    .padding(theme.spacing.s)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                        .strokeBorder(theme.colors.brand.brassGold.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}
