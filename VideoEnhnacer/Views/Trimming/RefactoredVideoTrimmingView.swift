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
    
    // MARK: - Callbacks
    private let onBack: (() -> Void)?
    private let onClose: (() -> Void)?
    private let onContinue: ((URL, Double, Double) -> Void)?
    
    // MARK: - Dependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(\.diContainer) private var container
    @StateObject private var viewModel: VideoTrimmingViewModel
    
    // MARK: - State
    @State private var navigateToEnhancement = false
    @State private var isShowingPaywall = false
    @State private var hasStartedLoading = false
    @Environment(\.horizontalSizeClass) private var hSize
    private var isIPad: Bool { hSize == .regular }
    private var isSmallPhone: Bool { DeviceSize.isSmallPhone }
    
    // MARK: - Initialization
    init(
        videoURL: URL,
        enhancementType: EnhancementType,
        onBack: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil,
        onContinue: ((URL, Double, Double) -> Void)? = nil
    ) {
        print("🐞 WHITE_SCREEN_DEBUG: RefactoredVideoTrimmingView.init() - URL: \(videoURL.lastPathComponent), Type: \(enhancementType.name)")
        self.onBack = onBack
        self.onClose = onClose
        self.onContinue = onContinue
        let container = DIContainer.shared
        print("🐞 WHITE_SCREEN_DEBUG: Creating VideoTrimmingViewModel via DIContainer")
        let trimmingViewModel = container.makeVideoTrimmingViewModel(
            videoURL: videoURL,
            enhancementType: enhancementType
        )
        
        // Initialize ViewModels with proper state management
        print("🐞 WHITE_SCREEN_DEBUG: Initializing ViewModels with proper state coordination")
        
        self._viewModel = StateObject(wrappedValue: trimmingViewModel)
        print("🐞 WHITE_SCREEN_DEBUG: RefactoredVideoTrimmingView.init() completed")
        print("🐞 WHITE_SCREEN_DEBUG: - viewModel.isLoadingVideo: \(trimmingViewModel.isLoadingVideo)")
        print("🐞 WHITE_SCREEN_DEBUG: - viewModel.playerViewModel.isLoading: \(trimmingViewModel.playerViewModel.isLoading)")
    }
    
    // MARK: - Body
    var body: some View {
        print("🐞 WHITE_SCREEN_DEBUG: RefactoredVideoTrimmingView.body - Rendering body")
        print("🐞 WHITE_SCREEN_DEBUG: Current states:")
        print("🐞 WHITE_SCREEN_DEBUG: - viewModel.isLoadingVideo: \(viewModel.isLoadingVideo)")
        print("🐞 WHITE_SCREEN_DEBUG: - viewModel.playerViewModel.isLoading: \(viewModel.playerViewModel.isLoading)")
        print("🐞 WHITE_SCREEN_DEBUG: - hasStartedLoading: \(hasStartedLoading)")
        print("🐞 WHITE_SCREEN_DEBUG: - viewModel.error: \(String(describing: viewModel.error))")
        print("🐞 WHITE_SCREEN_DEBUG: - viewModel.playerViewModel.error: \(String(describing: viewModel.playerViewModel.error))")
        
        let shouldShowLoading = viewModel.isLoadingVideo || viewModel.playerViewModel.isLoading
        print("🐞 WHITE_SCREEN_DEBUG: shouldShowLoading = \(shouldShowLoading) (isLoadingVideo: \(viewModel.isLoadingVideo), player.isLoading: \(viewModel.playerViewModel.isLoading))")
        
        return ZStack {
            Color.primarySoft
                .ignoresSafeArea()
            
            if shouldShowLoading {
//                print("🐞 WHITE_SCREEN_DEBUG: Showing VideoLoadingView")
                VideoLoadingView()
            } else if let error = viewModel.error {
//                print("🐞 WHITE_SCREEN_DEBUG: Showing VideoErrorView for viewModel.error: \(error)")
                VideoErrorView(error: error) {
                    viewModel.retryLoading()
                }
            } else if let playerError = viewModel.playerViewModel.error {
//                print("🐞 WHITE_SCREEN_DEBUG: Showing VideoErrorView for playerViewModel.error: \(playerError)")
                VideoErrorView(error: VideoProcessingError.processingFailed(playerError.localizedDescription)) {
                    viewModel.retryLoading()
                }
            } else {
//                print("🐞 WHITE_SCREEN_DEBUG: Showing contentView")
                contentView
            }
        }
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { navigationToolbar }
        // If a global go-home is requested
        // iOS 15: don't call dismiss here to avoid returning to this screen during chain dismissals
        .onReceive(NotificationCenter.default.publisher(for: .goHomeRequested)) { _ in
            if #available(iOS 16.0, *) {
                dismiss()
            } else {
                // no-op on iOS 15; AppCoordinator + ContentView will bring us home
            }
        }
        .onAppear {
            print("🐞 WHITE_SCREEN_DEBUG: RefactoredVideoTrimmingView.onAppear called")
            SubscriptionManager.shared.checkSubscriptionExpiry()
            handleViewAppearance()
        }
        .onDisappear { 
            print("🐞 WHITE_SCREEN_DEBUG: RefactoredVideoTrimmingView.onDisappear called")
            handleViewDisappearance() 
        }
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
        .fullScreenCover(isPresented: $isShowingPaywall, onDismiss: viewModel.acknowledgePaywall) {
            PaywallView(isPresented: $isShowingPaywall)
        }
        .onChange(of: viewModel.shouldShowPaywall) { shouldShow in
            guard shouldShow else { return }
            presentPaywall()
        }
        .safeAreaInset(edge: .bottom) {
            if isSmallPhone, !viewModel.isLoadingVideo, viewModel.error == nil {
                ContinueButton(
                    enhancementType: viewModel.enhancementType,
                    canProceed: viewModel.canProceed,
                    onContinue: handleContinueAction
                )
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 10)
                .background(
                    Color.primarySoft.opacity(0.95)
                        .ignoresSafeArea()
                )
                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: -2)
            }
        }
    }
    
    // MARK: - Content Views
    @ViewBuilder
    private var contentView: some View {
        if isSmallPhone {
            GeometryReader { _ in
                VStack(spacing: 12) {
                    VideoPreviewSection(
                        playerViewModel: viewModel.playerViewModel,
                        onChangeVideo: { showingVideoPicker = true },
                        preferredHeightIPad: nil
                    )

                    Spacer()

                    VideoControlsSection(
                        viewModel: viewModel,
                        onContinue: handleContinueAction,
                        onRequirePaywall: { presentPaywall() },
                        showContinueButton: false
                    )
                    .padding(.bottom, 12)
                }
                .padding(.top, 12)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        } else {
            ScrollView {
                VStack(spacing: isIPad ? 12 : 8) {
                    VideoPreviewSection(
                        playerViewModel: viewModel.playerViewModel,
                        onChangeVideo: { showingVideoPicker = true },
                        preferredHeightIPad: 560
                    )
                    .padding(.top, isIPad ? 36 : 20)

                    VideoInfoSection(
                        totalDuration: viewModel.totalDurationFormatted,
                        resolution: resolutionText,
                        size: sizeText
                    )
                    .padding(.top, isIPad ? 16 : 12)

                    // Controls
                    VideoControlsSection(
                        viewModel: viewModel,
                        onContinue: handleContinueAction,
                        onRequirePaywall: { presentPaywall() },
                        showContinueButton: !isIPad
                    )
                    .padding(.top, isIPad ? 24 : 20)
                    .padding(.bottom, isIPad ? 120 : 40)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, isIPad ? 28 : 20)
            }
            .overlay(alignment: .bottom) {
                if isIPad {
                    ContinueButton(
                        enhancementType: viewModel.enhancementType,
                        canProceed: viewModel.canProceed,
                        onContinue: handleContinueAction
                    )
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
                }
            }
        }
    }
    
    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var navigationToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            BackButton { handleBackAction() }
        }

        ToolbarItem(placement: .principal) {
            Text("Trim for \(viewModel.enhancementType.title)")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.accentWarm)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            CloseButton { handleCloseAction() }
        }
    }
    
    // MARK: - Gestures
    private var swipeToGoBackGesture: some Gesture {
        DragGesture()
            .onEnded { value in
                if value.startLocation.x < 50 && value.translation.width > 100 {
                    handleBackAction()
                }
            }
    }
    
    // MARK: - Event Handlers
    private func handleBackAction() {
        if let onBack {
            HapticFeedbackManager.impact(.light)
            onBack()
        } else {
            HapticFeedbackManager.impact(.light)
            dismiss()
        }
    }

    private func handleCloseAction() {
        if let onClose {
            HapticFeedbackManager.impact(.medium)
            onClose()
        } else {
            goHomeFromToolbar()
        }
    }

    private func handleContinueAction() {
        guard viewModel.canProceed else { return }
        HapticFeedbackManager.impact(.medium)
        if let onContinue {
            onContinue(viewModel.videoURL, viewModel.trimStartTime, viewModel.trimEndTime)
        } else {
            navigateToEnhancement = true
        }
    }

    private func handleViewAppearance() {
        print("🐞 WHITE_SCREEN_DEBUG: RefactoredVideoTrimmingView.handleViewAppearance() - START")
        print("🐞 WHITE_SCREEN_DEBUG: Enhancement type: \(viewModel.enhancementType.title)")
        
        hasStartedLoading = true
        
        Task { @MainActor in
            print("🐞 WHITE_SCREEN_DEBUG: Starting video loading sequence")
            viewModel.loadVideo()
            computeMetadata()
            print("🐞 WHITE_SCREEN_DEBUG: Video loading sequence initiated")
        }
        print("🐞 WHITE_SCREEN_DEBUG: RefactoredVideoTrimmingView.handleViewAppearance() - END")
    }
    
    private func handleViewDisappearance() {
        viewModel.cleanup()
    }

    private func goHomeFromToolbar() {
        HapticFeedbackManager.impact(.medium)
        NotificationCenter.default.post(name: .goHomeRequested, object: nil)
        if #available(iOS 16.0, *) {
            container.navigation.goToHome()
        } else {
            UIHelpers.dismissAllPresented(animated: true) {
                container.navigation.goToHome()
            }
        }
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

    private func presentPaywall() {
        isShowingPaywall = true
        viewModel.acknowledgePaywall()
    }
}

