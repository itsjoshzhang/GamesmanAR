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
        var mutexLock = false
        var sceneView: ARSCNView!
        var seenNodes: [Int: (node: ArucoNode, time: Date)] = [:]
        let busyQueue = DispatchQueue(label: "busyQueue", qos: .userInitiated)
        
        // Runs every frame. Finds board, piece, and camera transforms
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            if mutexLock { return }
            mutexLock = true
            
            // Detects all markers, filters for board/piece transforms
            func detectAR(isBoardMarker: Bool) -> [SKWorldTransform] {
                let boardMarks = Constants.FixedMarkerDict.keys
                let markerSize = isBoardMarker ? Constants.BoardMarkerSize : Constants.PieceMarkerSize
                
                let transforms = ArucoCV.estimatePose(frame.capturedImage,
                    withIntrinsics: frame.camera.intrinsics,
                    andMarkerSize: markerSize
                ) as! [SKWorldTransform]
                
                if isBoardMarker {
                    return transforms.filter { boardMarks.contains(Int($0.arucoId)) }
                } else {
                    return transforms.filter {!boardMarks.contains(Int($0.arucoId)) }
                }
            }
            
            // Some self bs, send transforms to nodes
            busyQueue.async { [weak self] in
                guard let self = self else { return }
                
                let boardTransforms = detectAR(isBoardMarker: true)
                let pieceTransforms = detectAR(isBoardMarker: false)
                let cameraTransform = SCNMatrix4(frame.camera.transform)
                
                if boardTransforms.isEmpty && pieceTransforms.isEmpty {
                    mutexLock = false
                    return
                }
                DispatchQueue.main.async {
                    self.updateNodes(boardTransforms, pieceTransforms, cameraTransform)
                    self.mutexLock = false
                }
            }
        }
        
        // Send world (rendered) and label (relative) positions
        func updateNodes(_ boardTransforms: [SKWorldTransform], _ pieceTransforms: [SKWorldTransform], _ cameraTransform: SCNMatrix4) {
            
            for Tfm in (boardTransforms + pieceTransforms) {
                let arucoId  = Int(Tfm.arucoId)
                let worldPos = SCNMatrix4Mult(Tfm.transform, cameraTransform)
                let labelPos = findPosition(arucoId, boardTransforms, pieceTransforms)
                let currNode: ArucoNode
                
                // Update current node if it exists
                if let tuple = seenNodes[arucoId] {
                    currNode = tuple.node
                    let wPos = SCNVector3(worldPos.m41, worldPos.m42, worldPos.m43)
                    let move = SCNAction.move(to: wPos, duration: 0.1)
                    currNode.runAction(move)
                
                // Otherwise make new node and text
                } else {
                    currNode = ArucoNode(arucoId: arucoId)
                    sceneView.scene.rootNode.addChildNode(currNode)
                    currNode.setWorldTransform(worldPos)
                }
                currNode.createText(label: labelPos)
                seenNodes[arucoId] = (node: currNode, time: Date())
            }
            
            // Remove unseen nodes after 1sec
            for (id, tuple) in seenNodes {
                if Date().timeIntervalSince(tuple.time) > 1.0 {
                    tuple.node.removeFromParentNode()
                    seenNodes.removeValue(forKey: id)
                }
            }
        }
        
        func findPosition(_ arucoId: Int, _ boardTransforms: [SKWorldTransform], _ pieceTransforms: [SKWorldTransform]) -> SCNVector3? {
            // Board markers: use known pos
            if let boardPos = Constants.FixedMarkerDict[arucoId] {
                return SCNVector3(boardPos.x, boardPos.y, boardPos.z)
            }
            
            // No board markers: return nil
            guard !boardTransforms.isEmpty,
                  let pieceTfm = pieceTransforms.first(where: { Int($0.arucoId) == arucoId })
            else { return nil }
            
            // Sum across all board markers
            var sums = SCNVector3(0, 0, 0)
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
