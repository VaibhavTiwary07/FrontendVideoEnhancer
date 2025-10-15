import SwiftUI
import AVFoundation
import AVKit

struct HistoryVideoPlayerView: View {
    let item: HistoryItem
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var isMuted: Bool = false
    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var showControls: Bool = true
    @State private var isSeeking: Bool = false
    @State private var timeObserver: Any?
    @State private var hideControlsTask: Task<Void, Never>?

    var body: some View {
        let _ = print("DEBUG_HISTORYCARD: HistoryVideoPlayerView body rendered - showControls: \(showControls), isPlaying: \(isPlaying)")
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = player {
                PlainPlayerView(player: player)
                    .ignoresSafeArea()
                    .onTapGesture {
                        print("DEBUG_HISTORYCARD: Video tapped - showControls was: \(showControls)")
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showControls.toggle()
                        }
                        print("DEBUG_HISTORYCARD: Video tapped - showControls now: \(showControls)")
                        if showControls {
                            scheduleHideControls()
                        }
                    }

                // Center Play/Pause Button
                if showControls {
                    let _ = print("DEBUG_HISTORYCARD: Rendering play/pause button - isPlaying: \(isPlaying)")
                    Button(action: togglePlayPause) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 70, height: 70)

                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                                .offset(x: isPlaying ? 0 : 3)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // Seek Bar at Bottom
                if showControls {
                    let _ = print("DEBUG_HISTORYCARD: Rendering seek bar - currentTime: \(currentTime), duration: \(duration)")
                    VStack {
                        Spacer()

                        HStack(spacing: 12) {
                            // Current Time
                            Text(formatTime(currentTime))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .monospacedDigit()

                            // Seek Bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // Background Track
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.white.opacity(0.3))
                                        .frame(height: 4)

                                    // Progress Track
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.white)
                                        .frame(width: max(0, geometry.size.width * progress), height: 4)

                                    // Thumb
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 14, height: 14)
                                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                        .offset(x: max(0, geometry.size.width * progress - 7))
                                }
                                .frame(height: 44)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            isSeeking = true
                                            let newProgress = min(max(0, value.location.x / geometry.size.width), 1)
                                            currentTime = newProgress * duration
                                        }
                                        .onEnded { value in
                                            let newProgress = min(max(0, value.location.x / geometry.size.width), 1)
                                            let seekTime = newProgress * duration
                                            player.seek(to: CMTime(seconds: seekTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))) { _ in
                                                isSeeking = false
                                            }
                                            scheduleHideControls()
                                        }
                                )
                            }
                            .frame(height: 44)

                            // Duration
                            Text(formatTime(duration))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color.black.opacity(0.0), Color.black.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
        .safeAreaInset(edge: .top) {
            HistoryPlayerTopBar(
                fileName: item.displayName,
                isMuted: isMuted,
                onToggleMute: toggleMute,
                onClose: { dismiss() }
            )
        }
        .onAppear {
            print("DEBUG_HISTORYCARD: HistoryVideoPlayerView.onAppear - item: \(item.displayName)")
            print("DEBUG_HISTORYCARD: Initial showControls: \(showControls)")
            let player = AVPlayer(url: item.processedURL)
            player.isMuted = isMuted
            player.allowsExternalPlayback = false
            self.player = player
            print("DEBUG_HISTORYCARD: Player created: \(player)")
            setupPlayer()
            player.play()
            isPlaying = true
            print("DEBUG_HISTORYCARD: Player started - isPlaying: \(isPlaying)")
            scheduleHideControls()
        }
        .onDisappear {
            hideControlsTask?.cancel()
            if let observer = timeObserver {
                player?.removeTimeObserver(observer)
                timeObserver = nil
            }
        }
    }

    private var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    private func setupPlayer() {
        print("DEBUG_HISTORYCARD: setupPlayer() called")
        guard let player = player else {
            print("DEBUG_HISTORYCARD: setupPlayer() - player is nil!")
            return
        }

        // Get duration
        if let currentItem = player.currentItem {
            let durationValue = currentItem.duration
            if durationValue.isNumeric && !durationValue.isIndefinite {
                duration = CMTimeGetSeconds(durationValue)
                print("DEBUG_HISTORYCARD: Duration set to: \(duration)")
            } else {
                print("DEBUG_HISTORYCARD: Duration not available yet")
            }
        }

        // Add time observer
        print("DEBUG_HISTORYCARD: Adding time observer")
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        let observer = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak player] time in
            guard let player = player, !isSeeking else { return }
            currentTime = CMTimeGetSeconds(time)

            // Update duration if not set yet
            if duration == 0 {
                if let currentItem = player.currentItem {
                    let durationValue = currentItem.duration
                    if durationValue.isNumeric && !durationValue.isIndefinite {
                        duration = CMTimeGetSeconds(durationValue)
                        print("DEBUG_HISTORYCARD: Duration updated in observer to: \(duration)")
                    }
                }
            }

            // Update playing state
            let wasPlaying = isPlaying
            isPlaying = player.rate > 0
            if wasPlaying != isPlaying {
                print("DEBUG_HISTORYCARD: Playing state changed to: \(isPlaying)")
            }
        }
        timeObserver = observer
        print("DEBUG_HISTORYCARD: setupPlayer() completed")
    }

    private func togglePlayPause() {
        print("DEBUG_HISTORYCARD: togglePlayPause() called - isPlaying was: \(isPlaying)")
        guard let player = player else {
            print("DEBUG_HISTORYCARD: togglePlayPause() - player is nil!")
            return
        }

        if isPlaying {
            player.pause()
            isPlaying = false
            print("DEBUG_HISTORYCARD: Paused")
        } else {
            player.play()
            isPlaying = true
            print("DEBUG_HISTORYCARD: Playing")
            scheduleHideControls()
        }
    }

    private func scheduleHideControls() {
        print("DEBUG_HISTORYCARD: scheduleHideControls() called - isPlaying: \(isPlaying)")
        hideControlsTask?.cancel()

        guard isPlaying else {
            print("DEBUG_HISTORYCARD: Not scheduling hide because not playing")
            return
        }

        print("DEBUG_HISTORYCARD: Scheduling controls to hide in 3 seconds")
        hideControlsTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            if !Task.isCancelled {
                print("DEBUG_HISTORYCARD: Hiding controls now")
                withAnimation(.easeInOut(duration: 0.3)) {
                    showControls = false
                }
                print("DEBUG_HISTORYCARD: Controls hidden - showControls: \(showControls)")
            } else {
                print("DEBUG_HISTORYCARD: Hide controls task was cancelled")
            }
        }
    }

    private func formatTime(_ time: Double) -> String {
        guard !time.isNaN && !time.isInfinite else { return "0:00" }
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
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
