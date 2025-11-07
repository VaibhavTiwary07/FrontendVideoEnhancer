import SwiftUI
import AVFoundation
import Combine

struct CustomVideoPlayerWithControls: View {
    let player: AVPlayer
    @Binding var isMuted: Bool
    let videoGravity: AVLayerVideoGravity
    let trimStart: Double?
    let trimEnd: Double?

    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var showControls: Bool = true
    @State private var isSeeking: Bool = false
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var timeObserver: Any?
    @State private var observedPlayerID: ObjectIdentifier?
    @State private var showCenterButton: Bool = true

    private let timeObserverInterval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

    // Computed properties for display
    private var displayDuration: Double {
        if let start = trimStart, let end = trimEnd {
            return end - start
        }
        return duration
    }

    private var displayCurrentTime: Double {
        if let start = trimStart {
            return max(0, currentTime - start)
        }
        return currentTime
    }

    var body: some View {
        ZStack {
            // Video Player
            AVPlayerUIView(player: player, videoGravity: videoGravity)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showControls.toggle()
                        // Also toggle center button visibility
                        showCenterButton.toggle()
                    }
                    if showControls {
                        scheduleHideControls()
                    }
                }

            // Mute Button (Top-Right)
            VStack {
                HStack {
                    Spacer()
                    MuteToggleButton(isMuted: $isMuted)
                        .padding(.trailing, DeviceSize.isSmallPhone ? 16 : 20)
                        .padding(.top, DeviceSize.isSmallPhone ? 8 : 12)
                }
                Spacer()
            }
            .opacity(showControls ? 1 : 0)

