import SwiftUI

extension View {
    
    // MARK: - Gradient Styles
    func primaryGradient() -> some View {
        self.background(
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.47, blue: 0.47),
                    Color(red: 1.0, green: 0.596, blue: 0.329),
                    Color(red: 0.988, green: 0.753, blue: 0.424)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    func subtlePrimaryGradient(opacity: Double = 0.1) -> some View {
        self.background(
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.47, blue: 0.47).opacity(opacity),
                    Color(red: 1.0, green: 0.596, blue: 0.329).opacity(opacity),
                    Color(red: 0.988, green: 0.753, blue: 0.424).opacity(opacity)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    // MARK: - Neomorphic Effects
    func neomorphicStyle(
        backgroundColor: Color = Color(red: 0.996, green: 0.996, blue: 0.996),
        cornerRadius: CGFloat = 16,
        shadowRadius: CGFloat = 8
    ) -> some View {
        self
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(
                color: Color.black.opacity(0.1),
                radius: shadowRadius,
                x: shadowRadius / 2,
                y: shadowRadius / 2
            )
            .shadow(
                color: Color.white.opacity(0.8),
                radius: shadowRadius,
                x: -shadowRadius / 2,
                y: -shadowRadius / 2
            )
    }
    
    func neomorphicPressed(
        backgroundColor: Color = Color(red: 0.992, green: 0.992, blue: 0.992),
        cornerRadius: CGFloat = 16,
        shadowRadius: CGFloat = 4
    ) -> some View {
        self
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(
                color: Color.black.opacity(0.15),
                radius: shadowRadius,
                x: -shadowRadius / 2,
                y: -shadowRadius / 2
            )
            .shadow(
                color: Color.white.opacity(0.9),
                radius: shadowRadius,
                x: shadowRadius / 2,
                y: shadowRadius / 2
            )
    }
    
    func neomorphicCard() -> some View {
        self
            .padding()
            .neomorphicStyle(cornerRadius: 20, shadowRadius: 10)
            .padding(.horizontal)
    }
}

// MARK: - Color Extensions
extension Color {
    static let primaryText = Color(red: 0.176, green: 0.176, blue: 0.176)
    static let secondaryText = Color(red: 0.42, green: 0.42, blue: 0.42)
    static let appBackground = Color(red: 0.996, green: 0.996, blue: 0.973)
    static let cardBackground = Color.white
}
