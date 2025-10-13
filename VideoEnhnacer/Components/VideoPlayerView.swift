import SwiftUI
import AVFoundation
import AVKit
import UIKit

struct VideoPreviewView: View {
    let videoURL: URL
    // Allow callers to control aspect behavior similar to Results screen
    var videoGravity: AVLayerVideoGravity = .resizeAspect
    private let showsMuteToggle: Bool
    private let startMuted: Bool
    private let externalMuteBinding: Binding<Bool>?
    private let externalPlaybackBinding: Binding<Bool>?
    @StateObject private var playerManager = VideoPreviewManager()
    
    init(
        videoURL: URL,
        videoGravity: AVLayerVideoGravity = .resizeAspect,
        showsMuteToggle: Bool = false,
        muteBinding: Binding<Bool>? = nil,
        playbackBinding: Binding<Bool>? = nil,
        startMuted: Bool = true
    ) {
        self.videoURL = videoURL
        self.videoGravity = videoGravity
        self.showsMuteToggle = showsMuteToggle
        self.externalMuteBinding = muteBinding
        self.externalPlaybackBinding = playbackBinding
        self.startMuted = startMuted
    }
    
    var body: some View {
        ZStack {
            if let player = playerManager.player {
                let muteBinding = makeMuteBinding()
                ZStack(alignment: .topTrailing) {
                    AVPlayerUIView(player: player, videoGravity: videoGravity)
                        .onAppear { playerManager.setPlaybackActive(currentPlaybackState) }
                        .onDisappear { playerManager.pausePlayback() }

                    if showsMuteToggle {
                        Button(action: {
                            muteBinding.wrappedValue.toggle()
                        }) {
                            Image(systemName: muteBinding.wrappedValue ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Circle().fill(Color.black.opacity(0.35)))
                        }
                        .accessibilityLabel(muteBinding.wrappedValue ? "Unmute" : "Mute")
                        .padding(12)
                    }
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
            let initialMute = externalMuteBinding?.wrappedValue ?? startMuted
            playerManager.setMuted(initialMute)
            playerManager.setupPlayer(with: videoURL)
            playerManager.setPlaybackActive(currentPlaybackState)
        }
        .onDisappear {
            playerManager.cleanup()
        }
        .onChange(of: externalMuteBinding?.wrappedValue ?? playerManager.isMuted) { newValue in
            playerManager.setMuted(newValue)
        }
        .onChange(of: currentPlaybackState) { newValue in
            playerManager.setPlaybackActive(newValue)
        }
    }

    private func makeMuteBinding() -> Binding<Bool> {
        if let external = externalMuteBinding {
            return Binding<Bool>(
                get: { external.wrappedValue },
                set: { newValue in
                    external.wrappedValue = newValue
                    playerManager.setMuted(newValue)
                }
            )
        }
        return Binding<Bool>(
            get: { playerManager.isMuted },
            set: { newValue in
                playerManager.setMuted(newValue)
            }
        )
    }
    
    private var currentPlaybackState: Bool {
        externalPlaybackBinding?.wrappedValue ?? true
    }
}

class VideoPreviewManager: ObservableObject {
    @Published var player: AVPlayer?
    @Published var hasError: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var isMuted: Bool = true
    private var timeObserver: Any?
    private var startTime: Double = 0
    private var endTime: Double?
    private var lifecycleObservers: [NSObjectProtocol] = []
    private var shouldResumeAfterInterruption: Bool = false
    private var pendingResume: Bool = false
    private var isVisible: Bool = false
    private var awaitingAdResume: Bool = false
    private var resumeFallbackWorkItem: DispatchWorkItem?
    
    // Debug tracking
    private let debugId = UUID().uuidString.prefix(8)
    private var setupCallCount = 0
    private var cleanupCallCount = 0
    private var retryCount = 0

    init() {
        registerLifecycleObservers()
    }
    
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
            
            // Apply current mute preference
            player?.isMuted = isMuted
            
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

    func startPlayback() {
        print("🎮 VideoPreviewManager[\(debugId)] - startPlayback()")
        isVisible = true
        shouldResumeAfterInterruption = true
        pendingResume = false
        player?.isMuted = isMuted
        player?.play()
    }

    func pausePlayback() {
        print("🎮 VideoPreviewManager[\(debugId)] - pausePlayback()")
        isVisible = false
        shouldResumeAfterInterruption = false
        pendingResume = false
        awaitingAdResume = false
        resumeFallbackWorkItem?.cancel()
        resumeFallbackWorkItem = nil
        player?.pause()
    }

    func setPlaybackActive(_ isActive: Bool) {
        if isActive {
            startPlayback()
        } else {
            pausePlayback()
        }
    }

    func setMuted(_ muted: Bool) {
        if isMuted == muted {
            player?.isMuted = muted
            return
        }
        isMuted = muted
        player?.isMuted = muted
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

        pausePlayback()
        
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
            print("  TimeObserver removed")
        }
        
        player = nil
        print("  Player set to nil")
        
        print("  Cleanup completed")
    }
    
    deinit {
        for observer in lifecycleObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        lifecycleObservers.removeAll()
        cleanup()
    }

    // MARK: - Lifecycle Handling
    private func registerLifecycleObservers() {
        let center = NotificationCenter.default

        let didEnterBackground = center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleDidEnterBackground()
        }
        lifecycleObservers.append(didEnterBackground)

        let appReturned = center.addObserver(forName: .appReturnedToForeground, object: nil, queue: .main) { [weak self] _ in
            self?.handleAppReturnedToForeground()
        }
        lifecycleObservers.append(appReturned)

        let resumeRequested = center.addObserver(forName: .resumeContentRequested, object: nil, queue: .main) { [weak self] _ in
            self?.handleResumeContentRequested()
        }
        lifecycleObservers.append(resumeRequested)

        let didBecomeActive = center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleDidBecomeActive()
        }
        lifecycleObservers.append(didBecomeActive)
    }

    private func handleDidEnterBackground() {
        guard isVisible else { return }
        print("🎮 VideoPreviewManager[\(debugId)] - didEnterBackground")
        if let player = player {
            if player.rate != 0 {
                shouldResumeAfterInterruption = true
            }
            player.pause()
        }
        pendingResume = false
    }

    private func handleAppReturnedToForeground() {
        guard isVisible else { return }
        print("🎮 VideoPreviewManager[\(debugId)] - appReturnedToForeground")
        if shouldResumeAfterInterruption {
            pendingResume = true
            awaitingAdResume = AdsManager.shared.suppressNonResumeAdPresentations
            if awaitingAdResume {
                scheduleResumeFallback()
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.resumeIfNeeded()
                }
            }
        }
    }

    private func handleResumeContentRequested() {
        guard isVisible else { return }
        print("🎮 VideoPreviewManager[\(debugId)] - resumeContentRequested")
        awaitingAdResume = false
        resumeFallbackWorkItem?.cancel()
        resumeFallbackWorkItem = nil
        resumeIfNeeded()
    }

    private func handleDidBecomeActive() {
        guard isVisible else { return }
        print("🎮 VideoPreviewManager[\(debugId)] - didBecomeActive")
        guard shouldResumeAfterInterruption && !pendingResume else { return }
        pendingResume = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.resumeIfNeeded()
        }
    }

    private func resumeIfNeeded() {
        guard pendingResume, shouldResumeAfterInterruption, isVisible else { return }
        guard !awaitingAdResume else { return }
        pendingResume = false
        awaitingAdResume = false
        player?.isMuted = isMuted
        player?.play()
        print("🎮 VideoPreviewManager[\(debugId)] - resumed playback")
    }

    private func scheduleResumeFallback() {
        resumeFallbackWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.awaitingAdResume = false
            self.resumeIfNeeded()
        }
        resumeFallbackWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0, execute: workItem)
    }
}
//
//#Preview {
//    VideoPreviewView(videoURL: URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!, videoGravity: .resizeAspect)
//        .frame(height: 200)
//        .padding()
//        .background(Color.black)
//}
