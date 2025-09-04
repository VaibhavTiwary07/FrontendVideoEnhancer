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
    @Published private(set) var isLoadingVideo: Bool = false
    @Published private(set) var isLoadingThumbnails: Bool = false
    @Published private(set) var error: VideoProcessingError?
    
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
        loadingTask = Task {
            await performVideoLoading()
        }
    }
    
    func updateTrimForPreset(_ preset: TimePreset) {
        selectedDuration = preset
        applyPresetDuration(preset)
    }
    
    func updateTrimTimes(start: Double, end: Double) {
        let clampedStart = max(0, min(start, videoDuration))
        let clampedEnd = max(clampedStart + 1.0, min(end, videoDuration))
        
        trimStartTime = clampedStart
        trimEndTime = clampedEnd
        
        // Update player trim range
        playerViewModel.setPlaybackRange(start: clampedStart, end: clampedEnd)
        
        // Seek to start time
        playerViewModel.seek(to: clampedStart)
        
        print("🎬 VideoTrimmingViewModel - Updated trim: \(clampedStart) to \(clampedEnd)")
    }
    
    func seekToStartTime() {
        playerViewModel.seek(to: trimStartTime)
        playerViewModel.play()
    }
    
    func retryLoading() {
        error = nil
        loadVideo()
    }
    
    func replaceVideo(with newURL: URL) {
        // Reset state and load new video
        trimmingReset()
        videoURL = newURL
        loadVideo()
    }
    
    func cleanup() {
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
        isLoadingVideo = true
        error = nil
        
        do {
            // Load video information
            let videoInfo = try await videoProcessingService.getVideoInfo(from: videoURL)
            
            await MainActor.run {
                self.videoDuration = videoInfo.duration
                self.trimEndTime = min(selectedDuration.duration, videoInfo.duration)
                print("🎬 VideoTrimmingViewModel - Loaded video: duration=\(videoInfo.duration)")
            }
            
            // Setup video players
            await setupVideoPlayers()
            
            // Generate thumbnails
            await generateThumbnails()
            
            await MainActor.run {
                self.isLoadingVideo = false
            }
            
        } catch let processingError as VideoProcessingError {
            await MainActor.run {
                self.error = processingError
                self.isLoadingVideo = false
            }
        } catch {
            await MainActor.run {
                self.error = VideoProcessingError.processingFailed(error.localizedDescription)
                self.isLoadingVideo = false
            }
        }
    }
    
    private func setupVideoPlayers() async {
        // Use direct file URLs so trimming works with user-selected videos
        playerViewModel.setupPlayers(originalURL: videoURL, enhancedURL: videoURL)
    }
    
    private func generateThumbnails() async {
        isLoadingThumbnails = true
        
        do {
            let generatedThumbnails = try await videoProcessingService.generateThumbnails(
                for: videoURL,
                count: 10,
                quality: .medium
            )
            
            await MainActor.run {
                self.thumbnails = generatedThumbnails
                self.isLoadingThumbnails = false
                print("🎬 VideoTrimmingViewModel - Generated \(generatedThumbnails.count) thumbnails")
            }
            
        } catch {
            await MainActor.run {
                self.isLoadingThumbnails = false
                print("🎬 VideoTrimmingViewModel - Thumbnail generation failed: \(error.localizedDescription)")
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
        
        // Update player
        playerViewModel.setPlaybackRange(start: trimStartTime, end: trimEndTime)
        playerViewModel.seek(to: trimStartTime)
        
        print("🎬 VideoTrimmingViewModel - Applied preset \(preset.title): \(trimStartTime) to \(trimEndTime)")
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
    //MARK: - VT
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
