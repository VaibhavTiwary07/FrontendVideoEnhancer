import SwiftUI
import Combine
import AVKit
import PhotosUI

// MARK: - Refactored Video Trimming View
/// Clean, MVVM-focused view following Single Responsibility Principle
struct RefactoredVideoTrimmingView: View {
    @State private var resolutionText: String = "—"
    @State private var sizeText: String = "—"
    @State private var showingVideoPicker = false
    
    // MARK: - Dependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(\.diContainer) private var container
    @StateObject private var viewModel: VideoTrimmingViewModel
    
    // MARK: - State
    @State private var navigateToEnhancement = false
    @State private var isShowingPaywall = false
    @Environment(\.horizontalSizeClass) private var hSize
    private var isIPad: Bool { hSize == .regular }
    
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { navigationToolbar }
        // If a global go-home is requested, dismiss this screen too
        .onReceive(NotificationCenter.default.publisher(for: .goHomeRequested)) { _ in
            dismiss()
        }
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
            .navigationViewStyle(StackNavigationViewStyle())
        }
        .gesture(swipeToGoBackGesture)
        .sheet(isPresented: $showingVideoPicker) {
            UIKitVideoPickerWrapper { newVideoURL in
                // Update video in-place and recompute metadata
                viewModel.replaceVideo(with: newVideoURL)
                computeMetadata()
            }
        }
        .fullScreenCover(isPresented: $isShowingPaywall) {
            PaywallView(isPresented: $isShowingPaywall)
        }
    }
    
    // MARK: - Content Views
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            VStack(spacing: isIPad ? 12 : 0) {
                VideoPreviewSection(
                    playerViewModel: viewModel.playerViewModel,
                    enhancementType: viewModel.enhancementType,
                    onChangeVideo: { showingVideoPicker = true },
                    preferredHeightIPad: 560
                )
                .padding(.top, isIPad ? 36 : (DeviceSize.isSmallPhone ? 16 : 20))

                VideoInfoSection(
                    totalDuration: viewModel.totalDurationFormatted,
                    resolution: resolutionText,
                    size: sizeText
                )
                .padding(.top, isIPad ? 16 : (DeviceSize.isSmallPhone ? 10 : 12))

                // Controls
                VideoControlsSection(
                    viewModel: viewModel,
                    onContinue: { navigateToEnhancement = true },
                    onRequirePaywall: { isShowingPaywall = true },
                    showContinueButton: !isIPad
                )
                .padding(.top, isIPad ? 24 : (DeviceSize.isSmallPhone ? 14 : 20))
                .padding(.bottom, isIPad ? 120 : (DeviceSize.isSmallPhone ? 48 : 40))
            }
            .frame(maxWidth: .infinity)
        }
        .overlay(alignment: .bottom) {
            if isIPad {
                ContinueButton(
                    enhancementType: viewModel.enhancementType,
                    canProceed: viewModel.canProceed,
                    onContinue: {
                        print("🎬 RefactoredVideoTrimmingView - Continuing with trim: \(viewModel.trimStartTime) to \(viewModel.trimEndTime)")
                        navigateToEnhancement = true
                    }
                )
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
        }
    }
    
    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var navigationToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            BackButton { dismiss() }
        }

        ToolbarItem(placement: .principal) {
            Text("Trim for \(viewModel.enhancementType.title)")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.accentWarm)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            CloseButton { dismiss() }
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
        computeMetadata()
    }
    
    private func handleViewDisappearance() {
        viewModel.cleanup()
    }

    private func computeMetadata() {
        let url = viewModel.videoURL
        let asset = AVAsset(url: url)
        // Resolution
        if let track = asset.tracks(withMediaType: .video).first {
            var size = track.naturalSize
            let transform = track.preferredTransform
            let rotated = abs(transform.b) > 0.0001 && abs(transform.c) > 0.0001
            if rotated { size = CGSize(width: size.height, height: size.width) }
            resolutionText = "\(Int(size.width))×\(Int(size.height))"
        } else {
            resolutionText = "—"
        }
        // File size (best effort)
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            if let bytes = attrs[.size] as? NSNumber {
                let mb = Double(truncating: bytes) / (1024.0 * 1024.0)
                sizeText = String(format: "%.1f MB", mb)
            } else {
                sizeText = "—"
            }
        } catch {
            sizeText = "—"
        }
    }
}

// MARK: - Video Preview Section
struct VideoPreviewSection: View {
    let playerViewModel: VideoPlayerViewModel
    let enhancementType: EnhancementType
    let onChangeVideo: (() -> Void)?
    let preferredHeightIPad: CGFloat?
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        VStack(spacing: 16) {
            VideoPlayerView(playerViewModel: playerViewModel)
                .frame(height: isIPad ? (preferredHeightIPad ?? 560) : (DeviceSize.isSmallPhone ? 260 : 340))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.accentWarm.opacity(0.2), lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    if let onChangeVideo {
                        VideoChangeButton { onChangeVideo() }
                            .padding(.trailing, 24)
                            .padding(.top, 12)
                    }
                }
                .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
                .padding(.horizontal, 20)
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
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Video Info Section
struct VideoInfoSection: View {
    let totalDuration: String
    let resolution: String
    let size: String
    @Environment(\.horizontalSizeClass) private var hSize
    private var isIPad: Bool { hSize == .regular }
    
