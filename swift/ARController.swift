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
            
            let transforms = ArucoCV.estimatePose(
                frame.capturedImage,
                withIntrinsics: frame.camera.intrinsics,
                andMarkerSize: Constants.BoardMarkerSize
            ) as! [SKWorldTransform]
            
            if transforms.isEmpty {
                mutexlock = false
                return
            }
            
            let cameraMatx = SCNMatrix4(frame.camera.transform)
            
            DispatchQueue.main.async {
                self.updateNodes(transforms: transforms, cameraMatx: cameraMatx)
                self.mutexlock = false
            }
        }
        
        func updateNodes(transforms: [SKWorldTransform], cameraMatx: SCNMatrix4) {
            for t in transforms {
                let arucoId = Int(t.arucoId)
                seenTimes[arucoId] = Date()
                
                let worldTransform = SCNMatrix4Mult(t.transform, cameraMatx)
                
                if let node = findNode(arucoId: arucoId) {
                    node.setWorldTransform(worldTransform)
                } else {
                    let node = ArucoNode(arucoId: arucoId)
                    sceneView.scene.rootNode.addChildNode(node)
                    node.setWorldTransform(worldTransform)
                }
            }
            
            for (id, lastSeen) in seenTimes {
                if Date().timeIntervalSince(lastSeen) > 1.0 {
                    findNode(arucoId: id)?.removeFromParentNode()
                    seenTimes.removeValue(forKey: id)
                }
            }
        }
        
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
