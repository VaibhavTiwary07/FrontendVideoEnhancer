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
    @Published var hasError: Bool = false
    @Published var errorMessage: String?
    private var timeObserver: Any?
    private var startTime: Double = 0
    private var endTime: Double?
    
    // Debug tracking
    private let debugId = UUID().uuidString.prefix(8)
    private var setupCallCount = 0
    private var cleanupCallCount = 0
    private var retryCount = 0
    
    func setupPlayer(with url: URL) {
        setupCallCount += 1
        print("🎮 VideoPreviewManager[\(debugId)] - setupPlayer() call #\(setupCallCount)")
        print("  URL: \(url.lastPathComponent)")
        print("  Previous player exists: \(player != nil)")
        print("  Previous error: \(hasError)")
        
        // Reset error state
        hasError = false
        errorMessage = nil
        
        // Validate URL
        guard url.isFileURL || url.scheme != nil else {
            let error = "Invalid URL: \(url)"
            print("  ERROR: \(error)")
            hasError = true
            errorMessage = error
            return
        }
        
        // For file URLs, check if file exists
        if url.isFileURL {
            let fileExists = FileManager.default.fileExists(atPath: url.path)
            print("  File exists at path: \(fileExists)")
            if !fileExists {
                let error = "Video file not found at: \(url.path)"
                print("  ERROR: \(error)")
                hasError = true
                errorMessage = error
                return
            }
        }
        
        // Clean up previous player if exists
        if player != nil {
            print("  Cleaning up previous player")
            cleanup()
        }
        
        do {
            let playerItem = AVPlayerItem(url: url)
            player = AVPlayer(playerItem: playerItem)
            
            print("  New player created: \(player != nil)")
            print("  PlayerItem status: \(playerItem.status.rawValue)")
            
            // Monitor player item status for errors
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemFailedToPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { [weak self] notification in
                guard let self = self else { return }
                if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                    print("🎮 VideoPreviewManager[\(self.debugId)] - Player failed: \(error.localizedDescription)")
                    self.hasError = true
                    self.errorMessage = error.localizedDescription
                }
            }
            
            // Mute audio for seamless experience
            player?.isMuted = true
            
            // Disable AirPlay for all video players
            player?.allowsExternalPlayback = false

            // Set up looping to startTime when reaching endTime or video end
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { [weak self] _ in
                guard let self = self else { return }
                print("🎮 VideoPreviewManager[\(self.debugId)] - Video reached end, looping to start")
                let start = CMTime(seconds: self.startTime, preferredTimescale: 600)
                self.player?.seek(to: start)
                self.player?.play()
            }

            addTimeObserver()
            print("  Setup completed successfully")
        } catch {
            print("  ERROR during setup: \(error.localizedDescription)")
            hasError = true
            errorMessage = error.localizedDescription
        }
    }
    
    func retrySetup(with url: URL) {
        retryCount += 1
        print("🎮 VideoPreviewManager[\(debugId)] - Retry #\(retryCount)")
        
        if retryCount > 3 {
            print("  Max retries reached, giving up")
            hasError = true
            errorMessage = "Failed after \(retryCount) retries"
            return
        }
        
        // Wait a bit before retrying
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.setupPlayer(with: url)
        }
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
        print("🎮 VideoPreviewManager[\(debugId)] - updateTrim()")
        print("  Previous: \(startTime)s to \(endTime ?? -1)s")
        print("  New: \(start)s to \(end)s")
        
        startTime = start
        endTime = end

        guard let player = player else { 
            print("  ERROR: No player available for trimming")
            return 
        }

        let wasPlaying = player.rate != 0
        print("  Player was playing: \(wasPlaying)")
        
        let startCMTime = CMTime(seconds: startTime, preferredTimescale: 600)
        player.seek(to: startCMTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak player] _ in
            print("🎮 VideoPreviewManager - Seek completed to \(start)s")
            if wasPlaying {
                player?.play()
                print("  Resumed playback after seek")
            }
        }
    }
    
    func cleanup() {
        cleanupCallCount += 1
        print("🎮 VideoPreviewManager[\(debugId)] - cleanup() call #\(cleanupCallCount)")
        print("  Player exists before cleanup: \(player != nil)")
        print("  TimeObserver exists: \(timeObserver != nil)")
        
        if let player = player {
            player.pause()
            print("  Player paused")
        }
        
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
            print("  TimeObserver removed")
        }
        
        player = nil
        print("  Player set to nil")
        
        NotificationCenter.default.removeObserver(self)
        print("  NotificationCenter observers removed")
        print("  Cleanup completed")
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
