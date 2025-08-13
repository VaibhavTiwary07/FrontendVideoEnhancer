import SwiftUI

struct NeomorphicButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void
    @State private var isPressed = false
    
    init(
        title: String,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            action()
        }) {
            HStack(spacing: 12) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .medium))
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.primaryText)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(minWidth: 120)
        }
        .buttonStyle(NeomorphicButtonStyle())
    }
}

struct NeomorphicButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .foregroundColor(configuration.isPressed ? .white : .primaryText)
            .background(
                Group {
                    if configuration.isPressed {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.47, blue: 0.47).opacity(0.8),
                                        Color(red: 1.0, green: 0.596, blue: 0.329).opacity(0.8),
                                        Color(red: 0.988, green: 0.753, blue: 0.424).opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .neomorphicPressed()
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.cardBackground)
                            .neomorphicStyle()
                    }
                }
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 20) {
        NeomorphicButton(
            title: "AI Upscale",
            systemImage: "arrow.up.circle"
        ) {
            print("AI Upscale tapped")
        }
        
        NeomorphicButton(
            title: "Face Enhancer"
        ) {
            print("Face Enhancer tapped")
        }
    }
    .padding()
    .background(Color.appBackground)
}