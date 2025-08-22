import SwiftUI
import AVFoundation
import AVKit

struct SpatialVideoPreview: View {
    let videoURL: URL
    let enhancementType: String
    let trimStartTime: Double?
    let trimEndTime: Double?
    @State private var scrollOffset: CGFloat = 0
    @StateObject private var playerManager = VideoPreviewManager()
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    private var videoHeight: CGFloat {
        isIPad ? 350 : 280
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background depth layers
                BackgroundDepthLayers(scrollOffset: scrollOffset)
                
                // Main video preview with spatial effects
                VStack(spacing: 0) {
                    // Video container with depth
                    ZStack {
                        // Shadow layers for depth
                        ForEach(0..<3) { layer in
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.black.opacity(0.3 - Double(layer) * 0.1))
                                .frame(height: videoHeight)
                                .offset(
                                    x: CGFloat(layer) * 2,
                                    y: CGFloat(layer) * 2
                                )
                                .scaleEffect(1.0 - CGFloat(layer) * 0.02)
                        }
                        
                        // Main video layer
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.cardSoft)
                            .frame(height: videoHeight)
                            .overlay(
                                Group {
                                    if let player = playerManager.player {
                                        VideoPlayer(player: player)
                                            .disabled(true)
                                            .cornerRadius(24)
                                            .onAppear {
                                                player.play()
                                            }
                                    } else {
                                        VideoLoadingView()
                                    }
                                }
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.accentWarm.opacity(0.15), lineWidth: 1)
                            )
                    }
                    .rotation3DEffect(
                        .degrees(scrollOffset * 0.1),
                        axis: (x: 1, y: 0, z: 0),
                        perspective: 0.5
                    )
                    .scaleEffect(1.0 + (abs(scrollOffset) * 0.0002))
                    
                    // Contextual information overlay
                    ContextualInfoOverlay(
                        enhancementType: enhancementType,
                        scrollOffset: scrollOffset
                    )
                    .padding(.top, 20)
                }
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            setupVideo()
        }
        .onDisappear {
            playerManager.cleanup()
        }
    }
    
    private func setupVideo() {
        playerManager.setupPlayer(with: videoURL)
        
        // Apply trimming if specified
        if let startTime = trimStartTime, let endTime = trimEndTime {
            playerManager.updateTrim(start: startTime, end: endTime)
            // Start playback so the preview begins from the trimmed start
            playerManager.player?.play()
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
    @State private var rotationAngle: Double = 0
    
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
                    .rotationEffect(.degrees(rotationAngle))
                    .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: rotationAngle)
            }
            
            Text("Preparing Preview...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.accentWarm.opacity(0.8))
        }
        .onAppear {
            rotationAngle = 360
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
                
                Text("Previewing with \(enhancementType)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.accentWarm.opacity(0.8))
                
                Spacer()
            }
            
        }
        .padding(.horizontal, 4)
        .offset(y: scrollOffset * 0.05)
    }
}


#Preview {
    ZStack {
        Color.primarySoft
            .ignoresSafeArea()
        
        ScrollView {
            SpatialVideoPreview(
                videoURL: URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!,
                enhancementType: "AI Upscale",
                trimStartTime: 5.0,
                trimEndTime: 15.0
            )
            .frame(height: 400)
        }
    }
}