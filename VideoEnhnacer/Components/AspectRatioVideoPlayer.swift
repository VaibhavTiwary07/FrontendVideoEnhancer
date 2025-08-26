import SwiftUI
import AVFoundation
import AVKit
import Combine

// MARK: - Video Loading State
/// Professional state management for video loading lifecycle
enum VideoLoadingState: Equatable {
    case loading
    case ready(videoSize: CGSize)
    case error(String)
    
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
    
    var hasError: Bool {
        if case .error = self { return true }
        return false
    }
    
    var videoSize: CGSize {
        if case .ready(let size) = self { return size }
        return CGSize(width: 16, height: 9) // Default 16:9 fallback
    }
    
    var errorMessage: String? {
        if case .error(let message) = self { return message }
        return nil
    }
}

// MARK: - Video Loading Manager (ObservableObject for proper state management)
class VideoLoadingManager: ObservableObject {
    @Published var loadingState: VideoLoadingState = .loading
    private var cancellables = Set<AnyCancellable>()
    private var loadingTimeout: Timer?
    private let loadingTimeoutDuration: TimeInterval = 10.0
    
    func startVideoLoading(for player: AVPlayer?) {
        cleanup()
        loadingState = .loading
        
        guard let player = player else {
            loadingState = .error("No player available")
            return
        }
        
        startLoadingTimeout()
        observePlayerStatus(player: player)
    }
    
    private func observePlayerStatus(player: AVPlayer) {
        guard let currentItem = player.currentItem else {
            loadingState = .error("Player item unavailable")
            return
        }
        
        currentItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.handlePlayerItemStatus(status, currentItem: currentItem)
            }
            .store(in: &cancellables)
    }
    
    private func handlePlayerItemStatus(_ status: AVPlayerItem.Status, currentItem: AVPlayerItem) {
        switch status {
        case .readyToPlay:
            cancelLoadingTimeout()
            loadVideoMetadata(from: currentItem)
            
        case .failed:
            cancelLoadingTimeout()
            let errorMessage = currentItem.error?.localizedDescription ?? "Video failed to load"
            loadingState = .error(errorMessage)
            print("❌ AspectRatioVideoPlayer - Player item failed: \(errorMessage)")
            
        case .unknown:
            break
            
        @unknown default:
            cancelLoadingTimeout()
            loadingState = .error("Unknown player status")
        }
    }
    
    private func loadVideoMetadata(from playerItem: AVPlayerItem) {
        Task {
            do {
                let tracks = try await playerItem.asset.loadTracks(withMediaType: .video)
                guard let videoTrack = tracks.first else {
                    await MainActor.run {
                        self.loadingState = .error("No video track found")
                    }
                    return
                }
                
                let naturalSize = try await videoTrack.load(.naturalSize)
                let transform = try await videoTrack.load(.preferredTransform)
                
                await MainActor.run {
                    let size = naturalSize.applying(transform)
                    let correctedSize = CGSize(
                        width: abs(size.width),
                        height: abs(size.height)
                    )
                    
                    guard correctedSize.width > 0 && correctedSize.height > 0 else {
                        self.loadingState = .error("Invalid video dimensions")
                        return
                    }
                    
                    self.loadingState = .ready(videoSize: correctedSize)
                    print("✅ AspectRatioVideoPlayer - Video loaded successfully: \(correctedSize)")
                }
                
            } catch {
                await MainActor.run {
                    self.loadingState = .error("Metadata load failed: \(error.localizedDescription)")
                    print("❌ AspectRatioVideoPlayer - Metadata error: \(error)")
                }
            }
        }
    }
    
    private func startLoadingTimeout() {
        loadingTimeout = Timer.scheduledTimer(withTimeInterval: loadingTimeoutDuration, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                if self?.loadingState.isLoading == true {
                    self?.loadingState = .error("Video load timeout")
                    print("⏰ AspectRatioVideoPlayer - Loading timeout after \(self?.loadingTimeoutDuration ?? 0) seconds")
                }
            }
        }
    }
    
    private func cancelLoadingTimeout() {
        loadingTimeout?.invalidate()
        loadingTimeout = nil
    }
    
    func cleanup() {
        cancelLoadingTimeout()
        cancellables.removeAll()
    }
    
    deinit {
        cleanup()
    }
}