// MARK: - Video Preview Section
struct VideoPreviewSection: View {
    let playerViewModel: VideoPlayerViewModel
    let onChangeVideo: (() -> Void)?
    let preferredHeightIPad: CGFloat?
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isMuted: Bool = true
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        VStack(spacing: DeviceSize.isSmallPhone ? 12 : 16) {
            VideoPlayerView(playerViewModel: playerViewModel, isMuted: isMuted)
                .frame(height: isIPad ? (preferredHeightIPad ?? 560) : (DeviceSize.isSmallPhone ? 190 : 340))
                .cornerRadius(DeviceSize.isSmallPhone ? 16 : 20)
                .overlay(
                    RoundedRectangle(cornerRadius: DeviceSize.isSmallPhone ? 16 : 20)
                        .stroke(Color.accentWarm.opacity(0.2), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if let onChangeVideo {
                        VideoChangeButton { onChangeVideo() }
                            .padding(.leading, DeviceSize.isSmallPhone ? 16 : 24)
                            .padding(.top, DeviceSize.isSmallPhone ? 8 : 12)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    MuteToggleButton(isMuted: $isMuted)
                        .padding(.trailing, DeviceSize.isSmallPhone ? 16 : 20)
                        .padding(.top, DeviceSize.isSmallPhone ? 8 : 12)
                }
                .shadow(color: .black.opacity(0.4), radius: DeviceSize.isSmallPhone ? 10 : 15, x: 0, y: DeviceSize.isSmallPhone ? 6 : 8)
                .padding(.horizontal, DeviceSize.isSmallPhone ? 12 : 20)
        }
        .onAppear {
            playerViewModel.setMuted(isMuted)
        }
        .onChange(of: isMuted) { newValue in
            playerViewModel.setMuted(newValue)
        }
    }
}

// MARK: - Video Player View
struct VideoPlayerView: View {
    @ObservedObject var playerViewModel: VideoPlayerViewModel
    let isMuted: Bool
    
