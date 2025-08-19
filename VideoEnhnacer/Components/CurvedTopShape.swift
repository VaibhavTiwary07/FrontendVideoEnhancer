import SwiftUI

struct CurvedTopShape: Shape {
    var curveHeight: CGFloat = 30
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Start from top-left corner
        path.move(to: CGPoint(x: 0, y: curveHeight))
        
        // Create upward curve at the top
        path.addQuadCurve(
            to: CGPoint(x: width, y: curveHeight),
            control: CGPoint(x: width / 2, y: 0)
        )
        
        // Draw right edge
        path.addLine(to: CGPoint(x: width, y: height))
        
        // Draw bottom edge
        path.addLine(to: CGPoint(x: 0, y: height))
        
        // Close the path
        path.closeSubpath()
        
        return path
    }
}

#Preview {
    CurvedTopShape(curveHeight: 40)
        .fill(Color.blue)
        .frame(width: 300, height: 200)
        .padding()
}