// MARK: - Senior-Level Aspect Ratio Video Player
/// Bulletproof video player with comprehensive error handling and intelligent sizing
struct AspectRatioVideoPlayer: View {
    let player: AVPlayer?
    let contentMode: VideoContentMode
    let maxHeight: CGFloat?
    let minHeight: CGFloat?
    let cornerRadius: CGFloat
    
    @StateObject private var loadingManager = VideoLoadingManager()
    
    init(
        player: AVPlayer?,
        contentMode: VideoContentMode = .fit,
        maxHeight: CGFloat? = nil,
        minHeight: CGFloat? = nil,
        cornerRadius: CGFloat = 20
    ) {
        self.player = player
        self.contentMode = contentMode
        self.maxHeight = maxHeight
        self.minHeight = minHeight
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                switch loadingManager.loadingState {
                case .loading:
                    VideoLoadingPlaceholder(
                        width: optimalWidth(for: geometry.size),
                        height: optimalHeight(for: geometry.size),
                        cornerRadius: cornerRadius
                    )
                    
                case .ready:
                    if let player = player {
                        VideoPlayer(player: player)
                            .frame(
                                width: optimalWidth(for: geometry.size),
                                height: optimalHeight(for: geometry.size)
                            )
                            .cornerRadius(cornerRadius)
                            .clipped()
                    } else {
                        VideoErrorPlaceholder(
                            width: optimalWidth(for: geometry.size),
                            height: optimalHeight(for: geometry.size),
                            cornerRadius: cornerRadius,
                            errorMessage: "Player unavailable"
                        )
                    }
                    
                case .error(let errorMessage):
                    VideoErrorPlaceholder(
                        width: optimalWidth(for: geometry.size),
                        height: optimalHeight(for: geometry.size),
                        cornerRadius: cornerRadius,
                        errorMessage: errorMessage
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(videoAspectRatio, contentMode: .fit)
        .onAppear {
            loadingManager.startVideoLoading(for: player)
        }
        .onDisappear {
            loadingManager.cleanup()
        }
        .onChange(of: player?.currentItem) { _ in
            loadingManager.startVideoLoading(for: player)
        }
    }
    
    // MARK: - Video Sizing Logic
    
    /// Video aspect ratio with intelligent fallbacks
    private var videoAspectRatio: CGFloat {
        let size = loadingManager.loadingState.videoSize
        guard size.width > 0 && size.height > 0 else { return 16.0/9.0 }
        return size.width / size.height
    }
    
    /// Calculate optimal width based on container and video dimensions
    private func optimalWidth(for containerSize: CGSize) -> CGFloat {
        let height = optimalHeight(for: containerSize)
        let width = height * videoAspectRatio
        return min(width, containerSize.width)
    }
    
    /// Calculate optimal height with device-optimized sizing
    private func optimalHeight(for containerSize: CGSize) -> CGFloat {
        let deviceSize = DynamicScaling.currentDeviceSize()
        let deviceOptimalHeight = optimalHeightForDevice(deviceSize)
        
        // Use video dimensions for aspect-based height calculation
        let videoSize = loadingManager.loadingState.videoSize
        if videoSize.width > 0 && videoSize.height > 0 {
            let aspectBasedHeight = containerSize.width / videoAspectRatio
            let constrainedHeight = min(aspectBasedHeight, deviceOptimalHeight)
            
            if let maxH = maxHeight {
                return min(constrainedHeight, maxH)
            }
            if let minH = minHeight {
                return max(constrainedHeight, minH)
            }
            
            return constrainedHeight
        }
        
        // Fallback to device-optimized height
        if let maxH = maxHeight {
            return min(deviceOptimalHeight, maxH)
        }
        if let minH = minHeight {
            return max(deviceOptimalHeight, minH)
        }
        
        return deviceOptimalHeight
    }
    
    /// Device-category based optimal heights for video content
    private func optimalHeightForDevice(_ deviceSize: DeviceSize) -> CGFloat {
        switch deviceSize {
        case .compact:    return 200  // iPhone SE, iPod touch
        case .standard:   return 250  // iPhone 14, 15
        case .large:      return 280  // iPhone Pro Max
        case .tablet:     return 400  // iPad mini
        case .desktop:    return 500  // iPad Pro
        }
    }
}

// MARK: - Video Content Mode
/// Defines how video content should be displayed within its frame
enum VideoContentMode {
    case fit        // Scale to fit within bounds (letterboxing)
    case fill       // Scale to fill bounds (may crop)
    case center     // Display at natural size, centered
}

// MARK: - Professional Video Placeholder Components

/// Senior-level loading placeholder with sophisticated animations
struct VideoLoadingPlaceholder: View {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        Color.accentWarm.opacity(0.15),
                        Color.accentWarm.opacity(0.08),
                        Color.accentWarm.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: width, height: height)
            .overlay(
                VStack(spacing: 16) {
                    // Professional loading indicator
                    ZStack {
                        // Outer ring
                        Circle()
                            .stroke(Color.accentWarm.opacity(0.2), lineWidth: 4)
                            .frame(width: 48, height: 48)
                        
                        // Animated inner ring
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(
                                LinearGradient.primaryTheme,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 48, height: 48)
                            .rotationEffect(.degrees(rotationAngle))
                            .scaleEffect(pulseScale)
                    }
                    
                    VStack(spacing: 6) {
                        Text("Loading Video")
                            .dynamicFont(16, weight: .semibold)
                            .foregroundColor(.accentWarm)
                        
                        Text("Preparing content...")
                            .dynamicFont(12, weight: .medium)
                            .foregroundColor(.accentWarm.opacity(0.7))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.accentWarm.opacity(0.2), lineWidth: 1)
            )
            .onAppear {
                startAnimations()
            }
    }
    
    private func startAnimations() {
        // Rotation animation
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
        
        // Pulse animation
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
        }
    }
}

