import Foundation
import AVFoundation
import Combine

// MARK: - Video Player Protocol
/// Defines the contract for video player operations following Dependency Inversion Principle
protocol VideoPlayerProtocol: AnyObject {
    // MARK: - Published Properties
    var playerStatePublisher: Published<VideoPlayerState>.Publisher { get }
    var currentTimePublisher: Published<Double>.Publisher { get }
    
    // MARK: - Player Management
    func setupPlayers(normalVideoName: String, enhancedVideoName: String) async throws
    func setupPlayerWithURL(_ videoURL: URL, forKey key: String) async throws
    func setActiveView(forKey key: String, isActive: Bool)
    func cleanup()
    
    // MARK: - Playback Control
    func play(forKey key: String) async
    func pause(forKey key: String)
    func seek(to time: Double, forKey key: String) async
    func setPlaybackRange(start: Double, end: Double, forKey key: String)
    
    // MARK: - Player Access
    func getNormalPlayer(forKey key: String) -> AVPlayer?
    func getEnhancedPlayer(forKey key: String) -> AVPlayer?
    
    // MARK: - State Management
    func getPlayerState(forKey key: String) -> VideoPlayerState
}

// MARK: - Video Player State
enum VideoPlayerState: Equatable {
    case idle
    case loading
    case ready
    case playing
    case paused
    case error(VideoPlayerError)
    
    var isPlayable: Bool {
        switch self {
        case .ready, .playing, .paused:
            return true
        default:
            return false
        }
    }
}

// MARK: - Video Player Error
enum VideoPlayerError: Error, Equatable, LocalizedError {
    case fileNotFound(String)
    case urlNotAccessible(String)
    case loadingFailed(String)
    case playbackFailed(String)
    case invalidTimeRange
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let fileName):
            return "Video file '\(fileName)' not found in bundle"
        case .urlNotAccessible(let urlString):
            return "Cannot access video at '\(urlString)'. Please check permissions."
        case .loadingFailed(let reason):
            return "Failed to load video: \(reason)"
        case .playbackFailed(let reason):
            return "Playback error: \(reason)"
        case .invalidTimeRange:
            return "Invalid time range specified"
        }
    }
}