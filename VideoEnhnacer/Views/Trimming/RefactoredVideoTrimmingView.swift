import SwiftUI
import AVKit

// MARK: - Refactored Video Trimming View
/// Clean, MVVM-focused view following Single Responsibility Principle
struct RefactoredVideoTrimmingView: View {
    
    // MARK: - Dependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(\.diContainer) private var container
    @StateObject private var viewModel: VideoTrimmingViewModel
    
    // MARK: - State
    @State private var navigateToEnhancement = false
    
    // MARK: - Initialization
    init(videoURL: URL, enhancementType: EnhancementType) {
        let container = DIContainer.shared
        let trimmingViewModel = container.makeVideoTrimmingViewModel(
            videoURL: videoURL,
            enhancementType: enhancementType
        )
        self._viewModel = StateObject(wrappedValue: trimmingViewModel)
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            Color.primarySoft
                .ignoresSafeArea()
            
            if viewModel.isLoadingVideo {
                VideoLoadingView()
            } else if let error = viewModel.error {
                VideoErrorView(error: error) {
                    viewModel.retryLoading()
                }
            } else {
                contentView
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar { navigationToolbar }
        .onAppear { handleViewAppearance() }
        .onDisappear { handleViewDisappearance() }
        .navigationDestination(isPresented: $navigateToEnhancement) {
            RefactoredEnhancementSelectionView(
                videoURL: viewModel.videoURL,
                enhancementType: viewModel.enhancementType,
                trimStartTime: viewModel.trimStartTime,
                trimEndTime: viewModel.trimEndTime
            )
        }
        .gesture(swipeToGoBackGesture)
    }
    
    // MARK: - Content Views
    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 0) {
            VideoPreviewSection(
                playerViewModel: viewModel.playerViewModel,
                enhancementType: viewModel.enhancementType
            )
            .padding(.top, 20)
            
            VideoInfoSection(
                selectedDuration: viewModel.trimmedDurationFormatted,
                totalDuration: viewModel.totalDurationFormatted
            )
            
            Spacer()
            
            VideoControlsSection(
                viewModel: viewModel,
                onContinue: { navigateToEnhancement = true }
            )
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var navigationToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            BackButton { dismiss() }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 16) {
                StepIndicator(currentStep: 2, totalSteps: 4)
                CloseButton { dismiss() }
            }
        }
    }
    
    // MARK: - Gestures
    private var swipeToGoBackGesture: some Gesture {
        DragGesture()
            .onEnded { value in
                if value.startLocation.x < 50 && value.translation.width > 100 {
                    HapticFeedbackManager.impact(.light)
                    dismiss()
                }
            }
    }
    
    // MARK: - Event Handlers
    private func handleViewAppearance() {
        viewModel.loadVideo()
        print("🎬 RefactoredVideoTrimmingView - Appeared for \(viewModel.enhancementType.title)")
    }
    
    private func handleViewDisappearance() {
        viewModel.cleanup()
    }
}

// MARK: - Video Preview Section
struct VideoPreviewSection: View {
    let playerViewModel: VideoPlayerViewModel
    let enhancementType: EnhancementType
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                VideoPlayerView(playerViewModel: playerViewModel)
                    .frame(height: isIPad ? 400 : 320)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.accentWarm.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
                    .padding(.horizontal, 20)
                
                VideoChangeButton { /* Handle change video */ }
            }
        }
    }
}

// MARK: - Video Player View
struct VideoPlayerView: View {
    @ObservedObject var playerViewModel: VideoPlayerViewModel
    
    var body: some View {
        Group {
            if let player = playerViewModel.normalPlayer {
                VideoPlayer(player: player)
                    .onAppear {
                        playerViewModel.setActive(true)
                        playerViewModel.play()
                    }
                    .onDisappear {
                        playerViewModel.setActive(false)
                    }
            } else if playerViewModel.isLoading {
                VideoLoadingPlaceholder()
            } else if let error = playerViewModel.error {
                VideoErrorPlaceholder(error: error)
            }
        }
    }
}

// MARK: - Video Loading Placeholder
struct VideoLoadingPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.accentWarm.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.accentWarm.opacity(0.2), lineWidth: 1)
            )
            .overlay(
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    
                    Text("Loading Video...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            )
    }
}

// MARK: - Video Error Placeholder
struct VideoErrorPlaceholder: View {
    let error: VideoPlayerError
    
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.red.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
            )
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.red.opacity(0.8))
                    
                    Text("Error Loading Video")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red.opacity(0.8))
                    
                    Text(error.localizedDescription)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.red.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding()
            )
    }
}

