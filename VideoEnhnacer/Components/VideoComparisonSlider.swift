import SwiftUI
import AVFoundation
import UIKit

struct VideoComparisonSlider: View {
    // Either provide asset names or URLs
    let normalVideoName: String?
    let enhancedVideoName: String?
    let originalURL: URL?
    let enhancedURL: URL?
    @ObservedObject var videoPlayerManager: VideoPlayerManager
    // When true, fill the given frame without extra background/padding
    let compact: Bool
    // Optional stable key to persist players across view lifecycles
    let customKey: String?
    // Optional background color
    let backgroundColor: Color?
    @State private var sliderValue: Double = 0.3
    @State private var isViewVisible: Bool = false
    @State private var isUserInteracting: Bool = false
    @State private var autoSlideTimer: Timer?
    @State private var resumeTimer: Timer?
    @State private var autoSlideDirection: Double = 1.0

    // Throttling for slider updates
    @State private var sliderUpdateWorkItem: DispatchWorkItem?

    // Tap vs Drag detection
    @State private var dragStartLocation: CGPoint?
    @State private var dragStartTime: Date?
    @State private var isDragging: Bool = false
    let onTapDetected: (() -> Void)?

    // Video playback controls
    @State private var isPlaying: Bool = true
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var showVideoControls: Bool = true
    @State private var isSeeking: Bool = false
    @State private var timeObserver: Any?
    @State private var hideControlsTask: Task<Void, Never>?

    private var videoKey: String {
        if let customKey = customKey, !customKey.isEmpty { return customKey }
        if let originalURL = originalURL, let enhancedURL = enhancedURL {
            return "\(originalURL.absoluteString.hashValue)-\(enhancedURL.absoluteString.hashValue)"
        }
        return "\(normalVideoName ?? "")->\(enhancedVideoName ?? "")"
    }
    
    private var playerState: VideoPlayerManager.PlayerState {
        videoPlayerManager.getPlayerState(forKey: videoKey)
    }
    
    private var labelTextColor: Color {
        if let backgroundColor = backgroundColor, backgroundColor == Color.black {
            return .white
        }
        return .secondaryText
    }

