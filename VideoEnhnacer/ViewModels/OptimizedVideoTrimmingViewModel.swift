import Foundation
import SwiftUI
import Combine
import AVFoundation

// MARK: - Optimized Video Trimming ViewModel
/// High-performance video trimming with parallel loading and caching
/// SOLID Principles: Single Responsibility, Dependency Inversion
@MainActor
final class OptimizedVideoTrimmingViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var trimStartTime: Double = 0
    @Published var trimEndTime: Double = 30
    @Published private(set) var videoDuration: Double = 0
    @Published private(set) var thumbnails: [UIImage] = []
    @Published private(set) var isLoading: Bool = true
    @Published private(set) var error: VideoProcessingError?

    // MARK: - Progress Tracking
    @Published private(set) var loadingProgress: LoadingProgress = .notStarted

    enum LoadingProgress {
        case notStarted
        case loadingMetadata
        case loadingPlayer
        case loadingThumbnails
        case complete

        var percentage: Double {
            switch self {
            case .notStarted: return 0
            case .loadingMetadata: return 0.2
            case .loadingPlayer: return 0.5
            case .loadingThumbnails: return 0.8
            case .complete: return 1.0
            }
        }
    }

    // MARK: - Dependencies
    private let videoURL: URL
    private let enhancementType: EnhancementType
    private let videoProcessingService: VideoProcessingProtocol
    let playerViewModel: VideoPlayerViewModel

    // MARK: - Performance Optimization
    private let performanceMonitor = PerformanceMonitor()
    private var loadingTask: Task<Void, Never>?

    // MARK: - Initialization
    init(
        videoURL: URL,
        enhancementType: EnhancementType,
        videoProcessingService: VideoProcessingProtocol,
        playerViewModel: VideoPlayerViewModel
    ) {
        self.videoURL = videoURL
        self.enhancementType = enhancementType
        self.videoProcessingService = videoProcessingService
        self.playerViewModel = playerViewModel
    }

    // MARK: - Optimized Loading
    func loadVideoOptimized() {
        loadingTask?.cancel()
        loadingTask = Task {
            await performOptimizedLoading()
        }
    }

    private func performOptimizedLoading() async {
        var metrics = performanceMonitor.startMeasurement(operation: "VideoLoading")

        do {
            // PHASE 1: Load metadata (fastest, needed for UI)
            loadingProgress = .loadingMetadata
            var metadataMetrics = performanceMonitor.startMeasurement(operation: "Metadata")

            let videoInfo = try await videoProcessingService.getVideoInfo(from: videoURL)

            metadataMetrics.end()
            videoDuration = videoInfo.duration
            trimEndTime = min(30, videoInfo.duration)

            // PHASE 2 & 3: Parallel loading (player + thumbnails simultaneously)
            loadingProgress = .loadingPlayer

            async let playerSetup = setupPlayersOptimized()
            async let thumbnailGen = generateThumbnailsOptimized()

            // Wait for both to complete
            try await playerSetup
            _ = await thumbnailGen // thumbnails can continue in background

            loadingProgress = .complete
            isLoading = false

            metrics.end()
            metrics.log()

        } catch {
            self.error = VideoProcessingError.processingFailed(error.localizedDescription)
            isLoading = false
        }
    }

    private func setupPlayersOptimized() async throws {
        var metrics = performanceMonitor.startMeasurement(operation: "PlayerSetup")

        playerViewModel.setupPlayers(originalURL: videoURL, enhancedURL: videoURL)

        metrics.end()
    }

    private func generateThumbnailsOptimized() async -> [UIImage] {
        loadingProgress = .loadingThumbnails
        var metrics = performanceMonitor.startMeasurement(operation: "ThumbnailGeneration")

        // Generate thumbnails in parallel batches
        let count = DeviceSize.isSmallPhone ? 6 : 10
        let generatedThumbnails = (try? await videoProcessingService.generateThumbnails(
            for: videoURL,
            count: count,
            quality: .medium
        )) ?? []

        thumbnails = generatedThumbnails
        metrics.end()

        return generatedThumbnails
    }
}

// MARK: - Performance Monitor (SOLID: Single Responsibility)
final class PerformanceMonitor {

    func startMeasurement(operation: String) -> PerformanceMeasurement {
        PerformanceMeasurement(operation: operation, startTime: Date())
    }
}

struct PerformanceMeasurement {
    let operation: String
    let startTime: Date
    private var endTime: Date?

    init(operation: String, startTime: Date) {
        self.operation = operation
        self.startTime = startTime
        self.endTime = nil
    }

    @discardableResult
    mutating func end() -> Self {
        endTime = Date()
        return self
    }

    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }

    func log() {
        print("⚡️ [Performance] \(operation): \(String(format: "%.3f", duration))s")
    }
}


// MARK: - Concurrent Operation Manager
/// Manages parallel operations with proper error handling
actor ConcurrentOperationManager {
    private var runningOperations: [String: Task<Void, Error>] = [:]

    func addOperation(_ key: String, operation: @escaping () async throws -> Void) {
        let task = Task {
            try await operation()
        }
        runningOperations[key] = task
    }

    func waitForAll() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (_, task) in runningOperations {
                group.addTask {
                    try await task.value
                }
            }
            try await group.waitForAll()
        }
        runningOperations.removeAll()
    }

    func cancelAll() {
        for (_, task) in runningOperations {
            task.cancel()
        }
        runningOperations.removeAll()
    }
}
