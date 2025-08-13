import SwiftUI

struct FloatingActionButton: View {
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            action()
        }) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
        }
        .buttonStyle(FABButtonStyle())
    }
}

struct FABButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .background(
                Circle()
                    .primaryGradient()
                    .shadow(
                        color: Color.black.opacity(0.2),
                        radius: configuration.isPressed ? 4 : 8,
                        x: 0,
                        y: configuration.isPressed ? 2 : 4
                    )
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
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