    var body: some View {
        Group {
            if let player = playerViewModel.normalPlayer {
                VideoPlayer(player: player)
                    .onAppear {
                        playerViewModel.setActive(true)
                        playerViewModel.setMuted(isMuted)
                        playerViewModel.play()
                    }
                    .onDisappear {
                        playerViewModel.setActive(false)
                    }
                    .onChange(of: isMuted) { newValue in
                        playerViewModel.setMuted(newValue)
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
            HStack(spacing: DeviceSize.isSmallPhone ? 4 : 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: DeviceSize.isSmallPhone ? 12 : 14, weight: .medium))
                Text("Change")
                    .font(.system(size: DeviceSize.isSmallPhone ? 12 : 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, DeviceSize.isSmallPhone ? 10 : 12)
            .padding(.vertical, DeviceSize.isSmallPhone ? 6 : 8)
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
    private var isSmallPhone: Bool { DeviceSize.isSmallPhone }
    
    var body: some View {
        infoCard {
            if isSmallPhone {
                VStack(spacing: 10) {
                    compactMetric(icon: "internaldrive", label: "Size", value: size)
                    Divider().background(Color.white.opacity(0.15))
                    compactMetric(icon: "clock", label: "Total Duration", value: totalDuration)
                    Divider().background(Color.white.opacity(0.15))
                    compactMetric(icon: "rectangle.expand.vertical", label: "Resolution", value: resolution)
                }
            } else {
                HStack(spacing: isIPad ? 20 : 16) {
                    metric(icon: "internaldrive", value: size, label: "Size")
                    divider
                    metric(icon: "clock", value: totalDuration, label: "Total Duration")
                    divider
                    metric(icon: "rectangle.expand.vertical", value: resolution, label: "Resolution")
                }
            }
        }
    }

    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, isSmallPhone ? 14 : 20)
            .padding(.vertical, isIPad ? 16 : (isSmallPhone ? 10 : 12))
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.accentWarm.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.accentWarm.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.2), radius: isIPad ? 8 : 6, x: 0, y: 3)
            .padding(.horizontal, isSmallPhone ? 14 : 20)
    }

