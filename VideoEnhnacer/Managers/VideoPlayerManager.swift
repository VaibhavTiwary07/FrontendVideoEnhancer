import SwiftUI
import AVFoundation

class VideoPlayerManager: ObservableObject {
    private var playerPairs: [String: (normal: AVPlayer, enhanced: AVPlayer)] = [:]
    private var loopObservers: [String: [NSObjectProtocol]] = [:]
    private var loadedKeys: Set<String> = []
    
    func setupVideoPlayers(forKey key: String, normalVideoName: String, enhancedVideoName: String) {
        guard !loadedKeys.contains(key) else { return }
        loadedKeys.insert(key)
        
        var normalPlayer: AVPlayer?
        var enhancedPlayer: AVPlayer?
        
        // Setup normal video player
        if let normalURL = Bundle.main.url(forResource: normalVideoName, withExtension: "mp4") {
            normalPlayer = AVPlayer(url: normalURL)
            normalPlayer?.isMuted = true
            normalPlayer?.play()
        }
        
        // Setup enhanced video player
        if let enhancedURL = Bundle.main.url(forResource: enhancedVideoName, withExtension: "mp4") {
            enhancedPlayer = AVPlayer(url: enhancedURL)
            enhancedPlayer?.isMuted = true
            enhancedPlayer?.play()
        }
        
        // Store players if both were created successfully
        if let normal = normalPlayer, let enhanced = enhancedPlayer {
            playerPairs[key] = (normal: normal, enhanced: enhanced)
            syncPlayers(forKey: key)
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
    
    func pausePlayers(forKey key: String) {
        playerPairs[key]?.normal.pause()
        playerPairs[key]?.enhanced.pause()
    }
    
    func resumePlayers(forKey key: String) {
        playerPairs[key]?.normal.play()
        playerPairs[key]?.enhanced.play()
    }
    
    func pauseAllPlayers() {
        for (_, playerPair) in playerPairs {
            playerPair.normal.pause()
            playerPair.enhanced.pause()
        }
    }
    
    func resumeAllPlayers() {
        for (_, playerPair) in playerPairs {
            playerPair.normal.play()
            playerPair.enhanced.play()
        }
    }
    
    deinit {
        for key in loopObservers.keys {
            cleanupObservers(forKey: key)
        }
        for (_, playerPair) in playerPairs {
            playerPair.normal.pause()
            playerPair.enhanced.pause()
        }
    }
}