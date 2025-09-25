import Foundation
import AVFoundation
import Combine
import UIKit

// MARK: - Video Player Service
/// Concrete implementation of VideoPlayerProtocol following Single Responsibility Principle
final class VideoPlayerService: VideoPlayerProtocol {
    
    // MARK: - Published Properties
    @Published private var currentTime: Double = 0
    
    var currentTimePublisher: Published<Double>.Publisher { $currentTime }
    
    // Per-key state tracking instead of global state
    private var keyStates: [String: VideoPlayerState] = [:]
    private var keyStateSubjectsDict: [String: CurrentValueSubject<VideoPlayerState, Never>] = [:]
    
    // MARK: - Private Properties
    private var playerPairs: [String: PlayerPair] = [:]
    private var loopObservers: [String: [NSObjectProtocol]] = [:]
    private var timeObservers: [String: Any] = [:]
    private var activeViewKeys: Set<String> = []
    private var loadingKeys: Set<String> = []
    private var loadedKeys: Set<String> = []
    
    // Debug tracking
    private let debugId = UUID().uuidString.prefix(8)
    private var setupCallCount = 0
    
    // MARK: - Private Types
    private struct PlayerPair {
        let normal: AVPlayer
        let enhanced: AVPlayer
        var trimStart: Double = 0
        var trimEnd: Double = 0
    }
    
    // MARK: - Initialization
    init() {
        print("🎬 VideoPlayerService[🆔 \(debugId)] - Initialized")
        setupApplicationLifecycleObservers()
    }
    
    // MARK: - VideoPlayerProtocol Implementation
    func setupPlayers(key: String, normalVideoName: String, enhancedVideoName: String) async throws {
        setupCallCount += 1
        print("🎬 VideoPlayerService[🆔 \(debugId)] - setupPlayers(names) call #\(setupCallCount)")
        print("  Key: \(key)")
        print("  Normal video: \(normalVideoName)")
        print("  Enhanced video: \(enhancedVideoName)")
        print("  Already loaded: \(loadedKeys.contains(key))")
        print("  Currently loading: \(loadingKeys.contains(key))")
        print("  Active keys: \(activeViewKeys)")
        print("  Loaded keys: \(loadedKeys)")
        print("  Loading keys: \(loadingKeys)")
        
        guard !loadedKeys.contains(key) && !loadingKeys.contains(key) else { 
            print("  Skipping setup - already loaded or loading")
            return 
        }
        
        loadingKeys.insert(key)
        print("  Added to loading keys: \(loadingKeys)")
        await updatePlayerState(.loading, forKey: key)
        
        do {
            print("  Starting player pair loading...")
            let pair = try await loadPlayerPair(normalVideoName: normalVideoName, enhancedVideoName: enhancedVideoName)
            playerPairs[key] = pair
            print("  Player pair loaded successfully")
            print("  Setting up observers...")
            setupPlayerObservers(forKey: key)
            loadingKeys.remove(key)
            loadedKeys.insert(key)
            print("  Setup completed - loaded keys: \(loadedKeys)")
            await updatePlayerState(.ready, forKey: key)
        } catch {
            print("  Setup failed with error: \(error)")
            loadingKeys.remove(key)
            let playerError = (error as? VideoPlayerError) ?? VideoPlayerError.loadingFailed(error.localizedDescription)
            print("  Converted to VideoPlayerError: \(playerError)")
            await updatePlayerState(.error(playerError), forKey: key)
            throw playerError
        }
    }

