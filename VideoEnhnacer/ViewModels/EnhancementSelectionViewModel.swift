import Foundation
import SwiftUI
import Combine

// MARK: - Operation Tracker
class OperationTracker: ObservableObject {
    @Published var operationCount: Int = 0
    private let userDefaultsKey = "EnhancementOperationCount"

    init() {
        self.operationCount = UserDefaults.standard.integer(forKey: userDefaultsKey)
        print("📊 OperationTracker initialized with operationCount: \(self.operationCount)")
    }

    func incrementOperationCount() {
        operationCount += 1
        UserDefaults.standard.set(operationCount, forKey: userDefaultsKey)
        print("📊 Operation count incremented to: \(operationCount)")
    }

    func resetOperationCount() {
        operationCount = 0
        UserDefaults.standard.set(0, forKey: userDefaultsKey)
        print("📊 Operation count reset to 0")
    }
}

// MARK: - Enhancement Selection ViewModel
@MainActor
final class EnhancementSelectionViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedOption: String = ""
    @Published private(set) var processingState: EnhancementProcessingState = .idle
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var isAnalyzing: Bool = false
    @Published private(set) var error: EnhancementError?
    @Published private(set) var result: EnhancementResult?
    @Published var showAlert: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    @Published var isShowingPaywall: Bool = false

    // MARK: - Private Properties
    private let enhancementService: EnhancementServiceProtocol
    private let videoProcessingService: VideoProcessingProtocol
    private let operationTracker: OperationTracker
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

    private var noOfOperations: Int {
        ConfigManager.shared.getInt(forKey: "nooperations")
    }

    // MARK: - Initialization
    init(
        videoURL: URL,
        enhancementType: EnhancementType,
        trimStartTime: Double? = nil,
        trimEndTime: Double? = nil,
        enhancementService: EnhancementServiceProtocol,
        videoProcessingService: VideoProcessingProtocol,
        operationTracker: OperationTracker = OperationTracker()
    ) {
        self.videoURL = videoURL
        self.enhancementType = enhancementType
        self.trimStartTime = trimStartTime
        self.trimEndTime = trimEndTime
        self.enhancementService = enhancementService
        self.videoProcessingService = videoProcessingService
        self.operationTracker = operationTracker

        TrimmingDiagnostics.log("📥 [EnhancementSelectionViewModel] Initialized: trimStart=\(trimStartTime?.description ?? "nil") trimEnd=\(trimEndTime?.description ?? "nil")")

        setupBindings()
        setDefaultSelection()
    }
    
    // MARK: - Public Methods
    func updateSelection(_ optionId: String) {
        selectedOption = optionId

        withAnimation(.easeInOut(duration: 0.3)) {
            isAnalyzing = true
        }

        Task {
            try await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.isAnalyzing = false
                }
            }
        }
    }

    func checkAndProcessVideo() {
        if SubscriptionManager.shared.isAppSubscribed() {
            print("✅ User is subscribed, proceeding with processing")
            processVideo()
        } else if operationTracker.operationCount < noOfOperations {
            print("✅ Operation count (\(operationTracker.operationCount)) is within limit (\(noOfOperations))")
            operationTracker.incrementOperationCount()
            processVideo()
        } else {
            print("🚫 Operation limit (\(noOfOperations)) exceeded with \(operationTracker.operationCount) operations")
            isShowingPaywall = true
        }
    }

    func processVideo() {
        guard let option = selectedEnhancementOption else {
            error = .invalidInput("No enhancement option selected")
            showAlert = true
            alertTitle = "Invalid Selection"
            alertMessage = "Please select an enhancement option."
            return
        }
        
        result = nil
        error = nil
        showAlert = false
        
        currentTask = Task { [weak self] in
            await self?.performVideoProcessing(with: option)
        }
    }
    
    func cancelProcessing() {
        currentTask?.cancel()
        currentTask = nil
        disableScreenWakeLock()

        Task { [weak self] in
            await self?.enhancementService.cancelProcessing()
        }
    }
    
    func retryProcessing() {
        error = nil
        showAlert = false
        processingState = .idle
        progress = 0.0
        processVideo()
    }

    func clearError() {
        error = nil
        showAlert = false
        if case .processing = processingState {
            // Keep state; external cancel stops the pipeline
        }
    }
    
    func resetState() {
        processingState = .idle
        progress = 0.0
        error = nil
        result = nil
        showAlert = false
        selectedOption = ""
        setDefaultSelection()
    }

    func resetForReappearance() {
        // Cancel any ongoing tasks
        currentTask?.cancel()
        currentTask = nil

        // Stop service processing
        Task { [weak self] in
            await self?.enhancementService.cancelProcessing()
        }

        // Reset state but keep user's selected options
        processingState = .idle
        progress = 0.0
        error = nil
        result = nil
        showAlert = false

        // Disable screen wake lock
        disableScreenWakeLock()
    }

    // MARK: - Private Methods
    private func setupBindings() {
        enhancementService.processingStatePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.processingState, on: self)
            .store(in: &cancellables)
        
        enhancementService.progressPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.progress, on: self)
            .store(in: &cancellables)
        
        // Bind to alert properties
        (enhancementService as? ServerEnhancementService)?.$showAlert
            .receive(on: DispatchQueue.main)
            .assign(to: \.showAlert, on: self)
            .store(in: &cancellables)
        
        (enhancementService as? ServerEnhancementService)?.$alertTitle
            .receive(on: DispatchQueue.main)
            .assign(to: \.alertTitle, on: self)
            .store(in: &cancellables)
        
        (enhancementService as? ServerEnhancementService)?.$alertMessage
            .receive(on: DispatchQueue.main)
            .assign(to: \.alertMessage, on: self)
            .store(in: &cancellables)
        
        $processingState
            .sink { [weak self] state in
                self?.handleProcessingStateChange(state)
            }
            .store(in: &cancellables)
    }
    
    private func setDefaultSelection() {
        let isSubscribed = SubscriptionManager.shared.isAppSubscribed()
        if let recommended = enhancementType.options.first(where: { $0.isRecommended }) {
            if !isSubscribed && isProOption(enhancementTypeId: enhancementType.id, optionId: recommended.id) {
                if let free = enhancementType.options.first(where: { !isProOption(enhancementTypeId: enhancementType.id, optionId: $0.id) }) {
                    selectedOption = free.id
                } else {
                    selectedOption = recommended.id
                }
            } else {
                selectedOption = recommended.id
            }
        } else if let first = enhancementType.options.first {
            selectedOption = first.id
        }
    }

    private func isProOption(enhancementTypeId: String, optionId: String) -> Bool {
        switch enhancementTypeId {
        case "ai_upscale":
            return optionId == "2K" || optionId == "4K" || optionId.lowercased() == "2x" || optionId.lowercased() == "4x"
        case "ai_denoise", "ai_auto_enhancement", "stabilizer":
            return optionId == "medium" || optionId == "high"
        default:
            return false
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
            showAlert = false
        default:
            break
        }
    }

    // MARK: - Screen Wake Lock Management
    private func enableScreenWakeLock() {
        UIApplication.shared.isIdleTimerDisabled = true
        print("🔒 Screen wake lock ENABLED - screen will stay on during processing")
    }

    private func disableScreenWakeLock() {
        UIApplication.shared.isIdleTimerDisabled = false
        print("🔓 Screen wake lock DISABLED - screen auto-lock resumed")
    }

    private func performVideoProcessing(with option: EnhancementOption) async {
        do {
            let request = EnhancementRequest(
                enhancementType: enhancementType,
                selectedOption: option,
                trimStartTime: trimStartTime,
                trimEndTime: trimEndTime
            )

            try enhancementService.validateEnhancement(request: request)

            TrimmingDiagnostics.log("⚙️ [EnhancementSelectionViewModel] Starting processing: trimStart=\(trimStartTime?.description ?? "nil") trimEnd=\(trimEndTime?.description ?? "nil")")

            // Enable screen wake lock to prevent interruption during processing
            enableScreenWakeLock()

            let result = try await enhancementService.processVideo(at: videoURL, with: request)
            
            await MainActor.run {
                self.result = result
                print("🎭 EnhancementSelectionViewModel - Processing completed successfully")
                self.disableScreenWakeLock()
            }
        } catch let enhancementError as EnhancementError {
            if case .cancelled = enhancementError {
                await MainActor.run {
                    print("🎭 EnhancementSelectionViewModel - Processing cancelled by user")
                    self.disableScreenWakeLock()
                }
            } else {
                await MainActor.run {
                    self.error = enhancementError
                    print("🎭 EnhancementSelectionViewModel - Processing failed: \(enhancementError.localizedDescription)")
                    self.disableScreenWakeLock()
                }
            }
        } catch is CancellationError {
            await MainActor.run {
                print("🎭 EnhancementSelectionViewModel - Processing cancelled (system cancellation)")
                self.disableScreenWakeLock()
            }
        } catch {
            await MainActor.run {
                self.error = .processingFailed(error.localizedDescription)
                print("🎭 EnhancementSelectionViewModel - Processing failed: \(error.localizedDescription)")
                self.disableScreenWakeLock()
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
        disableScreenWakeLock()
        Task { [weak self] in
            await self?.enhancementService.cancelProcessing()
        }
        // NOTE: Don't remove cancellables here - subscriptions must persist across view lifecycle
        // They will be cleaned up in deinit when the ViewModel is truly destroyed
    }
    
    // MARK: - Cleanup
    deinit {
        currentTask?.cancel()
        currentTask = nil
        // Note: Wake lock is already disabled via completion paths and cleanup()
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
