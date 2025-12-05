import Foundation
import Combine
import ARKit

/// ViewModel for AR Fish Measurement screen
@MainActor
final class MeasurementViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var currentLength: Double?
    @Published var measurementState: MeasurementState = .ready
    @Published var isSessionActive = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var instructions: String = "Point your camera at a flat surface to start measuring"
    
    // MARK: - Private Properties
    
    private let measurementService: MeasurementServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Enums
    
    enum MeasurementState: Equatable {
        case ready
        case scanning
        case startPointSet
        case measuring
        case completed
    }
    
    // MARK: - Computed Properties
    
    var formattedLength: String {
        guard let length = currentLength else { return "--" }
        return String(format: "%.1f cm", length)
    }
    
    var formattedLengthInInches: String {
        guard let length = currentLength else { return "--" }
        return String(format: "%.1f in", length / 2.54)
    }
    
    var isARAvailable: Bool {
        measurementService.isARAvailable
    }
    
    var canCapture: Bool {
        measurementState == .completed && currentLength != nil
    }
    
    // MARK: - Initialization
    
    init(measurementService: MeasurementServiceProtocol? = nil) {
        self.measurementService = measurementService ?? AppState.shared.measurementService
        setupBindings()
    }
    
    private func setupBindings() {
        measurementService.measurementPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] length in
                self?.currentLength = length
                if length != nil {
                    self?.measurementState = .measuring
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    
    func startSession() async {
        guard isARAvailable else {
            showError(message: "AR is not available on this device")
            return
        }
        
        do {
            try await measurementService.startSession()
            isSessionActive = true
            measurementState = .scanning
            instructions = "Move your device to scan the surface"
        } catch {
            showError(message: "Failed to start AR session: \(error.localizedDescription)")
        }
    }
    
    func stopSession() {
        measurementService.stopSession()
        isSessionActive = false
        measurementState = .ready
        currentLength = nil
    }
    
    func setStartPoint() {
        measurementState = .startPointSet
        instructions = "Now tap the other end of the fish"
    }
    
    func setEndPoint() {
        if measurementState == .startPointSet {
            measurementState = .completed
            instructions = "Measurement complete! Tap Capture to use this measurement"
        }
    }
    
    func captureMeasurement() -> Double? {
        measurementService.captureMeasurement()
    }
    
    func resetMeasurement() {
        currentLength = nil
        measurementState = .scanning
        instructions = "Tap the head of the fish to start measuring"
    }
    
    // MARK: - Helpers
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - AR View Coordinator

/// Coordinator for ARSCNView interactions
class ARMeasurementCoordinator: NSObject, ARSCNViewDelegate {
    var viewModel: MeasurementViewModel
    var startPoint: simd_float3?
    weak var arView: ARSCNView?
    
    init(viewModel: MeasurementViewModel) {
        self.viewModel = viewModel
    }
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let arView = gesture.view as? ARSCNView else { return }
        let location = gesture.location(in: arView)
        handleTap(at: location, in: arView)
    }
    
    func handleTap(at point: CGPoint, in view: ARSCNView) {
        Task { @MainActor in
            guard let service = AppState.shared.measurementService as? ARMeasurementService else {
                return
            }
            
            guard let hitPoint = service.hitTest(at: point, in: view) else { return }
            
            switch viewModel.measurementState {
            case .scanning:
                service.setStartPoint(hitPoint)
                startPoint = hitPoint
                viewModel.setStartPoint()
                
            case .startPointSet:
                service.setEndPoint(hitPoint)
                viewModel.setEndPoint()
                
            default:
                break
            }
        }
    }
}

