import SwiftUI
import Combine
import AVKit

// MARK: - Refactored Enhancement Selection View
/// Clean, focused view following MVVM and Single Responsibility Principle
struct RefactoredEnhancementSelectionView: View {
    
    // MARK: - Dependencies
    @Environment(\.diContainer) private var container
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EnhancementSelectionViewModel
    @StateObject private var playerViewModel: VideoPlayerViewModel
    
    // MARK: - State
    @State private var showingResults = false
    @State private var hasCompletedOnce = false // Track if processing has completed to prevent auto-restart
    @EnvironmentObject private var historyManager: HistoryManager

    private let onBack: (() -> Void)?
    private let onClose: (() -> Void)?
    private let onShowResults: ((EnhancementResult) -> Void)?
    
    // MARK: - Initialization
    init(
        videoURL: URL,
        enhancementType: EnhancementType,
        trimStartTime: Double? = nil,
        trimEndTime: Double? = nil,
        onBack: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil,
        onShowResults: ((EnhancementResult) -> Void)? = nil
    ) {
        self.onBack = onBack
        self.onClose = onClose
        self.onShowResults = onShowResults
        let container = DIContainer.shared

        let enhancementViewModel = container.makeEnhancementSelectionViewModel(
            videoURL: videoURL,
            enhancementType: enhancementType,
            trimStartTime: trimStartTime,
            trimEndTime: trimEndTime
        )
        self._viewModel = StateObject(wrappedValue: enhancementViewModel)

        let playerVM = container.makeVideoPlayerViewModel()
        self._playerViewModel = StateObject(wrappedValue: playerVM)
    }
    