    private var divider: some View {
        Divider()
            .background(Color.white.opacity(0.2))
            .frame(height: isIPad ? 46 : 40)
    }

    private func metric(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            Text(value)
                .font(.system(size: isIPad ? 20 : 16, weight: .bold))
                .foregroundColor(.accentWarm)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)

            Text(label)
                .font(.system(size: isIPad ? 12 : 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    private func compactMetric(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.75))

            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.accentWarm)
        }
    }
}

// MARK: - Video Info Card (removed duplicate - using Components/VideoInfoCard.swift version)

// MARK: - Video Controls Section
struct VideoControlsSection: View {
    @ObservedObject var viewModel: VideoTrimmingViewModel
    let onContinue: () -> Void
    let onRequirePaywall: (() -> Void)?
    var showContinueButton: Bool = true
    @Environment(\.horizontalSizeClass) private var hSize
    private var isIPad: Bool { hSize == .regular }
    private var isSmallPhone: Bool { DeviceSize.isSmallPhone }
    
    var body: some View {
        let content = VStack(spacing: isSmallPhone ? 12 : (isIPad ? 30 : 24)) {
            TimePresetButtons(
                selectedDuration: viewModel.selectedDuration,
                onPresetSelected: viewModel.updateTrimForPreset,
                onRequirePaywall: onRequirePaywall
            )
            .padding(.horizontal, isSmallPhone ? 6 : 20)
            Spacer()
            VideoTrimmingSliderView(
                startTime: $viewModel.trimStartTime,
                endTime: $viewModel.trimEndTime,
                duration: viewModel.videoDuration,
                thumbnails: viewModel.thumbnails,
                enhancementType: viewModel.enhancementType,
                playerViewModel: viewModel.playerViewModel
            )
            .frame(height: isSmallPhone ? 46 : 60)
            .padding(.horizontal, isSmallPhone ? 12 : 20)
            Spacer()
            if showContinueButton {
                ContinueButton(
                    enhancementType: viewModel.enhancementType,
                    canProceed: viewModel.canProceed,
                    onContinue: onContinue
                )
                .padding(.horizontal, isSmallPhone ? 12 : 20)
            }
        }
        
        if isSmallPhone {
            content
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.08))
                )
//                .overlay(
//                    RoundedRectangle(cornerRadius: 16)
//                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
//                )
        } else {
            content
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
        if DeviceSize.isSmallPhone {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
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
                }
                .padding(.horizontal, 4)
            }
        } else {
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
    private var isSmallPhone: Bool { DeviceSize.isSmallPhone }
    
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
                .font(.system(size: isIPad ? 18 : (isSmallPhone ? 13 : 16), weight: .semibold))
                .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                .frame(width: isIPad ? 110 : (isSmallPhone ? 104 : 84), height: isIPad ? 48 : (isSmallPhone ? 38 : 40))
                .background(
                    RoundedRectangle(cornerRadius: isSmallPhone ? 10 : 12)
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
        let isSmall = DeviceSize.isSmallPhone
        Button(action: {
            HapticFeedbackManager.impact(.medium)
            onContinue()
        }) {
            HStack(spacing: 12) {
//                Image(systemName: enhancementType.icon)
//                    .font(.system(size: 20, weight: .medium))
                
                Text("Continue")
                    .font(.system(size: isSmall ? 16 : 18, weight: .semibold))
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