    init(
        normalVideoName: String? = nil,
        enhancedVideoName: String? = nil,
        originalURL: URL? = nil,
        enhancedURL: URL? = nil,
        videoPlayerManager: VideoPlayerManager,
        compact: Bool = false,
        customKey: String? = nil,
        backgroundColor: Color? = nil,
        onTapDetected: (() -> Void)? = nil
    ) {
        self.normalVideoName = normalVideoName
        self.enhancedVideoName = enhancedVideoName
        self.originalURL = originalURL
        self.enhancedURL = enhancedURL
        self.videoPlayerManager = videoPlayerManager
        self.compact = compact
        self.customKey = customKey
        self.backgroundColor = backgroundColor
        self.onTapDetected = onTapDetected
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Safety check for geometry to prevent NaN crashes
                if geometry.size.width <= 0 || geometry.size.height <= 0 || 
                   geometry.size.width.isNaN || geometry.size.height.isNaN || 
                   geometry.size.width.isInfinite || geometry.size.height.isInfinite {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Text("Loading...")
                                .foregroundColor(.secondary)
                        )
                } else {
                // Background (skip in compact mode)
                if !compact {
                    if let backgroundColor = backgroundColor, backgroundColor == Color.black {
                        // Pure black background without any styling
                        Rectangle()
                            .fill(backgroundColor)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(backgroundColor ?? Color.cardBackground)
                            .neomorphicStyle(cornerRadius: 12, shadowRadius: 6)
                    }
                } else if let backgroundColor = backgroundColor {
                    Rectangle()
                        .fill(backgroundColor)
                        .ignoresSafeArea()
                }
                
                // Video Comparison Area
                VStack(spacing: compact ? 0 : 12) {
                    // Video Players Container
                    ZStack {
                        let videoHeight = compact ? geometry.size.height : max(60, geometry.size.height - 90)
                        let videoWidth = geometry.size.width
                        // Enhanced Video (Background)
                        Group {
                            if (playerState == .ready || playerState == .paused),
                               let enhancedPlayer = videoPlayerManager.getEnhancedPlayer(forKey: videoKey) {
                                AVPlayerUIView(player: enhancedPlayer, videoGravity: compact ? .resizeAspectFill : .resizeAspect)
                                    .frame(width: videoWidth, height: videoHeight)
                                    .if(!compact) { view in
                                        view.clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                            } else {
                                videoPlaceholder(title: "Enhanced", isLoading: playerState == .loading, height: videoHeight)
                                    .if(!compact) { view in
                                        view.clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                            }
                        }
                        
                        // Normal Video (Overlay with mask)
                        Group {
                            if (playerState == .ready || playerState == .paused),
                               let normalPlayer = videoPlayerManager.getNormalPlayer(forKey: videoKey) {
                                AVPlayerUIView(player: normalPlayer, videoGravity: compact ? .resizeAspectFill : .resizeAspect)
                                    .frame(width: videoWidth, height: videoHeight)
                                    .if(!compact) { view in
                                        view.clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .mask(
                                        HStack(spacing: 0) {
                                            Rectangle()
                                                .frame(width: max(0, min(geometry.size.width, geometry.size.width * sliderValue)))

                                            Color.clear
                                        }
                                    )
                            } else {
                                videoPlaceholder(title: "Normal", isLoading: playerState == .loading, height: videoHeight)
                                    .if(!compact) { view in
                                        view.clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .mask(
                                        HStack(spacing: 0) {
                                            Rectangle()
                                                .frame(width: max(0, min(geometry.size.width, geometry.size.width * sliderValue)))

                                            Color.clear
                                        }
                                    )
                            }
                        }
                        
                        // Divider Line
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 2, height: videoHeight)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 0)
                            .position(
                                x: max(1, min(geometry.size.width - 1, geometry.size.width * sliderValue)),
                                y: max(1, videoHeight / 2)
                            )

                        // Draggable handle aligned with divider
                        Circle()
                            .fill(Color.white)
                            .frame(width: 22, height: 22)
                            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)
                            .position(
                                x: max(11, min(geometry.size.width - 11, geometry.size.width * sliderValue)),
                                y: max(12, videoHeight / 2)
                            )
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        isUserInteracting = true
                                        stopAutoSlide()
                                        let newValue = geometry.size.width > 0 ? min(max(value.location.x / geometry.size.width, 0), 1) : sliderValue

                                        // Cancel previous update
                                        sliderUpdateWorkItem?.cancel()

                                        // Update immediately for smooth feedback on handle
                                        sliderValue = newValue
                                    }
                                    .onEnded { _ in
                                        sliderUpdateWorkItem?.cancel()
                                        scheduleAutoSlideResume()
                                    }
                            )

                        // Make the whole video area draggable with tap detection
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .frame(height: videoHeight)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        // Initialize tracking on first change
                                        if dragStartLocation == nil {
                                            dragStartLocation = value.startLocation
                                            dragStartTime = Date()
                                        }

                                        // Calculate distance from start
                                        let distance = hypot(
                                            value.location.x - value.startLocation.x,
                                            value.location.y - value.startLocation.y
                                        )

                                        // Only treat as drag if movement exceeds threshold (10 points)
                                        if distance > 10 {
                                            isDragging = true
                                            isUserInteracting = true
                                            stopAutoSlide()

                                            // Throttle updates to reduce lag
                                            let newValue = geometry.size.width > 0 ? min(max(value.location.x / geometry.size.width, 0), 1) : sliderValue

                                            // Cancel previous update
                                            sliderUpdateWorkItem?.cancel()

                                            // Update immediately for visual feedback
                                            sliderValue = newValue
                                        }
                                    }
                                    .onEnded { value in
                                        // Calculate final metrics
                                        let distance = hypot(
                                            value.location.x - value.startLocation.x,
                                            value.location.y - value.startLocation.y
                                        )
                                        let duration = dragStartTime.map { Date().timeIntervalSince($0) } ?? 0

                                        // Determine if it was a tap: < 10pt movement AND < 200ms duration
                                        if !isDragging && distance < 10 && duration < 0.2 {
                                            // TAP DETECTED - trigger callback to open video picker
                                            onTapDetected?()
                                        }

                                        // Reset state
                                        dragStartLocation = nil
                                        dragStartTime = nil
                                        isDragging = false
                                        sliderUpdateWorkItem?.cancel()

                                        if isUserInteracting {
                                            scheduleAutoSlideResume()
                                        }
                                    }
                            )

