import SwiftUI
import AVKit

// MARK: - Enhanced Video Trimming View
/// Updated trimming view using PryntTrimmerRepresentable for a unified experience
struct EnhancedVideoTrimmingView: View {
    
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
        .navigationBarItems(
            leading: BackButton { dismiss() },
            trailing: HStack(spacing: 16) {
                StepIndicator(currentStep: 2, totalSteps: 4)
                CloseButton { dismiss() }
            }
        )
        .onAppear { handleViewAppearance() }
        .onDisappear { handleViewDisappearance() }
        .fullScreenCover(isPresented: $navigateToEnhancement) {
            NavigationView {
                RefactoredEnhancementSelectionView(
                    videoURL: viewModel.videoURL,
                    enhancementType: viewModel.enhancementType,
                    trimStartTime: viewModel.trimStartTime,
                    trimEndTime: viewModel.trimEndTime
                )
            }
        }
        .gesture(swipeToGoBackGesture)
    }
    
    // MARK: - Content Views
    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 0) {
            SimpleVideoPreviewSection(
                videoURL: viewModel.videoURL,
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
        print("🎬 EnhancedVideoTrimmingView - Appeared for \(viewModel.enhancementType.title)")
    }
    
    private func handleViewDisappearance() {
        viewModel.cleanup()
    }
}

// MARK: - Simple Video Preview Section (Native iOS)
struct SimpleVideoPreviewSection: View {
    let videoURL: URL
    let enhancementType: EnhancementType
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                SimpleVideoPlayerView(videoURL: videoURL)
                    .deviceOptimizedVideoHeight()
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


// MARK: - Placeholder components are now in AspectRatioVideoPlayer.swift to avoid duplication

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
            
            PryntTrimmerSliderView(viewModel: viewModel)
                .frame(height: 60)
                .padding(.horizontal, 20)
            
            ContinueButton(
                enhancementType: viewModel.enhancementType,
                canProceed: viewModel.canProceed,
                onContinue: {
                    print("🎬 EnhancedVideoTrimmingView - Continuing with trim: \(viewModel.trimStartTime) to \(viewModel.trimEndTime)")
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
struct PryntTrimmerSliderView: View {
    @ObservedObject var viewModel: VideoTrimmingViewModel

    var body: some View {
        let asset = AVAsset(url: viewModel.videoURL)
        let startBinding = Binding<CMTime>(
            get: { CMTime(seconds: viewModel.trimStartTime, preferredTimescale: 600) },
            set: { viewModel.updateTrimTimes(start: $0.seconds, end: viewModel.trimEndTime) }
        )
        let endBinding = Binding<CMTime>(
            get: { CMTime(seconds: viewModel.trimEndTime, preferredTimescale: 600) },
            set: { viewModel.updateTrimTimes(start: viewModel.trimStartTime, end: $0.seconds) }
        )
        let currentBinding = Binding<CMTime?>(
            get: { CMTime(seconds: viewModel.currentTime, preferredTimescale: 600) },
            set: { time in viewModel.playerViewModel.seek(to: time?.seconds ?? 0) }
        )

        return PryntTrimmerRepresentable(
            startTime: startBinding,
            endTime: endBinding,
            currentTime: currentBinding,
            asset: asset,
            thumbnails: viewModel.thumbnails,
            playerManager: nil
        )
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
struct EnhancedVideoTrimmingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EnhancedVideoTrimmingView(
                videoURL: URL(string: "https://example.com/video.mp4")!,
                enhancementType: EnhancementType.mockAIUpscale
            )
        }
        .withDependencyInjection()
    }
}
#endif