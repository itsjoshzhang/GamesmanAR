import SwiftUI
import ARKit
import SceneKit

struct ARController: UIViewRepresentable {
    
    // MARK: - View setup
    
    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView()
        view.showsStatistics = true
        view.autoenablesDefaultLighting = true
        view.session.delegate = context.coordinator
        context.coordinator.sceneView = view
        return view
    }
    
    func updateUIView(_ view: ARSCNView, context: Context) {
        if view.session.configuration == nil {
            let config = ARWorldTrackingConfiguration()
            config.isLightEstimationEnabled = true
            config.planeDetection = .horizontal
            config.worldAlignment = .gravity
            view.session.run(config)
        }
    }
    
    func dismantleUIView(_ view: ARSCNView, coordinator: Coordinator) {
        view.session.pause()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    // MARK: - Main logic
    
    class Coordinator: NSObject, ARSessionDelegate {
        var sceneView: ARSCNView!
        var seenTimes: [Int: Date] = [:]
        var mutexLock = false
        
        // Runs every frame. Gets board+piece transforms,updates nodes
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            if mutexLock { return }
            mutexLock = true
            
            // Returns transforms for all markers based on markerSize
            func detect(_ markerSize: Double) -> [SKWorldTransform] {
                return ArucoCV.estimatePose(frame.capturedImage,
                    withIntrinsics: frame.camera.intrinsics,
                    andMarkerSize: markerSize
                ) as! [SKWorldTransform]
            }
            
            // Filter all transforms into board and piece
            let boardIDs = Constants.FixedMarkerDict.keys
            let boardTransforms = detect(Constants.BoardMarkerSize).filter { boardIDs.contains(Int($0.arucoId)) }
            let pieceTransforms = detect(Constants.PieceMarkerSize).filter {!boardIDs.contains(Int($0.arucoId)) }

            if (boardTransforms + pieceTransforms).isEmpty {
                mutexLock = false
                return
            }
            
            DispatchQueue.main.async {
                self.updateNodes(boardTransforms, pieceTransforms, SCNMatrix4(frame.camera.transform))
                self.mutexLock = false
            }
        }
        
        // Return node if it exists
        func findNode(arucoId: Int) -> ArucoNode? {
            for node in sceneView.scene.rootNode.childNodes {
                if let node = node as? ArucoNode, node.id == arucoId {
                    return node
                }
            }
            return nil
        }
        
        // Send world (rendered) and label (relative) positions
        func updateNodes(_ boardTransforms: [SKWorldTransform], _ pieceTransforms: [SKWorldTransform], _ cameraTransform: SCNMatrix4) {
            
            for t in (boardTransforms + pieceTransforms) {
                let arucoId = Int(t.arucoId)
                let worldPosition = SCNMatrix4Mult(t.transform, cameraTransform)
                let labelPosition = findPosition(arucoId, boardTransforms, pieceTransforms)
                
                // Update node if it exists, else make new
                if let node = findNode(arucoId: arucoId) {
                    node.setWorldTransform(worldPosition)
                    node.createText(label: labelPosition)
                } else {
                    let node = ArucoNode(arucoId: arucoId)
                    sceneView.scene.rootNode.addChildNode(node)
                    node.setWorldTransform(worldPosition)
                    node.createText(label: labelPosition)
                }
                seenTimes[arucoId] = Date()
            }
            
            // Remove unseen nodes after 1sec
            for (id, lastSeen) in seenTimes {
                if Date().timeIntervalSince(lastSeen) > 1.0 {
                    findNode(arucoId: id)?.removeFromParentNode()
                    seenTimes.removeValue(forKey: id)
                }
            }
        }
        
        func findPosition(_ arucoId: Int, _ boardTransforms: [SKWorldTransform], _ pieceTransforms: [SKWorldTransform]) -> SCNVector3? {
            
            // If board marker -> constant pos. If no board -> nil
            if let boardPos = Constants.FixedMarkerDict[arucoId] {
                return SCNVector3(boardPos.x, boardPos.y, boardPos.z)
            }
            if boardTransforms.isEmpty { return nil }
            
            // Verify piece marker
            guard let pieceTfm = pieceTransforms.first(where: { Int($0.arucoId) == arucoId })
            else { return nil }
            
            // Average pos across all board markers
            var sums = SCNVector3Zero
            for boardTfm in boardTransforms {
                let boardPos = Constants.FixedMarkerDict[Int(boardTfm.arucoId)]!
                
                // Find piece pos in board space (piece * board^-1)
                let boardInv = SCNMatrix4Invert(boardTfm.transform)
                let P2Bspace = SCNMatrix4Mult(pieceTfm.transform, boardInv)
                let piecePos = SCNVector3(P2Bspace.m41, P2Bspace.m42, P2Bspace.m43)
                
                sums.x += piecePos.x + Float(boardPos.x)
                sums.y += piecePos.y + Float(boardPos.y)
                sums.z += piecePos.z + Float(boardPos.z)
            }
            
            let count = Float(boardTransforms.count)
            return SCNVector3(sums.x / count, sums.y / count, sums.z / count)
        }
    }
}