    func setupPlayers(key: String, originalURL: URL, enhancedURL: URL) async throws {
        setupCallCount += 1
        print("🎬 VideoPlayerService[🆔 \(debugId)] - setupPlayers(URLs) call #\(setupCallCount)")
        print("  Key: \(key)")
        print("  Original URL: \(originalURL)")
        print("  Enhanced URL: \(enhancedURL)")
        print("  Original file: \(originalURL.lastPathComponent)")
        print("  Enhanced file: \(enhancedURL.lastPathComponent)")
        print("  Already loaded: \(loadedKeys.contains(key))")
        print("  Currently loading: \(loadingKeys.contains(key))")
        print("  Active keys: \(activeViewKeys)")
        print("  Loaded keys: \(loadedKeys)")
        print("  Loading keys: \(loadingKeys)")
        
        // Validate URLs
        if originalURL.isFileURL {
            let exists = FileManager.default.fileExists(atPath: originalURL.path)
            print("  Original file exists: \(exists)")
        }
        if enhancedURL.isFileURL {
            let exists = FileManager.default.fileExists(atPath: enhancedURL.path)
            print("  Enhanced file exists: \(exists)")
        }
        
        guard !loadedKeys.contains(key) && !loadingKeys.contains(key) else { 
            print("  Skipping setup - already loaded or loading")
            return 
        }
        
        loadingKeys.insert(key)
        print("  Added to loading keys: \(loadingKeys)")
        await updatePlayerState(.loading, forKey: key)
        
        do {
            print("  Creating AVPlayer instances...")
            let normalPlayer = AVPlayer(url: originalURL)
            let enhancedPlayer = AVPlayer(url: enhancedURL)
            print("  Players created")
            
            print("  Configuring players...")
            normalPlayer.isMuted = true
            enhancedPlayer.isMuted = true
            normalPlayer.allowsExternalPlayback = false
            enhancedPlayer.allowsExternalPlayback = false
            print("  Players configured")
            
            print("  Preloading players...")
            try await preloadPlayers([normalPlayer, enhancedPlayer])
            print("  Players preloaded successfully")
            
            let pair = PlayerPair(normal: normalPlayer, enhanced: enhancedPlayer)
            playerPairs[key] = pair
            print("  Player pair stored")
            
            print("  Setting up observers...")
            setupPlayerObservers(forKey: key)
            loadingKeys.remove(key)
            loadedKeys.insert(key)
            print("  Setup completed - loaded keys: \(loadedKeys)")
            await updatePlayerState(.ready, forKey: key)
        } catch {
            print("  Setup failed with error: \(error)")
            loadingKeys.remove(key)
            let playerError = (error as? VideoPlayerError) ?? VideoPlayerError.loadingFailed(error.localizedDescription)
            print("  Converted to VideoPlayerError: \(playerError)")
            await updatePlayerState(.error(playerError), forKey: key)
            throw playerError
        }
    }
    
    func setActiveView(forKey key: String, isActive: Bool) {
        print("🎬 VideoPlayerService[🆔 \(debugId)] - setActiveView(key: \(key), isActive: \(isActive))")
        print("  Previous active keys: \(activeViewKeys)")
        print("  Key is loaded: \(loadedKeys.contains(key))")

        if isActive {
            activeViewKeys.insert(key)
            print("  Added to active keys: \(activeViewKeys)")
            if loadedKeys.contains(key) {
                print("  Key is loaded, starting playback...")
                Task { await play(forKey: key) }
            } else {
                print("  Key not loaded yet, will play when ready")
            }
        } else {
            activeViewKeys.remove(key)
            print("  Removed from active keys: \(activeViewKeys)")
            pause(forKey: key)
        }
    }

    func cleanupPlayers(forKey key: String) {
        print("🎬 VideoPlayerService[🆔 \(debugId)] - cleanupPlayers(key: \(key))")

        if let playerPair = playerPairs[key] {
            print("  Player pair exists: true - pausing before cleanup")
            playerPair.normal.pause()
            playerPair.enhanced.pause()
        } else {
            print("  Player pair exists: false")
        }

        cleanupObservers(forKey: key)

        playerPairs.removeValue(forKey: key)
        activeViewKeys.remove(key)
        loadingKeys.remove(key)
        loadedKeys.remove(key)

        let previousState = keyStates.removeValue(forKey: key)
        if let subject = keyStateSubjectsDict[key] {
            subject.send(.idle)
            keyStateSubjectsDict.removeValue(forKey: key)
        }

        print("  Previous state: \(previousState ?? .idle)")
        print("  Remaining keys -> loaded: \(loadedKeys), active: \(activeViewKeys)")
    }

    func cleanup() {
        // Use cleanupPlayers to ensure per-key teardown logic remains consistent
        let keys = Set(playerPairs.keys)
            .union(keyStates.keys)
            .union(activeViewKeys)
            .union(loadingKeys)
            .union(loadedKeys)
        for key in keys {
            cleanupPlayers(forKey: key)
        }

        playerPairs.removeAll()
        loopObservers.removeAll()
        timeObservers.removeAll()
        activeViewKeys.removeAll()
        loadingKeys.removeAll()
        loadedKeys.removeAll()
    }
    
    func play(forKey key: String) async {
        print("🎬 VideoPlayerService[🆔 \(debugId)] - play(key: \(key))")
        print("  Player pair exists: \(playerPairs[key] != nil)")
        print("  Active keys: \(activeViewKeys)")
        
        guard let playerPair = playerPairs[key] else { 
            print("  No player pair found for key: \(key)")
            return 
        }
        
        print("  Starting playback...")
        playerPair.normal.play()
        playerPair.enhanced.play()
        print("  Playback started")
        await updatePlayerState(.playing, forKey: key)
    }
    