                        // Video Playback Controls Overlay (only in non-compact mode)
                        // Place controls ABOVE draggable area to ensure button receives touches
                        if !compact && showVideoControls && (playerState == .ready || playerState == .paused) {
                            videoPlaybackControls(height: videoHeight)
                                .allowsHitTesting(true) // Ensure controls receive touches
                                .zIndex(10) // Higher z-index to be on top
                        }
                    }
                    .onTapGesture {
                        // Only toggle controls in non-compact mode (results page)
                        if !compact {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showVideoControls.toggle()
                            }
                            if showVideoControls {
                                scheduleHideControls()
                            }
                        }
                    }
                    
                    if !compact {
                        // Labels
                        HStack {
                            Text("Before")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(labelTextColor)
                            
                            Spacer()
                            
                            Text("After")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(labelTextColor)
                        }
                        .padding(.horizontal, 8)
                        
                        // Custom Slider
                        ZStack {
                            // Track
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(
                                            LinearGradient(
                                                stops: [
                                                    .init(color: Color(red: 255/255, green: 16/255, blue: 0/255).opacity(0.91), location: 0.0),
                                                    .init(color: Color(red: 255/255, green: 110/255, blue: 99/255).opacity(0.3), location: 0.7)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: max(0, min(geometry.size.width, geometry.size.width * sliderValue)), height: 4)
                                        .clipShape(RoundedRectangle(cornerRadius: 2)),
                                    alignment: .leading
                                )
                            
                            // Thumb
                            Circle()
                                .fill(Color.white)
                                .frame(width: 20, height: 20)
                                .background(
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                stops: [
                                                    .init(color: Color(red: 255/255, green: 16/255, blue: 0/255).opacity(0.91), location: 0.0),
                                                    .init(color: Color(red: 255/255, green: 110/255, blue: 99/255).opacity(0.3), location: 0.7)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 18, height: 18)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                                .position(
                                    x: max(10, min(geometry.size.width - 10, geometry.size.width * sliderValue)),
                                    y: 10
                                )
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            isUserInteracting = true
                                            stopAutoSlide()
                                            let newValue = geometry.size.width > 0 ? min(max(value.location.x / geometry.size.width, 0), 1) : sliderValue

                                            // Cancel previous update
                                            sliderUpdateWorkItem?.cancel()

                                            // Update immediately for smooth feedback
                                            sliderValue = newValue
                                        }
                                        .onEnded { _ in
                                            sliderUpdateWorkItem?.cancel()
                                            scheduleAutoSlideResume()
                                        }
                                )
                        }
                        .frame(height: 20)
                    }
                }
                .padding(compact ? 0 : 8)
                } // End of geometry safety check
            }
        }
        .onAppear {
            print("DEBUG_COMPARE: VideoComparisonSlider onAppear")
            print("DEBUG_COMPARE: normalVideoName: \(String(describing: normalVideoName))")
            print("DEBUG_COMPARE: enhancedVideoName: \(String(describing: enhancedVideoName))")
            print("DEBUG_COMPARE: originalURL: \(String(describing: originalURL))")
            print("DEBUG_COMPARE: enhancedURL: \(String(describing: enhancedURL))")
            print("DEBUG_COMPARE: videoKey: \(videoKey)")
            print("DEBUG_COMPARE: Current player state: \(playerState)")
            if let originalURL = originalURL { print("DEBUG_COMPARE: originalURL exists? \(FileManager.default.fileExists(atPath: originalURL.path)) path=\(originalURL.path)") }
            if let enhancedURL = enhancedURL { print("DEBUG_COMPARE: enhancedURL exists? \(FileManager.default.fileExists(atPath: enhancedURL.path)) path=\(enhancedURL.path)") }
            let hasNormal = videoPlayerManager.getNormalPlayer(forKey: videoKey) != nil
            let hasEnhanced = videoPlayerManager.getEnhancedPlayer(forKey: videoKey) != nil
            print("DEBUG_COMPARE: Pre-setup players exists? normal=\(hasNormal) enhanced=\(hasEnhanced)")

            if hasNormal, let normalPlayer = videoPlayerManager.getNormalPlayer(forKey: videoKey) {
                let normalTime = CMTimeGetSeconds(normalPlayer.currentTime())
                print("DEBUG_COMPARE: Normal player current time: \(String(format: "%.3f", normalTime))s")
            }
            if hasEnhanced, let enhancedPlayer = videoPlayerManager.getEnhancedPlayer(forKey: videoKey) {
                let enhancedTime = CMTimeGetSeconds(enhancedPlayer.currentTime())
                print("DEBUG_COMPARE: Enhanced player current time: \(String(format: "%.3f", enhancedTime))s")
            }

            isViewVisible = true

            // Setup video players if not already done
            if let originalURL = originalURL, let enhancedURL = enhancedURL {
                print("DEBUG_COMPARE: Setting up URL-based players")
                videoPlayerManager.setupVideoPlayers(forKey: videoKey, originalURL: originalURL, processedURL: enhancedURL)
            } else if let normalVideoName = normalVideoName, let enhancedVideoName = enhancedVideoName {
                print("DEBUG_COMPARE: Setting up asset-based players")
                videoPlayerManager.setupVideoPlayers(forKey: videoKey, normalVideoName: normalVideoName, enhancedVideoName: enhancedVideoName)
            } else {
                print("DEBUG_COMPARE: ⚠️ No valid video sources provided!")
            }

            videoPlayerManager.setViewActive(forKey: videoKey, isActive: true)
            videoPlayerManager.debugStatus(forKey: videoKey, context: "onAppear after setViewActive")

            // If players are already ready, start playing immediately
            if playerState == .ready || playerState == .paused {
                print("DEBUG_COMPARE: Players already ready on appear - auto-playing")
                videoPlayerManager.resumePlayers(forKey: videoKey)
            }

            startAutoSlide()

            // Only setup time observer for non-compact mode (results page)
            if !compact {
                setupTimeObserver()
            }
        }
        // Re-activate after tab switches to ensure visibility of video and slider
        .onReceive(NotificationCenter.default.publisher(for: .homeTabBecameActive)) { _ in
            print("DEBUG_COMPARE: VideoComparisonSlider received homeTabBecameActive for key: \(videoKey)")
            isViewVisible = true
            if let originalURL = originalURL, let enhancedURL = enhancedURL {
                videoPlayerManager.setupVideoPlayers(forKey: videoKey, originalURL: originalURL, processedURL: enhancedURL)
            } else if let normalVideoName = normalVideoName, let enhancedVideoName = enhancedVideoName {
                videoPlayerManager.setupVideoPlayers(forKey: videoKey, normalVideoName: normalVideoName, enhancedVideoName: enhancedVideoName)
            }
            videoPlayerManager.setViewActive(forKey: videoKey, isActive: true)

            // Auto-play after tab switch if players are ready
            if playerState == .ready || playerState == .paused {
                print("DEBUG_COMPARE: Auto-playing after tab switch")
                videoPlayerManager.resumePlayers(forKey: videoKey)
            }
        }
        .onDisappear {
            print("DEBUG_COMPARE: VideoComparisonSlider onDisappear for key: \(videoKey)")
            isViewVisible = false
            videoPlayerManager.setViewActive(forKey: videoKey, isActive: false)
            stopAutoSlide()
            stopResumeTimer()
            cleanupTimeObserver()
            hideControlsTask?.cancel()
            videoPlayerManager.debugStatus(forKey: videoKey, context: "onDisappear after deactivate")
        }
        // iOS 15-compatible onChange signature
        .onChange(of: playerState) { state in
            print("DEBUG_COMPARE: Player state changed for key '\(videoKey)': \(state)")

            // Log player times when state changes
            if let normalPlayer = videoPlayerManager.getNormalPlayer(forKey: videoKey),
               let enhancedPlayer = videoPlayerManager.getEnhancedPlayer(forKey: videoKey) {
                let normalTime = CMTimeGetSeconds(normalPlayer.currentTime())
                let enhancedTime = CMTimeGetSeconds(enhancedPlayer.currentTime())
                print("DEBUG_COMPARE: State change - normalTime=\(String(format: "%.3f", normalTime))s enhancedTime=\(String(format: "%.3f", enhancedTime))s")
            }

            // Re-activate players when they become ready
            if state == .ready && isViewVisible {
                print("DEBUG_COMPARE: Re-activating players after state change")
                videoPlayerManager.setViewActive(forKey: videoKey, isActive: true)

                // AUTO-PLAY: Comparison mode needs videos to play immediately
                print("DEBUG_COMPARE: Auto-playing comparison videos")
                videoPlayerManager.resumePlayers(forKey: videoKey)

                videoPlayerManager.debugStatus(forKey: videoKey, context: "onChange -> ready, after setViewActive and play")
            }
        }
    }
    
    private func startAutoSlide() {
        stopAutoSlide()
        if compact {
            // Reduced frequency from 50ms (20fps) to 100ms (10fps) for better performance
            // Doubled speed to maintain same visual velocity
            autoSlideTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                guard !isUserInteracting else { return }

                // Only update if controls are not showing to avoid interference
                guard !showVideoControls else { return }

                let speed = 0.016 // Doubled from 0.008 to compensate for 2x longer interval
                sliderValue += speed * autoSlideDirection
                if sliderValue >= 1.0 {
                    sliderValue = 1.0
                    autoSlideDirection = -1.0
                } else if sliderValue <= 0.0 {
                    sliderValue = 0.0
                    autoSlideDirection = 1.0
                }
            }
        } else {
            autoSlideTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { _ in
                guard !isUserInteracting else { return }
                withAnimation(.easeInOut(duration: 1.5)) {
                    if sliderValue == 0.3 {
                        sliderValue = 1.0
                    } else if sliderValue == 1.0 {
                        sliderValue = 0.0
                    } else {
                        sliderValue = 0.3
                    }
                }
            }
        }
    }
    
    private func stopAutoSlide() {
        autoSlideTimer?.invalidate()
        autoSlideTimer = nil
    }
    
    private func scheduleAutoSlideResume() {
        stopResumeTimer()
        resumeTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            isUserInteracting = false
            startAutoSlide()
        }
    }
    
    private func stopResumeTimer() {
        resumeTimer?.invalidate()
        resumeTimer = nil
    }
    
    @ViewBuilder
    private func videoPlaceholder(title: String, isLoading: Bool, height: CGFloat) -> some View {
        Rectangle()
            .fill(LinearGradient(
                stops: [
                    .init(color: Color(red: 255/255, green: 16/255, blue: 0/255).opacity(0.27), location: 0.0),
                    .init(color: Color(red: 255/255, green: 110/255, blue: 99/255).opacity(0.09), location: 0.7)
                ],
                startPoint: .leading,
                endPoint: .trailing
            ))
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                ZStack {
                    if isLoading {
                        VStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(Color.primaryText.opacity(0.6))
                            
                            Text("Loading...")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondaryText)
                        }
                    } else {
                        Text(title)
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                }
            )
    }

    // MARK: - Video Playback Controls

    @ViewBuilder
    private func videoPlaybackControls(height: CGFloat) -> some View {
        VStack {
            Spacer()

            // Center play/pause button
            Button(action: togglePlayPause) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 54))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(PlainButtonStyle()) // Ensure button receives touches properly
            .contentShape(Rectangle()) // Expand touch target

            Spacer()

            // Bottom seek bar and time display
            VStack(spacing: 8) {
                // Seek bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track background
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 4)

                        // Progress
                        Capsule()
                            .fill(Color.white)
                            .frame(width: max(0, geo.size.width * (duration > 0 ? currentTime / duration : 0)), height: 4)

                        // Draggable thumb
                        Circle()
                            .fill(Color.white)
                            .frame(width: 16, height: 16)
                            .offset(x: max(0, geo.size.width * (duration > 0 ? currentTime / duration : 0)) - 8)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        isSeeking = true
                                        let newTime = max(0, min(duration, (value.location.x / geo.size.width) * duration))
                                        currentTime = newTime
                                    }
                                    .onEnded { value in
                                        let newTime = max(0, min(duration, (value.location.x / geo.size.width) * duration))
                                        seekToTime(newTime)
                                        isSeeking = false
                                        scheduleHideControls()
                                    }
                            )
                    }
                }
                .frame(height: 16)

                // Time display
                HStack {
                    Text(formatTime(currentTime))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)

                    Spacer()

                    Text(formatTime(duration))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .background(
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .frame(height: height)
    }

    private func setupTimeObserver() {
        guard let normalPlayer = videoPlayerManager.getNormalPlayer(forKey: videoKey) else { return }

        // Get duration
        if let currentItem = normalPlayer.currentItem {
            let durationValue = currentItem.duration
            if durationValue.isNumeric && !durationValue.isIndefinite {
                duration = CMTimeGetSeconds(durationValue)
            }
        }

        // Add time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        let observer = normalPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak normalPlayer] time in
            guard !isSeeking, let player = normalPlayer else { return }
            currentTime = CMTimeGetSeconds(time)

            // Update duration if not set yet
            if duration == 0, let currentItem = player.currentItem {
                let durationValue = currentItem.duration
                if durationValue.isNumeric && !durationValue.isIndefinite {
                    duration = CMTimeGetSeconds(durationValue)
                }
            }

            // Update playing state
            isPlaying = player.rate > 0
        }
        timeObserver = observer
    }

    private func cleanupTimeObserver() {
        if let observer = timeObserver,
           let player = videoPlayerManager.getNormalPlayer(forKey: videoKey) {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    private func togglePlayPause() {
        if isPlaying {
            videoPlayerManager.pausePlayers(forKey: videoKey)
            isPlaying = false
        } else {
            videoPlayerManager.resumePlayers(forKey: videoKey)
            isPlaying = true
        }
        scheduleHideControls()
    }

    private func seekToTime(_ time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

        // Seek both players simultaneously
        if let normalPlayer = videoPlayerManager.getNormalPlayer(forKey: videoKey) {
            normalPlayer.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        if let enhancedPlayer = videoPlayerManager.getEnhancedPlayer(forKey: videoKey) {
            enhancedPlayer.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    private func formatTime(_ time: Double) -> String {
        guard !time.isNaN && !time.isInfinite else { return "0:00" }
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func scheduleHideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            if !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.3)) {
                    showVideoControls = false
                }
            }
        }
    }
}

