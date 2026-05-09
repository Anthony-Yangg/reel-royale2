import SwiftUI
import MapKit

struct SpotMapView: View {
    let spots: [SpotWithDetails]
    @Binding var selectedSpot: Spot?
    @Binding var region: MKCoordinateRegion
    
    var body: some View {
        Map(coordinateRegion: $region, annotationItems: spots) { spotDetails in
            MapAnnotation(coordinate: spotDetails.spot.coordinate) {
                SpotMapPin(
                    spotDetails: spotDetails,
                    isSelected: selectedSpot?.id == spotDetails.spot.id
                )
                .onTapGesture {
                    withAnimation(.spring()) {
                        selectedSpot = spotDetails.spot
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

struct SpotMapPin: View {
    let spotDetails: SpotWithDetails
    let isSelected: Bool
    @State private var pulse: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Hot-spot pulse: spots fished in the last 24h glow.
                if isHot {
                    Circle()
                        .fill(Color.coral.opacity(0.35))
                        .frame(width: 70, height: 70)
                        .scaleEffect(pulse ? 1.15 : 0.85)
                        .opacity(pulse ? 0.0 : 0.6)
                        .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: pulse)
                        .onAppear { pulse = true }
                }

                // Pin background
                Circle()
                    .fill(pinColor)
                    .frame(width: isSelected ? 50 : 40, height: isSelected ? 50 : 40)
                    .shadow(color: pinColor.opacity(0.5), radius: isSelected ? 8 : 4)

                // Water type icon
                Image(systemName: spotDetails.spot.waterType?.icon ?? "mappin")
                    .font(.system(size: isSelected ? 20 : 16))
                    .foregroundColor(.white)

                // Crown for spots with kings
                if spotDetails.spot.hasKing {
                    CrownBadge(size: .small)
                        .offset(x: 16, y: -16)
                }
            }

            // Pin pointer
            Triangle()
                .fill(pinColor)
                .frame(width: 12, height: 8)
                .offset(y: -2)

            // Spot name (only when selected)
            if isSelected {
                Text(spotDetails.spot.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemBackground))
                    .cornerRadius(4)
                    .shadow(radius: 2)
                    .padding(.top, 4)
            }
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }

    /// "Hot" = activity in the last 24h. Used for the pulse animation.
    private var isHot: Bool {
        guard let last = spotDetails.spot.lastCatchAt else { return false }
        return Date().timeIntervalSince(last) < 86400
    }

    /// Three-tier coloring:
    /// - Crown: spot has a king
    /// - Coral: hot (active in last 24h) but unclaimed
    /// - Ocean: dormant or stale
    /// - Gray: cold (no catch in 7+ days)
    private var pinColor: Color {
        if spotDetails.spot.hasKing { return Color.crown }
        if let last = spotDetails.spot.lastCatchAt {
            let age = Date().timeIntervalSince(last)
            if age < 86400 { return Color.coral }
            if age > 7 * 86400 { return Color.gray }
        } else {
            return Color.gray
        }
        return Color.oceanBlue
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    SpotMapView(
        spots: [],
        selectedSpot: .constant(nil),
        region: .constant(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        ))
    )
}

