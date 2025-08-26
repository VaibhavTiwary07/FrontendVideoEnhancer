import SwiftUI
import AVFoundation
import AVKit
import Combine

// MARK: - Video Trimming Player Manager (Native iOS Approach)
/// Simple, native iOS ObservableObject for video trimming following Apple's patterns
final class VideoTrimmingPlayerManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var player: AVPlayer?
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    
    // MARK: - Private Properties
    private var timeObserver: Any?
    private var startTime: Double = 0
    private var endTime: Double?
    private var statusObserver: AnyCancellable?
    private let videoURL: URL
    
    // MARK: - Computed Properties
    var isReadyToPlay: Bool {
        player?.currentItem?.status == .readyToPlay
    }
    
    // MARK: - Initialization
    init(videoURL: URL) {
        self.videoURL = videoURL
        print("🎬 VideoTrimmingPlayerManager - Initialized with URL: \(videoURL.lastPathComponent)")
    }
    
    // MARK: - Public Methods
    func setupPlayer() {
        print("🎬 VideoTrimmingPlayerManager - Setting up player...")
        isLoading = true
        error = nil
        
        // Create player item and player
        let playerItem = AVPlayerItem(url: videoURL)
        player = AVPlayer(playerItem: playerItem)
        
        // Configure player for seamless experience
        player?.isMuted = true
        player?.automaticallyWaitsToMinimizeStalling = false
        
        // Observe player item status
        observePlayerStatus()
        
        // Set up periodic time observer
        addPeriodicTimeObserver()
        
        // Set up end of video notification
        setupNotifications(for: playerItem)
        
        print("✅ VideoTrimmingPlayerManager - Player setup completed")
    }
    
    func play() {
        guard isReadyToPlay else {
            print("⚠️ VideoTrimmingPlayerManager - Player not ready to play")
            return
        }
        player?.play()
        print("▶️ VideoTrimmingPlayerManager - Playing")
    }
    
    func pause() {
        player?.pause()
        print("⏸️ VideoTrimmingPlayerManager - Paused")
    }
    
    func seek(to time: Double) {
        guard let player = player else { return }
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        print("⏩ VideoTrimmingPlayerManager - Seeked to: \(time)")
    }
    
    func setTrimRange(start: Double, end: Double) {
        startTime = start
        endTime = end
        
        // Seek to start position
        seek(to: start)
        
        print("✂️ VideoTrimmingPlayerManager - Trim range set: \(start) to \(end)")
    }
    
    func cleanup() {
        // Remove observers
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        statusObserver?.cancel()
        statusObserver = nil
        
        // Remove notifications
        NotificationCenter.default.removeObserver(self)
        
        // Release player
        player?.pause()
        player = nil
        
        print("🧹 VideoTrimmingPlayerManager - Cleanup completed")
    }
    
    // MARK: - Private Methods
    private func observePlayerStatus() {
        guard let playerItem = player?.currentItem else { return }
        
        statusObserver = playerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.handlePlayerItemStatus(status, playerItem: playerItem)
            }
    }
    
    private func handlePlayerItemStatus(_ status: AVPlayerItem.Status, playerItem: AVPlayerItem) {
        switch status {
        case .readyToPlay:
            isLoading = false
            error = nil
            duration = playerItem.duration.seconds
            print("✅ VideoTrimmingPlayerManager - Player ready to play, duration: \(duration)")
            
        case .failed:
            isLoading = false
            let errorMessage = playerItem.error?.localizedDescription ?? "Unknown playback error"
            error = errorMessage
            print("❌ VideoTrimmingPlayerManager - Player failed: \(errorMessage)")
            
        case .unknown:
            isLoading = true
            print("⏳ VideoTrimmingPlayerManager - Player status unknown")
            
        @unknown default:
            isLoading = false
            error = "Unknown player status"
            print("⚠️ VideoTrimmingPlayerManager - Unknown player status")
        }
    }
    
    private func addPeriodicTimeObserver() {
        guard let player = player else { return }
        
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            
            self.currentTime = time.seconds
            
            // Handle trim end time
            if let endTime = self.endTime, time.seconds >= endTime {
                self.seek(to: self.startTime)
            }
        }
    }
    
    private func setupNotifications(for playerItem: AVPlayerItem) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlayerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
    }
    
    @objc private func handlePlayerDidFinishPlaying() {
        // Loop back to start time
        seek(to: startTime)
        if player?.rate != 0 {
            player?.play()
        }
        print("🔄 VideoTrimmingPlayerManager - Looped back to start")
    }
    
    // MARK: - Deinit
    deinit {
        cleanup()
        print("🗑️ VideoTrimmingPlayerManager - Deinitialized")
    }
}