    // MARK: - Body
    @Environment(\.horizontalSizeClass) private var hSize
    private var isIPad: Bool { hSize == .regular }
    var body: some View {
        ZStack {
            Color.primarySoft
                .ignoresSafeArea()
            
            // Scrollable content; add bottom inset for small devices and iPad overlay
            ScrollView {
                contentView
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.bottom, isIPad ? 120 : (DeviceSize.isSmallPhone ? 100 : 24))
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear {
                                    let bottomPadding = isIPad ? 120 : (DeviceSize.isSmallPhone ? 100 : 24)
                                    print("DEBUG_PROCESS_REFACT: ContentView size - width: \(geo.size.width), height: \(geo.size.height)")
                                    print("DEBUG_PROCESS_REFACT: ContentView bottom padding: \(bottomPadding)")
                                }
                        }
                    )
            }
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            print("DEBUG_PROCESS_REFACT: ScrollView viewport size - width: \(geo.size.width), height: \(geo.size.height)")
                        }
                }
            )
            .navigationBarBackButtonHidden()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { navigationToolbar }
            .overlay(alignment: .bottom) {
                if isIPad {
                    EnhancementActionView(
                        enhancementType: viewModel.enhancementType,
                        selectedOption: viewModel.selectedOption,
                        canProcess: viewModel.canProcess,
                        onProcess: { viewModel.checkAndProcessVideo() }
                    )
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .goHomeRequested)) { _ in
            if #available(iOS 16.0, *) {
                if let onClose {
                    onClose()
                } else {
                    dismiss()
                }
            } else {
                // no-op on iOS 15; navigation is handled centrally
            }
        }
        .onAppear {
            // DEBUG: Screen dimensions
            let screenBounds = UIScreen.main.bounds
            let window = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
            let safeAreaInsets = window?.safeAreaInsets ?? .zero
            print("DEBUG_PROCESS_REFACT: ========================")
            print("DEBUG_PROCESS_REFACT: Screen width: \(screenBounds.width), height: \(screenBounds.height)")
            print("DEBUG_PROCESS_REFACT: isIPad: \(isIPad)")
            print("DEBUG_PROCESS_REFACT: isSmallPhone: \(DeviceSize.isSmallPhone)")
            print("DEBUG_PROCESS_REFACT: Safe area - top: \(safeAreaInsets.top), bottom: \(safeAreaInsets.bottom)")
            print("DEBUG_PROCESS_REFACT: ========================")

            handleViewAppearance()
            SubscriptionManager.shared.checkSubscriptionExpiry()
            // Only auto-start processing for single-option enhancements if we haven't processed before
            if viewModel.enhancementType.options.count == 1 && !viewModel.isProcessing && viewModel.result == nil && !hasCompletedOnce {
                viewModel.checkAndProcessVideo()
            }
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .fullScreenCover(isPresented: $showingResults) { resultsView }
        .fullScreenCover(isPresented: $viewModel.isShowingPaywall) {
            PaywallView(isPresented: $viewModel.isShowingPaywall)
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(
                title: Text(viewModel.alertTitle),
                message: Text(viewModel.alertMessage),
                primaryButton: .default(Text("OK")) {
                    viewModel.clearError()
                    if viewModel.alertTitle == "Processing Complete" {
                        viewModel.resetState()
                    }
                },
                secondaryButton: viewModel.error != nil ? .default(Text("Retry")) {
                    viewModel.retryProcessing()
                } : .cancel()
            )
        }
        .processingOverlay(
            isPresenting: viewModel.isProcessing,
            progress: viewModel.progress,
            processingState: viewModel.processingState,
            onCancel: { viewModel.cancelProcessing() }
        )
        .onChange(of: viewModel.result, perform: handleResultChange)
        .onChange(of: viewModel.isProcessing) { isProcessing in
            if isProcessing {
                playerViewModel.pause()
            }
        }
        .onChange(of: viewModel.processingState) { state in
            if isOverlayActive(state) {
                playerViewModel.pause()
            }
        }
        .onChange(of: viewModel.isShowingPaywall) { isShowing in
            if isShowing {
                playerViewModel.pause()
            }
        }
    }
    
    // MARK: - Content Views
    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 12) {
            EnhancementVideoPreviewSection(
                playerViewModel: playerViewModel,
                enhancementType: viewModel.enhancementType,
                onChangeVideo: nil,
                preferredHeightIPad: 560,
                trimStart: viewModel.trimStartTime,
                trimEnd: viewModel.trimEndTime,
                isProcessing: viewModel.isProcessing,
                isShowingPaywall: viewModel.isShowingPaywall,
                processingState: viewModel.processingState
            )
            .padding(.top, isIPad ? 36 : (DeviceSize.isSmallPhone ? 16 : 20))

            HStack {
                EnhancementOptionsView(
                    enhancementType: viewModel.enhancementType,
                    filteredOptions: filteredEnhancementOptions,
                    selectedOption: $viewModel.selectedOption,
                    isAnalyzing: viewModel.isAnalyzing,
                    onOptionSelected: viewModel.updateSelection,
                    onRequirePaywall: { viewModel.isShowingPaywall = true }
                )
                .padding(.horizontal, 16)
                .padding(.top, isIPad ? 24 : 0)
            }

            if !isIPad {
                EnhancementActionView(
                    enhancementType: viewModel.enhancementType,
                    selectedOption: viewModel.selectedOption,
                    canProcess: viewModel.canProcess,
                    onProcess: { viewModel.checkAndProcessVideo() }
                )
                .padding(.top, 12)
                .padding(.horizontal, 16)
            }
        }
        .padding(.horizontal, 0)
    }
    
    @ViewBuilder
    private var resultsView: some View {
        if let result = viewModel.result {
            VideoResultsView(
                originalVideoURL: result.originalURL,
                processedVideoURL: result.processedURL,
                enhancementType: result.enhancementType.title,
                enhancementIcon: result.enhancementType.icon,
                gradientType: result.enhancementType.gradientType,
                appliedEnhancement: result.metadata.appliedEnhancement,
                enhancementTypeId: result.enhancementType.id
            )
        }
    }

    // MARK: - Filtered Options
    /// Filter enhancement options based on device capabilities
    private var filteredEnhancementOptions: [EnhancementOption] {
        viewModel.enhancementType.options.filter { option in
            // Hide 4K option on unsupported devices (iPod, iPhone SE, iPhone 8 and older)
            if option.id == "4K" && !DeviceSize.supports4K {
                return false
            }
            // Add more device-specific filters here if needed
            return true
        }
    }
    
    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var navigationToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if !viewModel.isProcessing {
                BackButton { handleBackAction() }
            } else {
                EmptyView()
            }
        }
        
        ToolbarItem(placement: .principal) {
            if !viewModel.isProcessing {
                Text("") // viewModel.enhancementType.title
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.accentWarm)
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            if !viewModel.isProcessing {
                CloseButton { handleCloseAction() }
            } else {
                EmptyView()
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

    private func handleResultChange(_ result: EnhancementResult?) {
        guard let result else { return }
        // Mark that processing has completed once to prevent auto-restart
        hasCompletedOnce = true
        if let onShowResults {
            onShowResults(result)
        } else {
            showingResults = true
        }
    }

    private func isOverlayActive(_ state: EnhancementProcessingState) -> Bool {
        switch state {
        case .preparing, .processing:
            return true
        default:
            return false
        }
    }

    private func handleViewAppearance() {
        print("🎭 RefactoredEnhancementSelectionView - Appeared with:")
        print("  Enhancement: \(viewModel.enhancementType.title)")
        print("  Video URL: \(viewModel.videoURL)")
        print("  Video URL lastPathComponent: \(viewModel.videoURL.lastPathComponent)")
        print("  Trim: \(viewModel.trimStartTime ?? -1) to \(viewModel.trimEndTime ?? -1)")
        print("  PlayerViewModel current state: \(playerViewModel.playerState)")
        print("  PlayerViewModel isLoading: \(playerViewModel.isLoading)")
        
        print("  🚀 Starting player setup immediately...")
        playerViewModel.setupPlayers(originalURL: viewModel.videoURL, enhancedURL: viewModel.videoURL)
        
        if let start = viewModel.trimStartTime, let end = viewModel.trimEndTime {
            print("  📐 Will apply trim range: \(start)s to \(end)s")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.playerViewModel.setPlaybackRange(start: start, end: end)
                self.playerViewModel.seek(to: start)
                print("  ✅ Trim range applied and seeked to start")
            }
        } else {
            print("  ℹ️ No trim range to apply")
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
}

// MARK: - Enhancement Video Preview Section
struct EnhancementVideoPreviewSection: View {
    let playerViewModel: VideoPlayerViewModel
    let enhancementType: EnhancementType
    let onChangeVideo: (() -> Void)?
    let preferredHeightIPad: CGFloat?
    let trimStart: Double?
    let trimEnd: Double?
    let isProcessing: Bool
    let isShowingPaywall: Bool
    let processingState: EnhancementProcessingState

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isMuted: Bool = true
    
    // Debug tracking
    private let debugId = UUID().uuidString.prefix(8)
    @State private var viewAppearCount = 0
    @State private var viewDisappearCount = 0
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        VStack(spacing: 16) {
            EnhancementVideoPlayerView(
                playerViewModel: playerViewModel,
                isMuted: $isMuted,
                trimStart: trimStart,
                trimEnd: trimEnd,
                isProcessing: isProcessing,
                isShowingPaywall: isShowingPaywall,
                processingState: processingState
            )
                .frame(height: isIPad ? (preferredHeightIPad ?? 560) : (DeviceSize.isSmallPhone ? 280 : 340))
                .cornerRadius(DeviceSize.isSmallPhone ? 16 : 20)
                .overlay(
                    RoundedRectangle(cornerRadius: DeviceSize.isSmallPhone ? 16 : 20)
                        .stroke(Color.accentWarm.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: DeviceSize.isSmallPhone ? 10 : 15, x: 0, y: DeviceSize.isSmallPhone ? 6 : 8)
                .padding(.horizontal, DeviceSize.isSmallPhone ? 12 : 20)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                let frameHeight = isIPad ? (preferredHeightIPad ?? 560) : (DeviceSize.isSmallPhone ? 280 : 340)
                                let horizontalPadding = DeviceSize.isSmallPhone ? 12 : 20
                                print("DEBUG_PROCESS_REFACT: VideoPlayerView size - width: \(geo.size.width), height: \(geo.size.height)")
                                print("DEBUG_PROCESS_REFACT: VideoPlayerView frame height: \(frameHeight)")
                                print("DEBUG_PROCESS_REFACT: VideoPlayerView padding.horizontal: \(horizontalPadding)")
                            }
                    }
                )
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        print("DEBUG_PROCESS_REFACT: VideoPreviewSection VStack size - width: \(geo.size.width), height: \(geo.size.height)")
                        print("DEBUG_PROCESS_REFACT: VideoPreviewSection spacing: 16")
                    }
            }
        )
        .onAppear {
            viewAppearCount += 1
            print("📺 EnhancementVideoPreviewSection[🆔 \(debugId)] - onAppear #\(viewAppearCount)")
            print("  Enhancement: \(enhancementType.title)")
            print("  IsIPad: \(isIPad)")
            print("  Frame height: \(isIPad ? (preferredHeightIPad ?? 560) : (DeviceSize.isSmallPhone ? 280 : 340))")
            print("  PlayerViewModel available: \(playerViewModel != nil)")
            print("  Player state: \(playerViewModel.playerState)")
            print("  Player loading: \(playerViewModel.isLoading)")
            print("  Player error: \(playerViewModel.error?.localizedDescription ?? "none")")
            print("  Normal player available: \(playerViewModel.normalPlayer != nil)")
            print("  Enhanced player available: \(playerViewModel.enhancedPlayer != nil)")
            print("  Is playable: \(playerViewModel.isPlayable)")
            
            // Monitor player state changes
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                print("📺 EnhancementVideoPreviewSection[🆔 \(self.debugId)] - Status check:")
                print("  Player state: \(self.playerViewModel.playerState)")
                print("  Loading: \(self.playerViewModel.isLoading)")
                print("  Normal player: \(self.playerViewModel.normalPlayer != nil ? "✅" : "❌")")
                print("  Error: \(self.playerViewModel.error?.localizedDescription ?? "none")")
                
                // Stop monitoring once player is ready or error occurs
                if self.playerViewModel.normalPlayer != nil || self.playerViewModel.error != nil {
                    timer.invalidate()
                    print("📺 EnhancementVideoPreviewSection[🆔 \(self.debugId)] - Stopping status monitoring")
                }
            }
        }
        .onDisappear {
            viewDisappearCount += 1
            print("📺 EnhancementVideoPreviewSection[🆔 \(debugId)] - onDisappear #\(viewDisappearCount)")
        }
        .onAppear {
            playerViewModel.setMuted(isMuted)
        }
        .onChange(of: isMuted) { newValue in
            playerViewModel.setMuted(newValue)
        }
    }
}

