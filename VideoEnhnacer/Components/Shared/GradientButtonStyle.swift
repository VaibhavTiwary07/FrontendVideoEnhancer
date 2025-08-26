import SwiftUI

// MARK: - Gradient Button Style
/// Shared button style with orange LinearGradient.primaryTheme styling
/// Reduces code duplication across the app
struct GradientButtonStyle: ButtonStyle {
    let isEnabled: Bool
    
    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(LinearGradient.primaryTheme.opacity(isEnabled ? 0.9 : 0.5))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Button Extension
extension Button {
    func gradientButtonStyle(isEnabled: Bool = true) -> some View {
        self.buttonStyle(GradientButtonStyle(isEnabled: isEnabled))
    }
}
