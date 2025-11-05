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
    @Published private(set) var isLoading: Bool = true
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
        setupBindings()
    }
    
    
    // MARK: - Public Methods
    func setupPlayers(normalVideoName: String, enhancedVideoName: String) {
        setupCallCount += 1

        // Set loading state immediately to show loading UI
        isLoading = true
        error = nil

        Task { @MainActor in
            do {
                try await videoPlayerService.setupPlayers(key: key, normalVideoName: normalVideoName, enhancedVideoName: enhancedVideoName)
                self.isLoading = false
            } catch {
                if let err = error as? VideoPlayerError {
                    self.error = err
                } else {
                    let playerError = VideoPlayerError.loadingFailed(error.localizedDescription)
                    self.error = playerError
                }
                self.isLoading = false
            }
        }
    }

    func setupPlayers(originalURL: URL, enhancedURL: URL) {
        let startTime = Date().timeIntervalSince1970
        setupCallCount += 1

        // Set loading state immediately to show loading UI
        isLoading = true
        error = nil
        
        // Validate URLs
        if originalURL.isFileURL {
            let exists = FileManager.default.fileExists(atPath: originalURL.path)
            if !exists {
                error = VideoPlayerError.fileNotFound(originalURL.lastPathComponent)
                isLoading = false
                return
            }
        }
        if enhancedURL.isFileURL {
            let exists = FileManager.default.fileExists(atPath: enhancedURL.path)
            if !exists {
                error = VideoPlayerError.fileNotFound(enhancedURL.lastPathComponent)
                isLoading = false
                return
            }
        }
        
        Task { @MainActor in
            do {
                try await videoPlayerService.setupPlayers(key: key, originalURL: originalURL, enhancedURL: enhancedURL)
                let endTime = Date().timeIntervalSince1970
                self.isLoading = false
            } catch {
                if let err = error as? VideoPlayerError {
                    self.error = err
                } else {
                    let playerError = VideoPlayerError.loadingFailed(error.localizedDescription)
                    self.error = playerError
                }
                self.isLoading = false
            }
        }
    }
    
    func setActive(_ isActive: Bool) {
        videoPlayerService.setActiveView(forKey: key, isActive: isActive)
    }
    
    func play() {
        playCallCount += 1
        Task {
            await videoPlayerService.play(forKey: key)
        }
    }
    
    func pause() {
        pauseCallCount += 1
        videoPlayerService.pause(forKey: key)
    }
    
    func seek(to time: Double) {
        Task {
            await videoPlayerService.seek(to: time, forKey: key)
        }
    }
    
    func setPlaybackRange(start: Double, end: Double) {
        videoPlayerService.setPlaybackRange(start: start, end: end, forKey: key)
    }
    
    func setMuted(_ muted: Bool) {
        normalPlayer?.isMuted = muted
        enhancedPlayer?.isMuted = muted
    }
    
    func cleanup() {
        videoPlayerService.cleanupPlayers(forKey: key)
        cancellables.removeAll()
    }

    // MARK: - Private Methods
    private func setupBindings() {
        
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
        
        
        switch state {
        case .loading:
            isLoading = true
            error = nil
        case .ready:
            isLoading = false
            error = nil
        case .playing:
            isLoading = false
            error = nil
        case .paused:
            isLoading = false
            error = nil
        case .error(let playerError):
            isLoading = false
            error = playerError
        case .idle:
            isLoading = false
            error = nil
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
