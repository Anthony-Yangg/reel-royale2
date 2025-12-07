import SwiftUI
import ARKit
import SceneKit

/// Helper class for AR measurement visualization
class ARMeasurementHelper {
    var startNode: SCNNode?
    var endNode: SCNNode?
    var lineNode: SCNNode?
    
    func createSphereNode(at position: SCNVector3, color: UIColor) -> SCNNode {
        let sphere = SCNSphere(radius: 0.005) // 5mm radius
        sphere.firstMaterial?.diffuse.contents = color
        sphere.firstMaterial?.lightingModel = .constant
        
        let node = SCNNode(geometry: sphere)
        node.position = position
        
        return node
    }
    
    func updateLine(from start: SCNVector3, to end: SCNVector3, in scene: SCNScene) {
        // Remove existing line
        lineNode?.removeFromParentNode()
        
        // Create line geometry
        let source = SCNGeometrySource(vertices: [start, end])
        let indices: [Int32] = [0, 1]
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        
        let lineGeometry = SCNGeometry(sources: [source], elements: [element])
        lineGeometry.firstMaterial?.diffuse.contents = UIColor.systemGreen
        lineGeometry.firstMaterial?.lightingModel = .constant
        
        lineNode = SCNNode(geometry: lineGeometry)
        scene.rootNode.addChildNode(lineNode!)
    }
    
    func reset(in scene: SCNScene) {
        startNode?.removeFromParentNode()
        endNode?.removeFromParentNode()
        lineNode?.removeFromParentNode()
        
        startNode = nil
        endNode = nil
        lineNode = nil
    }
    
    func setStartPoint(_ position: SCNVector3, in scene: SCNScene) {
        startNode?.removeFromParentNode()
        startNode = createSphereNode(at: position, color: .systemBlue)
        scene.rootNode.addChildNode(startNode!)
    }
    
    func setEndPoint(_ position: SCNVector3, in scene: SCNScene) {
        endNode?.removeFromParentNode()
        endNode = createSphereNode(at: position, color: .systemGreen)
        scene.rootNode.addChildNode(endNode!)
        
        if let startPos = startNode?.position {
            updateLine(from: startPos, to: position, in: scene)
        }
    }
}

extension ARMeasurementCoordinator {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // Could add real-time measurement updates here
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Handle anchor additions
    }
}

/// AR Measurement guidelines overlay
struct ARMeasurementGuidelines: View {
    let state: MeasurementViewModel.MeasurementState
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                // Center crosshair
                Image(systemName: "plus")
                    .font(.title)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                
                Spacer()
            }
            
            Spacer()
            
            // Guide lines
            if state == .scanning || state == .startPointSet {
                HStack(spacing: 40) {
                    VStack {
                        Circle()
                            .stroke(Color.seafoam, lineWidth: 2)
                            .frame(width: 20, height: 20)
                        Text("Head")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(height: 2)
                        .frame(maxWidth: 100)
                    
                    VStack {
                        Circle()
                            .stroke(Color.green, lineWidth: 2)
                            .frame(width: 20, height: 20)
                        Text("Tail")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 100)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black
        ARMeasurementGuidelines(state: .scanning)
    }
}

