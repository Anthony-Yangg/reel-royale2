import Foundation
import CoreLocation

// MARK: - Protocols

protocol WaterbodyRepositoryProtocol {
    func getWaterbodies(near coordinate: CLLocationCoordinate2D, radiusMeters: Double) async -> [Waterbody]
    func getWaterbody(byId id: String) async -> Waterbody?
}

protocol SpotGenerationServiceProtocol {
    func generateSpots(for waterbody: Waterbody) -> [Spot]
}

enum SpotAssignmentResult {
    case assigned(Spot)
    case ambiguous([Spot]) // User needs to choose
    case none // No matching spot found
}

protocol SpotAssignmentServiceProtocol {
    func assignSpot(for coordinate: CLLocationCoordinate2D, waterbodyId: String?) async -> SpotAssignmentResult
}

enum SpotCreationError: Error, LocalizedError {
    case tooCloseToExisting(Double)
    case maxSpotsReached(Int)
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .tooCloseToExisting(let dist):
            return "Too close to an existing spot (\(Int(dist))m away)."
        case .maxSpotsReached(let max):
            return "This waterbody has reached its limit of \(max) spots."
        case .invalidData:
            return "Invalid spot data."
        }
    }
}

protocol SpotCreationServiceProtocol {
    func validateNewSpot(waterbody: Waterbody, coordinate: CLLocationCoordinate2D) async throws
    func createSpot(waterbody: Waterbody, name: String, coordinate: CLLocationCoordinate2D) async throws -> Spot
}

// MARK: - Implementations

/// Mock Waterbody Repository
class MockWaterbodyRepository: WaterbodyRepositoryProtocol {
    private let waterbodies: [Waterbody] = [
        Waterbody(
            id: "wb_1",
            name: "Lake Evergreen",
            type: .lake,
            latitude: 37.7749,
            longitude: -122.4194,
            sizeTier: .medium
        ),
        Waterbody(
            id: "wb_2",
            name: "Crystal River",
            type: .river,
            latitude: 37.8000,
            longitude: -122.4500,
            sizeTier: .large
        ),
        Waterbody(
            id: "wb_3",
            name: "Fisherman's Pier",
            type: .pier,
            latitude: 37.8100,
            longitude: -122.4100,
            sizeTier: .tiny
        )
    ]
    
    func getWaterbodies(near coordinate: CLLocationCoordinate2D, radiusMeters: Double) async -> [Waterbody] {
        // Simple linear search for mock
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return waterbodies.filter { wb in
            let wbLoc = CLLocation(latitude: wb.latitude, longitude: wb.longitude)
            return wbLoc.distance(from: location) <= radiusMeters
        }
    }
    
    func getWaterbody(byId id: String) async -> Waterbody? {
        waterbodies.first { $0.id == id }
    }
}

/// Service to generate default spots for waterbodies
class SpotGenerationService: SpotGenerationServiceProtocol {
    
    func generateSpots(for waterbody: Waterbody) -> [Spot] {
        // Deterministic generation based on waterbody ID/Coordinate to keep it consistent in mock
        // In real app, this would run once and persist to DB.
        
        var spots: [Spot] = []
        let center = waterbody.coordinate
        
        switch waterbody.type {
        case .lake, .pond, .reservoir:
            spots = generateLakeSpots(for: waterbody, center: center)
        case .river, .creek, .canal, .stream:
            spots = generateRiverSpots(for: waterbody, center: center)
        case .pier:
            spots = generatePierSpots(for: waterbody, center: center)
        case .coast, .bay, .ocean:
            spots = generateRiverSpots(for: waterbody, center: center) // Treat like linear stretch for now
        }
        
        return spots
    }
    
    private func generateLakeSpots(for wb: Waterbody, center: CLLocationCoordinate2D) -> [Spot] {
        var spots: [Spot] = []
        let count = min(wb.sizeTier.maxSpots, 4) // Cap for mock
        let radius = getRadius(for: wb)
        
        if wb.sizeTier == .tiny {
            // One spot at center
            spots.append(createSpot(wb: wb, name: "Main Pool", lat: center.latitude, lon: center.longitude, radius: radius))
        } else {
            // Generate around center
            let offsets = [(0.002, 0.0), (-0.002, 0.0), (0.0, 0.002), (0.0, -0.002)]
            for i in 0..<count {
                let offset = offsets[i % offsets.count]
                spots.append(createSpot(
                    wb: wb,
                    name: "\(wb.name) - Spot \(i + 1)",
                    lat: center.latitude + offset.0,
                    lon: center.longitude + offset.1,
                    radius: radius
                ))
            }
        }
        return spots
    }
    
