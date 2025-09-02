import SwiftUI

struct HomeView: View {
    @State private var showVideoPropertyList = false
    @State private var selectedVideoURL: URL?
    @EnvironmentObject var videoPlayerManager: VideoPlayerManager
    @State private var isHomeViewActive = false
    @State private var selectedEnhancement: Enhancement?
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
                        // Top Carousel Section (Full Width)
                        PageControlImageCarousel()
                            .frame(height: 280)
                        
                        // Spacing between carousel and enhancement cards
                        Spacer()
                            .frame(height: 20)
                        
                        // Enhancement Cards Section
                        VStack(spacing: 16) {
                            VStack(spacing: 16) {
                                Text("Enhancement Options")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.primaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, dynamicHorizontalPadding(screenWidth: geometry.size.width))
                                    .padding(.top, dynamicTopPadding())
                                
                                VStack(spacing: dynamicCardSpacing(screenHeight: geometry.size.height)) {
                                    ImageComparisonCard(
                                        icon: "arrow.up.square",
                                        title: "AI Upscale",
                                        subtitle: "Enhance image resolution",
                                        gradientType: .cyanGray
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
                                        originalVideoURL: Bundle.main.url(forResource: "StablilizationBefore", withExtension: "mp4"),
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
        .fullScreenCover(item: $selectedEnhancement) { enhancement in
            VideoPickerView(
                enhancementType: enhancement.type,
                enhancementIcon: enhancement.icon,
                gradientType: enhancement.gradientType
            )
        }
        .onAppear {
            isHomeViewActive = true
            // Resume any players associated with visible comparison sliders
            videoPlayerManager.resumeActiveViewPlayers()
            print("🏠 HomeView onAppear: resuming players for active views")

            // Prewarm and reactivate Stabilizer and Frame Interpolation players with stable keys
            if let stabOrig = Bundle.main.url(forResource: "StablilizationBefore", withExtension: "mp4"),
               let stabProc = Bundle.main.url(forResource: "StabilizationAfter", withExtension: "mp4") {
                let key = "Stabilizer"
                videoPlayerManager.setupVideoPlayers(forKey: key, originalURL: stabOrig, processedURL: stabProc)
                videoPlayerManager.setViewActive(forKey: key, isActive: true)
                videoPlayerManager.debugStatus(forKey: key, context: "HomeView.onAppear prewarm")
            }

            if let interpOrig = Bundle.main.url(forResource: "interpolation_Before", withExtension: "mp4"),
               let interpProc = Bundle.main.url(forResource: "interpolation_After", withExtension: "mp4") {
                let key = "Frame Interpolation"
                videoPlayerManager.setupVideoPlayers(forKey: key, originalURL: interpOrig, processedURL: interpProc)
                videoPlayerManager.setViewActive(forKey: key, isActive: true)
                videoPlayerManager.debugStatus(forKey: key, context: "HomeView.onAppear prewarm")
            }
        }
        .onDisappear {
            isHomeViewActive = false
            print("🏠 HomeView onDisappear")
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
            return 10 // Tighter spacing for compact devices
        } else {
            return 16 // Standard spacing
        }
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
}


//#Preview {
//    HomeView(videoPlayerManager: VideoPlayerManager())
//}
