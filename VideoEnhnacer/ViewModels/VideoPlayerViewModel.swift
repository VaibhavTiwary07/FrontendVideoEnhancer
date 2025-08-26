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
        Task {
            await loadPlayers(normalVideoName: normalVideoName, enhancedVideoName: enhancedVideoName)
        }
    }
    
    func setupPlayerWithURL(_ videoURL: URL) {
        Task {
            await loadPlayerWithURL(videoURL)
        }
    }
    
    func setActive(_ isActive: Bool) {
        videoPlayerService.setActiveView(forKey: key, isActive: isActive)
    }
    
    func play() {
        Task {
            await videoPlayerService.play(forKey: key)
        }
    }
    
    func pause() {
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
    
    func cleanup() {
        videoPlayerService.cleanup()
        cancellables.removeAll()
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        // Bind to service state changes
        videoPlayerService.playerStatePublisher
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
        playerState = state
        
        switch state {
        case .loading:
            isLoading = true
            error = nil
        case .ready, .playing, .paused:
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
    
    private func loadPlayers(normalVideoName: String, enhancedVideoName: String) async {
        isLoading = true
        error = nil
        
        do {
            try await videoPlayerService.setupPlayers(
                normalVideoName: normalVideoName,
                enhancedVideoName: enhancedVideoName
            )
        } catch let playerError as VideoPlayerError {
            error = playerError
            isLoading = false
        } catch {
            self.error = VideoPlayerError.loadingFailed(error.localizedDescription)
            isLoading = false
        }
    }
    
    private func loadPlayerWithURL(_ videoURL: URL) async {
        isLoading = true
        error = nil
        
        do {
            try await videoPlayerService.setupPlayerWithURL(videoURL, forKey: key)
        } catch let playerError as VideoPlayerError {
            error = playerError
            isLoading = false
        } catch {
            self.error = VideoPlayerError.loadingFailed(error.localizedDescription)
            isLoading = false
        }
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