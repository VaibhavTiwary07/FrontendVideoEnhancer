import SwiftUI
import AVFoundation
import AVKit

struct VideoPreviewView: View {
    let videoURL: URL
    // Allow callers to control aspect behavior similar to Results screen
    var videoGravity: AVLayerVideoGravity = .resizeAspect
    @StateObject private var playerManager = VideoPreviewManager()
    
    init(videoURL: URL, videoGravity: AVLayerVideoGravity = .resizeAspect) {
        self.videoURL = videoURL
        self.videoGravity = videoGravity
    }
    
    var body: some View {
        ZStack {
            if let player = playerManager.player {
                AVPlayerUIView(player: player, videoGravity: videoGravity)
                    .onAppear { player.play() }
                    .onDisappear { player.pause() }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    )
            }
        }
        .onAppear {
            playerManager.setupPlayer(with: videoURL)
        }
        .onDisappear {
            playerManager.cleanup()
        }
    }
}

class VideoPreviewManager: ObservableObject {
    @Published var player: AVPlayer?
    private var timeObserver: Any?
    private var startTime: Double = 0
    private var endTime: Double?
    
    func setupPlayer(with url: URL) {
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        // Mute audio for seamless experience
        player?.isMuted = true

        // Set up looping to startTime when reaching endTime or video end
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            let start = CMTime(seconds: self.startTime, preferredTimescale: 600)
            self.player?.seek(to: start)
            self.player?.play()
        }

        addTimeObserver()
    }

    private func addTimeObserver() {
        guard let player = player else { return }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self = self, let end = self.endTime else { return }
            if time.seconds >= end {
                let start = CMTime(seconds: self.startTime, preferredTimescale: 600)
                player.seek(to: start, toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }
    }

    func updateTrim(start: Double, end: Double) {
        startTime = start
        endTime = end

        guard let player = player else { return }

        let wasPlaying = player.rate != 0
        let startCMTime = CMTime(seconds: startTime, preferredTimescale: 600)
        player.seek(to: startCMTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak player] _ in
            if wasPlaying {
                player?.play()
            }
        }
    }
    
    func cleanup() {
        player?.pause()
        player = nil
        
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        NotificationCenter.default.removeObserver(self)
    }
    
    deinit {
        cleanup()
    }
}
//
//#Preview {
//    VideoPreviewView(videoURL: URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!, videoGravity: .resizeAspect)
//        .frame(height: 200)
//        .padding()
//        .background(Color.black)
//}