final class PlayerContainerView: UIView {
    let playerLayer = AVPlayerLayer()
    
    override func layoutSubviews() {
        super.layoutSubviews()

        // Guard against invalid bounds during app transitions
        guard bounds.width > 0, bounds.height > 0,
              !bounds.width.isNaN, !bounds.height.isNaN,
              !bounds.width.isInfinite, !bounds.height.isInfinite else {
            print("🎥 PlayerContainerView.layoutSubviews skipped - invalid bounds=\(bounds)")
            return
        }

        playerLayer.frame = bounds
        print("🎥 PlayerContainerView.layoutSubviews bounds=\(bounds)")
    }
}

struct AVPlayerUIView: UIViewRepresentable {
    let player: AVPlayer
    let videoGravity: AVLayerVideoGravity
    
    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = videoGravity
        view.layer.addSublayer(view.playerLayer)
        
        // Disable AirPlay for all video players
        player.allowsExternalPlayback = false
        
        print("🎥 AVPlayerUIView.makeUIView created container with initial bounds=\(view.bounds) gravity=\(videoGravity.rawValue)")
        return view
    }
    
    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.playerLayer.player = player
        uiView.playerLayer.videoGravity = videoGravity

        // Disable AirPlay for all video players
        player.allowsExternalPlayback = false

        // Defer layout update to next run loop to avoid mid-transition calls
        DispatchQueue.main.async {
            uiView.setNeedsLayout()
        }
        print("🎥 AVPlayerUIView.updateUIView applied player + gravity; bounds=\(uiView.bounds)")
    }
}
//
//#Preview {
//    VideoComparisonSlider(
//        normalVideoName: "normal",
//        enhancedVideoName: "enhanced",
//        originalURL: nil,
//        enhancedURL: nil,
//        videoPlayerManager: VideoPlayerManager()
//    )
//    .frame(height: 160)
//    .padding()
//    .background(Color.appBackground)
//}
