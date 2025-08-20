import SwiftUI
import AVFoundation

class VideoPlayerManager: ObservableObject {
    private var playerPairs: [String: (normal: AVPlayer, enhanced: AVPlayer)] = [:]
    private var loopObservers: [String: [NSObjectProtocol]] = [:]
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
                                _ = try await asset.load(.isPlayable)
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
    }
    
    private func cleanupObservers(forKey key: String) {
        if let observers = loopObservers[key] {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
            loopObservers.removeValue(forKey: key)
        }
    }
    
    func setViewActive(forKey key: String, isActive: Bool) {
        if isActive {
            activeViewKeys.insert(key)
            if playerStates[key] == .ready {
                resumePlayers(forKey: key)
            }
        } else {
            activeViewKeys.remove(key)
            pausePlayers(forKey: key)
        }
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
        for (_, playerPair) in playerPairs {
            playerPair.normal.pause()
            playerPair.enhanced.pause()
        }
    }
}