    func pause(forKey key: String) {
        print("🎬 VideoPlayerService[🆔 \(debugId)] - pause(key: \(key))")
        print("  Player pair exists: \(playerPairs[key] != nil)")
        
        guard let playerPair = playerPairs[key] else { 
            print("  No player pair found for key: \(key)")
            return 
        }
        
        print("  Pausing playback...")
        playerPair.normal.pause()
        playerPair.enhanced.pause()
        Task { await updatePlayerState(.paused, forKey: key) }
    }
    
    func seek(to time: Double, forKey key: String) async {
        print("🎬 VideoPlayerService[🆔 \(debugId)] - seek(key: \(key), time: \(time)s)")
        print("  Player pair exists: \(playerPairs[key] != nil)")
        
        guard let playerPair = playerPairs[key] else { 
            print("  ❌ No player pair found for key: \(key)")
            return 
        }
        
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        print("  Seeking both players to \(time)s...")
        
        await withCheckedContinuation { continuation in
            playerPair.normal.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                playerPair.enhanced.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                    continuation.resume()
                }
            }
        }
        
        await updateCurrentTime(time)
        print("  ✅ Seek completed to \(time)s")
    }
    
    func setPlaybackRange(start: Double, end: Double, forKey key: String) {
        print("🎬 VideoPlayerService[🆔 \(debugId)] - setPlaybackRange(key: \(key))")
        print("  Start: \(start)s, End: \(end)s")
        print("  Player pair exists: \(playerPairs[key] != nil)")
        
        guard var playerPair = playerPairs[key] else { 
            print("  ❌ No player pair found for key: \(key)")
            return 
        }
        
        let previousStart = playerPair.trimStart
        let previousEnd = playerPair.trimEnd
        
        playerPair.trimStart = start
        playerPair.trimEnd = end
        playerPairs[key] = playerPair
        
        print("  ✅ Updated trim range from [\(previousStart), \(previousEnd)] to [\(start), \(end)]")
        print("  Setting up observers with new range...")
        
        // Update loop observers with new range
        setupPlayerObservers(forKey: key)
        
        print("  ✅ Playback range set successfully")
    }
    
    func getNormalPlayer(forKey key: String) -> AVPlayer? {
        return playerPairs[key]?.normal
    }
    
    func getEnhancedPlayer(forKey key: String) -> AVPlayer? {
        return playerPairs[key]?.enhanced
    }
    
    func getPlayerState(forKey key: String) -> VideoPlayerState {
        return keyStates[key] ?? .idle
    }
    
    func getPlayerStatePublisher(forKey key: String) -> AnyPublisher<VideoPlayerState, Never> {
        if keyStateSubjectsDict[key] == nil {
            keyStateSubjectsDict[key] = CurrentValueSubject<VideoPlayerState, Never>(.idle)
        }
        return keyStateSubjectsDict[key]!.eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    @MainActor
    private func updatePlayerState(_ newState: VideoPlayerState, forKey key: String) {
        let previousState = keyStates[key] ?? .idle
        keyStates[key] = newState
        
        // Update the subject for this specific key
        if keyStateSubjectsDict[key] == nil {
            keyStateSubjectsDict[key] = CurrentValueSubject<VideoPlayerState, Never>(newState)
        } else {
            keyStateSubjectsDict[key]?.send(newState)
        }
        
        print("🎬 VideoPlayerService[🆔 \(debugId)] - updatePlayerState for key: \(key)")
        print("  Previous: \(previousState)")
        print("  New: \(newState)")
        print("  All key states: \(keyStates)")
    }
    
    @MainActor
    private func updateCurrentTime(_ time: Double) {
        currentTime = time
    }
    
    private func loadPlayerPair(normalVideoName: String, enhancedVideoName: String) async throws -> PlayerPair {
        print("🎬 VideoPlayerService[🆔 \(debugId)] - loadPlayerPair(names)")
        print("  Normal: \(normalVideoName)")
        print("  Enhanced: \(enhancedVideoName)")
        
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                do {
                    print("🎬 VideoPlayerService - Finding bundle URLs...")
                    guard let normalURL = Bundle.main.url(forResource: normalVideoName, withExtension: "mp4") else {
                        print("🎬 VideoPlayerService - Normal video not found: \(normalVideoName)")
                        continuation.resume(throwing: VideoPlayerError.fileNotFound(normalVideoName))
                        return
                    }
                    print("🎬 VideoPlayerService - Normal URL: \(normalURL)")
                    
                    guard let enhancedURL = Bundle.main.url(forResource: enhancedVideoName, withExtension: "mp4") else {
                        print("🎬 VideoPlayerService - Enhanced video not found: \(enhancedVideoName)")
                        continuation.resume(throwing: VideoPlayerError.fileNotFound(enhancedVideoName))
                        return
                    }
                    print("🎬 VideoPlayerService - Enhanced URL: \(enhancedURL)")
                    
                    print("🎬 VideoPlayerService - Creating players...")
                    let normalPlayer = AVPlayer(url: normalURL)
                    let enhancedPlayer = AVPlayer(url: enhancedURL)
                    
                    // Configure players
                    print("🎬 VideoPlayerService - Configuring players...")
                    normalPlayer.isMuted = true
                    enhancedPlayer.isMuted = true
                    normalPlayer.allowsExternalPlayback = false
                    enhancedPlayer.allowsExternalPlayback = false
                    
                    // Preload the videos
                    print("🎬 VideoPlayerService - Preloading players...")
                    try await self.preloadPlayers([normalPlayer, enhancedPlayer])
                    print("🎬 VideoPlayerService - Preloading completed")
                    
                    let playerPair = PlayerPair(normal: normalPlayer, enhanced: enhancedPlayer)
                    print("🎬 VideoPlayerService - Player pair created successfully")
                    continuation.resume(returning: playerPair)
                    
                } catch {
                    print("🎬 VideoPlayerService - loadPlayerPair failed: \(error)")
                    continuation.resume(throwing: VideoPlayerError.loadingFailed(error.localizedDescription))
                }
            }
        }
    }
    
    private func preloadPlayers(_ players: [AVPlayer]) async throws {
        print("🎬 VideoPlayerService[🆔 \(debugId)] - preloadPlayers(count: \(players.count))")
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (index, player) in players.enumerated() {
                group.addTask {
                    print("🎬 VideoPlayerService - Preloading player \(index + 1)")
                    
                    if let asset = await player.currentItem?.asset {
                        print("🎬 VideoPlayerService - Asset found for player \(index + 1)")
                        
                        if #available(iOS 16.0, *) {
                            print("🎬 VideoPlayerService - Using iOS 16+ asset loading")
                            _ = try await asset.load(.isPlayable)
                            print("🎬 VideoPlayerService - Player \(index + 1) loaded successfully")
                        } else {
                            print("🎬 VideoPlayerService - Using iOS 15 compatible asset loading")
                            // iOS 15 compatible asset loading
                            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                                asset.loadValuesAsynchronously(forKeys: ["playable"]) {
                                    var error: NSError?
                                    let status = asset.statusOfValue(forKey: "playable", error: &error)
                                    if let error = error {
                                        print("🎬 VideoPlayerService - Player \(index + 1) loading failed: \(error)")
                                        continuation.resume(throwing: error)
                                    } else if status == .loaded {
                                        print("🎬 VideoPlayerService - Player \(index + 1) loaded successfully")
                                        continuation.resume()
                                    } else {
                                        print("🎬 VideoPlayerService - Player \(index + 1) not playable")
                                        continuation.resume(throwing: VideoPlayerError.loadingFailed("Asset not playable"))
                                    }
                                }
                            }
                        }
                    } else {
                        print("🎬 VideoPlayerService - No asset found for player \(index + 1)")
                        throw VideoPlayerError.loadingFailed("No asset found")
                    }
                }
            }
            try await group.waitForAll()
            print("🎬 VideoPlayerService - All players preloaded successfully")
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
            guard let self = self else { return }
            let seconds = CMTimeGetSeconds(time)
            Task { @MainActor in
                await self.updateCurrentTime(seconds)
            }

            // Enforce playback within selected trim range
            // If a valid range is set and current time reaches/exceeds trimEnd, loop back to trimStart
            let start = playerPair.trimStart
            let end = playerPair.trimEnd
            if end > start {
                // Add a small epsilon to avoid jitter at boundary
                if seconds >= (end - 0.02) {
                    print("🎬 VideoPlayerService - Trim loop: \(seconds)s >= \(end)s, looping to \(start)s")
                    let startTime = CMTime(seconds: start, preferredTimescale: 600)
                    playerPair.normal.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    playerPair.enhanced.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    // Continue playback only if any view is active
                    if !self.activeViewKeys.isEmpty {
                        playerPair.normal.play()
                        playerPair.enhanced.play()
                        print("🎬 VideoPlayerService - Continuing playback after trim loop")
                    }
                }
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
