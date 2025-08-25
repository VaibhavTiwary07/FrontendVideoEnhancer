import SwiftUI
import AVFoundation
import UIKit

struct VideoComparisonSlider: View {
    let normalVideoName: String
    let enhancedVideoName: String
    @ObservedObject var videoPlayerManager: VideoPlayerManager
    @State private var sliderValue: Double = 0.3
    @State private var isViewVisible: Bool = false
    @State private var isUserInteracting: Bool = false
    @State private var autoSlideTimer: Timer?
    @State private var resumeTimer: Timer?
    
    private var videoKey: String {
        "\(normalVideoName)-\(enhancedVideoName)"
    }
    
    private var playerState: VideoPlayerManager.PlayerState {
        videoPlayerManager.getPlayerState(forKey: videoKey)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.cardBackground)
                    .neomorphicStyle(cornerRadius: 12, shadowRadius: 6)
                
                // Video Comparison Area
                VStack(spacing: 12) {
                    // Video Players Container
                    ZStack {
                        let videoHeight = geometry.size.height - 90 // Account for labels, slider, and padding
                        // Enhanced Video (Background)
                        Group {
                            if playerState == .ready,
                               let enhancedPlayer = videoPlayerManager.getEnhancedPlayer(forKey: videoKey) {
                                AVPlayerUIView(player: enhancedPlayer)
                                    .frame(height: videoHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                videoPlaceholder(title: "Enhanced", isLoading: playerState == .loading, height: videoHeight)
                            }
                        }
                        
                        // Normal Video (Overlay with mask)
                        Group {
                            if playerState == .ready,
                               let normalPlayer = videoPlayerManager.getNormalPlayer(forKey: videoKey) {
                                AVPlayerUIView(player: normalPlayer)
                                    .frame(height: videoHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .mask(
                                        HStack(spacing: 0) {
                                            Rectangle()
                                                .frame(width: geometry.size.width * sliderValue)
                                            
                                            Color.clear
                                        }
                                    )
                            } else {
                                videoPlaceholder(title: "Normal", isLoading: playerState == .loading, height: videoHeight)
                                    .mask(
                                        HStack(spacing: 0) {
                                            Rectangle()
                                                .frame(width: geometry.size.width * sliderValue)
                                            
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
                                x: geometry.size.width * sliderValue,
                                y: videoHeight / 2
                            )
                    }
                    
                    // Labels
                    HStack {
                        Text("Before")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondaryText)
                        
                        Spacer()
                        
                        Text("After")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primaryText)
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
                                    .frame(width: geometry.size.width * sliderValue, height: 4)
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
                                x: geometry.size.width * sliderValue,
                                y: 10
                            )
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        isUserInteracting = true
                                        stopAutoSlide()
                                        let newValue = min(max(value.location.x / geometry.size.width, 0), 1)
                                        sliderValue = newValue
                                    }
                                    .onEnded { _ in
                                        scheduleAutoSlideResume()
                                    }
                            )
                    }
                    .frame(height: 20)
                }
                .padding(8)
            }
        }
        .onAppear {
            isViewVisible = true
            videoPlayerManager.setupVideoPlayers(forKey: videoKey, normalVideoName: normalVideoName, enhancedVideoName: enhancedVideoName)
            videoPlayerManager.setViewActive(forKey: videoKey, isActive: true)
            startAutoSlide()
        }
        .onDisappear {
            isViewVisible = false
            videoPlayerManager.setViewActive(forKey: videoKey, isActive: false)
            stopAutoSlide()
            stopResumeTimer()
        }
        .onChange(of: playerState) { _, state in
            // Handle state changes if needed for animations
        }
    }
    
    private func startAutoSlide() {
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

struct AVPlayerUIView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(playerLayer)
        
        DispatchQueue.main.async {
            playerLayer.frame = view.bounds
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let playerLayer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            DispatchQueue.main.async {
                playerLayer.frame = uiView.bounds
            }
        }
    }
}

#Preview {
    VideoComparisonSlider(
        normalVideoName: "normal",
        enhancedVideoName: "enhanced",
        videoPlayerManager: VideoPlayerManager()
    )
    .frame(height: 160)
    .padding()
    .background(Color.appBackground)
}