    private func generateRiverSpots(for wb: Waterbody, center: CLLocationCoordinate2D) -> [Spot] {
        // Linear generation simulation
        var spots: [Spot] = []
        let count = min(wb.sizeTier.maxSpots, 5)
        let radius = getRadius(for: wb)
        
        for i in 0..<count {
            // Spread out along a diagonal line for mock
            let latOffset = Double(i) * 0.004
            let lonOffset = Double(i) * 0.004
            spots.append(createSpot(
                wb: wb,
                name: "\(wb.name) - Reach \(i + 1)",
                lat: center.latitude + latOffset,
                lon: center.longitude + lonOffset,
                radius: radius
            ))
        }
        return spots
    }
    
    private func generatePierSpots(for wb: Waterbody, center: CLLocationCoordinate2D) -> [Spot] {
        let radius = 150.0
        return [createSpot(wb: wb, name: "\(wb.name) - End", lat: center.latitude, lon: center.longitude, radius: radius)]
    }
    
    private func getRadius(for wb: Waterbody) -> Double {
        switch wb.sizeTier {
        case .tiny: return 200
        case .small, .medium: return 300
        case .large: return 400
        }
    }
    
    private func createSpot(wb: Waterbody, name: String, lat: Double, lon: Double, radius: Double) -> Spot {
        // Use stable UUID for mock based on name
        let uuid = UUID(uuidString: "00000000-0000-0000-0000-\(String(name.hash).prefix(12))") ?? UUID()
        
        return Spot(
            id: uuid.uuidString,
            name: name,
            description: "Generated spot for \(wb.name)",
            latitude: lat,
            longitude: lon,
            radius: radius,
            waterbodyId: wb.id,
            waterType: wb.type
        )
    }
}

/// Service to assign catches to spots
class SpotAssignmentService: SpotAssignmentServiceProtocol {
    private let spotRepository: SpotRepositoryProtocol
    
    init(spotRepository: SpotRepositoryProtocol) {
        self.spotRepository = spotRepository
    }
    
    func assignSpot(for coordinate: CLLocationCoordinate2D, waterbodyId: String?) async -> SpotAssignmentResult {
        var candidates: [Spot] = []
        
        // 1. Get potential spots
        if let wbId = waterbodyId {
            // Fetch spots for this waterbody
            // Note: We need to add getSpots(forWaterbody:) to repository
            // For now, we'll fetch all (or rely on near) and filter
            // Assuming repository update.
            candidates = (try? await spotRepository.getAllSpots().filter { $0.waterbodyId == wbId }) ?? []
        } else {
            // Search nearby
            candidates = (try? await spotRepository.getSpots(near: coordinate, radiusMeters: 2000)) ?? []
        }
        
        // 2. Filter by containment
        let containingSpots = candidates.filter { $0.contains(coordinate: coordinate) }
        
        if let bestMatch = containingSpots.min(by: {
            let dist1 = $0.location.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
            let dist2 = $1.location.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
            return dist1 < dist2
        }) {
            return .assigned(bestMatch)
        }
        
        // 3. If no containment, look for "nearby" (ambiguous)
        let nearbyRadius = 1000.0 // 1km buffer
        let nearbySpots = candidates.filter {
            let dist = $0.location.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
            return dist <= ($0.radius + nearbyRadius)
        }
        
        if !nearbySpots.isEmpty {
            return .ambiguous(nearbySpots)
        }
        
        return .none
    }
}

/// Service for creating new spots with guardrails
class SpotCreationService: SpotCreationServiceProtocol {
    private let spotRepository: SpotRepositoryProtocol
    
    init(spotRepository: SpotRepositoryProtocol) {
        self.spotRepository = spotRepository
    }
    
    func validateNewSpot(waterbody: Waterbody, coordinate: CLLocationCoordinate2D) async throws {
        // 1. Check max spots
        let existingSpots = (try? await spotRepository.getAllSpots().filter { $0.waterbodyId == waterbody.id }) ?? []
        if existingSpots.count >= waterbody.sizeTier.maxSpots {
            throw SpotCreationError.maxSpotsReached(waterbody.sizeTier.maxSpots)
        }
        
        // 2. Check minimum distance
        let minDistance = 200.0
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        for spot in existingSpots {
            if spot.location.distance(from: location) < minDistance {
                throw SpotCreationError.tooCloseToExisting(minDistance)
            }
        }
    }
    
    func createSpot(waterbody: Waterbody, name: String, coordinate: CLLocationCoordinate2D) async throws -> Spot {
        try await validateNewSpot(waterbody: waterbody, coordinate: coordinate)
        
        // Determine radius
        let radius: Double
        switch waterbody.sizeTier {
        case .tiny: radius = 200
        case .small, .medium: radius = 250
        case .large: radius = 300
        }
        
        let newSpot = Spot(
            name: name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radius: radius,
            waterbodyId: waterbody.id,
            waterType: waterbody.type
        )
        
        return try await spotRepository.createSpot(newSpot)
    }
}

