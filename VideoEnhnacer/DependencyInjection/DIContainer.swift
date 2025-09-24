import Foundation
import SwiftUI
import AVFoundation
import Combine

// MARK: - Dependency Injection Container
/// Central container for managing dependencies following Dependency Inversion Principle
final class DIContainer: ObservableObject {
    static let shared = DIContainer()
    
    // MARK: - Service Properties
    private(set) lazy var videoPlayerService: VideoPlayerProtocol = VideoPlayerService()
    private(set) lazy var videoProcessingService: VideoProcessingProtocol = VideoProcessingService()
    private(set) lazy var enhancementService: EnhancementServiceProtocol = ServerEnhancementService(videoProcessingService: videoProcessingService)
    @MainActor private(set) lazy var navigationCoordinator: AppCoordinator = AppCoordinator()
    
    // MARK: - Private Initialization (Singleton)
    private init() {}
    
    // MARK: - Service Factory Methods
    @MainActor
    func makeVideoPlayerViewModel() -> VideoPlayerViewModel {
        VideoPlayerViewModel(videoPlayerService: videoPlayerService)
    }
    
    @MainActor
    func makeEnhancementSelectionViewModel(
        videoURL: URL,
        enhancementType: EnhancementType,
        trimStartTime: Double? = nil,
        trimEndTime: Double? = nil
    ) -> EnhancementSelectionViewModel {
        // Use a fresh enhancement service instance per selection session to avoid leaking
        // previous processing state (prevents stale Results from auto-presenting).
        let freshEnhancementService: EnhancementServiceProtocol = ServerEnhancementService(videoProcessingService: videoProcessingService)
        return EnhancementSelectionViewModel(
            videoURL: videoURL,
            enhancementType: enhancementType,
            trimStartTime: trimStartTime,
            trimEndTime: trimEndTime,
            enhancementService: freshEnhancementService,
            videoProcessingService: videoProcessingService
        )
    }
    
    @MainActor
    func makeVideoTrimmingViewModel(
        videoURL: URL,
        enhancementType: EnhancementType
    ) -> VideoTrimmingViewModel {
        let playerViewModel = makeVideoPlayerViewModel()
        return VideoTrimmingViewModel(
            videoURL: videoURL,
            enhancementType: enhancementType,
            videoProcessingService: videoProcessingService,
            playerViewModel: playerViewModel
        )
    }
    
    // MARK: - Service Registration (for testing or custom implementations)
    func registerVideoPlayerService(_ service: VideoPlayerProtocol) {
        videoPlayerService = service
    }
    
    func registerVideoProcessingService(_ service: VideoProcessingProtocol) {
        videoProcessingService = service
    }
    
    func registerEnhancementService(_ service: EnhancementServiceProtocol) {
        enhancementService = service
    }
    
    // MARK: - Cleanup
    func cleanup() {
        videoPlayerService.cleanup()
        // Additional cleanup if needed
    }
}

// MARK: - Environment Key for SwiftUI
private struct DIContainerKey: EnvironmentKey {
    static let defaultValue = DIContainer.shared
}

extension EnvironmentValues {
    var diContainer: DIContainer {
        get { self[DIContainerKey.self] }
        set { self[DIContainerKey.self] = newValue }
    }
}

// MARK: - SwiftUI View Extension
extension View {
    func withDependencyInjection(_ container: DIContainer = DIContainer.shared) -> some View {
        self.environment(\.diContainer, container)
    }
}

// MARK: - Property Wrapper for Dependency Injection
@propertyWrapper
struct Injected<T> {
    private let keyPath: KeyPath<DIContainer, T>
    
    init(_ keyPath: KeyPath<DIContainer, T>) {
        self.keyPath = keyPath
    }
    
    var wrappedValue: T {
        DIContainer.shared[keyPath: keyPath]
    }
}

// MARK: - Common Injection Points
extension DIContainer {
    // Quick access properties for common injections
    var videoPlayer: VideoPlayerProtocol { videoPlayerService }
    var videoProcessing: VideoProcessingProtocol { videoProcessingService }
    var enhancement: EnhancementServiceProtocol { enhancementService }
    @MainActor var navigation: AppCoordinator { navigationCoordinator }
}

// MARK: - Usage Examples for Property Wrapper
/*
 Usage in ViewModels:
 
 class SomeViewModel: ObservableObject {
     @Injected(\.videoPlayer) private var videoPlayerService
     @Injected(\.enhancement) private var enhancementService
 }
 
 Usage in Views:
 
 struct SomeView: View {
     @Environment(\.diContainer) private var container
     
     var body: some View {
         // Use container.makeVideoPlayerViewModel()
     }
 }
 */

// MARK: - Mock Container for Testing
#if DEBUG
final class MockDIContainer: ObservableObject {
    static let shared = MockDIContainer()
    
    private(set) lazy var videoPlayerService: VideoPlayerProtocol = MockVideoPlayerService()
    private(set) lazy var videoProcessingService: VideoProcessingProtocol = MockVideoProcessingService()
    private(set) lazy var enhancementService: EnhancementServiceProtocol = MockEnhancementService()
    @MainActor private(set) lazy var navigationCoordinator: AppCoordinator = AppCoordinator()
    
    private init() {
        // Setup mock services
    }
    
    @MainActor
    func makeVideoPlayerViewModel() -> VideoPlayerViewModel {
        VideoPlayerViewModel(videoPlayerService: videoPlayerService)
    }
    
