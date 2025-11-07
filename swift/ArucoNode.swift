import SwiftUI
import ARKit

class ArucoNode: SCNNode {
    public let id: Int
    private let size: CGFloat
    private var textNode: SCNNode?

    init(arucoId: Int) {
        id = arucoId
        if Constants.FixedMarkerDict[id] != nil {
            size = Constants.BoardMarkerSize
        } else {
            size = Constants.PieceMarkerSize
        }
        super.init()
        createAxes()
    }
    
    private func createAxes() {
        let length = size / 2
        
        func createNode(color: UIColor) -> SCNNode {
            let axis = SCNCylinder(radius: length / 20, height: length)
            axis.firstMaterial?.diffuse.contents = color
            let node = SCNNode(geometry: axis)
            self.addChildNode(node)
            return node
        }
        
        let xNode = createNode(color: UIColor.red)
        xNode.eulerAngles = SCNVector3(0, 0, -Float.pi / 2)
        xNode.position = SCNVector3(length / 2, 0, 0)
        
        let yNode = createNode(color: UIColor.green)
        yNode.position = SCNVector3(0, length / 2, 0)
        
        let zNode = createNode(color: UIColor.blue)
        zNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        zNode.position = SCNVector3(0, 0, length / 2)
    }
    
    public func createText(position: SCNVector3?) {
        textNode?.removeFromParentNode()
        
        let text = SCNText(string: "(?, ?, ?)", extrusionDepth: 0)
        if let pos = position {
            text.string = String(format: "(%.1f, %.1f, %.1f)",
                                 pos.x * 100, pos.y * 100, pos.z * 100)
        }
        text.font = UIFont.boldSystemFont(ofSize: 10)
        text.firstMaterial?.diffuse.contents = UIColor.magenta
        
        textNode = SCNNode(geometry: text)
        textNode?.scale = SCNVector3(0.001, 0.001, 0.001)
        textNode?.constraints = [SCNBillboardConstraint()]
        self.addChildNode(textNode!)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
