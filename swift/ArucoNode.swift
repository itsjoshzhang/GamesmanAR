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
        
        func createAxis(color: UIColor) -> SCNNode {
            let shape = SCNCylinder(radius: length / 20, height: length)
            shape.firstMaterial?.diffuse.contents = color
            let axis = SCNNode(geometry: shape)
            self.addChildNode(axis)
            return axis
        }
        
        let xAxis = createAxis(color: UIColor.red)
        xAxis.eulerAngles = SCNVector3(0, 0, -Float.pi / 2)
        xAxis.position = SCNVector3(length / 2, 0, 0)
        
        let yAxis = createAxis(color: UIColor.green)
        yAxis.position = SCNVector3(0, length / 2, 0)
        
        let zAxis = createAxis(color: UIColor.blue)
        zAxis.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        zAxis.position = SCNVector3(0, 0, length / 2)
    }
    
    public func createText(label: SCNVector3?) {
        guard let label = label else { return }
        textNode?.removeFromParentNode()
        
        let m_to_cm = String(format: "(%d, %d, %d)",
            Int(label.x * 100), Int(label.y * 100), Int(label.z * 100))
        
        let text = SCNText(string: m_to_cm, extrusionDepth: 0)
        text.firstMaterial?.diffuse.contents = UIColor.magenta
        text.font = UIFont.boldSystemFont(ofSize: 10)
        
        textNode = SCNNode(geometry: text)
        textNode?.scale = SCNVector3(0.001, 0.001, 0.001)
        textNode?.constraints = [SCNBillboardConstraint()]
        self.addChildNode(textNode!)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