// MARK: - Enhancement Video Player View
struct EnhancementVideoPlayerView: View {
    @ObservedObject var playerViewModel: VideoPlayerViewModel
    @Binding var isMuted: Bool
    let trimStart: Double?
    let trimEnd: Double?
    let isProcessing: Bool
    let isShowingPaywall: Bool
    let processingState: EnhancementProcessingState

    // Debug tracking
    private let debugId = UUID().uuidString.prefix(8)
    @State private var viewAppearCount = 0
    @State private var viewDisappearCount = 0

    // Check if any overlay is active
    private var isAnyOverlayActive: Bool {
        if isProcessing || isShowingPaywall {
            return true
        }

        switch processingState {
        case .preparing, .processing:
            return true
        default:
            return false
        }
    }

    var body: some View {
        Group {
            if let player = playerViewModel.normalPlayer {
                CustomVideoPlayerWithControls(
                    player: player,
                    isMuted: $isMuted,
                    videoGravity: .resizeAspect,
                    trimStart: trimStart,
                    trimEnd: trimEnd
                )
                    .onAppear {
                        viewAppearCount += 1
                        print("🎥 EnhancementVideoPlayerView[🆔 \(debugId)] - VideoPlayer onAppear #\(viewAppearCount)")
                        print("  Player available: true")
                        print("  Overlay active: \(isAnyOverlayActive)")

                        if !isAnyOverlayActive {
                            print("  Setting active...")
                            playerViewModel.setActive(true)
                        } else {
                            print("  Overlay active - setting inactive and pausing...")
                            playerViewModel.setActive(false)
                            playerViewModel.pause()
                        }
                        playerViewModel.setMuted(isMuted)
                    }
                    .onDisappear {
                        viewDisappearCount += 1
                        print("🎥 EnhancementVideoPlayerView[🆔 \(debugId)] - VideoPlayer onDisappear #\(viewDisappearCount)")
                        print("  Setting inactive...")
                        playerViewModel.setActive(false)
                    }
                    .onChange(of: isMuted) { newValue in
                        playerViewModel.setMuted(newValue)
                    }
                    .onChange(of: isProcessing) { processing in
                        if processing {
                            print("🎥 EnhancementVideoPlayerView[🆔 \(debugId)] - Processing started, pausing player")
                            playerViewModel.pause()
                            playerViewModel.setActive(false)
                        }
                    }
                    .onChange(of: isShowingPaywall) { showing in
                        if showing {
                            print("🎥 EnhancementVideoPlayerView[🆔 \(debugId)] - Paywall showing, pausing player")
                            playerViewModel.pause()
                            playerViewModel.setActive(false)
                        }
                    }
                    .onChange(of: processingState) { state in
                        if isAnyOverlayActive {
                            print("🎥 EnhancementVideoPlayerView[🆔 \(debugId)] - Processing state changed to \(state), overlay active, pausing player")
                            playerViewModel.pause()
                            playerViewModel.setActive(false)
                        }
                    }
            } else if let error = playerViewModel.error {
                EnhancementVideoErrorPlaceholder(error: error)
                    .onAppear {
                        print("🎥 EnhancementVideoPlayerView[🆔 \(debugId)] - Showing error placeholder")
                        print("  Error: \(error)")
                        print("  Player state: \(playerViewModel.playerState)")
                    }
            } else if playerViewModel.isLoading || playerViewModel.playerState == .loading {
                EnhancementVideoLoadingPlaceholder()
                    .onAppear {
                        print("🎥 EnhancementVideoPlayerView[🆔 \(debugId)] - Showing loading placeholder")
                        print("  Loading: \(playerViewModel.isLoading)")
                        print("  Player state: \(playerViewModel.playerState)")
                        print("  Normal player: \(playerViewModel.normalPlayer != nil ? "available" : "not available")")
                    }
            } else {
                // Fallback state - show loading instead of "No player available"
                EnhancementVideoLoadingPlaceholder()
                    .onAppear {
                        print("🎥 EnhancementVideoPlayerView[🆔 \(debugId)] - Fallback to loading state")
                        print("  Player available: \(playerViewModel.normalPlayer != nil)")
                        print("  Loading: \(playerViewModel.isLoading)")
                        print("  Error: \(playerViewModel.error?.localizedDescription ?? "none")")
                        print("  Player state: \(playerViewModel.playerState)")
                        print("  ⚠️ This may indicate a timing issue - showing loading as fallback")
                    }
            }
        }
        .onAppear {
            print("🎥 EnhancementVideoPlayerView[🆔 \(debugId)] - onAppear")
            print("  Player available: \(playerViewModel.normalPlayer != nil)")
            print("  Loading: \(playerViewModel.isLoading)")
            print("  Error: \(playerViewModel.error?.localizedDescription ?? "none")")
            print("  Player state: \(playerViewModel.playerState)")
            print("  Muted: \(isMuted)")
        }
    }
}

