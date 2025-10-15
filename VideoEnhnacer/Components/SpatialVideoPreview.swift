import SwiftUI
import AVFoundation
import AVKit

struct SpatialVideoPreview: View {
    let videoURL: URL
    let enhancementType: String
    let trimStartTime: Double?
    let trimEndTime: Double?
    // Optional override to control height from parent views
    let customHeight: CGFloat?
    @State private var scrollOffset: CGFloat = 0
    @StateObject private var playerManager = VideoPreviewManager()
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    // Debug tracking
    private let debugId = UUID().uuidString.prefix(8)
    @State private var setupCallCount = 0
    @State private var viewAppearCount = 0
    @State private var viewDisappearCount = 0
    @State private var isMuted: Bool = true

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    init(
        videoURL: URL,
        enhancementType: String,
        trimStartTime: Double?,
        trimEndTime: Double?,
        customHeight: CGFloat? = nil
    ) {
        self.videoURL = videoURL
        self.enhancementType = enhancementType
        self.trimStartTime = trimStartTime
        self.trimEndTime = trimEndTime
        self.customHeight = customHeight
    }
    
    private var videoHeight: CGFloat {
        if let customHeight {
            return customHeight
        }
        // Default emphasis when not overridden
        return isIPad ? 520 : 420
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background depth layers
                BackgroundDepthLayers(scrollOffset: scrollOffset)
                
                // Main video preview
                mainVideoContainer
                    .frame(maxWidth: .infinity)
            }
        }
        // Important: give explicit height when used inside ScrollView to avoid layout collisions
        .frame(height: videoHeight)
        .onAppear {
            viewAppearCount += 1
            print("🎬 SpatialVideoPreview[\(debugId)] - onAppear #\(viewAppearCount)")
            print("  URL: \(videoURL.lastPathComponent)")
            print("  Enhancement: \(enhancementType)")
            print("  Trim: \(trimStartTime ?? -1)s to \(trimEndTime ?? -1)s")
            print("  Height: \(videoHeight)")
            print("  Player exists: \(playerManager.player != nil)")
            setupVideo()
        }
        .onDisappear {
            viewDisappearCount += 1
            print("🎬 SpatialVideoPreview[\(debugId)] - onDisappear #\(viewDisappearCount)")
            print("  Player exists before cleanup: \(playerManager.player != nil)")
            playerManager.cleanup()
            print("  Player exists after cleanup: \(playerManager.player != nil)")
        }
    }
    
    @ViewBuilder
    private var mainVideoContainer: some View {
        VStack(spacing: 0) {
            // Video container with depth
            ZStack {
                shadowLayers
                mainVideoLayer
            }
            .rotation3DEffect(
                .degrees(scrollOffset * 0.1),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.5
            )
            .scaleEffect(1.0 + (abs(scrollOffset) * 0.0002))
            .clipped()
        }
    }
    
    @ViewBuilder
    private var shadowLayers: some View {
        ForEach(0..<3, id: \.self) { layer in
            shadowLayer(for: layer)
        }
    }
    
    private func shadowLayer(for layer: Int) -> some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color.black.opacity(0.3 - Double(layer) * 0.1))
            .frame(maxWidth: .infinity)
            .frame(height: videoHeight)
            .offset(
                x: CGFloat(layer) * 2,
                y: CGFloat(layer) * 2
            )
            .scaleEffect(1.0 - CGFloat(layer) * 0.02)
    }
    
    @ViewBuilder
    private var mainVideoLayer: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color.cardSoft)
            .frame(maxWidth: .infinity)
            .frame(height: videoHeight)
            .overlay(videoPlayerContent)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.accentWarm.opacity(0.15), lineWidth: 1)
            )
    }
    
    @ViewBuilder
    private var videoPlayerContent: some View {
        ZStack {
            if playerManager.hasError {
                // Error state with retry option
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.red)
                    
                    Text("Video Error")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if let errorMessage = playerManager.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Button("Retry") {
                        playerManager.retrySetup(with: videoURL)
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.7))
                    .cornerRadius(8)
                }
            } else if let player = playerManager.player {
                CustomVideoPlayerWithControls(
                    player: player,
                    isMuted: $isMuted,
                    videoGravity: .resizeAspect,
                    trimStart: nil,
                    trimEnd: nil
                )
                .aspectRatio(contentMode: .fit)
                .cornerRadius(24)
            } else {
                VideoLoadingView()
            }
            
            // Debug overlay in top-left corner
            VStack(alignment: .leading, spacing: 2) {
                Text("DEBUG[\(debugId)]")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                Text("Appear: \(viewAppearCount)")
                    .font(.system(size: 8))
                    .foregroundColor(.white)
                Text("Setup: \(setupCallCount)")
                    .font(.system(size: 8))
                    .foregroundColor(.white)
                Text("Player: \(playerManager.player != nil ? "✅" : "❌")")
                    .font(.system(size: 8))
                    .foregroundColor(.white)
                Text("Error: \(playerManager.hasError ? "⚠️" : "✅")")
                    .font(.system(size: 8))
                    .foregroundColor(.white)
                Text("Trim: \(trimStartTime != nil ? "✅" : "❌")")
                    .font(.system(size: 8))
                    .foregroundColor(.white)
            }
            .padding(4)
            .background(Color.black.opacity(0.7))
            .cornerRadius(4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(8)
        }
    }
    
    private func setupVideo() {
        setupCallCount += 1
        print("🎬 SpatialVideoPreview[\(debugId)] - setupVideo() call #\(setupCallCount)")
        print("  URL: \(videoURL)")
        print("  URL lastPathComponent: \(videoURL.lastPathComponent)")
        print("  URL isFileURL: \(videoURL.isFileURL)")
        print("  Current player exists: \(playerManager.player != nil)")
        print("  Current error state: \(playerManager.hasError)")
        
        if videoURL.isFileURL {
            let fileExists = FileManager.default.fileExists(atPath: videoURL.path)
            print("  File exists: \(fileExists)")
        }
        
        playerManager.setupPlayer(with: videoURL)
        
        print("  Player exists after setup: \(playerManager.player != nil)")
        print("  Error state after setup: \(playerManager.hasError)")
        if let error = playerManager.errorMessage {
            print("  Error message: \(error)")
        }
        
        // Apply trimming if specified
        if let startTime = trimStartTime, let endTime = trimEndTime {
            print("  Applying trim: \(startTime)s to \(endTime)s")
            playerManager.updateTrim(start: startTime, end: endTime)
            // Start playback so the preview begins from the trimmed start
            if let player = playerManager.player {
                player.play()
                print("  Playback started with trim - rate: \(player.rate)")
            } else {
                print("  ⚠️ Cannot start playback - no player available")
            }
        } else {
            print("  No trimming applied")
            if let player = playerManager.player {
                player.play()
                print("  Playback started without trim - rate: \(player.rate)")
            } else {
                print("  ⚠️ Cannot start playback - no player available")
            }
        }
    }
}

