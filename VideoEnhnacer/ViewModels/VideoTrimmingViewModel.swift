import Foundation
import SwiftUI
import Combine
import UIKit

// MARK: - Video Trimming ViewModel
/// MVVM ViewModel for video trimming operations following Single Responsibility Principle
@MainActor
final class VideoTrimmingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var trimStartTime: Double = 0
    @Published var trimEndTime: Double = 30
    @Published var selectedDuration: TimePreset = .thirtySeconds
    @Published private(set) var videoDuration: Double = 0
    @Published private(set) var thumbnails: [UIImage] = []
    @Published private(set) var isLoadingVideo: Bool = true
    @Published private(set) var isLoadingThumbnails: Bool = false
    @Published private(set) var error: VideoProcessingError?

    // Combined loading state - single source of truth to prevent flickering
    @Published private(set) var isLoading: Bool = true

    // MARK: - Private Properties
    private let videoProcessingService: VideoProcessingProtocol
    let playerViewModel: VideoPlayerViewModel
    private var cancellables = Set<AnyCancellable>()
    private var loadingTask: Task<Void, Never>?
    
    // MARK: - Public Properties
    @Published private(set) var videoURL: URL
    let enhancementType: EnhancementType
    
    // MARK: - Computed Properties
    var selectedDurationValue: Double {
        trimEndTime - trimStartTime
    }
    
    var canProceed: Bool {
        videoDuration > 0 && trimEndTime > trimStartTime
    }
    
    var trimmedDurationFormatted: String {
        formatDuration(selectedDurationValue)
    }
    
    var totalDurationFormatted: String {
        formatDuration(videoDuration)
    }

    // Memory-aware loading for small devices
    private var isSmallDevice: Bool {
        // Check if device has limited memory (iPod, iPhone SE, or < 3GB RAM)
        return DeviceSize.isSmallPhone ||
               ProcessInfo.processInfo.physicalMemory < 3_000_000_000
    }

    // MARK: - Time Presets
    enum TimePreset: CaseIterable {
        case thirtySeconds, fiveMinutes
        
        var duration: Double {
            switch self {
            case .thirtySeconds: return 30
            case .fiveMinutes: return 300
            }
        }
        
        var title: String {
            switch self {
            case .thirtySeconds: return "30s"
            case .fiveMinutes: return "5min"
            }
        }
    }
    
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
        setupBindings()
    }
    
    // MARK: - Public Methods
    func loadVideo() {
        TrimmingDiagnostics.log("🎬 [VideoTrimmingViewModel] loadVideo() called")
        loadingTask = Task {
            await performVideoLoading()
        }
    }

    var isAlreadyLoaded: Bool {
        videoDuration > 0 && !thumbnails.isEmpty && error == nil
    }

    func updateTrimForPreset(_ preset: TimePreset) {
        TrimmingDiagnostics.log("⏱️ [VideoTrimmingViewModel] Preset selected: \(preset.title) (\(preset.duration)s)")
        selectedDuration = preset
        applyPresetDuration(preset)
    }
    
    func updateTrimTimes(start: Double, end: Double) {
        let clampedStart = max(0, min(start, videoDuration))
        let clampedEnd = max(clampedStart + 1.0, min(end, videoDuration))

        trimStartTime = clampedStart
        trimEndTime = clampedEnd

        TrimmingDiagnostics.log("🎯 [VideoTrimmingViewModel] updateTrimTimes: start=\(clampedStart)s end=\(clampedEnd)s duration=\(clampedEnd - clampedStart)s")

        // Auto-select preset based on duration
        let duration = clampedEnd - clampedStart
        if duration > 30 {
            selectedDuration = .fiveMinutes
        } else {
            selectedDuration = .thirtySeconds
        }

        // Update player trim range
        playerViewModel.setPlaybackRange(start: clampedStart, end: clampedEnd)

        // Seek to start time
        playerViewModel.seek(to: clampedStart)

    }
    
    func seekToStartTime() {
        playerViewModel.seek(to: trimStartTime)
        playerViewModel.play()
    }
    
    func retryLoading() {
        TrimmingDiagnostics.log("🔄 [VideoTrimmingViewModel] Retrying video load after error")
        error = nil
        loadVideo()
    }
    
    func replaceVideo(with newURL: URL) {
        TrimmingDiagnostics.log("🔄 [VideoTrimmingViewModel] Replacing video with: \(newURL.lastPathComponent)")
        logToFile("🔄 [VideoTrimmingViewModel] replaceVideo called")
        logToFile("🔄 [VideoTrimmingViewModel] New URL: \(newURL.path)")
        logToFile("🔄 [VideoTrimmingViewModel] Old URL: \(videoURL.path)")

        // Reset state and load new video
        logToFile("🔄 [VideoTrimmingViewModel] Calling trimmingReset()...")
        trimmingReset()
        logToFile("🔄 [VideoTrimmingViewModel] trimmingReset() completed")

        logToFile("🔄 [VideoTrimmingViewModel] Setting videoURL to new URL...")
        videoURL = newURL
        logToFile("🔄 [VideoTrimmingViewModel] videoURL updated")

        logToFile("🔄 [VideoTrimmingViewModel] Calling loadVideo()...")
        loadVideo()
        logToFile("🔄 [VideoTrimmingViewModel] loadVideo() called (async loading will continue)")
    }

    private func logToFile(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)"

        print(logMessage)

        let projectLogFile = URL(fileURLWithPath: "/home/user/FrontendVideoEnhancer/video_selection_debug.log")
        if let data = (logMessage + "\n").data(using: .utf8) {
            if FileManager.default.fileExists(atPath: projectLogFile.path) {
                if let fileHandle = try? FileHandle(forWritingTo: projectLogFile) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: projectLogFile)
            }
        }
    }

    func cleanup() {
        TrimmingDiagnostics.log("🧹 [VideoTrimmingViewModel] Cleaning up (cancelling tasks, player, subscriptions)")
        loadingTask?.cancel()
        playerViewModel.cleanup()
        cancellables.removeAll()
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        // Update player when trim times change
        Publishers.CombineLatest($trimStartTime, $trimEndTime)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] start, end in
                self?.playerViewModel.setPlaybackRange(start: start, end: end)
            }
            .store(in: &cancellables)
        
        // Handle player errors
        playerViewModel.$error
            .compactMap { $0 }
            .sink { [weak self] playerError in
                self?.error = VideoProcessingError.processingFailed(playerError.localizedDescription)
            }
            .store(in: &cancellables)
    }
    
    private func performVideoLoading() async {
        TrimmingDiagnostics.log("⏳ [VideoTrimmingViewModel] performVideoLoading() started")
        LoadingDebugLogger.shared.log("📹 START LOADING: Setting isLoading=true, isLoadingVideo=true - Reason: performVideoLoading() called")

        // Set BOTH loading states at start - single source of truth
        await MainActor.run {
            // Only update if different - prevents redundant state changes
            if isLoading != true { isLoading = true }
            if isLoadingVideo != true { isLoadingVideo = true }
            if error != nil { error = nil }
        }

        do {
            TrimmingDiagnostics.log("📹 [VideoTrimmingViewModel] Getting video info from: \(videoURL.lastPathComponent)")
            // Load video information
            let videoInfo = try await videoProcessingService.getVideoInfo(from: videoURL)
            TrimmingDiagnostics.log("✅ [VideoTrimmingViewModel] Video info loaded - duration: \(videoInfo.duration)s")

            await MainActor.run {
                self.videoDuration = videoInfo.duration
                self.trimEndTime = min(selectedDuration.duration, videoInfo.duration)
            }

            // Memory-aware loading: sequential for small devices, parallel for large devices
            if isSmallDevice {
                TrimmingDiagnostics.log("📱 [VideoTrimmingViewModel] Small device detected - using sequential loading")
                // Sequential loading reduces memory pressure on iPod/iPhone SE
                await setupVideoPlayers()

                // Small delay to let memory stabilize before thumbnails
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

                await generateThumbnails()

                // Ensure minimum loading time to prevent flash on slow devices
                try? await Task.sleep(nanoseconds: 200_000_000) // Additional 200ms
            } else {
                TrimmingDiagnostics.log("📱 [VideoTrimmingViewModel] Large device detected - using parallel loading")
                // Parallel loading for better performance on devices with adequate RAM
                async let players = setupVideoPlayers()
                async let thumbs = generateThumbnails()

                await players
                await thumbs
            }

            TrimmingDiagnostics.log("✅ [VideoTrimmingViewModel] All loading complete - setting isLoading=false")
            LoadingDebugLogger.shared.log("✅ END LOADING: Setting isLoading=false, isLoadingVideo=false - Reason: All operations complete (duration:\(self.videoDuration)s, thumbnails:\(self.thumbnails.count))")

            // ALL async operations complete - now update state atomically
            await MainActor.run {
                // Only update if different - prevents redundant state changes
                if self.isLoadingVideo != false { self.isLoadingVideo = false }
                if self.isLoading != false { self.isLoading = false }  // Only set false when EVERYTHING is done
            }

        } catch let processingError as VideoProcessingError {
            TrimmingDiagnostics.log("❌ [VideoTrimmingViewModel] Video processing error: \(processingError.localizedDescription)")
            await MainActor.run {
                self.error = processingError
                if self.isLoadingVideo != false { self.isLoadingVideo = false }
                if self.isLoading != false { self.isLoading = false }
            }
        } catch {
            TrimmingDiagnostics.log("❌ [VideoTrimmingViewModel] Unexpected error: \(error.localizedDescription)")
            await MainActor.run {
                self.error = VideoProcessingError.processingFailed(error.localizedDescription)
                if self.isLoadingVideo != false { self.isLoadingVideo = false }
                if self.isLoading != false { self.isLoading = false }
            }
        }
    }
    
    private func setupVideoPlayers() async {
        TrimmingDiagnostics.log("🎥 [VideoTrimmingViewModel] Setting up video players")
        // Use direct file URLs so trimming works with user-selected videos
        await MainActor.run {
            playerViewModel.setupPlayers(originalURL: videoURL, enhancedURL: videoURL)
        }

        // Wait a brief moment to allow player setup to initialize
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        TrimmingDiagnostics.log("✅ [VideoTrimmingViewModel] Video players setup complete")
    }
    
    private func generateThumbnails() async {
        if isLoadingThumbnails != true { isLoadingThumbnails = true }

        // Memory optimization: reduce thumbnail count and quality on small devices
        let thumbnailCount = isSmallDevice ? 6 : 10
        let thumbnailQuality: ThumbnailQuality = isSmallDevice ? .low : .medium

        TrimmingDiagnostics.log("🖼️ [VideoTrimmingViewModel] Generating \(thumbnailCount) thumbnails at \(thumbnailQuality) quality")

        do {
            let generatedThumbnails = try await videoProcessingService.generateThumbnails(
                for: videoURL,
                count: thumbnailCount,
                quality: thumbnailQuality
            )

            await MainActor.run {
                self.thumbnails = generatedThumbnails
                if self.isLoadingThumbnails != false { self.isLoadingThumbnails = false }
            }

            TrimmingDiagnostics.log("✅ [VideoTrimmingViewModel] Generated \(generatedThumbnails.count) thumbnails")

        } catch {
            TrimmingDiagnostics.log("⚠️ [VideoTrimmingViewModel] Thumbnail generation failed: \(error.localizedDescription)")
            await MainActor.run {
                if self.isLoadingThumbnails != false { self.isLoadingThumbnails = false }
                // Don't treat thumbnail failure as a critical error
            }
        }
    }
    
    private func applyPresetDuration(_ preset: TimePreset) {
        let newEndTime = min(trimStartTime + preset.duration, videoDuration)

        // If preset would go beyond video end, adjust start time
        if newEndTime >= videoDuration {
            trimStartTime = max(0, videoDuration - preset.duration)
            trimEndTime = videoDuration
        } else {
            trimEndTime = newEndTime
        }

        TrimmingDiagnostics.log("✂️ [VideoTrimmingViewModel] Applied preset - start: \(trimStartTime)s, end: \(trimEndTime)s")

        // Update player
        playerViewModel.setPlaybackRange(start: trimStartTime, end: trimEndTime)
        playerViewModel.seek(to: trimStartTime)
    }

    private func trimmingReset() {
        trimStartTime = 0
        trimEndTime = 30
        selectedDuration = .thirtySeconds
        videoDuration = 0
        thumbnails = []
        isLoadingVideo = false
        isLoadingThumbnails = false
        error = nil
        playerViewModel.cleanup()
    }
    
    private func formatDuration(_ timeInSeconds: Double) -> String {
        if timeInSeconds < 60 {
            return String(format: "%.0fs", timeInSeconds)
        } else {
            let minutes = Int(timeInSeconds) / 60
            let seconds = Int(timeInSeconds) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    // MARK: - Cleanup
    deinit {
        loadingTask?.cancel()
        cancellables.removeAll()
    }
}

// MARK: - Preview Support
//#if DEBUG
//extension VideoTrimmingViewModel {
//    static var preview: VideoTrimmingViewModel {
//        VideoTrimmingViewModel(
//            videoURL: URL(string: "https://example.com/video.mp4")!,
//            enhancementType: EnhancementType.mockAIUpscale,
//            videoProcessingService: MockVideoProcessingService(),
//            playerViewModel: VideoPlayerViewModel.preview
//        )
//    }
//}
//#endif
