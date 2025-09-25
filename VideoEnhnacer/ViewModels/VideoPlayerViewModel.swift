import Foundation
import SwiftUI
import Combine
import AVFoundation

// MARK: - Video Player ViewModel
/// MVVM ViewModel for video player operations following Single Responsibility Principle
@MainActor
final class VideoPlayerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var playerState: VideoPlayerState = .idle
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: VideoPlayerError?
    
    // MARK: - Private Properties
    private let videoPlayerService: VideoPlayerProtocol
    private let key: String
    private var cancellables = Set<AnyCancellable>()
    
    // Debug tracking
    private let debugId = UUID().uuidString.prefix(8)
    private var setupCallCount = 0
    private var playCallCount = 0
    private var pauseCallCount = 0
    
    // MARK: - Computed Properties
    var isPlayable: Bool {
        playerState.isPlayable
    }
    
    var normalPlayer: AVPlayer? {
        videoPlayerService.getNormalPlayer(forKey: key)
    }
    
    var enhancedPlayer: AVPlayer? {
        videoPlayerService.getEnhancedPlayer(forKey: key)
    }
    
    // MARK: - Initialization
    init(
        videoPlayerService: VideoPlayerProtocol,
        key: String = UUID().uuidString
    ) {
        self.videoPlayerService = videoPlayerService
        self.key = key
        print("🎮 VideoPlayerViewModel[🆔 \(debugId)] - Initialized with key: \(key)")
        setupBindings()
    }
    
    // MARK: - Public Methods
    func setupPlayers(normalVideoName: String, enhancedVideoName: String) {
        setupCallCount += 1
        print("🎮 VideoPlayerViewModel[🆔 \(debugId)] - setupPlayers(names) call #\(setupCallCount)")
        print("  Normal video: \(normalVideoName)")
        print("  Enhanced video: \(enhancedVideoName)")
        print("  Key: \(key)")
        print("  Current state: \(playerState)")
        print("  Current loading: \(isLoading)")
        
        // Set loading state immediately to show loading UI
        isLoading = true
        error = nil
        print("  ✅ Loading state set to true immediately")
        
        Task { @MainActor in
            do {
                print("🎮 VideoPlayerViewModel[🆔 \(debugId)] - Starting video service setup...")
                try await videoPlayerService.setupPlayers(key: key, normalVideoName: normalVideoName, enhancedVideoName: enhancedVideoName)
                print("🎮 VideoPlayerViewModel[🆔 \(debugId)] - Video service setup completed successfully")
                print("  Normal player available: \(normalPlayer != nil)")
                print("  Enhanced player available: \(enhancedPlayer != nil)")
                self.isLoading = false
                print("  ✅ Loading state set to false - setup complete")
            } catch {
                print("🎮 VideoPlayerViewModel[🆔 \(debugId)] - Video service setup failed: \(error)")
                if let err = error as? VideoPlayerError {
                    self.error = err
                    print("  VideoPlayerError: \(err)")
                } else {
                    let playerError = VideoPlayerError.loadingFailed(error.localizedDescription)
                    self.error = playerError
                    print("  Converted to VideoPlayerError: \(playerError)")
                }
                self.isLoading = false
                print("  ❌ Loading state set to false - setup failed")
            }
        }
    }

    func setupPlayers(originalURL: URL, enhancedURL: URL) {
        setupCallCount += 1
        print("🎮 VideoPlayerViewModel[🆔 \(debugId)] - setupPlayers(URLs) call #\(setupCallCount)")
        print("  Original URL: \(originalURL.lastPathComponent)")
        print("  Enhanced URL: \(enhancedURL.lastPathComponent)")
        print("  Original URL absolute: \(originalURL)")
        print("  Enhanced URL absolute: \(enhancedURL)")
        print("  Key: \(key)")
        print("  Current state: \(playerState)")
        print("  Current loading: \(isLoading)")
        
        // Set loading state immediately to show loading UI
        isLoading = true
        error = nil
        print("  ✅ Loading state set to true immediately")
        
        // Validate URLs
        if originalURL.isFileURL {
            let exists = FileManager.default.fileExists(atPath: originalURL.path)
            print("  Original file exists: \(exists)")
            if !exists {
                let errorMsg = "Original video file not found: \(originalURL.path)"
                print("  ❌ \(errorMsg)")
                error = VideoPlayerError.fileNotFound(originalURL.lastPathComponent)
                isLoading = false
                return
            }
        }
        if enhancedURL.isFileURL {
            let exists = FileManager.default.fileExists(atPath: enhancedURL.path)
            print("  Enhanced file exists: \(exists)")
            if !exists {
                let errorMsg = "Enhanced video file not found: \(enhancedURL.path)"
                print("  ❌ \(errorMsg)")
                error = VideoPlayerError.fileNotFound(enhancedURL.lastPathComponent)
                isLoading = false
                return
            }
        }
        
        Task { @MainActor in
            do {
                print("🎮 VideoPlayerViewModel[🆔 \(debugId)] - Starting video service setup...")
                try await videoPlayerService.setupPlayers(key: key, originalURL: originalURL, enhancedURL: enhancedURL)
                print("🎮 VideoPlayerViewModel[🆔 \(debugId)] - Video service setup completed successfully")
                print("  Normal player available: \(normalPlayer != nil)")
                print("  Enhanced player available: \(enhancedPlayer != nil)")
                self.isLoading = false
                print("  ✅ Loading state set to false - setup complete")
            } catch {
                print("🎮 VideoPlayerViewModel[🆔 \(debugId)] - Video service setup failed: \(error)")
                if let err = error as? VideoPlayerError {
                    self.error = err
                    print("  VideoPlayerError: \(err)")
                } else {
                    let playerError = VideoPlayerError.loadingFailed(error.localizedDescription)
                    self.error = playerError
                    print("  Converted to VideoPlayerError: \(playerError)")
                }
                self.isLoading = false
                print("  ❌ Loading state set to false - setup failed")
            }
        }
    }
    
    func setActive(_ isActive: Bool) {
        print("🎮 VideoPlayerViewModel[🆔 \(debugId)] - setActive(\(isActive))")
        print("  Key: \(key)")
        videoPlayerService.setActiveView(forKey: key, isActive: isActive)
    }
    
    func play() {
        playCallCount += 1
        print("🎮 VideoPlayerViewModel[🆔 \(debugId)] - play() call #\(playCallCount)")
        print("  Key: \(key)")
        print("  Normal player available: \(normalPlayer != nil)")
        print("  Enhanced player available: \(enhancedPlayer != nil)")
        print("  Current state: \(playerState)")
        Task {
            await videoPlayerService.play(forKey: key)
            print("🎮 VideoPlayerViewModel[🆔 \(debugId)] - play() completed")
        }
    }
    
    func pause() {
        pauseCallCount += 1
        print("🎮 VideoPlayerViewModel[🆔 \(debugId)] - pause() call #\(pauseCallCount)")
        print("  Key: \(key)")
        videoPlayerService.pause(forKey: key)
    }
    
    func seek(to time: Double) {
        print("🎮 VideoPlayerViewModel[🆔 \(debugId)] - seek(to: \(time))")
        print("  Key: \(key)")
        Task {
            await videoPlayerService.seek(to: time, forKey: key)
            print("🎮 VideoPlayerViewModel[🆔 \(debugId)] - seek completed")
        }
    }
    
    func setPlaybackRange(start: Double, end: Double) {
        print("🎮 VideoPlayerViewModel[🆔 \(debugId)] - setPlaybackRange(start: \(start), end: \(end))")
        print("  Key: \(key)")
        videoPlayerService.setPlaybackRange(start: start, end: end, forKey: key)
    }
    
    func setMuted(_ muted: Bool) {
        print("🎮 VideoPlayerViewModel[🆔 \(debugId)] - setMuted(\(muted))")
        print("  Normal player available: \(normalPlayer != nil)")
        print("  Enhanced player available: \(enhancedPlayer != nil)")
        normalPlayer?.isMuted = muted
        enhancedPlayer?.isMuted = muted
    }
    
    func cleanup() {
        print("🎮 VideoPlayerViewModel[🆔 \(debugId)] - cleanup()")
        print("  Key: \(key)")
        videoPlayerService.cleanupPlayers(forKey: key)
        cancellables.removeAll()
    }

    // MARK: - Private Methods
    private func setupBindings() {
        print("🎮 VideoPlayerViewModel[🆔 \(debugId)] - setupBindings()")
        
        // Bind to service state changes for this specific key
        videoPlayerService.getPlayerStatePublisher(forKey: key)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleStateChange(state)
            }
            .store(in: &cancellables)
        
        videoPlayerService.currentTimePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentTime, on: self)
            .store(in: &cancellables)
    }
    
    private func handleStateChange(_ state: VideoPlayerState) {
        let previousState = playerState
        playerState = state
        
        print("🎮 VideoPlayerViewModel[🆔 \(debugId)] - handleStateChange")
        print("  Previous state: \(previousState)")
        print("  New state: \(state)")
        print("  Key: \(key)")
        
        switch state {
        case .loading:
            isLoading = true
            error = nil
            print("  -> Loading started")
        case .ready:
            isLoading = false
            error = nil
            print("  -> Ready - players loaded successfully")
            print("  Normal player available: \(normalPlayer != nil)")
            print("  Enhanced player available: \(enhancedPlayer != nil)")
        case .playing:
            isLoading = false
            error = nil
            print("  -> Playing")
        case .paused:
            isLoading = false
            error = nil
            print("  -> Paused")
        case .error(let playerError):
            isLoading = false
            error = playerError
            print("  -> Error: \(playerError)")
        case .idle:
            isLoading = false
            error = nil
            print("  -> Idle")
        }
    }
    
    private func loadPlayers(normalVideoName: String, enhancedVideoName: String) async { }

    deinit {
        videoPlayerService.cleanupPlayers(forKey: key)
    }
}

// MARK: - Preview Support
#if DEBUG
extension VideoPlayerViewModel {
    static var preview: VideoPlayerViewModel {
        DIContainer.shared.makeVideoPlayerViewModel()
    }
}

// Mock service is now defined in DIContainer.swift to avoid duplicates
#endif