struct BackgroundDepthLayers: View {
    let scrollOffset: CGFloat
    
    var body: some View {
        ZStack {
            // Distant background layer
            RoundedRectangle(cornerRadius: 32)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.interfaceSoft.opacity(0.3),
                            Color.primarySoft.opacity(0.1)
                        ],
                        center: .center,
                        startRadius: 50,
                        endRadius: 200
                    )
                )
                .scaleEffect(1.2)
                .offset(y: scrollOffset * 0.1)
                .blur(radius: 3)
            
            // Mid-ground layer
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.interfaceSoft.opacity(0.2))
                .scaleEffect(1.1)
                .offset(y: scrollOffset * 0.2)
                .blur(radius: 1)
        }
    }
}

struct VideoLoadingView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.accentWarm.opacity(0.2), lineWidth: 3)
                    .frame(width: 48, height: 48)

                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(Color.accentWarm, lineWidth: 3)
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .onAppear {
                        withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                            isAnimating = true
                        }
                    }
            }

            Text("Preparing Preview...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.accentWarm.opacity(0.8))
        }
    }
}

struct ContextualInfoOverlay: View {
    let enhancementType: String
    let scrollOffset: CGFloat
    
    
    var body: some View {
        VStack(spacing: 16) {
            // Enhancement type indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(red: 1.0, green: 0.596, blue: 0.329))
                    .frame(width: 8, height: 8)
                    .scaleEffect(1.0 + sin(Date().timeIntervalSince1970 * 2) * 0.2)
                    .animation(.easeInOut(duration: 1.0).repeatForever(), value: UUID())
                
//                Text("Previewing with \(enhancementType)")
//                    .font(.system(size: 14, weight: .medium))
//                    .foregroundColor(Color.accentWarm.opacity(0.8))
                
                Spacer()
            }
            
        }
        .padding(.horizontal, 4)
        .offset(y: scrollOffset * 0.05)
    }
}


#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        ScrollView {
            SpatialVideoPreview(
                videoURL: URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!,
                enhancementType: "AI Upscale",
                trimStartTime: 5.0,
                trimEndTime: 15.0,
                customHeight: nil
            )
            .frame(height: 400)
        }
    }
}
