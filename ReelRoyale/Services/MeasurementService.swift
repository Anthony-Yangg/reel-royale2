import Foundation
import ARKit
import RealityKit
import SceneKit
import Combine

/// Protocol for fish measurement operations
protocol MeasurementServiceProtocol {
    /// Check if AR measurement is available on this device
    var isARAvailable: Bool { get }
    
    /// Start an AR measurement session
    func startSession() async throws
    
    /// Stop the current AR session
    func stopSession()
    
    /// Get the current measured distance (if any)
    var currentMeasurement: Double? { get }
    
    /// Publisher for measurement updates
    var measurementPublisher: AnyPublisher<Double?, Never> { get }
    
    /// Capture the current measurement
    func captureMeasurement() -> Double?
}

/// ARKit-based fish length measurement service
final class ARMeasurementService: NSObject, MeasurementServiceProtocol {
    private var arSession: ARSession?
    weak var arView: ARSCNView?
    private var startPoint: simd_float3?
    private var endPoint: simd_float3?
    
    private let measurementSubject = CurrentValueSubject<Double?, Never>(nil)
    
    var currentMeasurement: Double? {
        measurementSubject.value
    }
    
    var measurementPublisher: AnyPublisher<Double?, Never> {
        measurementSubject.eraseToAnyPublisher()
    }
    
    var isARAvailable: Bool {
        ARWorldTrackingConfiguration.isSupported
    }
    
    func attach(to view: ARSCNView) {
        arView = view
        arSession = view.session
        arSession?.delegate = self
    }
    
    func startSession() async throws {
        guard isARAvailable else {
            throw AppError.validationError("AR is not supported on this device")
        }
        
        let session: ARSession
        if let existingSession = arSession {
            session = existingSession
        } else if let viewSession = arView?.session {
            session = viewSession
        } else {
            session = ARSession()
        }
        
        arSession = session
        arView?.session = session
        session.delegate = self
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    func stopSession() {
        arSession?.pause()
        arSession = nil
        startPoint = nil
        endPoint = nil
        measurementSubject.send(nil)
    }
    
    func setStartPoint(_ point: simd_float3) {
        startPoint = point
        updateMeasurement()
    }
    
    func setEndPoint(_ point: simd_float3) {
        endPoint = point
        updateMeasurement()
    }
    
    func captureMeasurement() -> Double? {
        currentMeasurement
    }
    
    private func updateMeasurement() {
        guard let start = startPoint, let end = endPoint else {
            measurementSubject.send(nil)
            return
        }
        
        // Calculate distance in meters
        let distance = simd_distance(start, end)
        
        // Convert to centimeters
        let distanceInCm = Double(distance) * 100
        
        measurementSubject.send(distanceInCm)
    }
    
    /// Perform a hit test at a screen point
    func hitTest(at point: CGPoint, in view: ARSCNView) -> simd_float3? {
        let results = view.hitTest(point, types: [.featurePoint, .estimatedHorizontalPlane])
        
        guard let result = results.first else { return nil }
        
        return simd_float3(
            result.worldTransform.columns.3.x,
            result.worldTransform.columns.3.y,
            result.worldTransform.columns.3.z
        )
    }
}

// MARK: - ARSessionDelegate

extension ARMeasurementService: ARSessionDelegate {
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("AR Session failed: \(error.localizedDescription)")
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        print("AR Session was interrupted")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        print("AR Session interruption ended")
    }
}

// MARK: - Measurement Result

struct MeasurementResult: Equatable {
    let lengthInCm: Double
    let unit: String
    let capturedAt: Date
    
    init(lengthInCm: Double, unit: String = "cm", capturedAt: Date = Date()) {
        self.lengthInCm = lengthInCm
        self.unit = unit
        self.capturedAt = capturedAt
    }
    
    var formattedLength: String {
        String(format: "%.1f %@", lengthInCm, unit)
    }
    
    /// Convert to inches
    var lengthInInches: Double {
        lengthInCm / 2.54
    }
    
    var formattedLengthInInches: String {
        String(format: "%.1f in", lengthInInches)
    }
}