    var body: some View {
        HStack(spacing: 16) {
            // Size
            VStack(spacing: 2) {
                Image(systemName: "internaldrive")
                    .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(size)
                    .font(.system(size: isIPad ? 20 : 16, weight: .bold))
                    .foregroundColor(.accentWarm)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                
                Text("Size")
                    .font(.system(size: isIPad ? 12 : 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
                .frame(height: 44)
            
            // Total Duration
            VStack(spacing: 2) {
                Image(systemName: "clock")
                    .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(totalDuration)
                    .font(.system(size: isIPad ? 20 : 16, weight: .bold))
                    .foregroundColor(.accentWarm)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                
                Text("Total Duration")
                    .font(.system(size: isIPad ? 12 : 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
                .frame(height: 44)
            
            // Resolution
            VStack(spacing: 2) {
                Image(systemName: "rectangle.expand.vertical")
                    .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(resolution)
                    .font(.system(size: isIPad ? 20 : 16, weight: .bold))
                    .foregroundColor(.accentWarm)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                
                Text("Resolution")
                    .font(.system(size: isIPad ? 12 : 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, isIPad ? 16 : 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.accentWarm.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.accentWarm.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.2), radius: isIPad ? 8 : 6, x: 0, y: 3)
        .padding(.horizontal, 20)
    }
}

// MARK: - Video Info Card (removed duplicate - using Components/VideoInfoCard.swift version)

// MARK: - Video Controls Section
struct VideoControlsSection: View {
    @ObservedObject var viewModel: VideoTrimmingViewModel
    let onContinue: () -> Void
    let onRequirePaywall: (() -> Void)?
    var showContinueButton: Bool = true
    
    var body: some View {
        VStack(spacing: 30) {
            TimePresetButtons(
                selectedDuration: viewModel.selectedDuration,
                onPresetSelected: viewModel.updateTrimForPreset,
                onRequirePaywall: onRequirePaywall
            )
            .padding(.horizontal, 20)
            
            VideoTrimmingSliderView(
                startTime: $viewModel.trimStartTime,
                endTime: $viewModel.trimEndTime,
                duration: viewModel.videoDuration,
                thumbnails: viewModel.thumbnails,
                enhancementType: viewModel.enhancementType,
                playerViewModel: viewModel.playerViewModel
            )
            .frame(height: 60)
            .padding(.horizontal, 20)
            
            if showContinueButton {
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
}

// MARK: - Time Preset Buttons
struct TimePresetButtons: View {
    let selectedDuration: VideoTrimmingViewModel.TimePreset
    let onPresetSelected: (VideoTrimmingViewModel.TimePreset) -> Void
    let onRequirePaywall: (() -> Void)?
    @Environment(\.horizontalSizeClass) private var hSize
    private var isIPad: Bool { hSize == .regular }
    
    var body: some View {
        HStack(spacing: isIPad ? 24 : 16) {
            Spacer()
            
            ForEach(VideoTrimmingViewModel.TimePreset.allCases, id: \.title) { preset in
                let isPro = preset == .fiveMinutes
                TimePresetButton(
                    title: preset.title,
                    isSelected: selectedDuration == preset,
                    showsProBadge: isPro && !SubscriptionManager.shared.isAppSubscribed(),
                    onTap: { onPresetSelected(preset) },
                    onRequirePro: isPro ? {
                        onRequirePaywall?()
                    } : nil
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
    let showsProBadge: Bool
    let onTap: () -> Void
    let onRequirePro: (() -> Void)?
    @Environment(\.horizontalSizeClass) private var hSize
    private var isIPad: Bool { hSize == .regular }
    
    var body: some View {
        Button(action: {
            HapticFeedbackManager.impact(.light)
            if showsProBadge {
                onRequirePro?()
            } else {
                onTap()
            }
        }) {
            Text(title)
                .font(.system(size: isIPad ? 18 : 16, weight: .semibold))
                .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                .frame(width: isIPad ? 110 : 80, height: isIPad ? 48 : 40)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? AnyShapeStyle(LinearGradient.primaryTheme) : AnyShapeStyle(Color.accentWarm.opacity(0.15)))
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                )
                .overlay(alignment: .topTrailing) {
                    if showsProBadge {
                        ProPill()
                            .offset(x: 6, y: -6)
                    }
                }
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
    let playerViewModel: VideoPlayerViewModel
    
    var body: some View {
        VideoTrimmingSlider(
            startTime: $startTime,
            endTime: $endTime,
            duration: duration,
            presetDuration: 30, // Default preset, not used for constraints
            gradientType: enhancementType.gradientType,
            thumbnails: thumbnails
        )
        .onChange(of: startTime) { newValue in
            // Update playback range and seek to the new start for instant preview
            playerViewModel.setPlaybackRange(start: newValue, end: endTime)
            playerViewModel.seek(to: newValue)
        }
        .onChange(of: endTime) { newValue in
            // Update playback range as end changes
            playerViewModel.setPlaybackRange(start: startTime, end: newValue)
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
//                Image(systemName: enhancementType.icon)
//                    .font(.system(size: 20, weight: .medium))
                
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


// MARK: - Pro Badge Component
private struct ProPill: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient.primaryTheme)
            )
            .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
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
