import SwiftUI
import AVFoundation
import AVKit

// MARK: - Simple Video Player View (Native iOS Approach)
/// Clean, simple video player view following native iOS patterns
struct SimpleVideoPlayerView: View {
    let videoURL: URL
    @StateObject private var playerManager: VideoTrimmingPlayerManager

    // MARK: - Initialization
    init(videoURL: URL) {
        self.videoURL = videoURL
        self._playerManager = StateObject(wrappedValue: VideoTrimmingPlayerManager(videoURL: videoURL))
    }

    init(videoURL: URL, playerManager: VideoTrimmingPlayerManager) {
        self.videoURL = videoURL
        self._playerManager = StateObject(wrappedValue: playerManager)
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            if let player = playerManager.player {
                if playerManager.isReadyToPlay {
                    VideoPlayer(player: player)
                        .onAppear {
                            playerManager.play()
                        }
                        .onDisappear {
                            playerManager.pause()
                        }
                } else {
                    loadingView
                }
            } else if let error = playerManager.error {
                errorView(error: error)
            } else {
                loadingView
            }
        }
        .onAppear {
            playerManager.setupPlayer()
        }
        .onDisappear {
            playerManager.cleanup()
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.gray.opacity(0.1))
            .overlay(
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .accentWarm))
                        .scaleEffect(1.2)
                    
                    Text("Loading Video...")
                        .dynamicFont(14, weight: .medium)
                        .foregroundColor(.accentWarm.opacity(0.8))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.accentWarm.opacity(0.2), lineWidth: 1)
            )
    }
    
    // MARK: - Error View
    private func errorView(error: String) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.red.opacity(0.05))
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .dynamicFont(24, weight: .medium)
                        .foregroundColor(.red.opacity(0.7))
                    
                    Text("Video Load Error")
                        .dynamicFont(16, weight: .semibold)
                        .foregroundColor(.red.opacity(0.8))
                    
                    Text(error)
                        .dynamicFont(12, weight: .regular)
                        .foregroundColor(.red.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Button("Retry") {
                        playerManager.setupPlayer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.1))
                            .overlay(
                                Capsule().stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .foregroundColor(.red.opacity(0.8))
                }
                .padding(20)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
            )
    }
    
    // MARK: - Public Methods
    func setTrimRange(start: Double, end: Double) {
        playerManager.setTrimRange(start: start, end: end)
    }
    
    func play() {
        playerManager.play()
    }
    
    func pause() {
        playerManager.pause()
    }
    
    func seek(to time: Double) {
        playerManager.seek(to: time)
    }
}

// MARK: - Preview
#Preview {
    SimpleVideoPlayerView(videoURL: URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!)
        .frame(height: 300)
        .padding(20)
        .background(Color.appBackground)
}