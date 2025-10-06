import SwiftUI
import Foundation

// MARK: - URL Identifiable Extension (Fix for fullScreenCover item binding)
extension URL: Identifiable {
    public var id: String { absoluteString }
}

extension View {
    
    // MARK: - Gradient Styles
    func primaryGradient() -> some View {
        self.background(LinearGradient.primaryTheme)
    }
    
    func subtlePrimaryGradient(opacity: Double = 0.1) -> some View {
        self.background(LinearGradient.primaryTheme.opacity(opacity))
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
    
    // Soft Warm Color System for Video Enhancement Screens
    static let primarySoft = Color(red: 0.165, green: 0.157, blue: 0.153)    // #2A2827 - Warm dark gray
    static let interfaceSoft = Color(red: 0.212, green: 0.204, blue: 0.196)  // #363432 - Warm medium gray
    static let cardSoft = Color(red: 0.259, green: 0.251, blue: 0.243)       // #42403E - Warm elevated gray
    static let overlaySoft = Color(red: 0.306, green: 0.294, blue: 0.286)    // #4E4B49 - Warm modal gray
    static let accentWarm = Color(red: 0.996, green: 0.996, blue: 0.973)     // #FEFEF8 - Matches home background
}
