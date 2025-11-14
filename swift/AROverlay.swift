import SceneKit
import UIKit

class AROverlay {
    var gridNodes: [String: SCNNode] = [:]
    let parentNode: SCNNode
    let stride = 0.05 // 5cm
    
    init(parentNode: SCNNode) {
        self.parentNode = parentNode
    }
    
    func update(_ boardTransforms: [SKWorldTransform], _ cameraTransform: SCNMatrix4) {
        if boardTransforms.isEmpty { return }
        
        // Calculate borders from FixedMarkerDict
        let positions = Constants.FixedMarkerDict.values
        let xs = positions.map { $0.x }
        let ys = positions.map { $0.y }
        let (minX, maxX) = (xs.min()!, xs.max()!)
        let (minY, maxY) = (ys.min()!, ys.max()!)
        
        // Create grid of images
        let xStart = Int((minX / stride).rounded(.down))
        let xFinal = Int((maxX / stride).rounded(.up))
        let yStart = Int((minY / stride).rounded(.down))
        let yFinal = Int((maxY / stride).rounded(.up))
        
        var currentKeys = Set<String>()
        
        for i in xStart...xFinal {
            for j in yStart...yFinal {
                
                let x = Double(i) * stride
                let y = Double(j) * stride
                let key = "\(i),\(j)"
                currentKeys.insert(key)
                
                // Average world position across all board markers
                var sumPos = SCNVector3(0, 0, 0)
                var sumRot = simd_quatf(ix: 0, iy: 0, iz: 0, r: 0)
                
                for boardTfm in boardTransforms {
                    let boardPos = Constants.FixedMarkerDict[Int(boardTfm.arucoId)]!
                    
                    // Board-to-world transform
                    let worldTfm = SCNMatrix4Mult(boardTfm.transform, cameraTransform)
                    
                    // Grid point in board space relative to this marker
                    let relative = SCNVector3(Float(x - boardPos.x), Float(y - boardPos.y), 0)
                    let worldPos = transformPoint(p: relative, m: worldTfm)
                    
                    sumPos.x += worldPos.x
                    sumPos.y += worldPos.y
                    sumPos.z += worldPos.z
                    
                    // Average rotation
                    sumRot.vector += simd_quatf(m: worldTfm).vector
                }
                
                let count = Float(boardTransforms.count)
                let avgPos = SCNVector3(sumPos.x / count, sumPos.y / count, sumPos.z / count)
                let avgRot = simd_normalize(sumRot)
                
                // Update current node if it exists
                if let node = gridNodes[key] {
                    let move = SCNAction.move(to: avgPos, duration: 0.1)
                    let rotate = SCNAction.rotateTo(
                        x: CGFloat(avgRot.angle) * CGFloat(avgRot.axis.x),
                        y: CGFloat(avgRot.angle) * CGFloat(avgRot.axis.y),
                        z: CGFloat(avgRot.angle) * CGFloat(avgRot.axis.z),
                        duration: 0.1)
                    node.runAction(SCNAction.group([move, rotate]))
                } else {
                    let node = createDot(pos: avgPos, rot: avgRot)
                    parentNode.addChildNode(node)
                    gridNodes[key] = node
                }
            }
        }
        
        // Remove nodes no longer in grid
        for (key, node) in gridNodes {
            if !currentKeys.contains(key) {
                node.removeFromParentNode()
                gridNodes.removeValue(forKey: key)
            }
        }
    }
    
    func transformPoint(p: SCNVector3, m: SCNMatrix4) -> SCNVector3 {
        let x = m.m11 * p.x + m.m21 * p.y + m.m31 * p.z + m.m41
        let y = m.m12 * p.x + m.m22 * p.y + m.m32 * p.z + m.m42
        let z = m.m13 * p.x + m.m23 * p.y + m.m33 * p.z + m.m43
        return SCNVector3(x, y, z)
    }
    
    func createDot(pos: SCNVector3, rot: simd_quatf) -> SCNNode {
        let plane = SCNPlane(width: stride / 2, height: stride / 2)
        plane.firstMaterial?.diffuse.contents = UIImage(named: "dot")
        plane.firstMaterial?.isDoubleSided = true
        
        let node = SCNNode(geometry: plane)
        node.simdPosition = simd_float3(pos.x, pos.y, pos.z)
        node.simdOrientation = rot
        return node
    }
}

extension simd_quatf {
    init(m: SCNMatrix4) {
        let matrix = simd_float3x3(
            simd_float3(m.m11, m.m12, m.m13),
            simd_float3(m.m21, m.m22, m.m23),
            simd_float3(m.m31, m.m32, m.m33)
        )
        self.init(matrix)
    }
}
