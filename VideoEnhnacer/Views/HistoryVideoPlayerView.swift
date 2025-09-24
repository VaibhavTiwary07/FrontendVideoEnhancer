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
                PlainPlayerView(player: player)
                    .ignoresSafeArea()
                    .onAppear { player.play() }
                    .onDisappear { player.pause() }
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
        .safeAreaInset(edge: .top) {
            HistoryPlayerTopBar(
                fileName: item.fileName,
                isMuted: isMuted,
                onToggleMute: toggleMute,
                onClose: { dismiss() }
            )
        }
        .onAppear {
            let player = AVPlayer(url: item.processedURL)
            player.isMuted = isMuted
            player.allowsExternalPlayback = false
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

private struct HistoryPlayerTopBar: View {
    let fileName: String
    let isMuted: Bool
    let onToggleMute: () -> Void
    let onClose: () -> Void
    @Environment(\.horizontalSizeClass) private var hSize

    private var isCompact: Bool { hSize == .compact || DeviceSize.isSmallPhone }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: isCompact ? 24 : 28, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
            }
            .accessibilityLabel("Close")

            Text(fileName)
                .font(.system(size: isCompact ? 13 : 15, weight: .medium))
                .foregroundColor(.white.opacity(0.95))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            Button(action: onToggleMute) {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: isCompact ? 20 : 24, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
            }
            .accessibilityLabel(isMuted ? "Unmute" : "Mute")
        }
        .padding(.horizontal, isCompact ? 16 : 20)
        .padding(.vertical, isCompact ? 10 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.75), Color.black.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
        )
    }
}

private struct PlainPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }

    final class PlayerContainerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }

        var playerLayer: AVPlayerLayer {
            guard let layer = self.layer as? AVPlayerLayer else {
                fatalError("Expected AVPlayerLayer")
            }
            return layer
        }
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
