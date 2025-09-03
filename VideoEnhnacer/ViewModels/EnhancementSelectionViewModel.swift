import Foundation
import SwiftUI
import Combine

// MARK: - Enhancement Selection ViewModel
/// MVVM ViewModel for enhancement selection operations following Single Responsibility Principle
@MainActor
final class EnhancementSelectionViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var selectedOption: String = ""
    @Published private(set) var processingState: EnhancementProcessingState = .idle
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var isAnalyzing: Bool = false
    @Published private(set) var error: EnhancementError?
    @Published private(set) var result: EnhancementResult?
    
    // MARK: - Private Properties
    private let enhancementService: EnhancementServiceProtocol
    private let videoProcessingService: VideoProcessingProtocol
    private var cancellables = Set<AnyCancellable>()
    private var currentTask: Task<Void, Never>?
    
    // MARK: - Public Properties
    let videoURL: URL
    let enhancementType: EnhancementType
    let trimStartTime: Double?
    let trimEndTime: Double?
    
    // MARK: - Computed Properties
    var isProcessing: Bool {
        switch processingState {
        case .processing, .preparing:
            return true
        default:
            return false
        }
    }
    
    var canProcess: Bool {
        !selectedOption.isEmpty && !isProcessing
    }
    
    var selectedEnhancementOption: EnhancementOption? {
        enhancementType.options.first { $0.id == selectedOption }
    }
    
    var dynamicSubtitle: String {
        generateDynamicSubtitle(for: enhancementType)
    }
    
    // MARK: - Initialization
    init(
        videoURL: URL,
        enhancementType: EnhancementType,
        trimStartTime: Double? = nil,
        trimEndTime: Double? = nil,
        enhancementService: EnhancementServiceProtocol,
        videoProcessingService: VideoProcessingProtocol
    ) {
        self.videoURL = videoURL
        self.enhancementType = enhancementType
        self.trimStartTime = trimStartTime
        self.trimEndTime = trimStartTime
        self.enhancementService = enhancementService
        self.videoProcessingService = videoProcessingService
        
        setupBindings()
        setDefaultSelection()
    }
    
    // MARK: - Public Methods
    func updateSelection(_ optionId: String) {
        selectedOption = optionId
        
        // Simulate analysis feedback
        withAnimation(.easeInOut(duration: 0.3)) {
            isAnalyzing = true
        }
        
        Task { [weak self] in
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self?.isAnalyzing = false
                }
            }
        }
    }
    
    func processVideo() {
        guard let option = selectedEnhancementOption else {
            error = .invalidInput("No enhancement option selected")
            return
        }
        
        currentTask = Task { [weak self] in
            await self?.performVideoProcessing(with: option)
        }
    }
    
    func cancelProcessing() {
        currentTask?.cancel()
        currentTask = nil
        
        Task { [weak self] in
            await self?.enhancementService.cancelProcessing()
        }
    }
    
    func retryProcessing() {
        error = nil
        processVideo()
    }
    
    func resetState() {
        processingState = .idle
        progress = 0.0
        error = nil
        result = nil
        selectedOption = ""
        setDefaultSelection()
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        // Bind to enhancement service state changes
        enhancementService.processingStatePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.processingState, on: self)
            .store(in: &cancellables)
        
        enhancementService.progressPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.progress, on: self)
            .store(in: &cancellables)
        
        // Handle processing state changes
        $processingState
            .sink { [weak self] state in
                self?.handleProcessingStateChange(state)
            }
            .store(in: &cancellables)
    }
    
    private func setDefaultSelection() {
        if let recommended = enhancementType.options.first(where: { $0.isRecommended }) {
            selectedOption = recommended.id
        } else if let first = enhancementType.options.first {
            selectedOption = first.id
        }
    }
    
    private func handleProcessingStateChange(_ state: EnhancementProcessingState) {
        switch state {
        case .completed(let enhancementResult):
            result = enhancementResult
            error = nil
        case .failed(let enhancementError):
            error = enhancementError
            result = nil
        case .cancelled:
            error = nil
            result = nil
        default:
            break
        }
    }
    
    private func performVideoProcessing(with option: EnhancementOption) async {
        do {
            // Create enhancement request
            let request = EnhancementRequest(
                enhancementType: enhancementType,
                selectedOption: option,
                trimStartTime: trimStartTime,
                trimEndTime: trimEndTime
            )
            
            // Validate the request
            try enhancementService.validateEnhancement(request: request)
            
            // Log processing start
            print("🎭 EnhancementSelectionViewModel - Starting processing:")
            print("   Enhancement: \(enhancementType.title)")
            print("   Option: \(option.title)")
            print("   Trim: \(trimStartTime ?? -1) to \(trimEndTime ?? -1)")
            
            // Process the video
            let result = try await enhancementService.processVideo(at: videoURL, with: request)
            
            await MainActor.run {
                self.result = result
                print("🎭 EnhancementSelectionViewModel - Processing completed successfully")
            }
            
        } catch let enhancementError as EnhancementError {
            await MainActor.run {
                self.error = enhancementError
                print("🎭 EnhancementSelectionViewModel - Processing failed: \(enhancementError.localizedDescription)")
            }
        } catch {
            await MainActor.run {
                self.error = .processingFailed(error.localizedDescription)
                print("🎭 EnhancementSelectionViewModel - Processing failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func generateDynamicSubtitle(for enhancementType: EnhancementType) -> String {
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
    
    // MARK: - Public Cleanup
    func cleanup() {
        currentTask?.cancel()
        currentTask = nil
        cancellables.removeAll()
    }
    
    // MARK: - Cleanup
    deinit {
        currentTask?.cancel()
        currentTask = nil
        cancellables.removeAll()
    }
}

// MARK: - Preview Support
#if DEBUG
extension EnhancementSelectionViewModel {
    static var preview: EnhancementSelectionViewModel {
        DIContainer.shared.makeEnhancementSelectionViewModel(
            videoURL: URL(string: "https://example.com/video.mp4")!,
            enhancementType: EnhancementType.mockAIUpscale
        )
    }
}

// Mock services are now defined in DIContainer.swift to avoid duplicates

// MARK: - Mock Enhancement Types
extension EnhancementType {
    static let mockAIUpscale = EnhancementType(
        id: "ai_upscale",
        name: "AI Upscale",
        description: "Enhance image resolution",
        icon: "arrow.up.square",
        category: .enhancement,
        processingTime: 30.0,
        qualityImpact: 0.9,
        options: [
            EnhancementOption(id: "2x", title: "2X", description: "", icon: "arrow.up.right.square", isRecommended: true),
            EnhancementOption(id: "4x", title: "4X", description: "", icon: "rectangle.expand.vertical")
        ],
        gradientType: .redPink
    )
}
#endif