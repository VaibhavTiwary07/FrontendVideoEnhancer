import SwiftUI

struct HomeView: View {
    @Binding var selectedCarouselSegment: Int
    @Binding var isSidebarExpanded: Bool
    @Binding var isShowingPaywall: Bool
    @State private var showVideoPropertyList = false
    @State private var selectedVideoURL: URL?
    @EnvironmentObject var videoPlayerManager: VideoPlayerManager
    @State private var isHomeViewActive = false
    @State private var selectedEnhancement: Enhancement?
    @Environment(\.scenePhase) private var scenePhase
    @State private var showResumeOverlay = false
    @State private var needsResumeGate = false
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isCompactDevice: Bool {
        verticalSizeClass == .compact || horizontalSizeClass == .compact
    }

    struct Enhancement: Identifiable {
        let id = UUID()
        let type: String
        let icon: String
        let gradientType: GradientType
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Hero section: carousel with header overlaid so image starts at top
                        ZStack(alignment: .top) {
                            PageControlImageCarousel(currentPage: $selectedCarouselSegment)
                                .ignoresSafeArea(edges: .top)

                            HeaderView(
                                isSidebarExpanded: $isSidebarExpanded,
                                isShowingPaywall: $isShowingPaywall,
                                selectedCarouselSegment: $selectedCarouselSegment
                            )
                            .padding(.top, 6)
                        }
                        
                        // Spacing between carousel and enhancement cards
                        Spacer()
                            .frame(height: dynamicCarouselGap(screenHeight: geometry.size.height))
                        
                        // Enhancement Cards Section
                        VStack(spacing: 16) {
                            VStack(spacing: 16) {
                                Text("Enhancement Options")
                                    .font(.system(size: isCompactDevice ? 20 : 26, weight: .semibold))
                                    .foregroundColor(.primaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, dynamicHorizontalPadding(screenWidth: geometry.size.width))
                                    .padding(.top, dynamicTopPadding())
                                
                                VStack(spacing: dynamicCardSpacing(screenHeight: geometry.size.height)) {
                                    ImageComparisonCard(
                                        icon: "arrow.up.square",
                                        title: "AI Upscale",
                                        subtitle: "Enhance image resolution",
                                        gradientType: .cyanGray,
                                        beforeImageName: "Upscaler",
                                        afterImageName: "Upscaler"
                                    ) {
                                        selectedEnhancement = Enhancement(
                                            type: "AI Upscale",
                                            icon: "arrow.up.square",
                                            gradientType: .cyanGray
                                        )
                                    }
                                    
                                    ImageComparisonCard(
                                        icon: getIOSCompatibleSymbol("face.smiling", fallback: "person.crop.circle"),
                                        title: "Face & Object Enhancer",
                                        subtitle: "Improve facial features",
                                        gradientType: .redPink
                                    ) {
                                        selectedEnhancement = Enhancement(
                                            type: "Face & Object Enhancer",
                                            icon: getIOSCompatibleSymbol("face.smiling", fallback: "person.crop.circle"),
                                            gradientType: .redPink
                                        )
                                    }
                                    
                                    ImageComparisonCard(
                                        icon: "waveform.path",
                                        title: "AI Denoise",
                                        subtitle: "Remove grain and noise",
                                        gradientType: .pinkGray,
                                        beforeImageName: "AIDenoiseBefore",
                                        afterImageName: "AIDenoiseAfter"
                                    ) {
                                        selectedEnhancement = Enhancement(
                                            type: "AI Denoise",
                                            icon: "waveform.path",
                                            gradientType: .pinkGray
                                        )
                                    }
                                    
                                    ImageComparisonCard(
                                        icon: "paintpalette.fill",
                                        title: "AI Color",
                                        subtitle: "Color correction",
                                        gradientType: .yellowGray,
                                        beforeImageName: "AIColorisationBefore",
                                        afterImageName: "AIColorisationAfter"
                                    ) {
                                        selectedEnhancement = Enhancement(
                                            type: "AI Color",
                                            icon: "paintpalette.fill",
                                            gradientType: .yellowGray
                                        )
                                    }
                                    
                                    ImageComparisonCard(
                                        icon: "wand.and.stars",
                                        title: "AI Auto Enhancement",
                                        subtitle: "One-click improvements",
                                        gradientType: .purpleGray,
                                        beforeImageName: "AutoEnhacementBefore",
                                        afterImageName: "AutoEnhacementAfter"
                                    ) {
                                        selectedEnhancement = Enhancement(
                                            type: "AI Auto Enhancement",
                                            icon: "wand.and.stars",
                                            gradientType: .purpleGray
                                        )
                                    }
                                    
                                    ImageComparisonCard(
                                        icon: "gyroscope",
                                        title: "Stabilizer",
                                        subtitle: "Reduce camera shake",
                                        gradientType: .gray,
                                        useVideoComparison: true,
                                        originalVideoURL: Bundle.main.url(forResource: "StabilizationBefore", withExtension: "mp4"),
                                        processedVideoURL: Bundle.main.url(forResource: "StabilizationAfter", withExtension: "mp4"),
                                        videoPlayerManager: videoPlayerManager
                                    ) {
                                        selectedEnhancement = Enhancement(
                                            type: "Stabilizer",
                                            icon: "gyroscope",
                                            gradientType: .gray
                                        )
                                    }
                                    
                                    ImageComparisonCard(
                                        icon: getIOSCompatibleSymbol("timer.circle.fill", fallback: "timer"),
                                        title: "Frame Interpolation",
                                        subtitle: "Smooth motion",
                                        gradientType: .cyanGray,
                                        useVideoComparison: true,
                                        originalVideoURL: Bundle.main.url(forResource: "interpolation_Before", withExtension: "mp4"),
                                        processedVideoURL: Bundle.main.url(forResource: "interpolation_After", withExtension: "mp4"),
                                        videoPlayerManager: videoPlayerManager
                                    ) {
                                        selectedEnhancement = Enhancement(
                                            type: "Frame Interpolation",
                                            icon: getIOSCompatibleSymbol("timer.circle.fill", fallback: "timer"),
                                            gradientType: .cyanGray
                                        )
                                    }
                                }
                                .padding(.bottom, dynamicBottomPadding(screenHeight: geometry.size.height))
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 32)
                                .fill(Color.appBackground)
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
                        )
                        // Move cards up to overlap carousel and cover page indicator
                        
