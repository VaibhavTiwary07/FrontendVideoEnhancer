import SwiftUI
import Combine
import AVFoundation

struct EnhancementSelectionView: View {
    let videoURL: URL
    let enhancementType: String
    let enhancementIcon: String
    let gradientType: GradientType
    let trimStartTime: Double?
    let trimEndTime: Double?
    
    @StateObject private var selectionState = EnhancementSelectionState()
    @StateObject private var serverService = ServerEnhancementService()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var scrollOffset: CGFloat = 0
    @State private var isProcessing = false
    @State private var processingProgress: Double = 0.0
    @State private var processedVideoURL: URL?
    @State private var showingResults = false
    @State private var processingError: String?
    @State private var showingError = false
    @State private var isShowingPaywall = false
    @State private var processingTask: Task<Void, Never>?

    // Debug tracking
    private let debugId = UUID().uuidString.prefix(8)
    @State private var viewAppearCount = 0
    @State private var viewDisappearCount = 0
    @State private var videoPlayerVisibleCount = 0
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    private var isSmallScreen: Bool {
        let screenHeight = UIScreen.main.bounds.height
        return screenHeight <= 736
    }
    
    private var adaptivePreviewHeight: CGFloat {
        if isIPad {
            return 280
        } else if isSmallScreen {
            return 200
        } else {
            return 240
        }
    }
    
    private var adaptiveTopPadding: CGFloat {
        isSmallScreen ? 10 : 50
    }
    
    private var dynamicSubtitle: String {
        switch enhancementType {
        case "AI Upscale":
            return "Select upscaler level that best fits your video"
        case "AI Denoise":
            return "Select denoise level that best fits your video"
        case "AI Auto Enhancement":
            return "Select auto enhancement level that best fits your video"
        case "Stabilizer":
            return "Select stabilization level that best fits your video"
        case "Frame Interpolation":
            return "Select interpolation level that best fits your video"
        case "Face & Object Enhancer":
            return "Select enhancement level that best fits your video"
        case "AI Color":
            return "Select color enhancement level that best fits your video"
        default:
            return "Select the level that best fits your video"
        }
    }
    
    private var enhancementOptions: [EnhancementOption] {
        switch enhancementType {
        case "AI Upscale":
            return [
                EnhancementOption(id: "1080", title: "1080p", description: "Upscale to Full HD", icon: "tv.and.hifispeaker.fill", isRecommended: true),
                EnhancementOption(id: "2K", title: "2K", description: "Upscale to 2K", icon: "plus.magnifyingglass"),
                EnhancementOption(id: "4K", title: "4K", description: "Upscale to 4K", icon: "rectangle.expand.vertical")
            ]
        case "AI Denoise":
            return [
                EnhancementOption(id: "low", title: "Low", description: "Gentle noise reduction", icon: "waveform.path"),
                EnhancementOption(id: "medium", title: "Medium", description: "Balanced reduction", icon: "sparkles", isRecommended: true),
                EnhancementOption(id: "high", title: "High", description: "Aggressive removal", icon: "slider.horizontal.3")
            ]
        case "AI Auto Enhancement":
            return [
                EnhancementOption(id: "low", title: "Low", description: "Subtle improvements", icon: "dial.low"),
                EnhancementOption(id: "medium", title: "Medium", description: "Balanced enhancement", icon: "wand.and.stars", isRecommended: true),
                EnhancementOption(id: "high", title: "High", description: "Maximum enhancement", icon: "dial.high.fill")
            ]
        case "Stabilizer":
            return [
                EnhancementOption(id: "low", title: "Low", description: "Gentle stabilization", icon: "level"),
                EnhancementOption(id: "medium", title: "Medium", description: "Standard stabilization", icon: "gyroscope", isRecommended: true),
                EnhancementOption(id: "high", title: "High", description: "Aggressive stabilization", icon: "arrow.triangle.2.circlepath")
            ]
        case "Frame Interpolation":
            return [
                EnhancementOption(id: "smooth", title: "Smooth", description: "Enhanced motion smoothness", icon: "play.rectangle.fill", isRecommended: true),
                EnhancementOption(id: "fluid", title: "Fluid", description: "Ultra-smooth motion", icon: "forward.frame.fill")
            ]
        case "Face & Object Enhancer":
            return [
                EnhancementOption(id: "enhanced", title: "Enhanced", description: "Face and object enhancement", icon: "face.smiling", isRecommended: true)
            ]
        case "AI Color":
            return [
                EnhancementOption(id: "enhanced", title: "Enhanced", description: "Color enhancement", icon: "paintpalette", isRecommended: true)
            ]
        default:
            return []
        }
    }
    