// MARK: - Enhancement Video Loading Placeholder
struct EnhancementVideoLoadingPlaceholder: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.3))
            
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                
                Text("Loading video...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

// MARK: - Enhancement Video Error Placeholder
struct EnhancementVideoErrorPlaceholder: View {
    let error: VideoPlayerError
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.red)
                
                Text(error.localizedDescription)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - View Modifiers
extension View {
    func errorAlert(error: EnhancementError?, onRetry: @escaping () -> Void) -> some View {
        self.alert(
            "Processing Error",
            isPresented: .constant(error != nil)
        ) {
            Button("Retry", action: onRetry)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(error?.localizedDescription ?? "Unknown error occurred")
        }
    }
    
    func processingOverlay(
        isPresenting: Bool,
        progress: Double,
        processingState: EnhancementProcessingState,
        onCancel: (() -> Void)? = nil
    ) -> some View {
        self.overlay(
            Group {
                if isPresenting {
                    EnhancementProcessingOverlay(
                        progress: progress,
                        processingState: processingState,
                        onCancel: onCancel
                    )
                }
            }
        )
    }
}

// MARK: - Processing Overlay
struct EnhancementProcessingOverlay: View {
    let progress: Double
    let processingState: EnhancementProcessingState
    let onCancel: (() -> Void)?
    @Environment(\.horizontalSizeClass) private var hSize
    private var isIPad: Bool { hSize == .regular }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .allowsHitTesting(true)

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: isIPad ? 10 : 8)
                        .frame(width: isIPad ? 180 : 120, height: isIPad ? 180 : 120)

                    Circle()
                        .trim(from: 0, to: max(0.0, min(1.0, progress)))
                        .stroke(
                            LinearGradient.primaryTheme,
                            style: StrokeStyle(lineWidth: isIPad ? 10 : 8, lineCap: .round)
                        )
                        .frame(width: isIPad ? 180 : 120, height: isIPad ? 180 : 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.25), value: progress)

                    Text("\(Int(max(0.0, min(1.0, progress)) * 100))%")
                        .font(.system(size: isIPad ? 30 : 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                Text(statusText)
                    .font(.system(size: isIPad ? 20 : 18, weight: .semibold))
                    .foregroundColor(.white)
                    .opacity(0.9)
                
                if let onCancel = onCancel, !isCompleted(processingState) {
                    Button(action: {
                        HapticFeedbackManager.impact(.medium)
                        onCancel()
                    }) {
                        Text("Cancel")
                            .font(.system(size: isIPad ? 18 : 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, isIPad ? 28 : 24)
                            .padding(.vertical, isIPad ? 14 : 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(0.8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .shadow(color: .black.opacity(0.3), radius: isIPad ? 6 : 4, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
    }

    private var statusText: String {
        switch processingState {
        case .preparing: return "Preparing..."
        case .processing(let phase): return phase.displayName
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        case .idle: return ""
        }
    }
    
    private func isCompleted(_ state: EnhancementProcessingState) -> Bool {
        if case .completed = state {
            return true
        }
        return false
    }
}

// MARK: - Enhancement Title Section
struct EnhancementTitleSection: View {
    let enhancementType: EnhancementType
    
    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                Text(enhancementType.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.accentWarm)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                
                Rectangle()
                    .fill(LinearGradient.primaryTheme)
                    .frame(width: 40, height: 2)
                    .cornerRadius(1)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                
                Text("Choose your enhancement level")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.accentWarm.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Enhancement Options View
struct EnhancementOptionsView: View {
    let enhancementType: EnhancementType
    let filteredOptions: [EnhancementOption]
    @Binding var selectedOption: String
    let isAnalyzing: Bool
    let onOptionSelected: (String) -> Void
    let onRequirePaywall: () -> Void
    @Environment(\.horizontalSizeClass) private var hSize
    private var isIPad: Bool { hSize == .regular }
    
    private var dynamicSubtitle: String {
//        switch enhancementType.id {
//        case "ai_upscale":
//            return "Choose upscaling level"
//        case "ai_denoise":
//            return "Choose denoise strength"
//        case "ai_auto_enhancement":
//            return "Choose enhancement strength"
//        case "stabilizer":
//            return "Choose stabilization level"
//        case "frame_interpolation":
//            return "Choose interpolation rate"
//        default:
//            return "Choose enhancement level"
//        }
        return "For \(enhancementType.name)"
    }
    
    var body: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            EnhancementSectionHeader(
                title: "Choose Enhancement Level",
                subtitle: dynamicSubtitle
            )
            .padding(.top, 8)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            print("DEBUG_PROCESS_REFACT: SectionHeader size - width: \(geo.size.width), height: \(geo.size.height)")
                            print("DEBUG_PROCESS_REFACT: SectionHeader padding.top: 8")
                        }
                }
            )

            HStack {
                Spacer()
                EnhancementOptionGrid(
                    options: filteredOptions,
                    selectedOption: selectedOption,
                    isAnalyzing: isAnalyzing,
                    onOptionSelected: onOptionSelected,
                    enhancementTypeId: enhancementType.id,
                    onRequirePaywall: onRequirePaywall
                )
                Spacer()
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        let spacing = isIPad ? 20 : 16
                        print("DEBUG_PROCESS_REFACT: OptionsView VStack size - width: \(geo.size.width), height: \(geo.size.height)")
                        print("DEBUG_PROCESS_REFACT: OptionsView spacing: \(spacing)")
                    }
            }
        )
    }
}

// MARK: - Enhancement Section Header
struct EnhancementSectionHeader: View {
    let title: String
    let subtitle: String
    @Environment(\.horizontalSizeClass) private var hSize
    private var isIPad: Bool { hSize == .regular }
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(title)
                .font(.system(size: isIPad ? 22 : 18, weight: .bold))
                .foregroundColor(.accentWarm)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
            
            Text(subtitle)
                .font(.system(size: isIPad ? 16 : 13, weight: .medium))
                .foregroundColor(.accentWarm.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

// MARK: - Enhancement Option Grid
struct EnhancementOptionGrid: View {
    let options: [EnhancementOption]
    let selectedOption: String
    let isAnalyzing: Bool
    let onOptionSelected: (String) -> Void
    let enhancementTypeId: String
    let onRequirePaywall: () -> Void
    @Environment(\.horizontalSizeClass) private var hSize
    private var isIPad: Bool { hSize == .regular }

    private var columnsCount: Int {
        if options.count <= 1 { return 1 }
        return isIPad ? 4 : 3
    }

    private var rowSpacing: CGFloat { isIPad ? 16 : 12 }
    private var itemSpacing: CGFloat { isIPad ? 16 : 12 }

    private var rows: [[EnhancementOption]] {
        guard columnsCount > 0 else { return [] }
        return stride(from: 0, to: options.count, by: columnsCount).map { start in
            let end = min(start + columnsCount, options.count)
            return Array(options[start..<end])
        }
    }

    var body: some View {
        VStack(spacing: rowSpacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                if row.count == columnsCount {
                    // Full row: distribute items evenly across width
                    HStack(spacing: itemSpacing) {
                        ForEach(row, id: \.id) { option in
                            let pro = isProOption(for: enhancementTypeId, optionId: option.id)
                            EnhancementOptionCard(
                                option: option,
                                isSelected: selectedOption == option.id,
                                isAnalyzing: isAnalyzing,
                                showsProBadge: false,
                                onTap: {
                                    onOptionSelected(option.id)
                                }
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                } else {
                    // Partial row: center items as a block
                    HStack(spacing: itemSpacing) {
                        Spacer(minLength: 0)
                        ForEach(row, id: \.id) { option in
                            let pro = isProOption(for: enhancementTypeId, optionId: option.id)
                            EnhancementOptionCard(
                                option: option,
                                isSelected: selectedOption == option.id,
                                isAnalyzing: isAnalyzing,
                                showsProBadge: false,
                                onTap: {
                                    onOptionSelected(option.id)
                                }
                            )
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        print("DEBUG_PROCESS_REFACT: OptionGrid size - width: \(geo.size.width), height: \(geo.size.height)")
                        print("DEBUG_PROCESS_REFACT: OptionGrid rowSpacing: \(rowSpacing), itemSpacing: \(itemSpacing)")
                        print("DEBUG_PROCESS_REFACT: OptionGrid columnsCount: \(columnsCount)")
                        print("DEBUG_PROCESS_REFACT: OptionGrid options count: \(options.count)")
                    }
            }
        )
    }
}

// MARK: - Enhancement Option Card
struct EnhancementOptionCard: View {
    let option: EnhancementOption
    let isSelected: Bool
    let isAnalyzing: Bool
    let showsProBadge: Bool
    let onTap: () -> Void
    @Environment(\.horizontalSizeClass) private var hSize
    private var isIPad: Bool { hSize == .regular }
    
    private var titleColor: Color {
        isSelected ? .white : Color.accentWarm
    }
    
    private var recommendedTextColor: Color {
        isSelected ? .white.opacity(0.9) : Color.accentWarm.opacity(0.7)
    }
    
    private var recommendedBackground: LinearGradient {
        if isSelected {
            return LinearGradient(colors: [Color.white.opacity(0.2)], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.47, blue: 0.47).opacity(0.3),
                    Color(red: 1.0, green: 0.596, blue: 0.329).opacity(0.3)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    private var cardBackground: LinearGradient {
        if isSelected {
            return LinearGradient.primaryTheme
        } else {
            return LinearGradient(colors: [Color.cardSoft], startPoint: .leading, endPoint: .trailing)
        }
    }
    
    private var strokeColor: Color {
        isSelected ? Color.white.opacity(0.2) : Color.accentWarm.opacity(0.3)
    }
    
    var body: some View {
        Button(action: {
            HapticFeedbackManager.impact(.medium)
            onTap()
        }) {
            VStack(spacing: 4) {
                Image(systemName: option.icon)
                    .font(.system(size: isIPad ? 20 : 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : Color.accentWarm)
                
                Text(option.title)
                    .font(.system(size: isIPad ? 14 : 12, weight: .bold, design: .rounded))
                    .foregroundColor(titleColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                if option.isRecommended {
                    Text("RECOMMENDED")
                        .font(.system(size: isIPad ? 8 : 6, weight: .bold))
                        .foregroundColor(recommendedTextColor)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(recommendedBackground)
                        )
                }
            }
            .frame(width: isIPad ? 96 : 64, height: isIPad ? 96 : 64)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(strokeColor, lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(isSelected ? 0.2 : 0.1), radius: isSelected ? 6 : 3, x: 0, y: isSelected ? 3 : 2)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            .overlay(
                // Analysis indicator
                Group {
                    if isAnalyzing && isSelected {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(isIPad ? 1.0 : 0.8)
                    }
                }
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

// Enhanced Pro badge component for enhancement and trimming contexts
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

// Helper consistent with classic view
private func isProOption(for enhancementTypeId: String, optionId: String) -> Bool {
    switch enhancementTypeId {
    case "ai_upscale":
        return optionId == "2K" || optionId == "4K"
    case "ai_denoise", "ai_auto_enhancement", "stabilizer":
        return optionId == "medium" || optionId == "high"
    default:
        return false
    }
}

// MARK: - Enhancement Action View
struct EnhancementActionView: View {
    let enhancementType: EnhancementType
    let selectedOption: String
    let canProcess: Bool
    let onProcess: () -> Void

    var body: some View {
        EnhancementProcessButton(
            enhancementType: enhancementType.title,
            selectedOption: selectedOption,
            canProcess: canProcess,
            onProcess: onProcess
        )
        .padding(.top, 12)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        print("DEBUG_PROCESS_REFACT: ActionView size - width: \(geo.size.width), height: \(geo.size.height)")
                        print("DEBUG_PROCESS_REFACT: ActionView padding.top: 12")
                    }
            }
        )
    }
}

// MARK: - Enhancement Process Button
struct EnhancementProcessButton: View {
    let enhancementType: String
    let selectedOption: String
    let canProcess: Bool
    let onProcess: () -> Void
    @Environment(\.horizontalSizeClass) private var hSize
    private var isIPad: Bool { hSize == .regular }
    
    var body: some View {
        Button(action: {
            HapticFeedbackManager.impact(.heavy)
            onProcess()
        }) {
            VStack(alignment: .center, spacing: 2) {
                Text("Process") // with \(enhancementType)
                    .font(.system(size: isIPad ? 20 : 18, weight: .semibold))
                    .foregroundColor(.white)

                if !selectedOption.isEmpty && !DeviceSize.isSmallPhone {
                    Text("Using \(selectedOption.capitalized) setting")
                        .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, isIPad ? 28 : 24)
            .padding(.vertical, isIPad ? 16 : (DeviceSize.isSmallPhone ? 12 : 14))
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            let horizontalPadding = isIPad ? 28 : 24
                            let verticalPadding = isIPad ? 16 : (DeviceSize.isSmallPhone ? 12 : 14)
                            let showingSubtitle = !selectedOption.isEmpty && !DeviceSize.isSmallPhone
                            print("DEBUG_PROCESS_REFACT: ProcessButton size - width: \(geo.size.width), height: \(geo.size.height)")
                            print("DEBUG_PROCESS_REFACT: ProcessButton isIPad: \(isIPad), isSmallPhone: \(DeviceSize.isSmallPhone)")
                            print("DEBUG_PROCESS_REFACT: ProcessButton padding - horizontal: \(horizontalPadding), vertical: \(verticalPadding)")
                            print("DEBUG_PROCESS_REFACT: ProcessButton showing subtitle: \(showingSubtitle)")
                            print("DEBUG_PROCESS_REFACT: ProcessButton canProcess: \(canProcess)")
                        }
                }
            )
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient.primaryTheme)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(
                        color: Color.black.opacity(0.15),
                        radius: isIPad ? 8 : 6,
                        x: 0,
                        y: 3
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!canProcess)
        .opacity(canProcess ? 1.0 : 0.7)
    }
}

// MARK: - Supporting Components
struct BackButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticFeedbackManager.impact(.light)
            action()
        }) {
            BackButtonIcon()
                .foregroundColor(.white)
        }
    }
}

struct CloseButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticFeedbackManager.impact(.medium)
            action()
        }) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.accentWarm)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.accentWarm.opacity(0.15))
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}


// MARK: - Haptic Feedback Manager
struct HapticFeedbackManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}


// MARK: - Preview
#if DEBUG
struct RefactoredEnhancementSelectionView_Previews: PreviewProvider {
    static var previews: some View {
       
            RefactoredEnhancementSelectionView(
                videoURL: URL(string: "https://example.com/video.mp4")!,
                enhancementType: EnhancementType.mockAIUpscale,
                trimStartTime: 5.0,
                trimEndTime: 15.0
            )
        
        .withDependencyInjection()
    }
}
#endif
