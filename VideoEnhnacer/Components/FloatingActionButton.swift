import SwiftUI

struct FloatingActionButton: View {
    let action: () -> Void
    @State private var isPressed = false
    @State private var rotationAngle: Double = 0
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        Button(action: {
            // Add haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            // Add rotation animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                rotationAngle += 45
            }
            
            action()
        }) {
            Image(systemName: "plus")
                .font(.system(size: isIPad ? 28 : 24, weight: .medium))
                .foregroundColor(.white)
                .frame(width: isIPad ? 72 : 64, height: isIPad ? 72 : 64)
                .rotationEffect(.degrees(rotationAngle))
                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
        }
        .buttonStyle(FABButtonStyle())
    }
}

struct FABButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .background(
                ZStack {
                    // Outer glow effect
                    Circle()
                        .fill(LinearGradient.primaryTheme)
                        .blur(radius: configuration.isPressed ? 2 : 4)
                        .opacity(0.6)
                        .scaleEffect(1.1)
                    
                    // Main button background
                    Circle()
                        .fill(LinearGradient.primaryTheme)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(
                            color: Color.black.opacity(0.25),
                            radius: configuration.isPressed ? 6 : 12,
                            x: 0,
                            y: configuration.isPressed ? 3 : 6
                        )
                        .shadow(
                            color: Color.black.opacity(0.1),
                            radius: configuration.isPressed ? 2 : 4,
                            x: 0,
                            y: configuration.isPressed ? 1 : 2
                        )
                }
            )
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            HStack {
                Spacer()
                FloatingActionButton {
                    print("FAB tapped")
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
    }
}