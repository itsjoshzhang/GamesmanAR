import SwiftUI
import ARKit
import SceneKit

struct ARController: UIViewRepresentable {
    
    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView()
        view.showsStatistics = true
        view.autoenablesDefaultLighting = true
        context.coordinator.sceneView = view
        view.session.delegate = context.coordinator
        return view
    }
    
    func updateUIView(_ view: ARSCNView, context: Context) {
        if view.session.configuration == nil {
            let config = ARWorldTrackingConfiguration()
            config.planeDetection = .horizontal
            config.isLightEstimationEnabled = true
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
    
    class Coordinator: NSObject, ARSessionDelegate {
        var sceneView: ARSCNView!
        var seenTimes: [Int: Date] = [:]
        var mutexlock = false
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            if mutexlock { return }
            mutexlock = true
            
            // Detect board markers
            let boardTransforms = ArucoCV.estimatePose(
                frame.capturedImage,
                withIntrinsics: frame.camera.intrinsics,
                andMarkerSize: Constants.BoardMarkerSize
            ) as! [SKWorldTransform]
            
            // Detect piece markers
            let pieceTransforms = ArucoCV.estimatePose(
                frame.capturedImage,
                withIntrinsics: frame.camera.intrinsics,
                andMarkerSize: Constants.PieceMarkerSize
            ) as! [SKWorldTransform]
            
            // Merge all transforms
            let keys = Constants.FixedMarkerDict.keys
            let allTransforms = (boardTransforms.filter { keys.contains(Int($0.arucoId)) } +
                                 pieceTransforms.filter {!keys.contains(Int($0.arucoId)) } )
            if allTransforms.isEmpty {
                mutexlock = false
                return
            }
            
            // Update all node poses
            let cameraMatrix = SCNMatrix4(frame.camera.transform)
            DispatchQueue.main.async {
                self.updateNodes(allTransforms: allTransforms, cameraMatrix: cameraMatrix)
                self.mutexlock = false
            }
        }
        
        // Return node if found
        func findNode(arucoId: Int) -> ArucoNode? {
            for node in sceneView.scene.rootNode.childNodes {
                if let node = node as? ArucoNode, node.id == arucoId {
                    return node
                }
            }
            return nil
        }
        
        func updateNodes(allTransforms: [SKWorldTransform], cameraMatrix: SCNMatrix4) {
            for t in allTransforms {
                let arucoId = Int(t.arucoId)
                let worldTransform = SCNMatrix4Mult(t.transform, cameraMatrix)
                let position = findPosition(arucoId: arucoId, allTransforms: allTransforms)
                
                // Update or create new nodes
                if let node = findNode(arucoId: arucoId) {
                    node.setWorldTransform(worldTransform)
                    node.createText(position: position)
                } else {
                    let node = ArucoNode(arucoId: arucoId)
                    sceneView.scene.rootNode.addChildNode(node)
                    node.setWorldTransform(worldTransform)
                    node.createText(position: position)
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
        
        func findPosition(arucoId: Int, allTransforms: [SKWorldTransform]) -> SCNVector3? {
            
            if let fixedAbs = Constants.FixedMarkerDict[arucoId] {
                return SCNVector3(fixedAbs.x, fixedAbs.y, fixedAbs.z)
            }
            
            // Get current marker transform
            guard let pieceT = allTransforms.first(where: { Int($0.arucoId) == arucoId }) else {
                return nil
            }
            let piecePos = SCNVector3(pieceT.transform.m41, pieceT.transform.m42, pieceT.transform.m43)
            
            // Find all visible fixed markers
            let fixedT = allTransforms.filter { Constants.FixedMarkerDict[Int($0.arucoId)] != nil }
            guard !fixedT.isEmpty else { return nil }
            
            // Calculate relative position in cm
            var sumX: Float = 0, sumY: Float = 0, sumZ: Float = 0
            for t in fixedT {
                let fixedPos = SCNVector3(t.transform.m41, t.transform.m42, t.transform.m43)
                let fixedAbs = Constants.FixedMarkerDict[Int(t.arucoId)]!
                
                sumX += (piecePos.x - fixedPos.x) * 100 + Float(fixedAbs.x)
                sumY += (piecePos.y - fixedPos.y) * 100 + Float(fixedAbs.y)
                sumZ += (piecePos.z - fixedPos.z) * 100 + Float(fixedAbs.z)
            }
            
            let count = Float(fixedT.count)
            return SCNVector3(sumX / count, sumY / count, sumZ / count)
        }
    }
}
