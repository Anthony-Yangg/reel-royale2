import SwiftUI
import MapKit

struct SpotMapView: View {
    let spots: [SpotWithDetails]
    @Binding var selectedSpot: Spot?
    @Binding var region: MKCoordinateRegion
    
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selection: String?
    
    var body: some View {
        Map(position: $cameraPosition, selection: $selection) {
            ForEach(spots) { spotDetails in
                let radius = max(spotDetails.spot.radius, 200) // fallback so circles stay visible
                
                // Spot area circle
                MapCircle(center: spotDetails.spot.coordinate, radius: radius)
                    .foregroundStyle(fillColor(for: spotDetails).opacity(0.25))
                    .stroke(strokeColor(for: spotDetails), lineWidth: 2)
                    .tag(spotDetails.spot.id)
                
                // Pin
                Annotation(spotDetails.spot.name, coordinate: spotDetails.spot.coordinate) {
                    SpotMapPin(
                        spotDetails: spotDetails,
                        isSelected: selection == spotDetails.spot.id
                    )
                }
                .tag(spotDetails.spot.id)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .onChange(of: selection) { _, newSelection in
            if let id = newSelection, let spot = spots.first(where: { $0.id == id })?.spot {
                selectedSpot = spot
            } else {
                selectedSpot = nil
            }
        }
        .onChange(of: selectedSpot) { _, newSpot in
            if let spot = newSpot {
                selection = spot.id
                withAnimation {
                    let updatedRegion = MKCoordinateRegion(
                        center: spot.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )
                    region = updatedRegion
                    cameraPosition = .region(updatedRegion)
                }
            } else {
                selection = nil
            }
        }
        .onAppear {
            cameraPosition = .region(region)
        }
    }
    
    private func fillColor(for spotDetails: SpotWithDetails) -> Color {
        spotDetails.spot.hasKing ? Color.crown : Color.oceanBlue
    }
    
    private func strokeColor(for spotDetails: SpotWithDetails) -> Color {
        spotDetails.spot.hasKing ? Color.crown : Color.oceanBlue
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


