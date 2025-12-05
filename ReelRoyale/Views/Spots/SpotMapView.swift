import SwiftUI
import MapKit

struct SpotMapView: View {
    let spots: [SpotWithDetails]
    @Binding var selectedSpot: Spot?
    @Binding var region: MKCoordinateRegion
    
    var body: some View {
        Map {
            ForEach(spots) { spotDetails in
                Annotation(spotDetails.spot.name, coordinate: spotDetails.spot.coordinate) {
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
        }
        .mapStyle(.standard(elevation: .realistic))
        .ignoresSafeArea(edges: .bottom)
    }
}

struct SpotMapPin: View {
    let spotDetails: SpotWithDetails
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
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
    
    private var pinColor: Color {
        if spotDetails.spot.hasKing {
            return Color.crown
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

