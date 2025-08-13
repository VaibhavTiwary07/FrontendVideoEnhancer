import SwiftUI
import AVFoundation

struct VideoComparisonSlider: View {
    let normalVideoName: String
    let enhancedVideoName: String
    let videoPlayerManager: VideoPlayerManager
    @State private var sliderValue: Double = 0.5
    
    private var videoKey: String {
        "\(normalVideoName)-\(enhancedVideoName)"
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
                        // Enhanced Video (Background)
                        if let enhancedPlayer = videoPlayerManager.getEnhancedPlayer(forKey: videoKey) {
                            VideoPlayerView(player: enhancedPlayer)
                                .frame(height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Rectangle()
                                .fill(LinearGradient(
                                    colors: [
                                        Color(red: 0.988, green: 0.753, blue: 0.424).opacity(0.3),
                                        Color(red: 1.0, green: 0.596, blue: 0.329).opacity(0.3)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    Text("Enhanced")
                                        .font(.caption)
                                        .foregroundColor(.secondaryText)
                                )
                        }
                        
                        // Normal Video (Overlay with mask)
                        if let normalPlayer = videoPlayerManager.getNormalPlayer(forKey: videoKey) {
                            VideoPlayerView(player: normalPlayer)
                                .frame(height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .mask(
                                    HStack(spacing: 0) {
                                        Rectangle()
                                            .frame(width: geometry.size.width * sliderValue)
                                        
                                        Color.clear
                                    }
                                )
                        } else {
                            Rectangle()
                                .fill(LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.47, blue: 0.47).opacity(0.3),
                                        Color(red: 1.0, green: 0.596, blue: 0.329).opacity(0.3)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    Text("Normal")
                                        .font(.caption)
                                        .foregroundColor(.secondaryText)
                                )
                                .mask(
                                    HStack(spacing: 0) {
                                        Rectangle()
                                            .frame(width: geometry.size.width * sliderValue)
                                        
                                        Color.clear
                                    }
                                )
                        }
                        
                        // Divider Line
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 2, height: 100)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 0)
                            .position(
                                x: geometry.size.width * sliderValue,
                                y: 50
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
                                            colors: [
                                                Color(red: 1.0, green: 0.47, blue: 0.47),
                                                Color(red: 1.0, green: 0.596, blue: 0.329),
                                                Color(red: 0.988, green: 0.753, blue: 0.424)
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
                                            colors: [
                                                Color(red: 1.0, green: 0.596, blue: 0.329),
                                                Color(red: 0.988, green: 0.753, blue: 0.424)
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
                                        let newValue = min(max(value.location.x / geometry.size.width, 0), 1)
                                        sliderValue = newValue
                                    }
                            )
                    }
                    .frame(height: 20)
                }
                .padding(12)
            }
        }
        .onAppear {
            videoPlayerManager.setupVideoPlayers(forKey: videoKey, normalVideoName: normalVideoName, enhancedVideoName: enhancedVideoName)
        }
        .onDisappear {
            videoPlayerManager.pausePlayers(forKey: videoKey)
        }
    }
    
}

struct VideoPlayerView: UIViewRepresentable {
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