import SwiftUI

// MARK: - Shared Back Button Component
/// Standardized back button with chevron.left icon used across all screens
/// Ensures consistent UX and haptic feedback throughout the app
struct BackButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticFeedbackManager.impact(.light)
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                Text("Back")
                    .font(.system(size: 17, weight: .medium))
            }
            .foregroundColor(.accentWarm)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentWarm.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Haptic Feedback Manager
/// Centralized haptic feedback management for consistent user experience
struct HapticFeedbackManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// MARK: - Preview
#Preview {
    BackButton {
        print("Back button tapped")
    }
    .padding()
}