import SwiftUI
import AVFoundation
import AVKit

// MARK: - Aspect Ratio Video Player
/// Senior-level video player component with intelligent aspect ratio handling and device-optimized sizing
struct AspectRatioVideoPlayer: View {
    let player: AVPlayer?
    let contentMode: VideoContentMode
    let maxHeight: CGFloat?
    let minHeight: CGFloat?
    let cornerRadius: CGFloat
    
    @State private var videoSize: CGSize = .zero
    @State private var isVideoLoaded = false
    @State private var hasError = false
    
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
                if let player = player, !hasError {
                    VideoPlayer(player: player)
                        .frame(
                            width: optimalWidth(for: geometry.size),
                            height: optimalHeight(for: geometry.size)
                        )
                        .cornerRadius(cornerRadius)
                        .clipped()
                } else {
                    VideoPlaceholder(
                        width: optimalWidth(for: geometry.size),
                        height: optimalHeight(for: geometry.size),
                        cornerRadius: cornerRadius,
                        hasError: hasError
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                loadVideoMetadata()
            }
            .onChange(of: player?.currentItem) { _ in
                loadVideoMetadata()
            }
        }
        .aspectRatio(videoAspectRatio, contentMode: .fit)
    }
    
    // MARK: - Video Sizing Logic
    
    /// Calculate optimal width based on container and video dimensions
    private func optimalWidth(for containerSize: CGSize) -> CGFloat {
        guard videoSize != .zero else {
            return containerSize.width
        }
        
        let height = optimalHeight(for: containerSize)
        let width = height * videoAspectRatio
        
        return min(width, containerSize.width)
    }
    
    /// Calculate optimal height based on device category and video constraints
    private func optimalHeight(for containerSize: CGSize) -> CGFloat {
        let deviceSize = DynamicScaling.currentDeviceSize()
        let deviceOptimalHeight = optimalHeightForDevice(deviceSize)
        
        // If we have video dimensions, use them to calculate proper height
        if videoSize != .zero {
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
    
    /// Video aspect ratio with fallback to 16:9
    private var videoAspectRatio: CGFloat {
        guard videoSize != .zero else { return 16.0/9.0 }
        return videoSize.width / videoSize.height
    }
    
    // MARK: - Video Metadata Loading
    
    private func loadVideoMetadata() {
        guard let player = player,
              let currentItem = player.currentItem else {
            hasError = true
            return
        }
        
        Task {
            do {
                let tracks = try await currentItem.asset.loadTracks(withMediaType: .video)
                guard let videoTrack = tracks.first else {
                    await MainActor.run {
                        hasError = true
                    }
                    return
                }
                
                let naturalSize = try await videoTrack.load(.naturalSize)
                let transform = try await videoTrack.load(.preferredTransform)
                
                await MainActor.run {
                    // Handle video rotation for proper aspect ratio
                    let size = naturalSize.applying(transform)
                    self.videoSize = CGSize(
                        width: abs(size.width),
                        height: abs(size.height)
                    )
                    self.isVideoLoaded = true
                    self.hasError = false
                }
            } catch {
                await MainActor.run {
                    self.hasError = true
                    print("❌ AspectRatioVideoPlayer - Failed to load video metadata: \(error)")
                }
            }
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

// MARK: - Video Placeholder Component
/// Loading and error state placeholder for video player
struct VideoPlaceholder: View {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let hasError: Bool
    
    @State private var animationProgress: CGFloat = 0
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: hasError 
                    ? [Color.red.opacity(0.1), Color.red.opacity(0.05)]
                    : [Color.accentWarm.opacity(0.15), Color.accentWarm.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: width, height: height)
            .overlay(
                placeholderContent
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        hasError 
                        ? Color.red.opacity(0.3)
                        : Color.accentWarm.opacity(0.2), 
                        lineWidth: 1
                    )
            )
            .onAppear {
                if !hasError {
                    startLoadingAnimation()
                }
            }
    }
    
    @ViewBuilder
    private var placeholderContent: some View {
        VStack(spacing: 12) {
            if hasError {
                // Error state
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .dynamicFont(24, weight: .medium)
                        .foregroundColor(.red.opacity(0.7))
                    
                    Text("Video Load Error")
                        .dynamicFont(14, weight: .medium)
                        .foregroundColor(.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            } else {
                // Loading state with skeleton animation
                VStack(spacing: 12) {
                    // Animated loading indicator
                    ZStack {
                        Circle()
                            .stroke(Color.accentWarm.opacity(0.3), lineWidth: 3)
                            .frame(width: 32, height: 32)
                        
                        Circle()
                            .trim(from: 0, to: animationProgress)
                            .stroke(
                                LinearGradient.primaryTheme,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(width: 32, height: 32)
                            .rotationEffect(.degrees(-90))
                    }
                    
                    Text("Loading Video...")
                        .dynamicFont(14, weight: .medium)
                        .foregroundColor(.accentWarm.opacity(0.8))
                }
            }
        }
    }
    
    private func startLoadingAnimation() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
            animationProgress = 1.0
        }
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