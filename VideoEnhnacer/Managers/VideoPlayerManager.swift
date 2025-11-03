import SwiftUI
import AVFoundation

class VideoPlayerManager: ObservableObject {
    private var playerPairs: [String: (normal: AVPlayer, enhanced: AVPlayer)] = [:]
    private var loopObservers: [String: [NSObjectProtocol]] = [:]
    // Store both token and player reference to ensure cleanup removes from correct player instance
    private var timeSyncObservers: [String: (token: Any, player: AVPlayer)] = [:]
    private var loadedKeys: Set<String> = []
    private var loadingKeys: Set<String> = []
    private var activeViewKeys: Set<String> = []
    private var playerMuteStates: [String: Bool] = [:]
    
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
        print("🎬 VideoPlayerManager: Setting up video players (assets) for key '\(key)' normal='\(normalVideoName)' enhanced='\(enhancedVideoName)'")
        guard !loadedKeys.contains(key) && !loadingKeys.contains(key) else {
            print("🎬 Players already loaded/loading for key '\(key)' (assets)")
            return
        }
        
        loadingKeys.insert(key)
        playerStates[key] = .loading
        
        // Perform video loading on background queue
        Task {
            do {
                let players = try await loadVideoPlayersAsync(normalVideoName: normalVideoName, enhancedVideoName: enhancedVideoName)
                
                await MainActor.run {
                    print("🎬 Successfully loaded players (assets) for key '\(key)'")
                    let muteState = self.playerMuteStates[key] ?? true
                    players.normal.isMuted = muteState
                    // Always mute enhanced player to prevent double audio in comparison mode
                    players.enhanced.isMuted = true
                    self.playerMuteStates[key] = muteState
                    self.playerPairs[key] = players
                    self.loadedKeys.insert(key)
                    self.loadingKeys.remove(key)
                    self.playerStates[key] = .ready
                    self.syncPlayers(forKey: key)

                    // REMOVED AUTO-PLAY: Playback control delegated to UI
                    // if self.activeViewKeys.contains(key) {
                    //     self.resumePlayers(forKey: key)
                    // }
                }
            } catch {
                await MainActor.run {
                    print("❌ Failed to load players (assets) for key '\(key)': \(error.localizedDescription)")
                    self.loadingKeys.remove(key)
                    self.playerStates[key] = .error(error.localizedDescription)
                }
            }
        }
    }

    // New: Setup players from file URLs (for server-processed results)
    func setupVideoPlayers(forKey key: String, originalURL: URL, processedURL: URL, forceReload: Bool = false) {
        print("🎬 VideoPlayerManager: Setting up video players for key '\(key)' (forceReload: \(forceReload))")
        print("🎬 Original URL: \(originalURL)")
        print("🎬 Processed URL: \(processedURL)")

        // If forceReload is true, cleanup existing players first
        if forceReload && (loadedKeys.contains(key) || loadingKeys.contains(key)) {
            print("🎬 Force reload requested - cleaning up existing players for key '\(key)'")
            cleanupPlayersForKey(key)
        }

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
                let muteState = self.playerMuteStates[key] ?? true
                normalPlayer.isMuted = muteState
                // Always mute enhanced player to prevent double audio in comparison mode
                enhancedPlayer.isMuted = true
                normalPlayer.allowsExternalPlayback = false
                enhancedPlayer.allowsExternalPlayback = false
                
                // Preload by ensuring asset is playable
                try await preload(player: normalPlayer)
                try await preload(player: enhancedPlayer)
                
                await MainActor.run {
                    print("🎬 Successfully loaded players for key '\(key)'")
                    self.playerPairs[key] = (normal: normalPlayer, enhanced: enhancedPlayer)
                    self.loadedKeys.insert(key)
                    self.loadingKeys.remove(key)
                    self.playerMuteStates[key] = muteState
                    self.playerStates[key] = .ready
                    self.syncPlayers(forKey: key)

                    // REMOVED AUTO-PLAY: Playback control delegated to UI
                    // if self.activeViewKeys.contains(key) {
                    //     print("🎬 Auto-playing loaded players for active key '\(key)'")
                    //     self.resumePlayers(forKey: key)
                    // }
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
                normalPlayer.allowsExternalPlayback = false
                enhancedPlayer.allowsExternalPlayback = false
                
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

        print("DEBUG_COMPARE: syncPlayers() called for key '\(key)'")

        // Clean up existing observers for this key
        cleanupObservers(forKey: key)
        cleanupTimeObserver(forKey: key)
        
        var observers: [NSObjectProtocol] = []

        // Leader-Follower Loop Pattern: Only normal (leader) player controls looping for BOTH players
        // This prevents desynchronization caused by videos having slightly different durations
        let normalObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerPair.normal.currentItem,
            queue: .main
        ) { [weak self] _ in
            let normalTime = CMTimeGetSeconds(playerPair.normal.currentTime())
            let enhancedTime = CMTimeGetSeconds(playerPair.enhanced.currentTime())
            print("DEBUG_COMPARE: Normal video (leader) reached end - normalTime=\(normalTime)s enhancedTime=\(enhancedTime)s")
            print("DEBUG_COMPARE: Looping BOTH players to zero (leader-follower pattern)")

            // Loop both players simultaneously to maintain sync
            playerPair.normal.seek(to: .zero)
            playerPair.enhanced.seek(to: .zero)

            // Resume playback immediately for continuous looping in comparison mode
            // This ensures both players resume in sync (AVPlayer doesn't auto-resume after seek)
            playerPair.normal.play()
            playerPair.enhanced.play()

            print("DEBUG_COMPARE: Resumed playback after loop - both players playing")
        }
        observers.append(normalObserver)

        // Enhanced (follower) player does NOT have its own loop observer
        // The leader controls looping for both to prevent desynchronization

        loopObservers[key] = observers

        // Periodically sync enhanced player's time to normal player's time
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        print("DEBUG_COMPARE: Setting up time sync observer for key '\(key)' - checking every 0.1s, threshold=0.15s")
        let token = playerPair.normal.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let enhancedTime = playerPair.enhanced.currentTime()
            let normalTimeSeconds = CMTimeGetSeconds(time)
            let enhancedTimeSeconds = CMTimeGetSeconds(enhancedTime)
            let diff = abs(enhancedTimeSeconds - normalTimeSeconds)

            // Log time sync check (sample every 10th check to reduce console spam - roughly every 1 second)
            let shouldLogThisCheck = Int(normalTimeSeconds * 10) % 10 == 0
            if shouldLogThisCheck {
                print("DEBUG_COMPARE: Time sync check - normalTime=\(String(format: "%.3f", normalTimeSeconds))s enhancedTime=\(String(format: "%.3f", enhancedTimeSeconds))s diff=\(String(format: "%.3f", diff))s")
            }

            // Relaxed threshold from 0.05 to 0.15 seconds to reduce stuttering
            if diff > 0.15 {
                print("DEBUG_COMPARE: ⚠️ DRIFT DETECTED - diff=\(String(format: "%.3f", diff))s exceeds threshold (0.15s) - seeking enhanced player from \(String(format: "%.3f", enhancedTimeSeconds))s to \(String(format: "%.3f", normalTimeSeconds))s")
                playerPair.enhanced.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }
        // Store both token AND player reference to prevent "different instance" crash during cleanup
        timeSyncObservers[key] = (token: token, player: playerPair.normal)
        print("DEBUG_COMPARE: Time sync observer registered for key '\(key)'")
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
        if let observerData = timeSyncObservers[key] {
            print("DEBUG_COMPARE: Cleaning up time observer for key '\(key)'")
            // Remove observer from the STORED player reference (not current playerPairs)
            // This prevents "different instance" crash when players are recreated
            observerData.player.removeTimeObserver(observerData.token)
            timeSyncObservers.removeValue(forKey: key)
            print("DEBUG_COMPARE: Time observer removed successfully for key '\(key)'")
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

            // REMOVED AUTO-PLAY: Playback control delegated to UI (CustomVideoPlayerWithControls)
            // if playerStates[key] == .ready || playerStates[key] == .paused {
            //     print("🎬 Resuming players for key '\(key)'")
            //     resumePlayers(forKey: key)
            // } else {
            //     print("🎬 Players not ready for key '\(key)', state: \(playerStates[key] ?? .loading)")
            // }
            print("🎬 View activated for key '\(key)' - playback control delegated to UI")
        } else {
            activeViewKeys.remove(key)
            // Pause players when the owning view disappears to prevent overlapping audio across screens
            print("videoviewoverlapping VideoPlayerManager: Pausing players for key '\(key)' after deactivation")
            pausePlayers(forKey: key)
            // Clean up time observers to prevent unnecessary syncing when the view is no longer visible
            cleanupTimeObserver(forKey: key)
            print("🎬 View deactivated for key '\(key)' and players paused")
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
        playerMuteStates.removeValue(forKey: key)
    }
    
    func pausePlayers(forKey key: String) {
        if let playerPair = playerPairs[key] {
            let normalTime = CMTimeGetSeconds(playerPair.normal.currentTime())
            let enhancedTime = CMTimeGetSeconds(playerPair.enhanced.currentTime())

            print("DEBUG_COMPARE: pausePlayers() called for key '\(key)'")
            print("DEBUG_COMPARE: Pausing at - normalTime=\(String(format: "%.3f", normalTime))s enhancedTime=\(String(format: "%.3f", enhancedTime))s")

            playerPair.normal.pause()
            playerPair.enhanced.pause()
        }

        if playerStates[key] == .ready {
            playerStates[key] = .paused
        }
    }
    
    func resumePlayers(forKey key: String) {
        guard playerStates[key] == .ready || playerStates[key] == .paused else { return }

        if let playerPair = playerPairs[key] {
            let normalTime = CMTimeGetSeconds(playerPair.normal.currentTime())
            let enhancedTime = CMTimeGetSeconds(playerPair.enhanced.currentTime())
            let normalRate = playerPair.normal.rate
            let enhancedRate = playerPair.enhanced.rate

            print("DEBUG_COMPARE: resumePlayers() called for key '\(key)'")
            print("DEBUG_COMPARE: Before resume - normalTime=\(String(format: "%.3f", normalTime))s normalRate=\(normalRate)")
            print("DEBUG_COMPARE: Before resume - enhancedTime=\(String(format: "%.3f", enhancedTime))s enhancedRate=\(enhancedRate)")

            playerPair.normal.play()
            playerPair.enhanced.play()

            print("DEBUG_COMPARE: After resume - both players .play() called")
        }

        playerStates[key] = .ready
    }
    
    func pauseAllPlayers() {
        for key in playerPairs.keys {
            pausePlayers(forKey: key)
        }
        activeViewKeys.removeAll()
    }

    func resumeActiveViewPlayers() {
        // REMOVED AUTO-RESUME: Playback control delegated to UI (CustomVideoPlayerWithControls)
        // The UI controls will handle resuming playback if needed
        print("🎬 resumeActiveViewPlayers() called - playback control delegated to UI")

        // Still ensure sync observers exist for comparison views
        for key in loadedKeys {
            if timeSyncObservers[key] == nil, playerPairs[key] != nil {
                syncPlayers(forKey: key)
            }
        }
    }

    func setMuted(_ muted: Bool, forKey key: String) {
        playerMuteStates[key] = muted
        if let pair = playerPairs[key] {
            // Only mute/unmute the normal player (which has audio)
            pair.normal.isMuted = muted
            // Enhanced player stays muted to prevent double audio
            pair.enhanced.isMuted = true
        }
    }

    func toggleMute(forKey key: String) -> Bool {
        let newValue = !(playerMuteStates[key] ?? true)
        setMuted(newValue, forKey: key)
        return newValue
    }

    func isMuted(forKey key: String) -> Bool {
        playerMuteStates[key] ?? true
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