            // Center Play/Pause Button
            if showCenterButton {
                Button(action: togglePlayPause) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 70, height: 70)

                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: isPlaying ? 0 : 3) // Slight offset for play icon
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }

            // Playback Controls (Bottom)
            VStack {
                Spacer()

                if showControls {
                    HStack(spacing: 12) {
                        // Current Time
                        Text(formatTime(displayCurrentTime))
                            .font(.system(size: DeviceSize.isSmallPhone ? 11 : 13, weight: .medium, design: .rounded))
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
                                    .fill(LinearGradient.primaryTheme)
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
                                        if let start = trimStart, let end = trimEnd {
                                            // Map progress to trim range
                                            currentTime = start + (newProgress * (end - start))
                                        } else {
                                            currentTime = newProgress * duration
                                        }
                                    }
                                    .onEnded { value in
                                        let newProgress = min(max(0, value.location.x / geometry.size.width), 1)
                                        let seekTime: Double
                                        if let start = trimStart, let end = trimEnd {
                                            // Map progress to trim range
                                            seekTime = start + (newProgress * (end - start))
                                        } else {
                                            seekTime = newProgress * duration
                                        }
                                        player.seek(to: CMTime(seconds: seekTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))) { _ in
                                            isSeeking = false
                                        }
                                        scheduleHideControls()
                                    }
                            )
                        }
                        .frame(height: 44)

                        // Duration
                        Text(formatTime(displayDuration))
                            .font(.system(size: DeviceSize.isSmallPhone ? 11 : 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, DeviceSize.isSmallPhone ? 12 : 16)
                    .padding(.vertical, DeviceSize.isSmallPhone ? 10 : 12)
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
        }
        .background(Color.black)
        .onAppear {
            print("DEBUG_PAUSE: onAppear - player.rate: \(player.rate)")
            setupPlayer()
            // Auto-play video on load
            player.play()
            isPlaying = true
            showCenterButton = false // Hide center button since we're auto-playing
            scheduleHideControls()
            print("DEBUG_PAUSE: onAppear complete - isPlaying: \(isPlaying), player.rate: \(player.rate)")
        }
        .onDisappear {
            print("DEBUG_PAUSE: onDisappear - cleaning up")
            hideControlsTask?.cancel()

            // Defensive cleanup: Only remove observer if it belongs to current player
            if let observer = timeObserver,
               let observedID = observedPlayerID,
               ObjectIdentifier(player) == observedID {
                print("DEBUG_PAUSE: Removing time observer from current player")
                player.removeTimeObserver(observer)
            } else if timeObserver != nil {
                print("DEBUG_PAUSE: ⚠️ Skipping observer removal - player instance mismatch")
            }

            timeObserver = nil
            observedPlayerID = nil
        }
        .onChange(of: isPlaying) { newValue in
            print("DEBUG_PAUSE: onChange(of: isPlaying) triggered")
            print("DEBUG_PAUSE: newValue: \(newValue), player.rate BEFORE action: \(player.rate)")
            if newValue {
                player.play()
                print("DEBUG_PAUSE: Called player.play()")
            } else {
                player.pause()
                print("DEBUG_PAUSE: Called player.pause()")
            }
            print("DEBUG_PAUSE: player.rate AFTER action: \(player.rate)")
        }
        .onChange(of: ObjectIdentifier(player)) { newPlayerID in
            print("DEBUG_PAUSE: ⚠️ onChange(of: player) - Player instance changed!")
            print("DEBUG_PAUSE: Old player ID: \(observedPlayerID?.debugDescription ?? "nil")")
            print("DEBUG_PAUSE: New player ID: \(newPlayerID)")

            // Clean up old observer state (can't remove from old player, just discard)
            if timeObserver != nil {
                print("DEBUG_PAUSE: Discarding old time observer - will create new one in setupPlayer")
            }
            timeObserver = nil
            observedPlayerID = nil

            // Reset state for new player
            currentTime = 0
            duration = 0
            isPlaying = false

            // Setup will be called by onAppear or can be called manually
            setupPlayer()
        }
    }

    // MARK: - Computed Properties

    
    private var progress: Double {
        if let start = trimStart, let end = trimEnd {
            let trimDuration = end - start
            guard trimDuration > 0 else { return 0 }
            let elapsed = currentTime - start
            return max(0, min(1, elapsed / trimDuration))
        }
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    // MARK: - Private Methods

    private func setupPlayer() {
        print("DEBUG_PAUSE: setupPlayer() called")
        print("DEBUG_PAUSE: Initial player.rate: \(player.rate)")

        // Track current player identity for safe observer management
        let currentPlayerID = ObjectIdentifier(player)

        // Clean up old observer if it's from a different player
        if let oldObserver = timeObserver,
           let oldPlayerID = observedPlayerID,
           oldPlayerID != currentPlayerID {
            print("DEBUG_PAUSE: ⚠️ Player changed - discarding old observer (can't remove from old player)")
            timeObserver = nil
            observedPlayerID = nil
        }

        // Get duration
        print("DEBUG_END_TIME: Attempting to get duration")
        print("DEBUG_END_TIME: currentItem exists: \(player.currentItem != nil)")
        if let currentItem = player.currentItem {
            let durationValue = currentItem.duration
            print("DEBUG_END_TIME: durationValue = \(durationValue)")
            print("DEBUG_END_TIME: isNumeric = \(durationValue.isNumeric)")
            print("DEBUG_END_TIME: isIndefinite = \(durationValue.isIndefinite)")
            if durationValue.isNumeric && !durationValue.isIndefinite {
                duration = CMTimeGetSeconds(durationValue)
                print("DEBUG_END_TIME: ✅ Duration set to: \(duration)")
            } else {
                print("DEBUG_END_TIME: ❌ Duration NOT set - failed conditions")
            }
        } else {
            print("DEBUG_END_TIME: ❌ No currentItem available")
        }
        print("DEBUG_END_TIME: Final duration value: \(duration)")

        // Observe playback time - store the token for proper cleanup
        let observer = player.addPeriodicTimeObserver(forInterval: timeObserverInterval, queue: .main) { [weak player] time in
            guard let player = player, !isSeeking else { return }
            currentTime = CMTimeGetSeconds(time)

            // Update duration if it's not set yet (asset loaded after setupPlayer)
            if duration == 0 {
                if let currentItem = player.currentItem {
                    let durationValue = currentItem.duration
                    if durationValue.isNumeric && !durationValue.isIndefinite {
                        duration = CMTimeGetSeconds(durationValue)
                        print("DEBUG_END_TIME: [Time Observer] ✅ Duration NOW set to: \(duration) seconds")
                    }
                }
            }

            let previousIsPlaying = isPlaying
            // Update isPlaying based on player rate
            isPlaying = player.rate > 0

            if previousIsPlaying != isPlaying {
                print("DEBUG_PAUSE: Time observer detected state change")
                print("DEBUG_PAUSE: previousIsPlaying: \(previousIsPlaying), new isPlaying: \(isPlaying)")
                print("DEBUG_PAUSE: player.rate: \(player.rate)")
            }
        }
        timeObserver = observer
        observedPlayerID = currentPlayerID
        print("DEBUG_PAUSE: ✅ Time observer registered for player ID: \(currentPlayerID)")

        // Initial playing state
        isPlaying = player.rate > 0
        showCenterButton = !isPlaying // Show center button if paused
        print("DEBUG_PAUSE: setupPlayer() complete - isPlaying set to: \(isPlaying)")
    }

    private func togglePlayPause() {
        print("DEBUG_PAUSE: ========================================")
        print("DEBUG_PAUSE: togglePlayPause() called")
        print("DEBUG_PAUSE: BEFORE toggle - isPlaying: \(isPlaying), player.rate: \(player.rate)")

        HapticFeedbackManager.impact(.light)
        isPlaying.toggle()

        print("DEBUG_PAUSE: AFTER toggle - isPlaying: \(isPlaying)")
        print("DEBUG_PAUSE: This should trigger onChange(of: isPlaying)")
        print("DEBUG_PAUSE: ========================================")

        scheduleHideControls()
    }

    private func scheduleHideControls() {
        hideControlsTask?.cancel()

        guard isPlaying else { return }

        hideControlsTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            if !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showControls = false
                    showCenterButton = false
                }
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
}

// MARK: - Preview

#Preview {
    let testURL = Bundle.main.url(forResource: "normal", withExtension: "mp4") ?? URL(fileURLWithPath: "/tmp/test.mp4")
    let player = AVPlayer(url: testURL)

    return CustomVideoPlayerWithControls(
        player: player,
        isMuted: .constant(true),
        videoGravity: .resizeAspect,
        trimStart: nil,
        trimEnd: nil
    )
    .frame(height: 300)
    .background(Color.black)
}
