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
        var mutexlock = false
        var seenTimes: [Int: Date] = [:]
        
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
        
        func updateNodes(allTransforms: [SKWorldTransform], cameraMatrix: SCNMatrix4) {
            
            for t in allTransforms {
                let arucoId = Int(t.arucoId)
                let worldTransform = SCNMatrix4Mult(t.transform, cameraMatrix)
                
                // Update or create new nodes
                if let node = findNode(arucoId: arucoId) {
                    node.setWorldTransform(worldTransform)
                } else {
                    let node = ArucoNode(arucoId: arucoId)
                    sceneView.scene.rootNode.addChildNode(node)
                    node.setWorldTransform(worldTransform)
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
        
        // Return node if exists
        func findNode(arucoId: Int) -> ArucoNode? {
            for node in sceneView.scene.rootNode.childNodes {
                if let node = node as? ArucoNode, node.id == arucoId {
                    return node
                }
            }
            return nil
        }
    }
}
