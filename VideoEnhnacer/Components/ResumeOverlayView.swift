import SwiftUI

struct ResumeOverlayView: View {
    let onResume: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: 16) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.white)

                Text("Welcome Back")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)

                Text("Tap resume to continue")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.85))

                Button(action: onResume) {
                    Text("Resume")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(
                            Capsule().fill(LinearGradient.primaryTheme)
                        )
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(LinearGradient.primaryTheme.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 24)
            .transition(.scale.combined(with: .opacity))
        }
        .zIndex(2)
        .allowsHitTesting(true)
    }
}

#Preview {
    ResumeOverlayView(onResume: {})
}
