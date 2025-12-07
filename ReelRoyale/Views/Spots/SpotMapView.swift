import SwiftUI
import MapKit
import MapboxMaps
import UIKit

struct SpotMapView: View {
    let spots: [SpotWithDetails]
    @Binding var selectedSpot: Spot?
    @Binding var region: MKCoordinateRegion
    
    var body: some View {
        MapboxSpotsView(spots: spots, selectedSpot: $selectedSpot, region: $region)
            .ignoresSafeArea()
    }
}

struct MapboxSpotsView: UIViewRepresentable {
    let spots: [SpotWithDetails]
    @Binding var selectedSpot: Spot?
    @Binding var region: MKCoordinateRegion
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    @MainActor
    func makeUIView(context: Context) -> MapView {
        let camera = CameraOptions(center: region.centerCoordinate, zoom: region.approxZoom)
        let initOptions = MapInitOptions(cameraOptions: camera)
        let mapView = MapView(frame: .zero, mapInitOptions: initOptions)
        mapView.ornaments.options.scaleBar.visibility = OrnamentVisibility.hidden
        mapView.ornaments.options.logo.position = OrnamentPosition.bottomLeft
        context.coordinator.attach(mapView: mapView)
        context.coordinator.syncCameraToRegion(region)
        context.coordinator.renderAnnotations(spots: spots, selectedId: selectedSpot?.id)
        return mapView
    }
    
    @MainActor
    func updateUIView(_ mapView: MapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.syncCameraIfNeeded()
        context.coordinator.renderAnnotations(spots: spots, selectedId: selectedSpot?.id)
    }
    
    final class Coordinator: NSObject, AnnotationInteractionDelegate {
        var parent: MapboxSpotsView
        weak var mapView: MapView?
        var annotationManager: PointAnnotationManager?
        var cameraCancelable: Cancelable?
        
        init(parent: MapboxSpotsView) {
            self.parent = parent
        }
        
        deinit {
            cameraCancelable?.cancel()
        }
        
        func attach(mapView: MapView) {
            self.mapView = mapView
            cameraCancelable = mapView.mapboxMap.onEvery(event: .cameraChanged) { [weak self] _ in
                self?.updateRegionFromCamera()
            }
            annotationManager = mapView.annotations.makePointAnnotationManager()
            annotationManager?.delegate = self
        }
        
        func syncCameraToRegion(_ region: MKCoordinateRegion) {
            guard let mapView else { return }
            let camera = CameraOptions(center: region.centerCoordinate, zoom: region.approxZoom)
            mapView.mapboxMap.setCamera(to: camera)
        }
        
        func syncCameraIfNeeded() {
            guard let mapView else { return }
            let camera = mapView.mapboxMap.cameraState
            let target = parent.region
            let deltaLat = abs(camera.center.latitude - target.center.latitude)
            let deltaLon = abs(camera.center.longitude - target.center.longitude)
            if deltaLat > 0.0001 || deltaLon > 0.0001 {
                syncCameraToRegion(target)
            }
        }
        
        @MainActor
        func renderAnnotations(spots: [SpotWithDetails], selectedId: String?) {
            guard let manager = annotationManager else { return }
            manager.annotations = spots.map { spotDetails in
                var annotation = PointAnnotation(id: spotDetails.id, coordinate: spotDetails.spot.coordinate)
                annotation.image = image(for: spotDetails, isSelected: spotDetails.id == selectedId)
                annotation.iconAnchor = .bottom
                return annotation
            }
        }
        
        func annotationManager(_ manager: AnnotationManager, didDetectTappedAnnotations annotations: [MapboxMaps.Annotation]) {
            guard
                let first = annotations.first,
                let mapView,
                let spot = parent.spots.first(where: { $0.id == first.id })
            else { return }
            
            parent.selectedSpot = spot.spot
            let camera = CameraOptions(center: spot.spot.coordinate, zoom: max(mapView.mapboxMap.cameraState.zoom, 12))
            mapView.mapboxMap.setCamera(to: camera)
        }
        
        @MainActor
        private func image(for spotDetails: SpotWithDetails, isSelected: Bool) -> PointAnnotation.Image? {
            let renderer = ImageRenderer(content: SpotMapPin(spotDetails: spotDetails, isSelected: isSelected))
            renderer.scale = UIScreen.main.scale
            guard let uiImage = renderer.uiImage else { return nil }
            return .init(image: uiImage, name: "pin-\(spotDetails.id)-\(isSelected ? "sel" : "base")")
        }
        
        private func updateRegionFromCamera() {
            guard let mapView else { return }
            let state = mapView.mapboxMap.cameraState
            let span = MKCoordinateSpan(
                latitudeDelta: state.latitudeDelta(for: mapView.frame.size),
                longitudeDelta: state.longitudeDelta(for: mapView.frame.size)
            )
            parent.region = MKCoordinateRegion(center: state.center, span: span)
        }
    }
}

struct SpotMapPin: View {
    let spotDetails: SpotWithDetails
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(pinColor)
                    .frame(width: isSelected ? 50 : 40, height: isSelected ? 50 : 40)
                    .shadow(color: pinColor.opacity(0.5), radius: isSelected ? 8 : 4)
                
                Image(systemName: spotDetails.spot.waterType?.icon ?? "mappin")
                    .font(.system(size: isSelected ? 20 : 16))
                    .foregroundColor(.white)
                
                if spotDetails.spot.hasKing {
                    CrownBadge(size: .small)
                        .offset(x: 16, y: -16)
                }
            }
            
            Triangle()
                .fill(pinColor)
                .frame(width: 12, height: 8)
                .offset(y: -2)
            
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

private extension MKCoordinateRegion {
    var centerCoordinate: CLLocationCoordinate2D {
        center
    }
    
    var approxZoom: Double {
        let width = Double(UIScreen.main.bounds.width * UIScreen.main.scale)
        guard width > 0 else { return 12 }
        let degreesPerPixel = span.longitudeDelta / width
        let zoom = log2(360 / (degreesPerPixel * 256))
        return max(0, min(20, zoom))
    }
}

private extension CameraState {
    func latitudeDelta(for size: CGSize) -> CLLocationDegrees {
        let degreesPerPixel = 360 / (256 * pow(2, zoom))
        return degreesPerPixel * CLLocationDegrees(size.height)
    }
    
    func longitudeDelta(for size: CGSize) -> CLLocationDegrees {
        let degreesPerPixel = 360 / (256 * pow(2, zoom))
        return degreesPerPixel * CLLocationDegrees(size.width)
    }
}