    var body: some View {
        ZStack {
            Color.primarySoft
                .ignoresSafeArea()
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Header with spatial video preview
                        HeaderSection(
                            enhancementType: enhancementType,
                            enhancementIcon: enhancementIcon
                        )
                        .id("header")
                        .padding(.top, 20)
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear {
                                        print("📐 EnhancementSelectionView[\(debugId)] - HeaderSection frame: \(geo.size)")
                                        print("DEBUG_PROCESSBUTTON: HeaderSection size - width: \(geo.size.width), height: \(geo.size.height)")
                                        print("DEBUG_PROCESSBUTTON: HeaderSection padding.top: 20")
                                    }
                            }
                        )
                        
                        // Spatial video preview
                        SpatialVideoPreview(
                            videoURL: videoURL,
                            enhancementType: enhancementType,
                            trimStartTime: trimStartTime,
                            trimEndTime: trimEndTime
                        )
                        .frame(height: adaptivePreviewHeight)
                        .padding(.top, 20)
                        .onAppear {
                            videoPlayerVisibleCount += 1
                            print("📺 EnhancementSelectionView[\(debugId)] - SpatialVideoPreview appeared #\(videoPlayerVisibleCount)")
                            print("  Frame height: \(adaptivePreviewHeight)")
                        }
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear {
                                        print("📐 EnhancementSelectionView[\(debugId)] - SpatialVideoPreview frame: \(geo.size)")
                                        print("  Expected height: \(adaptivePreviewHeight)")
                                        print("DEBUG_PROCESSBUTTON: SpatialVideoPreview size - width: \(geo.size.width), height: \(geo.size.height)")
                                        print("DEBUG_PROCESSBUTTON: SpatialVideoPreview expected height: \(adaptivePreviewHeight)")
                                        print("DEBUG_PROCESSBUTTON: SpatialVideoPreview padding.top: 20")
                                    }
                                    .onChange(of: geo.size) { newSize in
                                        print("📐 EnhancementSelectionView[\(debugId)] - SpatialVideoPreview frame changed: \(newSize)")
                                        if newSize.height != adaptivePreviewHeight {
                                            print("  ⚠️ Height mismatch! Expected: \(adaptivePreviewHeight), Actual: \(newSize.height)")
                                        }
                                        print("DEBUG_PROCESSBUTTON: SpatialVideoPreview size changed - width: \(newSize.width), height: \(newSize.height)")
                                    }
                            }
                        )
                        
                        // Enhancement options section
                        VStack(spacing: 16) {
                            SectionHeader(
                                title: "Choose Enhancement Level",
                                subtitle: dynamicSubtitle
                            )
                            .padding(.horizontal, 20)
                            .padding(.top, adaptiveTopPadding)
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .onAppear {
                                            print("DEBUG_PROCESSBUTTON: SectionHeader size - width: \(geo.size.width), height: \(geo.size.height)")
                                            print("DEBUG_PROCESSBUTTON: SectionHeader padding.top: \(adaptiveTopPadding)")
                                        }
                                }
                            )
                            
                            // Enhancement options centered grid (handles single, partial, full rows)
                            Group {
                                let columnsCount = enhancementOptions.count <= 1 ? 1 : (isIPad ? 4 : 3)
                                let rows: [[EnhancementOption]] = stride(from: 0, to: enhancementOptions.count, by: columnsCount).map { start in
                                    let end = min(start + columnsCount, enhancementOptions.count)
                                    return Array(enhancementOptions[start..<end])
                                }
                                VStack(spacing: 12) {
                                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                                        if row.count == columnsCount {
                                            HStack(spacing: 12) {
                                                ForEach(row, id: \.id) { option in
                                                    let pro = isProOption(for: enhancementType, optionId: option.id)
                                                    OptionCard(
                                                        option: option,
                                                        isSelected: selectionState.selectedOption == option.id,
                                                        showsProBadge: pro && !SubscriptionManager.shared.isAppSubscribed(),
                                                        onTap: {
                                                            if pro && !SubscriptionManager.shared.isAppSubscribed() {
                                                                isShowingPaywall = true
                                                            } else {
                                                                selectionState.updateSelection(option.id)
                                                            }
                                                        }
                                                    )
                                                    .frame(maxWidth: .infinity)
                                                }
                                            }
                                        } else {
                                            HStack(spacing: 12) {
                                                Spacer(minLength: 0)
                                                ForEach(row, id: \.id) { option in
                                                    let pro = isProOption(for: enhancementType, optionId: option.id)
                                                    OptionCard(
                                                        option: option,
                                                        isSelected: selectionState.selectedOption == option.id,
                                                        showsProBadge: pro && !SubscriptionManager.shared.isAppSubscribed(),
                                                        onTap: {
                                                            if pro && !SubscriptionManager.shared.isAppSubscribed() {
                                                                isShowingPaywall = true
                                                            } else {
                                                                selectionState.updateSelection(option.id)
                                                            }
                                                        }
                                                    )
                                                }
                                                Spacer(minLength: 0)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .onAppear {
                                            print("DEBUG_PROCESSBUTTON: OptionsGrid size - width: \(geo.size.width), height: \(geo.size.height)")
                                            print("DEBUG_PROCESSBUTTON: OptionsGrid padding.horizontal: 20")
                                        }
                                }
                            )


                            // Process button
                            ProcessButton(
                                enhancementType: enhancementType,
                                selectedOption: selectionState.selectedOption,
                                isSmallScreen: isSmallScreen,
                                onProcess: {
                                    processVideo()
                                }
                            )
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, isSmallScreen ? 120 : 30)
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .onAppear {
                                            let bottomPadding = isSmallScreen ? 120 : 30
                                            print("DEBUG_PROCESSBUTTON: ProcessButton with padding size - width: \(geo.size.width), height: \(geo.size.height)")
                                            print("DEBUG_PROCESSBUTTON: ProcessButton padding - horizontal: 20, top: 20, bottom: \(bottomPadding)")
                                        }
                                }
                            )
                        }
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear {
                                        print("DEBUG_PROCESSBUTTON: Entire options VStack size - width: \(geo.size.width), height: \(geo.size.height)")
                                        print("DEBUG_PROCESSBUTTON: VStack spacing: 16")
                                    }
                            }
                        )
                    }
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear {
                                    print("DEBUG_PROCESSBUTTON: ========================")
                                    print("DEBUG_PROCESSBUTTON: LazyVStack (all content) size - width: \(geo.size.width), height: \(geo.size.height)")
                                    print("DEBUG_PROCESSBUTTON: LazyVStack spacing: 0")
                                    print("DEBUG_PROCESSBUTTON: ========================")
                                }
                        }
                    )
                }
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                let screenBounds = UIScreen.main.bounds
                                let window = UIApplication.shared.connectedScenes
                                    .compactMap { $0 as? UIWindowScene }
                                    .flatMap { $0.windows }
                                    .first { $0.isKeyWindow }
                                let safeAreaInsets = window?.safeAreaInsets ?? .zero
                                print("DEBUG_PROCESSBUTTON: ========================")
                                print("DEBUG_PROCESSBUTTON: ScrollView viewport size - width: \(geometry.size.width), height: \(geometry.size.height)")
                                print("DEBUG_PROCESSBUTTON: ScrollView visible height (excluding safe area): \(screenBounds.height - safeAreaInsets.top - safeAreaInsets.bottom)")
                                print("DEBUG_PROCESSBUTTON: ========================")
                            }
                            .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                    }
                )
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
            }
            
            // Full-screen processing overlay
            if isProcessing {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Custom circular progress with orange gradient
                    ZStack {
                        // Background track
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 8)
                            .frame(width: 120, height: 120)
                        
                        // Progress circle with gradient
                        Circle()
                            .trim(from: 0, to: getCurrentProgress())
                            .stroke(
                                LinearGradient.primaryTheme,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.3), value: getCurrentProgress())
                        
                        // Percentage text inside circle
                        Text("\(Int(getCurrentProgress() * 100))%")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    Text(getCurrentStatus())
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .opacity(0.9)
                    
                    // Cancel button
                    if isProcessing {
                        Button("Cancel") {
                            cancelProcessing()
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.7))
                        )
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingPaywall) {
            PaywallView(isPresented: $isShowingPaywall)
        }
        .navigationBarBackButtonHidden()
        .navigationBarItems(
            leading: Button(action: {
                print("DEBUG_PROCESSING_BACK: EnhancementSelectionView - Back button tapped")
                print("DEBUG_PROCESSING_BACK: EnhancementSelectionView - isProcessing=\(isProcessing), processingTask=\(processingTask != nil ? "EXISTS" : "NIL")")
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                print("DEBUG_PROCESSING_BACK: EnhancementSelectionView - Calling dismiss()")
                dismiss()
                print("DEBUG_PROCESSING_BACK: EnhancementSelectionView - dismiss() returned")
            }) {
                BackButtonIcon()
                    .foregroundColor(.white)
            },
            trailing: HStack(spacing: 16) {
                // Enhanced step indicator
                VStack(spacing: 4) {
                    // Progress dots with connecting lines
                    HStack(spacing: 8) {
                        ForEach(1...4, id: \.self) { step in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(step <= 3 ? Color.accentWarm : Color.accentWarm.opacity(0.3))
                                    .frame(width: step == 3 ? 10 : 8, height: step == 3 ? 10 : 8)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.accentWarm, lineWidth: step == 3 ? 2 : 1)
                                            .opacity(step == 3 ? 1 : 0.5)
                                    )
                                
                                // Connecting line (except for last step)
                                if step < 4 {
                                    Rectangle()
                                        .fill(step < 3 ? Color.accentWarm : Color.accentWarm.opacity(0.3))
                                        .frame(width: 12, height: 2)
                                        .cornerRadius(1)
                                }
                            }
                        }
                    }
                    
                    Text("Step 3 of 4")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.accentWarm)
                }
                
                // Close button
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    dismiss()
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
        )
        // If a global go-home is requested, dismiss this screen too
        .onReceive(NotificationCenter.default.publisher(for: .goHomeRequested)) { _ in
            dismiss()
        }
        .onAppear {
            viewAppearCount += 1
            print("🎭 EnhancementSelectionView[\(debugId)] - onAppear #\(viewAppearCount)")
            print("  Enhancement: \(enhancementType)")
            print("  Video URL: \(videoURL.lastPathComponent)")
            print("  Trim: \(trimStartTime ?? -1)s to \(trimEndTime ?? -1)s")
            print("  IsIPad: \(isIPad)")
            print("  Adaptive height: \(adaptivePreviewHeight)")
            print("  Options count: \(enhancementOptions.count)")

            // DEBUG: Screen dimensions
            let screenBounds = UIScreen.main.bounds
            let window = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
            let safeAreaInsets = window?.safeAreaInsets ?? .zero
            print("DEBUG_PROCESSBUTTON: Screen width: \(screenBounds.width), height: \(screenBounds.height)")
            print("DEBUG_PROCESSBUTTON: isSmallScreen: \(isSmallScreen)")
            print("DEBUG_PROCESSBUTTON: Safe area - top: \(safeAreaInsets.top), bottom: \(safeAreaInsets.bottom), left: \(safeAreaInsets.left), right: \(safeAreaInsets.right)")
            print("DEBUG_PROCESSBUTTON: Adaptive preview height: \(adaptivePreviewHeight)")
            print("DEBUG_PROCESSBUTTON: Adaptive top padding: \(adaptiveTopPadding)")

            SubscriptionManager.shared.checkSubscriptionExpiry()
            
            // Set default selection, respecting PRO gating for unsubscribed users
            let isSubscribed = SubscriptionManager.shared.isAppSubscribed()
            print("  User subscribed: \(isSubscribed)")
            
            if let recommended = enhancementOptions.first(where: { $0.isRecommended }) {
                print("  Found recommended option: \(recommended.title)")
                if !isSubscribed && isProOption(for: enhancementType, optionId: recommended.id) {
                    print("  Recommended is PRO, looking for free option")
                    // Pick first non-PRO option
                    if let free = enhancementOptions.first(where: { !isProOption(for: enhancementType, optionId: $0.id) }) {
                        selectionState.selectedOption = free.id
                        print("  Selected free option: \(free.title)")
                    } else {
                        selectionState.selectedOption = recommended.id
                        print("  No free option, using recommended: \(recommended.title)")
                    }
                } else {
                    selectionState.selectedOption = recommended.id
                    print("  Selected recommended option: \(recommended.title)")
                }
            } else if let first = enhancementOptions.first {
                selectionState.selectedOption = first.id
                print("  No recommended, selected first option: \(first.title)")
            }

            // If this enhancement has only one option (e.g., Face/Object or AI Color), auto-start processing
            if enhancementOptions.count == 1 {
                print("  Auto-starting processing for single option")
                processVideo()
            }
            
            print("  onAppear completed")
        }
        .onDisappear {
            viewDisappearCount += 1
            print("DEBUG_PROCESSING_BACK: ========================================")
            print("DEBUG_PROCESSING_BACK: EnhancementSelectionView.onDisappear - ENTERED #\(viewDisappearCount)")
            print("DEBUG_PROCESSING_BACK: EnhancementSelectionView.onDisappear - isProcessing=\(isProcessing)")
            print("DEBUG_PROCESSING_BACK: EnhancementSelectionView.onDisappear - processingProgress=\(processingProgress)")
            print("DEBUG_PROCESSING_BACK: EnhancementSelectionView.onDisappear - processingTask=\(processingTask != nil ? "EXISTS" : "NIL")")
            print("DEBUG_PROCESSING_BACK: EnhancementSelectionView.onDisappear - processedVideoURL=\(processedVideoURL != nil ? "EXISTS" : "NIL")")

            // Cancel ongoing processing
            if let task = processingTask {
                print("DEBUG_PROCESSING_BACK: EnhancementSelectionView.onDisappear - Cancelling processingTask, isCancelled=\(task.isCancelled)")
                task.cancel()
                print("DEBUG_PROCESSING_BACK: EnhancementSelectionView.onDisappear - After cancel(), isCancelled=\(task.isCancelled)")
                processingTask = nil
                print("DEBUG_PROCESSING_BACK: EnhancementSelectionView.onDisappear - processingTask set to nil")
            } else {
                print("DEBUG_PROCESSING_BACK: EnhancementSelectionView.onDisappear - No processingTask to cancel")
            }

            // Cancel server service operations
            print("DEBUG_PROCESSING_BACK: EnhancementSelectionView.onDisappear - Calling serverService.cancelProcessing()")
            Task {
                await serverService.cancelProcessing()
                print("DEBUG_PROCESSING_BACK: EnhancementSelectionView.onDisappear - serverService.cancelProcessing() completed")
            }

            // Reset state
            print("DEBUG_PROCESSING_BACK: EnhancementSelectionView.onDisappear - Resetting state flags")
            isProcessing = false
            processingProgress = 0.0
            processedVideoURL = nil

            print("DEBUG_PROCESSING_BACK: EnhancementSelectionView.onDisappear - COMPLETED")
            print("DEBUG_PROCESSING_BACK: ========================================")
        }
        .fullScreenCover(isPresented: $showingResults) {
            if let processedURL = processedVideoURL {
                VideoResultsView(
                    originalVideoURL: videoURL,
                    processedVideoURL: processedURL,
                    enhancementType: enhancementType,
                    enhancementIcon: enhancementIcon,
                    gradientType: gradientType
                )
            }
        }
        .alert("Processing Error", isPresented: $showingError) {
            Button("Retry") { 
                retryProcessing()
            }
            Button("Cancel", role: .cancel) { 
                processingError = nil
            }
        } message: {
            Text(processingError ?? "Unknown error occurred")
        }
        .onChange(of: showingResults) { newValue in
            if !newValue {
                isProcessing = false
                processingProgress = 0.0
            }
        }
        .onReceive(serverService.progressPublisher) { prog in
            print("DEBUG_PROCESSING_BACK: EnhancementSelectionView - Progress update received: \(prog)")
            processingProgress = prog
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentProgress() -> Double { processingProgress }
    
    private func getCurrentStatus() -> String { isProcessing ? "Processing Video..." : "" }
    
    private func cancelProcessing() {
        print("DEBUG_PROCESSING_BACK: EnhancementSelectionView.cancelProcessing() - CALLED")
        print("DEBUG_PROCESSING_BACK: cancelProcessing() - isProcessing=\(isProcessing), processingTask=\(processingTask != nil ? "EXISTS" : "NIL")")

        // Cancel the processing task
        if let task = processingTask {
            print("DEBUG_PROCESSING_BACK: cancelProcessing() - Cancelling processingTask")
            task.cancel()
            processingTask = nil
        } else {
            print("DEBUG_PROCESSING_BACK: cancelProcessing() - No processingTask to cancel")
        }

        // Cancel server service operations
        print("DEBUG_PROCESSING_BACK: cancelProcessing() - Calling serverService.cancelProcessing()")
        Task {
            await serverService.cancelProcessing()
            print("DEBUG_PROCESSING_BACK: cancelProcessing() - serverService.cancelProcessing() completed")
        }

        // Reset state
        print("DEBUG_PROCESSING_BACK: cancelProcessing() - Resetting state")
        isProcessing = false
        processingProgress = 0.0
        print("DEBUG_PROCESSING_BACK: EnhancementSelectionView.cancelProcessing() - COMPLETED")
    }
    
    private func retryProcessing() {
        // Clear previous error
        processingError = nil
        showingError = false
        
        // Start processing again
        processVideo()
    }
    
    private func processVideo() {
        // Add haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
        
        // Debug: Log processing data
        print("🎭 EnhancementSelectionView - Processing with:")
        print("   trimStartTime: \(trimStartTime ?? -1)")
        print("   trimEndTime: \(trimEndTime ?? -1)")
        print("   enhancementType: \(enhancementType)")
        print("   enhancementOption: \(selectionState.selectedOption)")
        
        isProcessing = true
        processingProgress = 0.0

        print("DEBUG_PROCESSING_BACK: EnhancementSelectionView.processVideo() - Creating Task")
        // Store task reference for cancellation
        processingTask = Task {
            print("DEBUG_PROCESSING_BACK: processVideo() - Task STARTED")
            do {
                let typeId: String
                switch enhancementType {
                case "AI Auto Enhancement": typeId = "ai_auto_enhancement"
                case "AI Denoise": typeId = "ai_denoise"
                case "Face & Object Enhancer": typeId = "face_enhancer"
                case "AI Color": typeId = "ai_color"
                case "Stabilizer": typeId = "stabilizer"
                case "Frame Interpolation": typeId = "frame_interpolation"
                case "AI Upscale": typeId = "ai_upscale"
                default: typeId = "ai_auto_enhancement"
                }
                let type = EnhancementType(
                    id: typeId,
                    name: enhancementType,
                    description: "",
                    icon: enhancementIcon,
                    options: enhancementOptions,
                    gradientType: gradientType
                )
                let selected = enhancementOptions.first { $0.id == selectionState.selectedOption } ?? enhancementOptions.first!
                let request = EnhancementRequest(
                    enhancementType: type,
                    selectedOption: selected,
                    trimStartTime: trimStartTime,
                    trimEndTime: trimEndTime
                )
                print("DEBUG_PROCESSING_BACK: processVideo() - Calling serverService.processVideo()")
                let result = try await serverService.processVideo(at: videoURL, with: request)
                print("DEBUG_PROCESSING_BACK: processVideo() - serverService.processVideo() returned")

                // Check if task was cancelled before updating UI
                guard !Task.isCancelled else {
                    print("DEBUG_PROCESSING_BACK: processVideo() - Task.isCancelled=true, skipping result update")
                    await MainActor.run {
                        isProcessing = false
                    }
                    return
                }

                print("DEBUG_PROCESSING_BACK: processVideo() - Task not cancelled, updating UI with result")
                await MainActor.run {
                    processedVideoURL = result.processedURL
                    isProcessing = false
                    showingResults = true
                    print("DEBUG_PROCESSING_BACK: processVideo() - UI updated, showingResults=true")
                }
            } catch is CancellationError {
                // Task was cancelled
                print("DEBUG_PROCESSING_BACK: processVideo() - CancellationError caught")
                await MainActor.run {
                    isProcessing = false
                    print("DEBUG_PROCESSING_BACK: processVideo() - isProcessing set to false after cancellation")
                }
            } catch {
                print("DEBUG_PROCESSING_BACK: processVideo() - Error caught: \(error.localizedDescription)")
                await MainActor.run {
                    processingError = error.localizedDescription
                    showingError = true
                    isProcessing = false
                    print("DEBUG_PROCESSING_BACK: processVideo() - Error state set")
                }
            }
            print("DEBUG_PROCESSING_BACK: processVideo() - Task COMPLETED/EXITED")
        }
        print("DEBUG_PROCESSING_BACK: EnhancementSelectionView.processVideo() - Task created and stored")
    }
}