                        .zIndex(1)
                        .padding(.vertical, isCompactDevice ? 8 : 20)
                        .padding(.horizontal, isCompactDevice ? 0 : 8)
                        .offset(y: -100)
                    }
                }
            }
            
            // Floating Action Button
//            VStack {
//                Spacer()
//                HStack {
//                    Spacer()
//                    FloatingActionButton {
//                        showVideoPropertyList = true
//                    }
//                    .padding(.trailing, 20)
//                    .padding(.bottom, 20)
//                }
//            }
        }
        .sheet(isPresented: $showVideoPropertyList) {
            VideoPropertyListView()
        }
        // Ensure stabilizer and interpolation cards reinitialize after tab switches
        .onReceive(NotificationCenter.default.publisher(for: .homeTabBecameActive)) { _ in
            print("📣 HomeView: Received homeTabBecameActive; reinitializing comparison players")
            reinitializeComparisonPlayers(context: "homeTabBecameActive")
        }
        .onReceive(NotificationCenter.default.publisher(for: .homeResumeGateRequested)) { _ in
            needsResumeGate = true
            videoPlayerManager.pauseAllPlayers()
            if isHomeViewActive {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showResumeOverlay = true
                }
                print("🏠 HomeView received resume gate request; showing overlay")
            } else {
                print("🏠 HomeView received resume gate request; will show overlay on appear")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .homeAdRequested)) { _ in
            // Ensure no resume overlay remains; just show the interstitial
            withAnimation(.easeOut(duration: 0.2)) {
                showResumeOverlay = false
            }
            needsResumeGate = false
            if let presenter = UIHelpers.topViewController() {
                AdsManager.shared.showInterstitialAd(for: .homeButtonClick, from: presenter)
            } else if let rootVC = UIApplication.shared.connectedScenes
                        .compactMap({ $0 as? UIWindowScene })
                        .first?.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                AdsManager.shared.showInterstitialAd(for: .homeButtonClick, from: rootVC)
            } else {
                print("⚠️ HomeView: No presenter available for Home ad")
            }
        }
        .overlay(alignment: .center) {
            if showResumeOverlay {
                ZStack {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    VStack(spacing: 16) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(.white)

                        Text("Welcome Back")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Tap resume to continue")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.85))

                        Button(action: handleResumeTapped) {
                            Text("Resume")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(LinearGradient.primaryTheme)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.85))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(LinearGradient.primaryTheme.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)
                    .transition(.scale.combined(with: .opacity))
                }
                .zIndex(2)
            }
        }
        // VideoPickerView is removed from flow; direct picking happens in cards
        .onAppear {
            isHomeViewActive = true
            if needsResumeGate {
                videoPlayerManager.pauseAllPlayers()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showResumeOverlay = true
                }
                print("🏠 HomeView onAppear: resume gate active; showing overlay")
            } else {
                // Resume any players associated with visible comparison sliders
                videoPlayerManager.resumeActiveViewPlayers()
                print("🏠 HomeView onAppear: resuming players for active views")
            }
            reinitializeComparisonPlayers(context: "HomeView.onAppear prewarm")
        }
        .onDisappear {
            isHomeViewActive = false
            print("🏠 HomeView onDisappear")
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background:
                // Gate resume behind overlay when returning
                needsResumeGate = true
                videoPlayerManager.pauseAllPlayers()
                print("🏠 HomeView scenePhase → background; pausing and setting resume gate")
            case .active:
                if isHomeViewActive && needsResumeGate {
                    // Ensure nothing plays behind the overlay
                    videoPlayerManager.pauseAllPlayers()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showResumeOverlay = true
                    }
                    print("🏠 HomeView scenePhase → active; showing resume overlay")
                }
            default:
                break
            }
        }
    }

    // MARK: - Reinitialize video comparison players for Stabilizer and Interpolation
    private func reinitializeComparisonPlayers(context: String) {
        print("🔄 reinitializeComparisonPlayers invoked (context=\(context))")
        // Stabilizer
        if let stabOrig = Bundle.main.url(forResource: "StabilizationBefore", withExtension: "mp4"),
           let stabProc = Bundle.main.url(forResource: "StabilizationAfter", withExtension: "mp4") {
            let key = "Stabilizer"
            print("🔄 Setting up players for \(key) from bundle URLs")
            videoPlayerManager.setupVideoPlayers(forKey: key, originalURL: stabOrig, processedURL: stabProc)
            videoPlayerManager.setViewActive(forKey: key, isActive: true)
            videoPlayerManager.debugStatus(forKey: key, context: context)
        }

        // Frame Interpolation
        if let interpOrig = Bundle.main.url(forResource: "interpolation_Before", withExtension: "mp4"),
           let interpProc = Bundle.main.url(forResource: "interpolation_After", withExtension: "mp4") {
            let key = "Frame Interpolation"
            print("🔄 Setting up players for \(key) from bundle URLs")
            videoPlayerManager.setupVideoPlayers(forKey: key, originalURL: interpOrig, processedURL: interpProc)
            videoPlayerManager.setViewActive(forKey: key, isActive: true)
            videoPlayerManager.debugStatus(forKey: key, context: context)
        }
    }
    
    // MARK: - Dynamic Layout Helper Functions
    
    private func dynamicCarouselOverlapHeight(screenHeight: CGFloat) -> CGFloat {
        if isCompactDevice || screenHeight < 700 {
            return 200 // Smaller overlap for compact devices
        } else if screenHeight < 800 {
            return 220 // Medium overlap for standard phones
        } else {
            return 250 // Original overlap for larger screens
        }
    }
    
    private func dynamicHorizontalPadding(screenWidth: CGFloat) -> CGFloat {
        if screenWidth < 380 {
            return 16 // Smaller padding for very small screens
        } else {
            return 20 // Standard padding
        }
    }
    
    private func dynamicTopPadding() -> CGFloat {
        return isCompactDevice ? 12 : 20
    }
    
    private func dynamicCardSpacing(screenHeight: CGFloat) -> CGFloat {
        if isCompactDevice || screenHeight < 700 {
            return 20 // Increased from 14 to prevent overlapping
        } else if screenHeight < 900 {
            return 24 // Increased from 20 for better separation
        } else {
            return 32 // Increased from 28 for more breathing room on iPad/large screens
        }
    }

    private func dynamicCarouselHeight(screenHeight: CGFloat) -> CGFloat {
        if isCompactDevice || screenHeight < 700 { return 260 }
        if screenHeight < 900 { return 320 }
        return 380
    }

    private func dynamicCarouselGap(screenHeight: CGFloat) -> CGFloat {
        if isCompactDevice || screenHeight < 700 { return 16 }
        if screenHeight < 900 { return 24 }
        return 36
    }
    
    private func dynamicCardsOverlapOffset(screenHeight: CGFloat) -> CGFloat {
        if isCompactDevice || screenHeight < 700 { return 24 }
        if screenHeight < 900 { return 32 }
        return 40
    }
    
    
    private func dynamicBottomPadding(screenHeight: CGFloat) -> CGFloat {
        if isCompactDevice || screenHeight < 700 {
            return 60 // Less bottom padding for small screens
        } else if screenHeight < 800 {
            return 80 // Medium padding
        } else {
            return 100 // Original padding for larger screens
        }
    }
    
    private func getIOSCompatibleSymbol(_ preferredSymbol: String, fallback: String) -> String {
        if #available(iOS 16.0, *) {
            return preferredSymbol
        } else {
            return fallback
        }
    }

    private func handleResumeTapped() {
        // Try to show interstitial ad for resume event; if not loaded, proceed anyway
        if let presenter = UIHelpers.topViewController() {
            AdsManager.shared.showInterstitialAd(for: .resumeButtonClick, from: presenter)
        } else {
            print("⚠️ Unable to find presenter for resume ad; continuing without ad")
        }

        withAnimation(.easeOut(duration: 0.25)) {
            showResumeOverlay = false
        }
        needsResumeGate = false
        videoPlayerManager.resumeActiveViewPlayers()
        print("🏠 Resume tapped → ad requested, players resumed")
    }
}


//#Preview {
//    HomeView(videoPlayerManager: VideoPlayerManager())
//}