// MARK: - Video Change Button
struct VideoChangeButton: View {
    let action: () -> Void
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                Button(action: {
                    HapticFeedbackManager.impact(.light)
                    action()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("Change")
                            .font(.system(size: 14, weight: .semibold))
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

// MARK: - Video Info Section
struct VideoInfoSection: View {
    let selectedDuration: String
    let totalDuration: String
    
    var body: some View {
        HStack {
            InfoCardItem(
                icon: "scissors",
                title: "Selected Duration",
                value: selectedDuration,
                alignment: .leading
            )
            
            Spacer()
            
            InfoCardItem(
                icon: "clock",
                title: "Total Duration",
                value: totalDuration,
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
}

// MARK: - Video Info Card (removed duplicate - using Components/VideoInfoCard.swift version)

// MARK: - Video Controls Section
struct VideoControlsSection: View {
    @ObservedObject var viewModel: VideoTrimmingViewModel
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            TimePresetButtons(
                selectedDuration: viewModel.selectedDuration,
                onPresetSelected: viewModel.updateTrimForPreset
            )
            .padding(.horizontal, 20)
            
            VideoTrimmingSliderView(
                startTime: $viewModel.trimStartTime,
                endTime: $viewModel.trimEndTime,
                duration: viewModel.videoDuration,
                thumbnails: viewModel.thumbnails,
                enhancementType: viewModel.enhancementType
            )
            .frame(height: 60)
            .padding(.horizontal, 20)
            
            ContinueButton(
                enhancementType: viewModel.enhancementType,
                canProceed: viewModel.canProceed,
                onContinue: {
                    print("🎬 RefactoredVideoTrimmingView - Continuing with trim: \(viewModel.trimStartTime) to \(viewModel.trimEndTime)")
                    onContinue()
                }
            )
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Time Preset Buttons
struct TimePresetButtons: View {
    let selectedDuration: VideoTrimmingViewModel.TimePreset
    let onPresetSelected: (VideoTrimmingViewModel.TimePreset) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(VideoTrimmingViewModel.TimePreset.allCases, id: \.title) { preset in
                TimePresetButton(
                    title: preset.title,
                    isSelected: selectedDuration == preset,
                    onTap: { onPresetSelected(preset) }
                )
            }
            
            Spacer()
        }
    }
}

// MARK: - Time Preset Button
struct TimePresetButton: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            HapticFeedbackManager.impact(.light)
            onTap()
        }) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                .frame(width: 80, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? AnyShapeStyle(LinearGradient.primaryTheme) : AnyShapeStyle(Color.accentWarm.opacity(0.15)))
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Video Trimming Slider View
struct VideoTrimmingSliderView: View {
    @Binding var startTime: Double
    @Binding var endTime: Double
    let duration: Double
    let thumbnails: [UIImage]
    let enhancementType: EnhancementType
    
    var body: some View {
        VideoTrimmingSlider(
            startTime: $startTime,
            endTime: $endTime,
            duration: duration,
            presetDuration: 30, // Default preset, not used for constraints
            gradientType: enhancementType.gradientType,
            thumbnails: thumbnails
        )
        .onChange(of: startTime) { _, newValue in
            print("🎚️ RefactoredVideoTrimmingView - Start time changed to: \(newValue)")
        }
        .onChange(of: endTime) { _, newValue in
            print("🎚️ RefactoredVideoTrimmingView - End time changed to: \(newValue)")
        }
    }
}

// MARK: - Continue Button
struct ContinueButton: View {
    let enhancementType: EnhancementType
    let canProceed: Bool
    let onContinue: () -> Void
    
    var body: some View {
        Button(action: {
            HapticFeedbackManager.impact(.medium)
            onContinue()
        }) {
            HStack(spacing: 12) {
                Image(systemName: enhancementType.icon)
                    .font(.system(size: 20, weight: .medium))
                
                Text("Continue to \(enhancementType.title)")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
            }
        }
        .buttonStyle(FloatingActionButtonStyle())
        .disabled(!canProceed)
        .opacity(canProceed ? 1.0 : 0.7)
    }
}

// MARK: - Loading and Error Views (removed duplicate - using SpatialVideoPreview version)

struct VideoErrorView: View {
    let error: VideoProcessingError
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(.red.opacity(0.8))
            
            Text("Error Loading Video")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.red.opacity(0.8))
            
            Text(error.localizedDescription)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.red.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Retry", action: onRetry)
                .buttonStyle(FloatingActionButtonStyle())
        }
        .padding(40)
    }
}

// MARK: - Info Card Item
struct InfoCardItem: View {
    let icon: String
    let title: String
    let value: String
    let alignment: HorizontalAlignment
    
    var body: some View {
        VStack(alignment: alignment, spacing: 6) {
            HStack(spacing: 6) {
                if alignment == .leading {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.accentWarm)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
        }
    }
}

// MARK: - Preview
#if DEBUG
struct RefactoredVideoTrimmingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            RefactoredVideoTrimmingView(
                videoURL: URL(string: "https://example.com/video.mp4")!,
                enhancementType: EnhancementType.mockAIUpscale
            )
        }
        .withDependencyInjection()
    }
}
#endif