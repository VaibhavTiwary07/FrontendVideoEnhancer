import SwiftUI
import AVFoundation

class VideoPlayerManager: ObservableObject {
    private var playerPairs: [String: (normal: AVPlayer, enhanced: AVPlayer)] = [:]
    private var loopObservers: [String: [NSObjectProtocol]] = [:]
    private var timeSyncObservers: [String: Any] = [:]
    private var loadedKeys: Set<String> = []
    private var loadingKeys: Set<String> = []
    private var activeViewKeys: Set<String> = []
    
    // Published states for UI updates
    @Published private var playerStates: [String: PlayerState] = [:]
    
    enum PlayerState: Equatable {
        case loading
        case ready
        case error(String)
        case paused
    }

    // Debug helper to inspect internal state for a given key
    func debugStatus(forKey key: String, context: String = "") {
        let state = playerStates[key] ?? .loading
        let loaded = loadedKeys.contains(key)
        let loading = loadingKeys.contains(key)
        let active = activeViewKeys.contains(key)
        let pair = playerPairs[key]
        let hasNormal = pair?.normal.currentItem != nil
        let hasEnhanced = pair?.enhanced.currentItem != nil
        print("🧩 VideoPlayerManager.debugStatus \(context) -> key='\(key)' state=\(state) loaded=\(loaded) loading=\(loading) active=\(active) hasNormal=\(hasNormal) hasEnhanced=\(hasEnhanced)")
    }
    
    func getPlayerState(forKey key: String) -> PlayerState {
        return playerStates[key] ?? .loading
    }
    
    func setupVideoPlayers(forKey key: String, normalVideoName: String, enhancedVideoName: String) {
        guard !loadedKeys.contains(key) && !loadingKeys.contains(key) else { return }
        
        loadingKeys.insert(key)
        playerStates[key] = .loading
        
        // Perform video loading on background queue
        Task {
            do {
                let players = try await loadVideoPlayersAsync(normalVideoName: normalVideoName, enhancedVideoName: enhancedVideoName)
                
                await MainActor.run {
                    self.playerPairs[key] = players
                    self.loadedKeys.insert(key)
                    self.loadingKeys.remove(key)
                    self.playerStates[key] = .ready
                    self.syncPlayers(forKey: key)
                    
                    // Auto-play if view is active
                    if self.activeViewKeys.contains(key) {
                        self.resumePlayers(forKey: key)
                    }
                }
            } catch {
                await MainActor.run {
                    self.loadingKeys.remove(key)
                    self.playerStates[key] = .error(error.localizedDescription)
                }
            }
        }
    }

    // New: Setup players from file URLs (for server-processed results)
    func setupVideoPlayers(forKey key: String, originalURL: URL, processedURL: URL) {
        print("🎬 VideoPlayerManager: Setting up video players for key '\(key)'")
        print("🎬 Original URL: \(originalURL)")
        print("🎬 Processed URL: \(processedURL)")
        
        guard !loadedKeys.contains(key) && !loadingKeys.contains(key) else { 
            print("🎬 Players already loaded/loading for key '\(key)'")
            return 
        }
        
        loadingKeys.insert(key)
        playerStates[key] = .loading
        
        Task {
            do {
                let normalPlayer = AVPlayer(url: originalURL)
                let enhancedPlayer = AVPlayer(url: processedURL)
                normalPlayer.isMuted = true
                enhancedPlayer.isMuted = true
                
                // Preload by ensuring asset is playable
                try await preload(player: normalPlayer)
                try await preload(player: enhancedPlayer)
                
                await MainActor.run {
                    print("🎬 Successfully loaded players for key '\(key)'")
                    self.playerPairs[key] = (normal: normalPlayer, enhanced: enhancedPlayer)
                    self.loadedKeys.insert(key)
                    self.loadingKeys.remove(key)
                    self.playerStates[key] = .ready
                    self.syncPlayers(forKey: key)
                    if self.activeViewKeys.contains(key) {
                        print("🎬 Auto-playing loaded players for active key '\(key)'")
                        self.resumePlayers(forKey: key)
                    }
                }
            } catch {
                await MainActor.run {
                    self.loadingKeys.remove(key)
                    self.playerStates[key] = .error(error.localizedDescription)
                }
            }
        }
    }

