import SwiftUI

// MARK: - Shared Close Button Component  
/// Standardized close button with X icon used across all screens
/// Ensures consistent UX and haptic feedback throughout the app
struct CloseButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticFeedbackManager.impact(.medium)
            action()
        }) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.accentWarm)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.accentWarm.opacity(0.15))
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    CloseButton {
        print("Close button tapped")
    }
    .padding()
}