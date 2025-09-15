import SwiftUI
import AVKit

struct HistoryVideoPlayerView: View {
    let item: HistoryItem
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var isMuted: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onAppear { player.play() }
                    .onDisappear { player.pause() }
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }

            // Top bar overlay with close button and title
            VStack {
                HStack(spacing: 16) {
                    Text(item.fileName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button(action: toggleMute) {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                    }

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()
            }
        }
        .onAppear {
            let player = AVPlayer(url: item.processedURL)
            player.isMuted = isMuted
            self.player = player
            player.play()
        }
    }

    private func toggleMute() {
        guard let player = player else { return }
        isMuted.toggle()
        player.isMuted = isMuted
    }
}

#Preview {
    let sample = HistoryItem(
        originalURL: URL(fileURLWithPath: "/tmp/orig.mp4"),
        processedURL: URL(fileURLWithPath: "/tmp/proc.mp4"),
        enhancementTitle: "Upscale",
        enhancementIcon: "arrow.up.forward"
    )
    return HistoryVideoPlayerView(item: sample)
}
