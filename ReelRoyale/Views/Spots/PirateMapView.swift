import SwiftUI
import MapKit

/// Pirate-themed Apple Map with treasure-chest pins overlaying real geography.
/// iOS 17+ Map content-builder API.
struct PirateMapView: View {
    let spots: [SpotWithDetails]
    @Binding var selectedSpot: Spot?
    @Binding var cameraPosition: MapCameraPosition
    var currentUserId: String? = nil

    @Environment(\.reelTheme) private var theme

    var body: some View {
        Map(position: $cameraPosition, interactionModes: .all, selection: spotSelectionBinding) {
            UserAnnotation()
            ForEach(spots, id: \.spot.id) { sd in
                Annotation(sd.spot.name, coordinate: sd.spot.coordinate, anchor: .bottom) {
                    TreasureChestPin(
                        variant: variant(for: sd),
                        spotName: sd.spot.name,
                        isSelected: selectedSpot?.id == sd.spot.id
                    ) {
                        withAnimation(theme.motion.standard) {
                            selectedSpot = sd.spot
                        }
                    }
                }
                .tag(sd.spot.id)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .overlay(alignment: .bottom) {
            // Subtle teal scrim near bottom — gives water a hint of pirate teal
            LinearGradient(
                colors: [theme.colors.brand.deepSea.opacity(0.0), theme.colors.brand.deepSea.opacity(0.25)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 100)
            .allowsHitTesting(false)
        }
    }

    private var spotSelectionBinding: Binding<String?> {
        Binding(
            get: { selectedSpot?.id },
            set: { newId in
                if let id = newId, let spot = spots.first(where: { $0.spot.id == id })?.spot {
                    selectedSpot = spot
                } else {
                    selectedSpot = nil
                }
            }
        )
    }

    private func variant(for sd: SpotWithDetails) -> TreasureChestPin.Variant {
        if let kingId = sd.spot.currentKingUserId, kingId == currentUserId {
            return .claimedByYou
        }
        if sd.spot.hasKing {
            // Tier unknown in Wave 3 (joined data lands Wave 5); default to firstMate visual.
            return .claimedByOther(tier: .firstMate)
        }
        return .vacant
    }
}
