import SwiftUI
import AVKit
import PryntTrimmerView

// MARK: - Simple Video Trimming View (Native iOS Approach)
/// Clean, native iOS trimming view without complex service layers
struct SimpleVideoTrimmingView: View {
    
    // MARK: - Properties
    let videoURL: URL
    let enhancementType: EnhancementType

    @StateObject private var playerManager: VideoTrimmingPlayerManager
    private let videoProcessingService = VideoProcessingService()
    
    @Environment(\.dismiss) private var dismiss
    @State private var navigateToEnhancement = false
    @State private var trimStartTime: Double = 0
    @State private var trimEndTime: Double = 30
    @State private var selectedDuration: TimePreset = .thirtySeconds
    @State private var videoDuration: Double = 0
    @State private var thumbnails: [UIImage] = []
    @State private var isLoadingThumbnails = false
    
    // PryntTrimmerView states
    @State private var startTimeCMTime: CMTime = .zero
    @State private var endTimeCMTime: CMTime = CMTime(seconds: 30, preferredTimescale: 600)
    @State private var currentTimeCMTime: CMTime? = nil
    @State private var videoAsset: AVAsset?
    
    // Note: Direct player control will be handled through proper SwiftUI patterns
    
    // MARK: - Initialization
    init(videoURL: URL, enhancementType: EnhancementType) {
        self.videoURL = videoURL
        self.enhancementType = enhancementType
        self._playerManager = StateObject(wrappedValue: VideoTrimmingPlayerManager(videoURL: videoURL))
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
    
    // MARK: - Body
    var body: some View {
        ZStack {
            Color.primarySoft
                .ignoresSafeArea()
            
            contentView
        }
        .navigationBarBackButtonHidden()
        .navigationBarItems(
            leading: BackButton { dismiss() },
            trailing: HStack(spacing: 16) {
                StepIndicator(currentStep: 2, totalSteps: 4)
                CloseButton { dismiss() }
            }
        )
        .onAppear {
            setupInitialValues()
        }
        .fullScreenCover(isPresented: $navigateToEnhancement) {
            NavigationView {
                RefactoredEnhancementSelectionView(
                    videoURL: videoURL,
                    enhancementType: enhancementType,
                    trimStartTime: trimStartTime,
                    trimEndTime: trimEndTime
                )
            }
        }
    }
    
    // MARK: - Content View
    private var contentView: some View {
        VStack(spacing: 0) {
            // Video Preview Section
            VStack(spacing: 16) {
                ZStack {
                    SimpleVideoPlayerView(videoURL: videoURL, playerManager: playerManager)
                        .frame(height: DynamicScaling.videoHeight(for: DynamicScaling.currentDeviceSize()))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.accentWarm.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
                        .onAppear {
                            // Player setup happens automatically in SimpleVideoPlayerView
                        }
                    
                    // Video Change Button
                    VStack {
                        HStack {
                            Spacer()
                            
                            Button(action: {
                                // Handle change video functionality
                                HapticFeedbackManager.impact(.light)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .dynamicFont(14, weight: .medium)
                                    
                                    Text("Change")
                                        .dynamicFont(14, weight: .semibold)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(LinearGradient.primaryTheme.opacity(0.9))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                )
                                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
                            }
                        }
                        .padding(.trailing, 32)
                        .padding(.top, 16)
                        
                        Spacer()
                    }
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)
            
            // Video Info Section
            videoInfoSection
                .padding(.vertical, 20)
            
            Spacer()
            
            // Video Controls Section
            videoControlsSection
                .padding(.bottom, 40)
        }
    }
    
    // MARK: - Video Info Section
    private var videoInfoSection: some View {
        HStack {
            InfoCardItem(
                icon: "scissors",
                title: "Selected Duration",
                value: trimmedDurationFormatted,
                alignment: .leading
            )
            
            Spacer()
            
            InfoCardItem(
                icon: "clock",
                title: "Total Duration",
                value: totalDurationFormatted,
                alignment: .trailing
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.accentWarm.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.accentWarm.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Video Controls Section
    private var videoControlsSection: some View {
        VStack(spacing: 30) {
            // Time Preset Buttons
            timePresetButtons
                .padding(.horizontal, 20)
            
            // Trimming Slider (simplified - will need to be implemented)
            videoTrimmingSlider
                .frame(height: 60)
                .padding(.horizontal, 20)
            
            // Continue Button
            continueButton
                .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Time Preset Buttons
    private var timePresetButtons: some View {
        HStack(spacing: 16) {
            ForEach(TimePreset.allCases, id: \.title) { preset in
                Button(action: {
                    HapticFeedbackManager.impact(.light)
                    updateTrimForPreset(preset)
                }) {
                    Text(preset.title)
                        .dynamicFont(16, weight: .semibold)
                        .foregroundColor(selectedDuration == preset ? .white : .white.opacity(0.8))
                        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                        .frame(width: 80, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedDuration == preset ? 
                                      AnyShapeStyle(LinearGradient.primaryTheme) : 
                                      AnyShapeStyle(Color.accentWarm.opacity(0.15)))
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
        }
    }
    
    // MARK: - Enhanced Video Trimming Slider with PryntTrimmerView
    private var videoTrimmingSlider: some View {
        Group {
            if let asset = videoAsset {
                if isLoadingThumbnails {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentWarm.opacity(0.2))
                        .overlay(
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Generating Thumbnails...")
                                    .dynamicFont(14, weight: .medium)
                                    .foregroundColor(.accentWarm)
                            }
                        )
                } else {
                    PryntTrimmerRepresentable(
                    startTime: $startTimeCMTime,
                    endTime: $endTimeCMTime,
                    currentTime: $currentTimeCMTime,
                    asset: asset,
                    handleColor: .white,
                    mainColor: UIColor(red: 1.0, green: 0.596, blue: 0.329, alpha: 1.0), // Orange theme
                    positionBarColor: .white,
                    backgroundColor: UIColor.black.withAlphaComponent(0.3),
                    thumbnails: thumbnails,
                    playerManager: playerManager,
                    onPositionChanged: { time in
                        // Handle position scrubbing
                        HapticFeedbackManager.impact(.light)
                    },
                    onPositionStoppedMoving: { time in
                        // Handle scrubbing end
                        HapticFeedbackManager.impact(.medium)
                    },
                    onTrimChanged: { startTime, endTime in
                        // Update our state when trim changes
                        trimStartTime = startTime.seconds
                        trimEndTime = endTime.seconds
                        
                        // Update preset selection based on duration
                        let duration = endTime.seconds - startTime.seconds
                        if abs(duration - TimePreset.thirtySeconds.duration) < 1.0 {
                            selectedDuration = .thirtySeconds
                        } else if abs(duration - TimePreset.fiveMinutes.duration) < 1.0 {
                            selectedDuration = .fiveMinutes
                        }
                        
                        HapticFeedbackManager.impact(.light)
                    },
                    onEditingBegan: {
                        HapticFeedbackManager.impact(.light)
                    },
                    onEditingEnded: {
                        HapticFeedbackManager.impact(.medium)
                    }
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.accentWarm.opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                }
            } else {
                // Fallback loading state
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentWarm.opacity(0.2))
                    .overlay(
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading Trimmer...")
                                .dynamicFont(14, weight: .medium)
                                .foregroundColor(.accentWarm)
                        }
                    )
            }
        }
    }
    
    // MARK: - Continue Button
    private var continueButton: some View {
        Button(action: {
            HapticFeedbackManager.impact(.medium)
            navigateToEnhancement = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: enhancementType.icon)
                    .dynamicFont(20, weight: .medium)
                
                Text("Continue to \(enhancementType.title)")
                    .dynamicFont(18, weight: .semibold)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
            }
        }
        .buttonStyle(FloatingActionButtonStyle())
        .disabled(!canProceed)
        .opacity(canProceed ? 1.0 : 0.7)
    }
    
    // MARK: - Helper Methods
    private func setupInitialValues() {
        // Load video duration from URL using AVAsset
        Task {
            do {
                let asset = AVAsset(url: videoURL)

                // Set the asset for PryntTrimmerView
                await MainActor.run {
                    self.videoAsset = asset
                }

                if #available(iOS 16.0, *) {
                    let duration = try await asset.load(.duration)
                    await MainActor.run {
                        self.videoDuration = duration.seconds
                        self.trimEndTime = min(selectedDuration.duration, duration.seconds)

                        // Initialize CMTime values
                        self.startTimeCMTime = .zero
                        self.endTimeCMTime = CMTime(seconds: min(selectedDuration.duration, duration.seconds), preferredTimescale: 600)
                        self.playerManager.setTrimRange(start: self.startTimeCMTime, end: self.endTimeCMTime)
                    }
                } else {
                    // iOS 15 compatible
                    let duration = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CMTime, Error>) in
                        asset.loadValuesAsynchronously(forKeys: ["duration"]) {
                            var error: NSError?
                            let status = asset.statusOfValue(forKey: "duration", error: &error)
                            if let error = error {
                                continuation.resume(throwing: error)
                            } else if status == .loaded {
                                continuation.resume(returning: asset.duration)
                            } else {
                                continuation.resume(throwing: NSError(domain: "VideoTrimmingError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load duration"]))
                            }
                        }
                    }
                    await MainActor.run {
                        self.videoDuration = duration.seconds
                        self.trimEndTime = min(selectedDuration.duration, duration.seconds)

                        // Initialize CMTime values
                        self.startTimeCMTime = .zero
                        self.endTimeCMTime = CMTime(seconds: min(selectedDuration.duration, duration.seconds), preferredTimescale: 600)
                        self.playerManager.setTrimRange(start: self.startTimeCMTime, end: self.endTimeCMTime)
                    }
                }

                // Observe player time updates to sync position bar
                playerManager.onPositionChange = { time in
                    self.currentTimeCMTime = time
                }

                // Generate thumbnails
                await generateThumbnails()

            } catch {
                print("❌ Failed to load video duration: \(error)")
            }
        }
    }

    private func generateThumbnails() async {
        isLoadingThumbnails = true
        do {
            let thumbs = try await videoProcessingService.generateThumbnails(for: videoURL, count: 10, quality: .medium)
            await MainActor.run {
                self.thumbnails = thumbs
                self.isLoadingThumbnails = false
            }
        } catch {
            await MainActor.run { self.isLoadingThumbnails = false }
            print("❌ Thumbnail generation failed: \(error)")
        }
    }
    
    private func updateTrimForPreset(_ preset: TimePreset) {
        selectedDuration = preset
        trimStartTime = 0
        trimEndTime = min(preset.duration, videoDuration)
        
        // Update CMTime values for PryntTrimmerView
        startTimeCMTime = .zero
        endTimeCMTime = CMTime(seconds: min(preset.duration, videoDuration), preferredTimescale: 600)
        playerManager.setTrimRange(start: startTimeCMTime, end: endTimeCMTime)
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        SimpleVideoTrimmingView(
            videoURL: URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!,
            enhancementType: EnhancementType.mockAIUpscale
        )
    }
}
