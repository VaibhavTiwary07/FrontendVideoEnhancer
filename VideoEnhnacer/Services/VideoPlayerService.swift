import Foundation
import AVFoundation
import Combine
import UIKit

// MARK: - Video Player Service
/// Concrete implementation of VideoPlayerProtocol following Single Responsibility Principle
final class VideoPlayerService: VideoPlayerProtocol {
    
    // MARK: - Published Properties
    @Published private var playerState: VideoPlayerState = .idle
    @Published private var currentTime: Double = 0
    
    var playerStatePublisher: Published<VideoPlayerState>.Publisher { $playerState }
    var currentTimePublisher: Published<Double>.Publisher { $currentTime }
    
    // MARK: - Private Properties
    private var playerPairs: [String: PlayerPair] = [:]
    private var loopObservers: [String: [NSObjectProtocol]] = [:]
    private var timeObservers: [String: Any] = [:]
    private var activeViewKeys: Set<String> = []
    private var loadingKeys: Set<String> = []
    private var loadedKeys: Set<String> = []
    
    // MARK: - Private Types
    private struct PlayerPair {
        let normal: AVPlayer
        let enhanced: AVPlayer
        var trimStart: Double = 0
        var trimEnd: Double = 0
    }
    
    // MARK: - Initialization
    init() {
        setupApplicationLifecycleObservers()
    }
    
    // MARK: - VideoPlayerProtocol Implementation
    func setupPlayers(normalVideoName: String, enhancedVideoName: String) async throws {
        let key = "\(normalVideoName)_\(enhancedVideoName)"
        
        guard !loadedKeys.contains(key) && !loadingKeys.contains(key) else {
            return
        }
        
        loadingKeys.insert(key)
        await updatePlayerState(.loading)
        
        do {
            let playerPair = try await loadPlayerPair(
                normalVideoName: normalVideoName,
                enhancedVideoName: enhancedVideoName
            )
            
            playerPairs[key] = playerPair
            setupPlayerObservers(forKey: key)
            
            loadingKeys.remove(key)
            loadedKeys.insert(key)
            await updatePlayerState(.ready)
            
        } catch {
            loadingKeys.remove(key)
            if let playerError = error as? VideoPlayerError {
                await updatePlayerState(.error(playerError))
                throw playerError
            } else {
                let playerError = VideoPlayerError.loadingFailed(error.localizedDescription)
                await updatePlayerState(.error(playerError))
                throw playerError
            }
        }
    }
    
    func setActiveView(forKey key: String, isActive: Bool) {
        if isActive {
            activeViewKeys.insert(key)
            if loadedKeys.contains(key) {
                Task { await play(forKey: key) }
            }
        } else {
            activeViewKeys.remove(key)
            pause(forKey: key)
        }
    }
    
    func cleanup() {
        // Pause all players
        for (_, playerPair) in playerPairs {
            playerPair.normal.pause()
            playerPair.enhanced.pause()
        }
        
        // Clean up all observers
        for key in playerPairs.keys {
            cleanupObservers(forKey: key)
        }
        
        // Clear all data
        playerPairs.removeAll()
        loopObservers.removeAll()
        timeObservers.removeAll()
        activeViewKeys.removeAll()
        loadingKeys.removeAll()
        loadedKeys.removeAll()
        
        Task { await updatePlayerState(.idle) }
    }
    
    func play(forKey key: String) async {
        guard let playerPair = playerPairs[key] else { return }
        
        playerPair.normal.play()
        playerPair.enhanced.play()
        await updatePlayerState(.playing)
    }
    
    func pause(forKey key: String) {
        guard let playerPair = playerPairs[key] else { return }
        
        playerPair.normal.pause()
        playerPair.enhanced.pause()
        Task { await updatePlayerState(.paused) }
    }
    
