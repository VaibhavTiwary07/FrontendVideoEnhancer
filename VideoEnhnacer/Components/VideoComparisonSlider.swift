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
        backgroundColor: Color? = nil
    ) {
        self.normalVideoName = normalVideoName
        self.enhancedVideoName = enhancedVideoName
        self.originalURL = originalURL
        self.enhancedURL = enhancedURL
        self.videoPlayerManager = videoPlayerManager
        self.compact = compact
        self.customKey = customKey
        self.backgroundColor = backgroundColor
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
                                        sliderValue = newValue
                                    }
                                    .onEnded { _ in
                                        scheduleAutoSlideResume()
                                    }
                            )

                        // Make the whole video area draggable
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .frame(height: videoHeight)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        isUserInteracting = true
                                        stopAutoSlide()
                                        let newValue = geometry.size.width > 0 ? min(max(value.location.x / geometry.size.width, 0), 1) : sliderValue
                                        sliderValue = newValue
                                    }
                                    .onEnded { _ in
                                        scheduleAutoSlideResume()
                                    }
                            )
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
                                            sliderValue = newValue
                                        }
                                        .onEnded { _ in
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
            print("🎯 VideoComparisonSlider onAppear")
            print("🎯 normalVideoName: \(String(describing: normalVideoName))")
            print("🎯 enhancedVideoName: \(String(describing: enhancedVideoName))")
            print("🎯 originalURL: \(String(describing: originalURL))")
            print("🎯 enhancedURL: \(String(describing: enhancedURL))")
            print("🎯 videoKey: \(videoKey)")
            print("🎯 Current player state: \(playerState)")
            if let originalURL = originalURL { print("🎯 originalURL exists? \(FileManager.default.fileExists(atPath: originalURL.path)) path=\(originalURL.path)") }
            if let enhancedURL = enhancedURL { print("🎯 enhancedURL exists? \(FileManager.default.fileExists(atPath: enhancedURL.path)) path=\(enhancedURL.path)") }
            let hasNormal = videoPlayerManager.getNormalPlayer(forKey: videoKey) != nil
            let hasEnhanced = videoPlayerManager.getEnhancedPlayer(forKey: videoKey) != nil
            print("🎯 Pre-setup players exists? normal=\(hasNormal) enhanced=\(hasEnhanced)")
            
            isViewVisible = true
            
            // Setup video players if not already done
            if let originalURL = originalURL, let enhancedURL = enhancedURL {
                print("🎯 Setting up URL-based players")
                videoPlayerManager.setupVideoPlayers(forKey: videoKey, originalURL: originalURL, processedURL: enhancedURL)
            } else if let normalVideoName = normalVideoName, let enhancedVideoName = enhancedVideoName {
                print("🎯 Setting up asset-based players")
                videoPlayerManager.setupVideoPlayers(forKey: videoKey, normalVideoName: normalVideoName, enhancedVideoName: enhancedVideoName)
            } else {
                print("🎯 ⚠️ No valid video sources provided!")
            }
            
            videoPlayerManager.setViewActive(forKey: videoKey, isActive: true)
            videoPlayerManager.debugStatus(forKey: videoKey, context: "onAppear after setViewActive")

            // If players are already ready, start playing immediately
            if playerState == .ready || playerState == .paused {
                print("🎯 Players already ready on appear - auto-playing")
                videoPlayerManager.resumePlayers(forKey: videoKey)
            }

            startAutoSlide()
        }
        // Re-activate after tab switches to ensure visibility of video and slider
        .onReceive(NotificationCenter.default.publisher(for: .homeTabBecameActive)) { _ in
            print("🎯 VideoComparisonSlider received homeTabBecameActive for key: \(videoKey)")
            isViewVisible = true
            if let originalURL = originalURL, let enhancedURL = enhancedURL {
                videoPlayerManager.setupVideoPlayers(forKey: videoKey, originalURL: originalURL, processedURL: enhancedURL)
            } else if let normalVideoName = normalVideoName, let enhancedVideoName = enhancedVideoName {
                videoPlayerManager.setupVideoPlayers(forKey: videoKey, normalVideoName: normalVideoName, enhancedVideoName: enhancedVideoName)
            }
            videoPlayerManager.setViewActive(forKey: videoKey, isActive: true)

            // Auto-play after tab switch if players are ready
            if playerState == .ready || playerState == .paused {
                print("🎯 Auto-playing after tab switch")
                videoPlayerManager.resumePlayers(forKey: videoKey)
            }
        }
        .onDisappear {
            print("🎯 VideoComparisonSlider onDisappear for key: \(videoKey)")
            isViewVisible = false
            videoPlayerManager.setViewActive(forKey: videoKey, isActive: false)
            stopAutoSlide()
            stopResumeTimer()
            videoPlayerManager.debugStatus(forKey: videoKey, context: "onDisappear after deactivate")
        }
        // iOS 15-compatible onChange signature
        .onChange(of: playerState) { state in
            print("🎯 Player state changed for key '\(videoKey)': \(state)")
            // Re-activate players when they become ready
            if state == .ready && isViewVisible {
                print("🎯 Re-activating players after state change")
                videoPlayerManager.setViewActive(forKey: videoKey, isActive: true)

                // AUTO-PLAY: Comparison mode needs videos to play immediately
                print("🎯 Auto-playing comparison videos")
                videoPlayerManager.resumePlayers(forKey: videoKey)

                videoPlayerManager.debugStatus(forKey: videoKey, context: "onChange -> ready, after setViewActive and play")
            }
        }
    }
    
    private func startAutoSlide() {
        stopAutoSlide()
        if compact {
            autoSlideTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                guard !isUserInteracting else { return }
                let speed = 0.008
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