struct HeaderSection: View {
    let enhancementType: String
    let enhancementIcon: String
    
    var body: some View {
        VStack(spacing: 12) {
            // Clean minimal header with gradient accent
            VStack(spacing: 8) {
                Text(enhancementType)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.accentWarm)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                
                // Decorative gradient line
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

struct SectionHeader: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.accentWarm)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
            
            Text(subtitle)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.accentWarm.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

struct ProcessButton: View {
    let enhancementType: String
    let selectedOption: String
    let isSmallScreen: Bool
    let onProcess: () -> Void

    var body: some View {
        Button(action: onProcess) {
            VStack(alignment: .center, spacing: 2) {
                Text("Process")// with \(enhancementType)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                if !selectedOption.isEmpty && !isSmallScreen {
                    Text("Using \(selectedOption.capitalized) setting")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, isSmallScreen ? 14 : 18)
            .frame(width: UIScreen.main.bounds.width * (isSmallScreen ? 0.60 : 0.68))
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            let screenWidth = UIScreen.main.bounds.width
                            let buttonWidthPercent = isSmallScreen ? 0.60 : 0.68
                            let calculatedWidth = screenWidth * buttonWidthPercent
                            let verticalPadding = isSmallScreen ? 14 : 18
                            print("DEBUG_PROCESSBUTTON: ProcessButton size - width: \(geo.size.width), height: \(geo.size.height)")
                            print("DEBUG_PROCESSBUTTON: ProcessButton isSmallScreen: \(isSmallScreen)")
                            print("DEBUG_PROCESSBUTTON: ProcessButton calculated width: \(calculatedWidth) (\(buttonWidthPercent * 100)% of \(screenWidth))")
                            print("DEBUG_PROCESSBUTTON: ProcessButton padding - horizontal: 24, vertical: \(verticalPadding)")
                            print("DEBUG_PROCESSBUTTON: ProcessButton showing subtitle: \(!selectedOption.isEmpty && !isSmallScreen)")
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
                        radius: 6,
                        x: 0,
                        y: 3
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(selectedOption.isEmpty)
        .opacity(selectedOption.isEmpty ? 0.7 : 1.0)
    }
}

// MARK: - State Management

class EnhancementSelectionState: ObservableObject {
    @Published var selectedOption: String = ""
    @Published var isAnalyzing: Bool = false
    
    func updateSelection(_ option: String) {
        selectedOption = option
        
        // Simulate analysis
        isAnalyzing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isAnalyzing = false
        }
    }
}

// MARK: - Option Card Component

struct OptionCard: View {
    let option: EnhancementOption
    let isSelected: Bool
    let showsProBadge: Bool
    let onTap: () -> Void
    
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
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            onTap()
        }) {
            VStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? .white : Color.accentWarm)
                
                Text(option.title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(titleColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                
                if option.isRecommended {
                    Text("RECOMMENDED")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(recommendedTextColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(recommendedBackground)
                        )
                }
            }
            .frame(width: 70, height: 70)
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

// Small gradient PRO pill styled like header, without icon
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
            .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
    }
}

// Helper to determine which options are PRO-gated
private func isProOption(for enhancementType: String, optionId: String) -> Bool {
    switch enhancementType {
    case "AI Upscale":
        return optionId == "2K" || optionId == "4K"
    case "AI Denoise", "AI Auto Enhancement", "Stabilizer":
        return optionId == "medium" || optionId == "high"
    default:
        return false
    }
}

// MARK: - Preference Keys

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    NavigationView {
        EnhancementSelectionView(
            videoURL: URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!,
            enhancementType: "AI Upscale",
            enhancementIcon: "arrow.up.square",
            gradientType: .redPink,
            trimStartTime: 5.0,
            trimEndTime: 15.0
        )
    }
}
