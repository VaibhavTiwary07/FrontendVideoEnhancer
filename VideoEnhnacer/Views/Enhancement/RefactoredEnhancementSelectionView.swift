import SwiftUI

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
                .toolbar { navigationToolbar }
        }
        .onAppear { handleViewAppearance() }
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
        VStack(spacing: 0) {
            // Title at the top
            EnhancementTitleSection(enhancementType: viewModel.enhancementType)
                .padding(.top, 12)
                .padding(.horizontal, 20)
            
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 20) {
                    // Video Preview
                    SpatialVideoPreview(
                        videoURL: viewModel.videoURL,
                        enhancementType: viewModel.enhancementType.title,
                        trimStartTime: viewModel.trimStartTime,
                        trimEndTime: viewModel.trimEndTime
                    )
                    
                    EnhancementOptionsView(
                        enhancementType: viewModel.enhancementType,
                        selectedOption: $viewModel.selectedOption,
                        isAnalyzing: viewModel.isAnalyzing,
                        onOptionSelected: viewModel.updateSelection
                    )
                   
                    EnhancementActionView(
                        enhancementType: viewModel.enhancementType,
                        selectedOption: viewModel.selectedOption,
                        canProcess: viewModel.canProcess,
                        onProcess: viewModel.processVideo
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
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
        print("   Enhancement: \(viewModel.enhancementType.title)")
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
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .allowsHitTesting(true)

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 8)
                        .frame(width: 120, height: 120)

                    Circle()
                        .trim(from: 0, to: max(0.0, min(1.0, progress)))
                        .stroke(
                            LinearGradient.primaryTheme,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.25), value: progress)

                    Text("\(Int(max(0.0, min(1.0, progress)) * 100))%")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                Text(statusText)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .opacity(0.9)
                
                if let onCancel = onCancel, !isCompleted(processingState) {
                    Button(action: {
                        HapticFeedbackManager.impact(.medium)
                        onCancel()
                    }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(0.8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
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
        VStack(spacing: 16) {
            EnhancementSectionHeader(
                title: "Choose Enhancement Level",
                subtitle: dynamicSubtitle
            )
            .padding(.top, 20)
            
            EnhancementOptionGrid(
                options: enhancementType.options,
                selectedOption: selectedOption,
                isAnalyzing: isAnalyzing,
                onOptionSelected: onOptionSelected
            )
        }
    }
}

// MARK: - Enhancement Section Header
struct EnhancementSectionHeader: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.accentWarm)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(subtitle)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.accentWarm.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Enhancement Option Grid
struct EnhancementOptionGrid: View {
    let options: [EnhancementOption]
    let selectedOption: String
    let isAnalyzing: Bool
    let onOptionSelected: (String) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(options, id: \.id) { option in
                EnhancementOptionCard(
                    option: option,
                    isSelected: selectedOption == option.id,
                    isAnalyzing: isAnalyzing,
                    onTap: { onOptionSelected(option.id) }
                )
            }
        }
    }
}

// MARK: - Enhancement Option Card
struct EnhancementOptionCard: View {
    let option: EnhancementOption
    let isSelected: Bool
    let isAnalyzing: Bool
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
            HapticFeedbackManager.impact(.medium)
            onTap()
        }) {
            VStack(spacing: 4) {
                Image(systemName: option.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : Color.accentWarm)
                
                Text(option.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(titleColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                if option.isRecommended {
                    Text("RECOMMENDED")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(recommendedTextColor)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(recommendedBackground)
                        )
                }
            }
            .frame(width: 80, height: 80)
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
                            .scaleEffect(0.8)
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
        .padding(.top, 20)
    }
}

// MARK: - Enhancement Process Button
struct EnhancementProcessButton: View {
    let enhancementType: String
    let selectedOption: String
    let canProcess: Bool
    let onProcess: () -> Void
    
    var body: some View {
        Button(action: {
            HapticFeedbackManager.impact(.heavy)
            onProcess()
        }) {
            VStack(alignment: .center, spacing: 2) {
                Text("Process with \(enhancementType)")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                if !selectedOption.isEmpty {
                    Text("Using \(selectedOption.capitalized) setting")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
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
        NavigationView {
            RefactoredEnhancementSelectionView(
                videoURL: URL(string: "https://example.com/video.mp4")!,
                enhancementType: EnhancementType.mockAIUpscale,
                trimStartTime: 5.0,
                trimEndTime: 15.0
            )
        }
        .withDependencyInjection()
    }
}
#endif