/// Senior-level error placeholder with actionable feedback
struct VideoErrorPlaceholder: View {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let errorMessage: String
    
    @State private var showingDetails = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        Color.red.opacity(0.08),
                        Color.red.opacity(0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: width, height: height)
            .overlay(
                VStack(spacing: 16) {
                    // Error icon with subtle animation
                    Image(systemName: "exclamationmark.triangle.fill")
                        .dynamicFont(32, weight: .medium)
                        .foregroundColor(.red.opacity(0.7))
                        .scaleEffect(showingDetails ? 1.1 : 1.0)
                    
                    VStack(spacing: 8) {
                        Text("Video Load Error")
                            .dynamicFont(16, weight: .semibold)
                            .foregroundColor(.red.opacity(0.8))
                        
                        Text(errorMessage.count > 50 ? 
                             String(errorMessage.prefix(50)) + "..." : 
                             errorMessage)
                            .dynamicFont(12, weight: .medium)
                            .foregroundColor(.red.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    
                    // Tap to expand details
                    if errorMessage.count > 50 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showingDetails.toggle()
                            }
                        }) {
                            Text(showingDetails ? "Show Less" : "Show Details")
                                .dynamicFont(11, weight: .medium)
                                .foregroundColor(.red.opacity(0.7))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.red.opacity(0.1))
                                        .overlay(
                                            Capsule().stroke(Color.red.opacity(0.2), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .opacity(showingDetails ? 0.9 : 0.8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 30) {
        // Loading state
        AspectRatioVideoPlayer(
            player: nil,
            contentMode: .fit,
            maxHeight: 300
        )
        .frame(height: 200)
        
        // Error state  
        AspectRatioVideoPlayer(
            player: AVPlayer(),
            contentMode: .fit,
            maxHeight: 300
        )
        .frame(height: 200)
    }
    .padding(20)
    .background(Color.appBackground)
}