    func seek(to time: Double, forKey key: String) async {
        guard let playerPair = playerPairs[key] else { return }
        
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        
        await withCheckedContinuation { continuation in
            playerPair.normal.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                playerPair.enhanced.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                    continuation.resume()
                }
            }
        }
        
        await updateCurrentTime(time)
    }
    
    func setPlaybackRange(start: Double, end: Double, forKey key: String) {
        guard var playerPair = playerPairs[key] else { return }
        
        playerPair.trimStart = start
        playerPair.trimEnd = end
        playerPairs[key] = playerPair
        
        // Update loop observers with new range
        setupPlayerObservers(forKey: key)
    }
    
    func getNormalPlayer(forKey key: String) -> AVPlayer? {
        return playerPairs[key]?.normal
    }
    
    func getEnhancedPlayer(forKey key: String) -> AVPlayer? {
        return playerPairs[key]?.enhanced
    }
    
    func getPlayerState(forKey key: String) -> VideoPlayerState {
        return playerState
    }
    
    // MARK: - Private Methods
    @MainActor
    private func updatePlayerState(_ newState: VideoPlayerState) {
        playerState = newState
    }
    
    @MainActor
    private func updateCurrentTime(_ time: Double) {
        currentTime = time
    }
    
    private func loadPlayerPair(normalVideoName: String, enhancedVideoName: String) async throws -> PlayerPair {
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                do {
                    guard let normalURL = Bundle.main.url(forResource: normalVideoName, withExtension: "mp4") else {
                        continuation.resume(throwing: VideoPlayerError.fileNotFound(normalVideoName))
                        return
                    }
                    
                    guard let enhancedURL = Bundle.main.url(forResource: enhancedVideoName, withExtension: "mp4") else {
                        continuation.resume(throwing: VideoPlayerError.fileNotFound(enhancedVideoName))
                        return
                    }
                    
                    let normalPlayer = AVPlayer(url: normalURL)
                    let enhancedPlayer = AVPlayer(url: enhancedURL)
                    
                    // Configure players
                    normalPlayer.isMuted = true
                    enhancedPlayer.isMuted = true
                    
                    // Preload the videos
                    try await self.preloadPlayers([normalPlayer, enhancedPlayer])
                    
                    let playerPair = PlayerPair(normal: normalPlayer, enhanced: enhancedPlayer)
                    continuation.resume(returning: playerPair)
                    
                } catch {
                    continuation.resume(throwing: VideoPlayerError.loadingFailed(error.localizedDescription))
                }
            }
        }
    }
    
    private func preloadPlayers(_ players: [AVPlayer]) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for player in players {
                group.addTask {
                    if let asset = await player.currentItem?.asset {
                        _ = try await asset.load(.isPlayable)
                    }
                }
            }
            try await group.waitForAll()
        }
    }
    
    private func setupPlayerObservers(forKey key: String) {
        guard let playerPair = playerPairs[key] else { return }
        
        // Clean up existing observers
        cleanupObservers(forKey: key)
        
        var observers: [NSObjectProtocol] = []
        
        // Setup loop observers
        let normalLoopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerPair.normal.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.handlePlayerDidReachEnd(playerPair: playerPair)
        }
        observers.append(normalLoopObserver)
        
        let enhancedLoopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerPair.enhanced.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.handlePlayerDidReachEnd(playerPair: playerPair)
        }
        observers.append(enhancedLoopObserver)
        
        // Setup time observer
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        let timeObserver = playerPair.normal.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            let seconds = CMTimeGetSeconds(time)
            Task {
                await self?.updateCurrentTime(seconds)
            }
        }
        timeObservers[key] = timeObserver
        
        loopObservers[key] = observers
    }
    
    private func handlePlayerDidReachEnd(playerPair: PlayerPair) {
        let startTime = CMTime(seconds: playerPair.trimStart, preferredTimescale: 600)
        
        playerPair.normal.seek(to: startTime)
        playerPair.enhanced.seek(to: startTime)
        
        // Only continue playing if we're in an active view
        if !activeViewKeys.isEmpty {
            playerPair.normal.play()
            playerPair.enhanced.play()
        }
    }
    
    private func cleanupObservers(forKey key: String) {
        // Remove notification observers
        if let observers = loopObservers[key] {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
            loopObservers.removeValue(forKey: key)
        }
        
        // Remove time observer
        if let timeObserver = timeObservers[key],
           let playerPair = playerPairs[key] {
            playerPair.normal.removeTimeObserver(timeObserver)
            timeObservers.removeValue(forKey: key)
        }
    }
    
    private func setupApplicationLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        // Pause all players
        for key in playerPairs.keys {
            pause(forKey: key)
        }
        activeViewKeys.removeAll()
    }
    
    @objc private func appWillEnterForeground() {
        // Resume active players
        for key in activeViewKeys {
            Task { await play(forKey: key) }
        }
    }
    
    // MARK: - Cleanup
    deinit {
        cleanup()
        NotificationCenter.default.removeObserver(self)
    }
}