    private func preload(player: AVPlayer) async throws {
        if let asset = await player.currentItem?.asset {
            if #available(iOS 16.0, *) {
                _ = try await asset.load(.isPlayable)
            } else {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    asset.loadValuesAsynchronously(forKeys: ["playable"]) {
                        var err: NSError?
                        let status = asset.statusOfValue(forKey: "playable", error: &err)
                        if let err = err { continuation.resume(throwing: err) }
                        else if status == .loaded { continuation.resume() }
                        else { continuation.resume(throwing: VideoLoadError.loadFailed) }
                    }
                }
            }
        }
    }
    
    private func loadVideoPlayersAsync(normalVideoName: String, enhancedVideoName: String) async throws -> (normal: AVPlayer, enhanced: AVPlayer) {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let normalURL = Bundle.main.url(forResource: normalVideoName, withExtension: "mp4"),
                      let enhancedURL = Bundle.main.url(forResource: enhancedVideoName, withExtension: "mp4") else {
                    continuation.resume(throwing: VideoLoadError.fileNotFound)
                    return
                }
                
                let normalPlayer = AVPlayer(url: normalURL)
                let enhancedPlayer = AVPlayer(url: enhancedURL)
                
                normalPlayer.isMuted = true
                enhancedPlayer.isMuted = true
                
                // Preload the videos
                let group = DispatchGroup()
                var loadError: Error?
                
                [normalPlayer, enhancedPlayer].forEach { player in
                    group.enter()
                    Task {
                        defer { group.leave() }
                        do {
                            if let asset = await player.currentItem?.asset {
                                if #available(iOS 16.0, *) {
                                    _ = try await asset.load(.isPlayable)
                                } else {
                                    // iOS 15 compatible asset loading
                                    let keys = ["playable"]
                                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                                        asset.loadValuesAsynchronously(forKeys: keys) {
                                            var error: NSError?
                                            let status = asset.statusOfValue(forKey: "playable", error: &error)
                                            if let error = error {
                                                continuation.resume(throwing: error)
                                            } else if status == .loaded {
                                                continuation.resume()
                                            } else {
                                                continuation.resume(throwing: VideoLoadError.loadFailed)
                                            }
                                        }
                                    }
                                }
                            }
                        } catch {
                            loadError = error
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    if let error = loadError {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: (normal: normalPlayer, enhanced: enhancedPlayer))
                    }
                }
            }
        }
    }
    
    enum VideoLoadError: LocalizedError {
        case fileNotFound
        case loadFailed
        
        var errorDescription: String? {
            switch self {
            case .fileNotFound:
                return "Video file not found"
            case .loadFailed:
                return "Failed to load video"
            }
        }
    }
    
    func getNormalPlayer(forKey key: String) -> AVPlayer? {
        return playerPairs[key]?.normal
    }
    
    func getEnhancedPlayer(forKey key: String) -> AVPlayer? {
        return playerPairs[key]?.enhanced
    }
    
    private func syncPlayers(forKey key: String) {
        guard let playerPair = playerPairs[key] else { return }
        
        // Clean up existing observers for this key
        cleanupObservers(forKey: key)
        cleanupTimeObserver(forKey: key)
        
        var observers: [NSObjectProtocol] = []
        
        // Loop normal video
        let normalObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerPair.normal.currentItem,
            queue: .main
        ) { _ in
            playerPair.normal.seek(to: .zero)
            playerPair.normal.play()
        }
        observers.append(normalObserver)
        
        // Loop enhanced video
        let enhancedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerPair.enhanced.currentItem,
            queue: .main
        ) { _ in
            playerPair.enhanced.seek(to: .zero)
            playerPair.enhanced.play()
        }
        observers.append(enhancedObserver)
        
        loopObservers[key] = observers

        // Periodically sync enhanced player's time to normal player's time
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        let token = playerPair.normal.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let enhancedTime = playerPair.enhanced.currentTime()
            let diff = abs(CMTimeGetSeconds(enhancedTime) - CMTimeGetSeconds(time))
            if diff > 0.05 {
                playerPair.enhanced.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }
        timeSyncObservers[key] = token
    }
    
    private func cleanupObservers(forKey key: String) {
        if let observers = loopObservers[key] {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
            loopObservers.removeValue(forKey: key)
        }
    }

    private func cleanupTimeObserver(forKey key: String) {
        if let token = timeSyncObservers[key] {
            if let pair = playerPairs[key] {
                pair.normal.removeTimeObserver(token)
            }
            timeSyncObservers.removeValue(forKey: key)
        }
    }
    
    func setViewActive(forKey key: String, isActive: Bool) {
        print("🎬 VideoPlayerManager: Setting view active for key '\(key)': \(isActive)")
        print("🎬 Current player state for key '\(key)': \(playerStates[key] ?? .loading)")
        print("🎬 Active view keys: \(activeViewKeys)")
        
        if isActive {
            activeViewKeys.insert(key)
            // Ensure time sync observers exist after re-activation
            if timeSyncObservers[key] == nil, playerPairs[key] != nil {
                syncPlayers(forKey: key)
            }

            if playerStates[key] == .ready || playerStates[key] == .paused {
                print("🎬 Resuming players for key '\(key)'")
                resumePlayers(forKey: key)
            } else {
                print("🎬 Players not ready for key '\(key)', state: \(playerStates[key] ?? .loading)")
            }
        } else {
            activeViewKeys.remove(key)
            print("🎬 Pausing players for key '\(key)'")
            pausePlayers(forKey: key)
            cleanupTimeObserver(forKey: key)
        }
    }
    
    func cleanupPlayersForKey(_ key: String) {
        print("🎬 VideoPlayerManager: Cleaning up players for key '\(key)'")
        cleanupObservers(forKey: key)
        cleanupTimeObserver(forKey: key)
        if let playerPair = playerPairs[key] {
            playerPair.normal.pause()
            playerPair.enhanced.pause()
        }
        playerPairs.removeValue(forKey: key)
        loadedKeys.remove(key)
        loadingKeys.remove(key)
        activeViewKeys.remove(key)
        playerStates.removeValue(forKey: key)
    }
    
    func pausePlayers(forKey key: String) {
        playerPairs[key]?.normal.pause()
        playerPairs[key]?.enhanced.pause()
        if playerStates[key] == .ready {
            playerStates[key] = .paused
        }
    }
    
    func resumePlayers(forKey key: String) {
        guard playerStates[key] == .ready || playerStates[key] == .paused else { return }
        playerPairs[key]?.normal.play()
        playerPairs[key]?.enhanced.play()
        playerStates[key] = .ready
    }
    
    func pauseAllPlayers() {
        for key in playerPairs.keys {
            pausePlayers(forKey: key)
        }
        activeViewKeys.removeAll()
    }
    
    func resumeActiveViewPlayers() {
        for key in activeViewKeys {
            if playerStates[key] == .ready || playerStates[key] == .paused {
                resumePlayers(forKey: key)
            }
        }
    }
    
    init() {
        // Listen for app lifecycle events
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
        pauseAllPlayers()
    }
    
    @objc private func appWillEnterForeground() {
        resumeActiveViewPlayers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        for key in loopObservers.keys {
            cleanupObservers(forKey: key)
        }
        for key in timeSyncObservers.keys {
            cleanupTimeObserver(forKey: key)
        }
        for (_, playerPair) in playerPairs {
            playerPair.normal.pause()
            playerPair.enhanced.pause()
        }
    }
}
