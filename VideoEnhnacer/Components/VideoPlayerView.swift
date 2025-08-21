import SwiftUI
import AVFoundation
import AVKit

struct VideoPreviewView: View {
    let videoURL: URL
    @StateObject private var playerManager = VideoPreviewManager()
    
    var body: some View {
        ZStack {
            if let player = playerManager.player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
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
    private var endTime: Double = 0

    func setupPlayer(with url: URL, startTime: Double = 0, endTime: Double? = nil) {
        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)

        self.startTime = startTime
        self.endTime = endTime ?? asset.duration.seconds

        addTimeObserver()
        seekToStart()
    }

    func updateTrimRange(start: Double, end: Double) {
        startTime = start
        endTime = end
    }

    private func addTimeObserver() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let current = CMTimeGetSeconds(time)
            if current >= self.endTime {
                self.seekToStart()
            }
        }
    }

    private func seekToStart() {
        let start = CMTime(seconds: startTime, preferredTimescale: 600)
        player?.seek(to: start)
        player?.play()
    }
    
    func cleanup() {
        player?.pause()
        player = nil
        
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }
    
    deinit {
        cleanup()
    }
}

#Preview {
    VideoPreviewView(videoURL: URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!)
        .frame(height: 200)
        .padding()
        .background(Color.black)
}