import SwiftUI

@main
struct cvARuco: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        ARController()
            .edgesIgnoringSafeArea(.all)
    }
}

struct Constants {
    // Aruco marker side length in meters
    public static let BoardMarkerSize = 0.050
    public static let PieceMarkerSize = 0.025
    
    // Maps Aruco id to center coord in m
    public static let FixedMarkerDict = [
        666: (x: 0.0,  y: 0.0,  z: 0.0),
        669: (x: 0.15, y: 0.0,  z: 0.0),
        66:  (x: 0.0,  y: 0.15, z: 0.0),
        69:  (x: 0.15, y: 0.15, z: 0.0),
    ]
}
