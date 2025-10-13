import SwiftUI

struct MuteToggleButton: View {
    @Binding var isMuted: Bool
    
    var body: some View {
        Button(action: toggleMute) {
            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: DeviceSize.isSmallPhone ? 18 : 20, weight: .semibold))
                .foregroundColor(.white)
                .padding(DeviceSize.isSmallPhone ? 8 : 10)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.45))
                )
                .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isMuted ? "Unmute" : "Mute")
    }
    
    private func toggleMute() {
        HapticFeedbackManager.impact(.light)
        isMuted.toggle()
    }
}
