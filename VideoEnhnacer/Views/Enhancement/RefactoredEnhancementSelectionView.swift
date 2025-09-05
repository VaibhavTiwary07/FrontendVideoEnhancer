import SwiftUI
import Combine

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
    
    // MARK: - Initialization
    init(
        videoURL: URL,
        enhancementType: EnhancementType,
        trimStartTime: Double? = nil,
        trimEndTime: Double? = nil
    ) {
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
    var body: some View {
        ZStack {
            Color.primarySoft
                .ignoresSafeArea()
            
            contentView
                .navigationBarBackButtonHidden()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { navigationToolbar }
        }
        // If a global go-home is requested, dismiss this screen too
        .onReceive(NotificationCenter.default.publisher(for: .goHomeRequested)) { _ in
            dismiss()
        }
        .onAppear { handleViewAppearance() }
        .onAppear {
            // If only one option exists (e.g., Face/Object or AI Color), auto-start processing
            if viewModel.enhancementType.options.count == 1 && !viewModel.isProcessing && viewModel.result == nil {
                // Ensure a selection exists (default is set in VM init)
                viewModel.processVideo()
            }
        }
        .onDisappear {
            // Do not cleanup the shared player service here; it wipes all players, including Trimming's
            // Only clear this view's processing pipeline
            viewModel.cleanup()
        }
        .fullScreenCover(isPresented: $showingResults) { resultsView }
        .errorAlert(error: viewModel.error) { viewModel.retryProcessing() }
        .processingOverlay(
            isPresenting: viewModel.isProcessing,
            progress: viewModel.progress,
            processingState: viewModel.processingState,
            onCancel: { viewModel.cancelProcessing() }
        )
        .onChange(of: viewModel.result) { result in
            if result != nil { showingResults = true }
        }
    }
    
    // MARK: - Content Views
    @ViewBuilder
    private var contentView: some View {
        GeometryReader { geo in
            // Layout without scroll; fit within available height
            VStack(spacing: 8) {
                Spacer()
                SpatialVideoPreview(
                    videoURL: viewModel.videoURL,
                    enhancementType: viewModel.enhancementType.title,
                    trimStartTime: viewModel.trimStartTime,
                    trimEndTime: viewModel.trimEndTime,
                    customHeight: min(geo.size.height * 0.60, 350)
                )
                
            Spacer()
                HStack {
                    Spacer()
                    EnhancementOptionsView(
                        enhancementType: viewModel.enhancementType,
                        selectedOption: $viewModel.selectedOption,
                        isAnalyzing: viewModel.isAnalyzing,
                        onOptionSelected: viewModel.updateSelection
                    )
                    Spacer()
                }
                Spacer()
                EnhancementActionView(
                    enhancementType: viewModel.enhancementType,
                    selectedOption: viewModel.selectedOption,
                    canProcess: viewModel.canProcess,
                    onProcess: viewModel.processVideo
                )
                .padding(.top, 8)
                .padding(.bottom, 6)
            }
            .padding(.horizontal, 16)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
    }
    
    @ViewBuilder
    private var resultsView: some View {
        if let result = viewModel.result {
            VideoResultsView(
                originalVideoURL: result.originalURL,
                processedVideoURL: result.processedURL,
                enhancementType: result.enhancementType.title,
                enhancementIcon: result.enhancementType.icon,
                gradientType: result.enhancementType.gradientType
            )
        }
    }
    
    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var navigationToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if !viewModel.isProcessing {
                BackButton { dismiss() }
            } else {
                EmptyView()
            }
        }
        
        // Inline title aligned with back and close buttons
        ToolbarItem(placement: .principal) {
            if !viewModel.isProcessing {
                Text(viewModel.enhancementType.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.accentWarm)
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            if !viewModel.isProcessing {
                CloseButton { dismiss() }
            } else {
                EmptyView()
            }
        }
    }
    
    // MARK: - Event Handlers
    private func handleViewAppearance() {
        print("🎭 RefactoredEnhancementSelectionView - Appeared with:")
        print("  Enhancement: \(viewModel.enhancementType.title)")
        print("   Trim: \(viewModel.trimStartTime ?? -1) to \(viewModel.trimEndTime ?? -1)")
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
    @Binding var selectedOption: String
    let isAnalyzing: Bool
    let onOptionSelected: (String) -> Void
    @Environment(\.horizontalSizeClass) private var hSize
    private var isIPad: Bool { hSize == .regular }
    
    private var dynamicSubtitle: String {
        switch enhancementType.id {
        case "ai_upscale":
            return "Choose upscaling level"
        case "ai_denoise":
            return "Choose denoise strength"
        case "ai_auto_enhancement":
            return "Choose enhancement strength"
        case "stabilizer":
            return "Choose stabilization level"
        case "frame_interpolation":
            return "Choose interpolation rate"
        default:
            return "Choose enhancement level"
        }
    }
    
    var body: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            EnhancementSectionHeader(
                title: "Choose Enhancement Level",
                subtitle: dynamicSubtitle
            )
            .padding(.top, 8)
            
            HStack {
                Spacer()
                EnhancementOptionGrid(
                    options: enhancementType.options,
                    selectedOption: selectedOption,
                    isAnalyzing: isAnalyzing,
                    onOptionSelected: onOptionSelected
                )
                Spacer()
            }
        }
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
                            EnhancementOptionCard(
                                option: option,
                                isSelected: selectedOption == option.id,
                                isAnalyzing: isAnalyzing,
                                onTap: { onOptionSelected(option.id) }
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                } else {
                    // Partial row: center items as a block
                    HStack(spacing: itemSpacing) {
                        Spacer(minLength: 0)
                        ForEach(row, id: \.id) { option in
                            EnhancementOptionCard(
                                option: option,
                                isSelected: selectedOption == option.id,
                                isAnalyzing: isAnalyzing,
                                onTap: { onOptionSelected(option.id) }
                            )
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Enhancement Option Card
struct EnhancementOptionCard: View {
    let option: EnhancementOption
    let isSelected: Bool
    let isAnalyzing: Bool
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
        }
        .buttonStyle(PlainButtonStyle())
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
                Text("Process with \(enhancementType)")
                    .font(.system(size: isIPad ? 20 : 18, weight: .semibold))
                    .foregroundColor(.white)
                
                if !selectedOption.isEmpty {
                    Text("Using \(selectedOption.capitalized) setting")
                        .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, isIPad ? 28 : 24)
            .padding(.vertical, isIPad ? 16 : 14)
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
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
//                Text("Back")
//                    .font(.system(size: 17, weight: .medium))
            }
            .foregroundColor(.accentWarm)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentWarm.opacity(0.1))
            )
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
