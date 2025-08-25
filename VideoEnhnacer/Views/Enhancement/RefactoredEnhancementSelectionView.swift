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
                .navigationBarItems(
                    leading: BackButton { dismiss() },
                    trailing: HStack(spacing: 16) {
                        StepIndicator(currentStep: 3, totalSteps: 4)
                        CloseButton { dismiss() }
                    }
                )
        }
        .onAppear { handleViewAppearance() }
        .onDisappear { handleViewDisappearance() }
        .fullScreenCover(isPresented: $showingResults) { resultsView }
        .errorAlert(error: viewModel.error) { viewModel.retryProcessing() }
        .processingOverlay(
            isPresenting: viewModel.isProcessing,
            progress: viewModel.progress,
            processingState: viewModel.processingState
        )
        .onChange(of: viewModel.result) { result in
            if result != nil { showingResults = true }
        }
    }
    
    // MARK: - Content Views
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                EnhancementHeaderView(
                    enhancementType: viewModel.enhancementType,
                    playerViewModel: playerViewModel,
                    videoURL: viewModel.videoURL,
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
            BackButton { dismiss() }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 16) {
                StepIndicator(currentStep: 3, totalSteps: 4)
                CloseButton { dismiss() }
            }
        }
    }
    
    // MARK: - Event Handlers
    private func handleViewAppearance() {
        print("🎭 RefactoredEnhancementSelectionView - Appeared with:")
        print("   Enhancement: \(viewModel.enhancementType.title)")
        print("   Trim: \(viewModel.trimStartTime ?? -1) to \(viewModel.trimEndTime ?? -1)")
    }
    
    private func handleViewDisappearance() {
        viewModel.cleanup()
        playerViewModel.cleanup()
    }
}

// MARK: - Enhancement Header View
struct EnhancementHeaderView: View {
    let enhancementType: EnhancementType
    let playerViewModel: VideoPlayerViewModel
    let videoURL: URL
    let trimStartTime: Double?
    let trimEndTime: Double?
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        VStack(spacing: 16) {
            EnhancementTitleSection(enhancementType: enhancementType)
                .padding(.top, 20)
            
            SpatialVideoPreview(
                videoURL: videoURL,
                enhancementType: enhancementType.title,
                trimStartTime: trimStartTime,
                trimEndTime: trimEndTime
            )
            .frame(height: isIPad ? 280 : 240)
            .padding(.top, 20)
        }
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
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            EnhancementOptionGrid(
                options: enhancementType.options,
                selectedOption: selectedOption,
                isAnalyzing: isAnalyzing,
                onOptionSelected: onOptionSelected
            )
            .padding(.horizontal, 20)
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
        .padding(.horizontal, 20)
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

// MARK: - Shared components are now imported from Components/Shared/

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
        processingState: EnhancementProcessingState
    ) -> some View {
        self.overlay(
            Group {
                if isPresenting {
                    EnhancementProcessingOverlay(
                        progress: progress,
                        processingState: processingState
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
    
    private var statusText: String {
        switch processingState {
        case .processing(let phase):
            return phase.displayName
        case .preparing:
            return "Preparing..."
        default:
            return "Processing Video..."
        }
    }
    
    var body: some View {
        Color.black.opacity(0.8)
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 8)
                            .frame(width: 120, height: 120)
                        
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                LinearGradient.primaryTheme,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.3), value: progress)
                        
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    Text(statusText)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .opacity(0.9)
                }
            )
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