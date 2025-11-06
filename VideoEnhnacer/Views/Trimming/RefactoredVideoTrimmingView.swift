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
    @State private var selectedPhotoItem: Any? // Holds PhotosPickerItem for iOS 16+

    // MARK: - Callbacks
    private let onBack: (() -> Void)?
    private let onClose: (() -> Void)?
    private let onContinue: ((URL, Double, Double) -> Void)?
    
    // MARK: - Dependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(\.diContainer) private var container
    @StateObject private var viewModel: VideoTrimmingViewModel
    @StateObject private var loadingState: LoadingStateObserver

    // MARK: - State
    @State private var isShowingPaywall = false
    @State private var hasStartedLoading = false
    @Environment(\.horizontalSizeClass) private var hSize
    private var isIPad: Bool { hSize == .regular }
    private var isSmallPhone: Bool { DeviceSize.isSmallPhone }
    
    // MARK: - Initialization
    init(
        videoURL: URL,
        enhancementType: EnhancementType,
        injectedViewModel: VideoTrimmingViewModel? = nil,
        onBack: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil,
        onContinue: ((URL, Double, Double) -> Void)? = nil
    ) {
        self.onBack = onBack
        self.onClose = onClose
        self.onContinue = onContinue

        // Use injected view model if provided, otherwise create new one
        let trimmingViewModel: VideoTrimmingViewModel
        if let injected = injectedViewModel {
            trimmingViewModel = injected
            LoadingDebugLogger.shared.log("✅ USING INJECTED: VideoTrimmingViewModel in RefactoredVideoTrimmingView")
        } else {
            let container = DIContainer.shared
            trimmingViewModel = container.makeVideoTrimmingViewModel(
                videoURL: videoURL,
                enhancementType: enhancementType
            )
            LoadingDebugLogger.shared.log("🆕 CREATING NEW: VideoTrimmingViewModel in RefactoredVideoTrimmingView")
        }

        self._viewModel = StateObject(wrappedValue: trimmingViewModel)
        self._loadingState = StateObject(wrappedValue: LoadingStateObserver(viewModel: trimmingViewModel))

        // Device tracking log
        let deviceName = UIDevice.current.name
        let osVersion = UIDevice.current.systemVersion
        let model = UIDevice.current.model
        TrimmingDiagnostics.log("📱 [RefactoredVideoTrimmingView] Initialized on device: \(model) (\(deviceName)), iOS \(osVersion)")
    }

    @ViewBuilder
    private func buildErrorOrContent() -> some View {
        if let error = viewModel.error {
            VideoErrorView(error: error) {
                viewModel.retryLoading()
            }
        } else if let playerError = viewModel.playerViewModel.error {
            VideoErrorView(error: VideoProcessingError.processingFailed(playerError.localizedDescription)) {
                viewModel.retryLoading()
            }
        } else {
            contentView
        }
    }

    // MARK: - Body
    var body: some View {
        // Use LoadingContainerView with Binding to prevent unnecessary re-renders
        // The container only observes the boolean loading state, not other ViewModel properties
        let isLoadingBinding = Binding(
            get: { loadingState.isLoading },
            set: { _ in }  // read-only binding
        )

        return LoadingContainerView(
            isLoading: isLoadingBinding,
            loadingView: {
                VideoLoadingView()
            },
            contentView: {
                buildErrorOrContent()
                    .task {
                        // Minimum display time to prevent flashing on small devices
                        let delay: UInt64 = DeviceSize.isSmallPhone ? 500_000_000 : 300_000_000
                        try? await Task.sleep(nanoseconds: delay)
                    }
            }
        )
        .background(
            Color.primarySoft
                .ignoresSafeArea()
        )
        .preferredColorScheme(.dark)
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
            TrimmingDiagnostics.log("👁️ [RefactoredVideoTrimmingView] View appeared")
            SubscriptionManager.shared.checkSubscriptionExpiry()
            handleViewAppearance()
        }
        .onDisappear {
            TrimmingDiagnostics.log("👋 [RefactoredVideoTrimmingView] View disappeared")
            handleViewDisappearance()
        }
        .gesture(swipeToGoBackGesture)
        .modifier(TrimmingVideoPickerModifier(
            showingVideoPicker: $showingVideoPicker,
            selectedPhotoItem: $selectedPhotoItem,
            onVideoSelected: { newVideoURL in
                TrimmingDiagnostics.log("🔄 [RefactoredVideoTrimmingView] User changed video to: \(newVideoURL.lastPathComponent)")
                logVideoSelectionToFile("🎯 [RefactoredVideoTrimmingView] onVideoSelected callback triggered")
                logVideoSelectionToFile("🎯 [RefactoredVideoTrimmingView] New video URL: \(newVideoURL.path)")
                logVideoSelectionToFile("🎯 [RefactoredVideoTrimmingView] Calling viewModel.replaceVideo...")

                // Update video in-place and recompute metadata
                viewModel.replaceVideo(with: newVideoURL)
                logVideoSelectionToFile("🎯 [RefactoredVideoTrimmingView] viewModel.replaceVideo completed")

                logVideoSelectionToFile("🎯 [RefactoredVideoTrimmingView] Calling computeMetadata...")
                computeMetadata()
                logVideoSelectionToFile("🎯 [RefactoredVideoTrimmingView] computeMetadata completed")
                logVideoSelectionToFile("🎯 [RefactoredVideoTrimmingView] onVideoSelected callback finished")
            }
        ))
        .fullScreenCover(isPresented: $isShowingPaywall) {
            PaywallView(isPresented: $isShowingPaywall)
        }
        .onChange(of: isShowingPaywall) { isShowing in
            if isShowing {
                viewModel.playerViewModel.pause()
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSmallPhone, !viewModel.isLoadingVideo, viewModel.error == nil {
                ContinueButton(
                    enhancementType: viewModel.enhancementType,
                    canProceed: viewModel.canProceed,
                    onContinue: handleContinueAction
                )
                .padding(.horizontal, 20)
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
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 12) {
                        VideoPreviewSection(
                            playerViewModel: viewModel.playerViewModel,
                            onChangeVideo: { showingVideoPicker = true },
                            preferredHeightIPad: nil
                        )
                        .padding(.top, 12)

                        Spacer()

                        VideoControlsSection(
                            viewModel: viewModel,
                            onContinue: handleContinueAction,
                            onRequirePaywall: { presentPaywall() },
                            showContinueButton: false
                        )
                        
                        Spacer()
                    }
                    .frame(minHeight: geo.size.height)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                }
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
            Text("Trimming") //for \(viewModel.enhancementType.title)
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
        TrimmingDiagnostics.log("⬅️ [RefactoredVideoTrimmingView] Back button tapped")
        if let onBack {
            HapticFeedbackManager.impact(.light)
            onBack()
        } else {
            HapticFeedbackManager.impact(.light)
            dismiss()
        }
    }

    private func handleCloseAction() {
        TrimmingDiagnostics.log("❌ [RefactoredVideoTrimmingView] Close button tapped")
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
        TrimmingDiagnostics.log("📤 [RefactoredVideoTrimmingView] Continue clicked: trimStart=\(viewModel.trimStartTime) trimEnd=\(viewModel.trimEndTime)")

        guard let onContinue else {
            TrimmingDiagnostics.log("⚠️ [RefactoredVideoTrimmingView] No onContinue callback provided - cannot navigate to enhancement")
            assertionFailure("RefactoredVideoTrimmingView requires onContinue callback for navigation")
            return
        }

        onContinue(viewModel.videoURL, viewModel.trimStartTime, viewModel.trimEndTime)
    }

    private func handleViewAppearance() {
        // Skip reload if video data is already loaded
        if viewModel.isAlreadyLoaded {
            TrimmingDiagnostics.log("✅ [RefactoredVideoTrimmingView] Data already loaded, skipping reload")
            LoadingDebugLogger.shared.log("⏭️ SKIP RELOAD: Already loaded - duration:\(viewModel.videoDuration)s, thumbnails:\(viewModel.thumbnails.count), trimStart:\(viewModel.trimStartTime)s, trimEnd:\(viewModel.trimEndTime)s")

            Task { @MainActor in
                // Just setup player without full reload
                viewModel.playerViewModel.setupPlayers(
                    originalURL: viewModel.videoURL,
                    enhancedURL: viewModel.videoURL
                )
                computeMetadata()
            }
            return
        }

        TrimmingDiagnostics.log("🚀 [RefactoredVideoTrimmingView] Starting video loading for: \(viewModel.videoURL.lastPathComponent)")
        LoadingDebugLogger.shared.log("🚀 TRIGGER RELOAD: Not loaded - duration:\(viewModel.videoDuration)s, thumbnails:\(viewModel.thumbnails.count) - calling viewModel.loadVideo()")
        hasStartedLoading = true

        Task { @MainActor in
            viewModel.loadVideo()
            computeMetadata()
        }
    }

    private func handleViewDisappearance() {
        TrimmingDiagnostics.log("🧹 [RefactoredVideoTrimmingView] Cleaning up resources")
        viewModel.cleanup()
    }

    private func logVideoSelectionToFile(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)"

        // Print to console
        print(logMessage)

        // Write to project directory
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
        TrimmingDiagnostics.log("📊 [RefactoredVideoTrimmingView] Computing video metadata")
        let url = viewModel.videoURL
        let asset = AVAsset(url: url)
        // Resolution
        if let track = asset.tracks(withMediaType: .video).first {
            var size = track.naturalSize
            let transform = track.preferredTransform
            let rotated = abs(transform.b) > 0.0001 && abs(transform.c) > 0.0001
            if rotated { size = CGSize(width: size.height, height: size.width) }
            resolutionText = "\(Int(size.width))×\(Int(size.height))"
            TrimmingDiagnostics.log("📐 [RefactoredVideoTrimmingView] Video resolution: \(resolutionText)")
        } else {
            resolutionText = "—"
            TrimmingDiagnostics.log("⚠️ [RefactoredVideoTrimmingView] Could not determine video resolution")
        }
        // File size (best effort)
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            if let bytes = attrs[.size] as? NSNumber {
                let mb = Double(truncating: bytes) / (1024.0 * 1024.0)
                sizeText = String(format: "%.1f MB", mb)
                TrimmingDiagnostics.log("💾 [RefactoredVideoTrimmingView] File size: \(sizeText)")
            } else {
                sizeText = "—"
            }
        } catch {
            sizeText = "—"
            TrimmingDiagnostics.log("⚠️ [RefactoredVideoTrimmingView] Could not determine file size: \(error.localizedDescription)")
        }
    }

    private func presentPaywall() {
        isShowingPaywall = true
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
            VideoPlayerView(playerViewModel: playerViewModel, isMuted: $isMuted)
                .frame(height: isIPad ? (preferredHeightIPad ?? 560) : (DeviceSize.isSmallPhone ? 260 : 340))
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
    @Binding var isMuted: Bool

    var body: some View {
        Group {
            if let player = playerViewModel.normalPlayer {
                CustomVideoPlayerWithControls(
                    player: player,
                    isMuted: $isMuted,
                    videoGravity: .resizeAspect,
                    trimStart: nil,
                    trimEnd: nil
                )
                .onAppear {
                    playerViewModel.setActive(true)
                    playerViewModel.setMuted(isMuted)
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

//            if !isSmallPhone {
//                Spacer()
//            }

            VideoTrimmingSliderView(
                startTime: $viewModel.trimStartTime,
                endTime: $viewModel.trimEndTime,
                duration: viewModel.videoDuration,
                thumbnails: viewModel.thumbnails,
                enhancementType: viewModel.enhancementType,
                playerViewModel: viewModel.playerViewModel,
                viewModel: viewModel
            )
            .frame(height: isSmallPhone ? 46 : 60)
            .padding(.horizontal, isSmallPhone ? 12 : 20)
            .padding(.top, isSmallPhone ? 8 : 0)

//            if !isSmallPhone {
//                Spacer()
//            }

            if showContinueButton {
                ContinueButton(
                    enhancementType: viewModel.enhancementType,
                    canProceed: viewModel.canProceed,
                    onContinue: onContinue
                )
                .padding(.horizontal, isSmallPhone ? 12 : 20)
                .padding(.top, isSmallPhone ? 8 : 0)
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
                        TimePresetButton(
                            title: preset.title,
                            isSelected: selectedDuration == preset,
                            showsProBadge: false,
                            onTap: { onPresetSelected(preset) }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        } else {
            HStack(spacing: isIPad ? 24 : 16) {
                Spacer()

                ForEach(VideoTrimmingViewModel.TimePreset.allCases, id: \.title) { preset in
                    TimePresetButton(
                        title: preset.title,
                        isSelected: selectedDuration == preset,
                        showsProBadge: false,
                        onTap: { onPresetSelected(preset) }
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
    @Environment(\.horizontalSizeClass) private var hSize
    private var isIPad: Bool { hSize == .regular }
    private var isSmallPhone: Bool { DeviceSize.isSmallPhone }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: {
                HapticFeedbackManager.impact(.light)
                onTap()
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
            }
            .buttonStyle(PlainButtonStyle())

            if showsProBadge {
                ProPill()
                    .offset(x: 6, y: -6)
            }
        }
        .padding(.top, showsProBadge ? 8 : 0)
        .padding(.trailing, showsProBadge ? 8 : 0)
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
    @ObservedObject var viewModel: VideoTrimmingViewModel

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

            // Auto-select preset based on duration
            let duration = endTime - newValue
            if duration > 30 {
                viewModel.selectedDuration = .fiveMinutes
            } else {
                viewModel.selectedDuration = .thirtySeconds
            }
        }
        .onChange(of: endTime) { newValue in
            // Update playback range as end changes
            playerViewModel.setPlaybackRange(start: startTime, end: newValue)

            // Auto-select preset based on duration
            let duration = newValue - startTime
            if duration > 30 {
                viewModel.selectedDuration = .fiveMinutes
            } else {
                viewModel.selectedDuration = .thirtySeconds
            }
        }
    }
}

//// MARK: - Continue Button
//struct ContinueButton: View {
//    let enhancementType: EnhancementType
//    let canProceed: Bool
//    let onContinue: () -> Void
//    
//    var body: some View {
//        let isSmall = DeviceSize.isSmallPhone
//        Button(action: {
//            HapticFeedbackManager.impact(.medium)
//            onContinue()
//        }) {
//            HStack(spacing: 12) {
////                Image(systemName: enhancementType.icon)
////                    .font(.system(size: 20, weight: .medium))
//                
//                Text("Continue")
//                    .font(.system(size: isSmall ? 16 : 18, weight: .semibold))
//                    .foregroundColor(.white)
//                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
//            }
//        }
//        .buttonStyle(FloatingActionButtonStyle())
//        .disabled(!canProceed)
//        .opacity(canProceed ? 1.0 : 0.7)
//    }
//}

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
            Text("Continue")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .frame(width: UIScreen.main.bounds.width * 0.68)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient.primaryTheme)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(
                            color: Color.black.opacity(0.15),
                            radius: 6,
                            x: 0,
                            y: 3
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
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

// MARK: - Video Picker Modifier
fileprivate struct TrimmingVideoPickerModifier: ViewModifier {
    @Binding var showingVideoPicker: Bool
    @Binding var selectedPhotoItem: Any?
    let onVideoSelected: (URL) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            // MODERN: Native SwiftUI PhotosPicker
            content
                .photosPicker(
                    isPresented: $showingVideoPicker,
                    selection: Binding<PhotosPickerItem?>(
                        get: {
                            let item = selectedPhotoItem as? PhotosPickerItem
                            logToFile("📸 [VideoSelection] Binding getter called - current item: \(item != nil ? "exists" : "nil")")
                            return item
                        },
                        set: { newValue in
                            logToFile("📸 [VideoSelection] ==========================================")
                            logToFile("📸 [VideoSelection] Binding setter called with item: \(newValue != nil ? "EXISTS" : "NIL")")
                            if let item = newValue {
                                logToFile("📸 [VideoSelection] Item identifier: \(item.itemIdentifier ?? "no identifier")")
                            }

                            selectedPhotoItem = newValue

                            if let item = newValue {
                                logToFile("📸 [VideoSelection] Starting Task to load video...")
                                Task {
                                    logToFile("📸 [VideoSelection] Task started - calling loadVideoModern...")
                                    await loadVideoModern(from: item)
                                }
                            } else {
                                logToFile("📸 [VideoSelection] No item selected (user cancelled?)")
                            }
                        }
                    ),
                    matching: .videos
                )
                .onChange(of: showingVideoPicker) { isShowing in
                    logToFile("📸 [VideoSelection] Picker presentation changed: \(isShowing ? "SHOWING" : "HIDDEN")")
                }
        } else {
            // FALLBACK: UIKit picker for iOS 15
            content
                .sheet(isPresented: $showingVideoPicker) {
                    UIKitVideoPickerWrapper { url in
                        logToFile("📸 [VideoSelection] UIKit picker selected video: \(url.lastPathComponent)")
                        onVideoSelected(url)
                    }
                }
        }
    }

    @available(iOS 16.0, *)
    private func loadVideoModern(from item: PhotosPickerItem) async {
        let timestamp = Date()
        logToFile("📸 [VideoSelection] loadVideoModern() called at \(timestamp)")
        logToFile("📸 [VideoSelection] Item identifier: \(item.itemIdentifier ?? "unknown")")
        print("🐞 TRIMMING_MODERN_PICKER_DEBUG: Loading video from PhotosPickerItem...")

        do {
            logToFile("📸 [VideoSelection] Calling item.loadOriginalVideoFromTrimming()...")
            if let url = try await item.loadOriginalVideoFromTrimming() {
                let elapsed = Date().timeIntervalSince(timestamp)
                logToFile("📸 [VideoSelection] ✅ Successfully loaded video: \(url.lastPathComponent)")
                logToFile("📸 [VideoSelection] Video URL: \(url.path)")
                logToFile("📸 [VideoSelection] Load time: \(String(format: "%.2f", elapsed))s")
                print("🐞 TRIMMING_MODERN_PICKER_DEBUG: ✅ Successfully loaded video: \(url.lastPathComponent)")

                await MainActor.run {
                    logToFile("📸 [VideoSelection] On MainActor - calling onVideoSelected callback...")
                    onVideoSelected(url)
                    logToFile("📸 [VideoSelection] onVideoSelected callback completed")
                    logToFile("📸 [VideoSelection] Clearing selectedPhotoItem...")
                    selectedPhotoItem = nil
                    logToFile("📸 [VideoSelection] ==========================================")
                }
            } else {
                logToFile("📸 [VideoSelection] ❌ loadOriginalVideoFromTrimming returned nil")
                print("🐞 TRIMMING_MODERN_PICKER_DEBUG: ❌ loadOriginalVideoFromTrimming returned nil")
            }
        } catch {
            logToFile("📸 [VideoSelection] ❌ Error loading video: \(error.localizedDescription)")
            logToFile("📸 [VideoSelection] Error details: \(error)")
            print("🐞 TRIMMING_MODERN_PICKER_DEBUG: ❌ Error loading video: \(error.localizedDescription)")
        }
    }

    private func logToFile(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)"

        // Print to console
        print(logMessage)

        // Write to file
        let logFile = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("video_selection_debug.log")

        if let data = (logMessage + "\n").data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logFile)
            }
        }

        // Also write to project directory for easy access
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
}

// MARK: - PhotosPickerItem Extension for Original Video Loading (Trimming)
@available(iOS 16.0, *)
extension PhotosPickerItem {
    func loadOriginalVideoFromTrimming() async throws -> URL? {
        print("🐞 TRIMMING_MODERN_PICKER_DEBUG: Starting loadOriginalVideoFromTrimming")

        // APPROACH 1: Try using itemIdentifier (works for most local videos)
        if let identifier = self.itemIdentifier {
            print("🐞 TRIMMING_MODERN_PICKER_DEBUG: Has itemIdentifier: \(identifier)")

            let assets = PHAsset.fetchAssets(
                withLocalIdentifiers: [identifier],
                options: nil
            )

            if let asset = assets.firstObject {
                print("🐞 TRIMMING_MODERN_PICKER_DEBUG: Found PHAsset, attempting to load video")
                return try await loadVideoFromPHAssetForTrimming(asset)
            } else {
                print("🐞 TRIMMING_MODERN_PICKER_DEBUG: No PHAsset found for identifier")
            }
        } else {
            print("🐞 TRIMMING_MODERN_PICKER_DEBUG: No itemIdentifier - trying loadTransferable fallback")
        }

        // APPROACH 2: Fallback to loadTransferable (works for iCloud, recent videos, etc.)
        print("🐞 TRIMMING_MODERN_PICKER_DEBUG: Attempting loadTransferable approach...")

        guard let movie = try await self.loadTransferable(type: MovieTransferable.self) else {
            print("🐞 TRIMMING_MODERN_PICKER_DEBUG: loadTransferable returned nil")
            return nil
        }

        print("🐞 TRIMMING_MODERN_PICKER_DEBUG: ✅ Successfully loaded video via loadTransferable: \(movie.url.lastPathComponent)")
        return movie.url
    }

    private func loadVideoFromPHAssetForTrimming(_ asset: PHAsset) async throws -> URL? {
        return try await withCheckedThrowingContinuation { continuation in
            let resources = PHAssetResource.assetResources(for: asset)

            guard let resource = resources.first(where: { $0.type == .video }) else {
                print("🐞 TRIMMING_MODERN_PICKER_DEBUG: No video resource found in PHAsset")
                continuation.resume(returning: nil)
                return
            }

            // Use temporary directory for better iOS compatibility
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("video_\(UUID().uuidString).mov")

            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true

            print("🐞 TRIMMING_MODERN_PICKER_DEBUG: Writing video data to temporary file...")

            PHAssetResourceManager.default().writeData(
                for: resource,
                toFile: fileURL,
                options: options
            ) { error in
                if let error = error {
                    print("🐞 TRIMMING_MODERN_PICKER_DEBUG: Error writing video data: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    print("🐞 TRIMMING_MODERN_PICKER_DEBUG: ✅ Successfully wrote video to: \(fileURL.lastPathComponent)")
                    continuation.resume(returning: fileURL)
                }
            }
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