    @MainActor
    func makeEnhancementSelectionViewModel(
        videoURL: URL,
        enhancementType: EnhancementType,
        trimStartTime: Double? = nil,
        trimEndTime: Double? = nil
    ) -> EnhancementSelectionViewModel {
        EnhancementSelectionViewModel(
            videoURL: videoURL,
            enhancementType: enhancementType,
            trimStartTime: trimStartTime,
            trimEndTime: trimEndTime,
            enhancementService: enhancementService,
            videoProcessingService: videoProcessingService
        )
    }
    
    @MainActor
    func makeVideoTrimmingViewModel(
        videoURL: URL,
        enhancementType: EnhancementType
    ) -> VideoTrimmingViewModel {
        let playerViewModel = makeVideoPlayerViewModel()
        return VideoTrimmingViewModel(
            videoURL: videoURL,
            enhancementType: enhancementType,
            videoProcessingService: videoProcessingService,
            playerViewModel: playerViewModel
        )
    }
}

// MARK: - Mock Services
final class MockVideoPlayerService: VideoPlayerProtocol {
    @Published private var currentTime: Double = 0
    
    var currentTimePublisher: Published<Double>.Publisher { $currentTime }
    
    // Per-key state tracking for mock
    private var keyStates: [String: VideoPlayerState] = [:]
    private var keyStateSubjects: [String: CurrentValueSubject<VideoPlayerState, Never>] = [:]
    
    func setupPlayers(key: String, normalVideoName: String, enhancedVideoName: String) async throws {
        keyStates[key] = .loading
        keyStateSubjects[key]?.send(.loading)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        keyStates[key] = .ready
        keyStateSubjects[key]?.send(.ready)
    }
    func setupPlayers(key: String, originalURL: URL, enhancedURL: URL) async throws {
        keyStates[key] = .loading
        keyStateSubjects[key]?.send(.loading)
        try await Task.sleep(nanoseconds: 500_000_000)
        keyStates[key] = .ready
        keyStateSubjects[key]?.send(.ready)
    }
    
    func setActiveView(forKey key: String, isActive: Bool) {}
    func cleanup() {}
    func play(forKey key: String) async { 
        keyStates[key] = .playing
        keyStateSubjects[key]?.send(.playing)
    }
    func pause(forKey key: String) { 
        keyStates[key] = .paused
        keyStateSubjects[key]?.send(.paused)
    }
    func seek(to time: Double, forKey key: String) async { currentTime = time }
    func setPlaybackRange(start: Double, end: Double, forKey key: String) {}
    func getNormalPlayer(forKey key: String) -> AVPlayer? { nil }
    func getEnhancedPlayer(forKey key: String) -> AVPlayer? { nil }
    func getPlayerState(forKey key: String) -> VideoPlayerState { 
        return keyStates[key] ?? .idle
    }
    func getPlayerStatePublisher(forKey key: String) -> AnyPublisher<VideoPlayerState, Never> {
        if keyStateSubjects[key] == nil {
            keyStateSubjects[key] = CurrentValueSubject<VideoPlayerState, Never>(.idle)
        }
        return keyStateSubjects[key]!.eraseToAnyPublisher()
    }
}

final class MockVideoProcessingService: VideoProcessingProtocol {
    func getVideoInfo(from url: URL) async throws -> VideoInfo {
        VideoInfo(
            url: url,
            duration: 30.0,
            dimensions: CGSize(width: 1920, height: 1080),
            frameRate: 30.0,
            bitRate: 5000000,
            format: "mp4",
            fileSize: 10485760,
            hasAudio: true,
            metadata: [:]
        )
    }
    
    func validateVideoFile(at url: URL) async throws -> Bool { true }
    func trimVideo(at url: URL, startTime: Double, endTime: Double, quality: VideoQuality) async throws -> URL { url }
    func generateThumbnails(for url: URL, count: Int, quality: ThumbnailQuality) async throws -> [UIImage] { [] }
    func generateThumbnail(for url: URL, at time: Double, quality: ThumbnailQuality) async throws -> UIImage { UIImage() }
    func compressVideo(at url: URL, quality: VideoQuality, progress: @escaping (Double) -> Void) async throws -> URL { url }
    func convertVideoFormat(at url: URL, to format: VideoFormat, quality: VideoQuality) async throws -> URL { url }
}

final class MockEnhancementService: EnhancementServiceProtocol {
    @Published private var processingState: EnhancementProcessingState = .idle
    @Published private var progress: Double = 0.0
    
    var processingStatePublisher: Published<EnhancementProcessingState>.Publisher { $processingState }
    var progressPublisher: Published<Double>.Publisher { $progress }
    
    func processVideo(at url: URL, with request: EnhancementRequest) async throws -> EnhancementResult {
        processingState = .preparing
        
        for i in 1...10 {
            try await Task.sleep(nanoseconds: 100_000_000)
            progress = Double(i) / 10.0
        }
        
        let result = EnhancementResult(
            originalURL: url,
            processedURL: url,
            enhancementType: request.enhancementType,
            processingTime: 2.0,
            metadata: EnhancementMetadata(
                processingTime: 2.0,
                enhancementStrength: 0.8,
                qualityScore: 0.9,
                fileSize: 1024,
                appliedSettings: [:],
                processingStartTime: Date(),
                processingEndTime: Date()
            )
        )
        
        processingState = .completed(result)
        return result
    }
    
    func cancelProcessing() async { processingState = .cancelled }
    func getSupportedEnhancementTypes() -> [EnhancementType] { [] }
    func validateEnhancement(request: EnhancementRequest) throws {}
}
#endif
