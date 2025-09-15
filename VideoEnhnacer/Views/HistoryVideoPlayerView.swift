import SwiftUI
import AVKit

struct HistoryVideoPlayerView: View {
    let item: HistoryItem
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = true

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
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                    }

                    Spacer()

                    Text(item.fileName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: 24)

                    Button(action: togglePlayback) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
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
            player.isMuted = false
            self.player = player
            self.isPlaying = true
        }
    }

    private func togglePlayback() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
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

