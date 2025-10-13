import Foundation
import Combine

// MARK: - Enhancement Service
/// Concrete implementation of EnhancementServiceProtocol following Open/Closed Principle
final class EnhancementService: EnhancementServiceProtocol {
    
    // MARK: - Published Properties
    @Published private var processingState: EnhancementProcessingState = .idle
    @Published private var progress: Double = 0.0
    
    var processingStatePublisher: Published<EnhancementProcessingState>.Publisher { $processingState }
    var progressPublisher: Published<Double>.Publisher { $progress }
    
    // MARK: - Private Properties
    private let videoProcessingService: VideoProcessingProtocol
    private let enhancementRegistry: EnhancementTypeRegistry
    private var currentProcessingTask: Task<Void, Never>?
    
    // MARK: - Initialization
    init(videoProcessingService: VideoProcessingProtocol, enhancementRegistry: EnhancementTypeRegistry = .shared) {
        self.videoProcessingService = videoProcessingService
        self.enhancementRegistry = enhancementRegistry
    }
    
    // MARK: - EnhancementServiceProtocol Implementation
    func processVideo(at url: URL, with request: EnhancementRequest) async throws -> EnhancementResult {
        // Cancel any existing processing
        await cancelProcessing()
        
        return try await withCheckedThrowingContinuation { continuation in
            currentProcessingTask = Task {
                await performVideoProcessing(url: url, request: request, continuation: continuation)
            }
        }
    }
    
    func cancelProcessing() async {
        currentProcessingTask?.cancel()
        currentProcessingTask = nil
        await updateProcessingState(.cancelled)
    }
    
    func getSupportedEnhancementTypes() -> [EnhancementType] {
        return enhancementRegistry.getAllEnhancementTypes()
    }
    
    func validateEnhancement(request: EnhancementRequest) throws {
        // Validate enhancement type is supported
        let supportedTypes = getSupportedEnhancementTypes()
        guard supportedTypes.contains(where: { $0.id == request.enhancementType.id }) else {
            throw EnhancementError.invalidInput("Unsupported enhancement type: \(request.enhancementType.id)")
        }
        
        // Validate enhancement option exists for the type
        guard request.enhancementType.options.contains(where: { $0.id == request.selectedOption.id }) else {
            throw EnhancementError.invalidInput("Invalid option \(request.selectedOption.id) for enhancement type \(request.enhancementType.id)")
        }
        
        // Validate trim times if provided
        if let startTime = request.trimStartTime, let endTime = request.trimEndTime {
            guard startTime >= 0 && endTime > startTime else {
                throw EnhancementError.invalidInput("Invalid trim time range")
            }
        }
    }
    
    // MARK: - Private Methods
    @MainActor
    private func updateProcessingState(_ newState: EnhancementProcessingState) {
        processingState = newState
    }
    
    @MainActor
    private func updateProgress(_ newProgress: Double) {
        progress = newProgress
    }
    
    private func performVideoProcessing(
        url: URL,
        request: EnhancementRequest,
        continuation: CheckedContinuation<EnhancementResult, Error>
    ) async {
        do {
            await updateProcessingState(.preparing)
            await updateProgress(0.0)
            
            // Phase 1: Initialize
            await updateProcessingState(.processing(phase: .initialization))
            try await simulateProcessingDelay(0.5, progressRange: 0.0...0.1)
            
            // Phase 2: Analysis
            await updateProcessingState(.processing(phase: .analysis))
            let videoInfo = try await videoProcessingService.getVideoInfo(from: url)
            try await simulateProcessingDelay(1.0, progressRange: 0.1...0.3)
            
            // Phase 3: Enhancement Processing
            await updateProcessingState(.processing(phase: .enhancement))
            let processedURL = try await applyEnhancement(
                url: url,
                request: request,
                videoInfo: videoInfo
            )
            try await simulateProcessingDelay(2.0, progressRange: 0.3...0.8)
            
            // Phase 4: Export
            await updateProcessingState(.processing(phase: .export))
            try await simulateProcessingDelay(1.0, progressRange: 0.8...0.95)
            
            // Phase 5: Finalization
            await updateProcessingState(.processing(phase: .finalization))
            try await simulateProcessingDelay(0.5, progressRange: 0.95...1.0)
            
            // Create result
            let result = EnhancementResult(
                originalURL: url,
                processedURL: processedURL,
                enhancementType: request.enhancementType,
                processingTime: 5.0, // Total simulated processing time
                metadata: EnhancementMetadata(
                    processingTime: 5.0,
                    enhancementStrength: 0.8,
                    qualityScore: 0.9,
                    fileSize: 1024 * 1024 * 10, // 10MB mock size
                    appliedSettings: createAppliedSettings(from: request),
                    processingStartTime: Date().addingTimeInterval(-5.0),
                    processingEndTime: Date()
                )
            )
            
            await updateProcessingState(.completed(result))
            continuation.resume(returning: result)
            
        } catch {
            if Task.isCancelled || error is CancellationError || (error as? EnhancementError) == .cancelled {
                await updateProcessingState(.cancelled)
                continuation.resume(throwing: EnhancementError.cancelled)
                return
            }

            let enhancementError: EnhancementError
            if let existingError = error as? EnhancementError {
                enhancementError = existingError
            } else {
                enhancementError = .processingFailed(error.localizedDescription)
            }
            
            await updateProcessingState(.failed(enhancementError))
            continuation.resume(throwing: enhancementError)
        }
    }
    
    private func applyEnhancement(
        url: URL,
        request: EnhancementRequest,
        videoInfo: VideoInfo
    ) async throws -> URL {
        // For now, this is a mock implementation
        // In a real app, this would apply actual AI enhancement processing
        
        var processedURL = url
        
        // Apply trimming if specified
        if let startTime = request.trimStartTime, let endTime = request.trimEndTime {
            processedURL = try await videoProcessingService.trimVideo(
                at: processedURL,
                startTime: startTime,
                endTime: endTime,
                quality: videoQualityFromOutputQuality(request.outputQuality)
            )
        }
        
        // Mock enhancement processing based on type and option
        switch request.enhancementType.id {
        case "ai_upscale":
            // Mock upscaling
            print("🎨 Applying AI Upscale with \(request.selectedOption.title)")
            
        case "ai_denoise":
            // Mock denoising
            print("🎨 Applying AI Denoise with \(request.selectedOption.title)")
            
        case "stabilizer":
            // Mock stabilization
            print("🎨 Applying Stabilization with \(request.selectedOption.title)")
            
        default:
            print("🎨 Applying \(request.enhancementType.name) with \(request.selectedOption.title)")
        }
        
        return processedURL
    }
    
    private func simulateProcessingDelay(_ duration: TimeInterval, progressRange: ClosedRange<Double>) async throws {
        let steps = 10
        let stepDuration = duration / Double(steps)
        let progressIncrement = (progressRange.upperBound - progressRange.lowerBound) / Double(steps)
        
        for i in 0..<steps {
            if Task.isCancelled {
                throw EnhancementError.cancelled
            }
            
            try await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
            
            let currentProgress = progressRange.lowerBound + (Double(i + 1) * progressIncrement)
            await updateProgress(currentProgress)
        }
    }
    
    private func createAppliedSettings(from request: EnhancementRequest) -> [String: String] {
        var settings = [
            "enhancementType": request.enhancementType.id,
            "selectedOption": request.selectedOption.id,
            "intensity": request.selectedOption.intensity.rawValue,
            "outputQuality": request.outputQuality.rawValue
        ]
        
        if let trimStart = request.trimStartTime {
            settings["trimStartTime"] = String(trimStart)
        }
        
        if let trimEnd = request.trimEndTime {
            settings["trimEndTime"] = String(trimEnd)
        }
        
        return settings
    }
    
    private func videoQualityFromOutputQuality(_ outputQuality: OutputQuality) -> VideoQuality {
        switch outputQuality {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        case .original: return .original
        }
    }
}

// MARK: - Enhancement Type Registry
/// Registry for managing available enhancement types following Open/Closed Principle
final class EnhancementTypeRegistry {
    static let shared = EnhancementTypeRegistry()
    
    private var enhancementTypes: [EnhancementType] = []
    
    private init() {
        setupDefaultEnhancementTypes()
    }
    
    func getAllEnhancementTypes() -> [EnhancementType] {
        return enhancementTypes
    }
    
    func getEnhancementType(withId id: String) -> EnhancementType? {
        return enhancementTypes.first { $0.id == id }
    }
    
    func registerEnhancementType(_ type: EnhancementType) {
        if !enhancementTypes.contains(where: { $0.id == type.id }) {
            enhancementTypes.append(type)
        }
    }
    
    private func setupDefaultEnhancementTypes() {
        enhancementTypes = [
            createAIUpscaleType(),
            createFaceEnhancerType(),
            createAIDenoiseType(),
            createAIColorType(),
            createAutoEnhancementType(),
            createStabilizerType(),
            createFrameInterpolationType()
        ]
    }
    
    private func createAIUpscaleType() -> EnhancementType {
        EnhancementType(
            id: "ai_upscale",
            name: "AI Upscale",
            description: "Enhance image resolution using AI",
            icon: "arrow.up.square",
            category: .enhancement,
            processingTime: 30.0,
            qualityImpact: 0.9,
            options: [
                EnhancementOption(id: "1080", title: "1080p", description: "Upscale to Full HD", icon: "tv.and.hifispeaker.fill", isRecommended: true),
                EnhancementOption(id: "2K", title: "2K", description: "Upscale to 2K", icon: "plus.magnifyingglass"),
                EnhancementOption(id: "4K", title: "4K", description: "Upscale to 4K", icon: "rectangle.expand.vertical")
            ],
            gradientType: .redPink
        )
    }
    
    private func createFaceEnhancerType() -> EnhancementType {
        EnhancementType(
            id: "face_enhancer",
            name: "Face & Object Enhancer",
            description: "Improve facial features and object details",
            icon: getIOSCompatibleSymbol("face.smiling", fallback: "person.crop.circle"),
            category: .enhancement,
            processingTime: 25.0,
            qualityImpact: 0.8,
            options: [
                EnhancementOption(id: "auto", title: "Auto", description: "Automatic enhancement", icon: getIOSCompatibleSymbol("wand.and.stars", fallback: "wand.and.stars"), isRecommended: true)
            ],
            gradientType: .yellowGray
        )
    }
    
    private func createAIDenoiseType() -> EnhancementType {
        EnhancementType(
            id: "ai_denoise",
            name: "AI Denoise",
            description: "Remove grain and noise using AI",
            icon: "waveform.path",
            category: .cleanup,
            processingTime: 20.0,
            qualityImpact: 0.7,
            options: [
                EnhancementOption(id: "low", title: "Low", description: "Gentle noise reduction", icon: "waveform.path"),
                EnhancementOption(id: "medium", title: "Medium", description: "Balanced reduction", icon: "sparkles", isRecommended: true),
                EnhancementOption(id: "high", title: "High", description: "Aggressive removal", icon: "slider.horizontal.3")
            ],
            gradientType: .purpleGray
        )
    }
    
    private func createAIColorType() -> EnhancementType {
        EnhancementType(
            id: "ai_color",
            name: "AI Color",
            description: "Color correction and enhancement",
            icon: "paintpalette.fill",
            category: .color,
            processingTime: 15.0,
            qualityImpact: 0.6,
            options: [
                EnhancementOption(id: "auto", title: "Auto", description: "Automatic color correction", icon: "wand.and.stars", isRecommended: true)
            ],
            gradientType: .cyanGray
        )
    }
    
    private func createAutoEnhancementType() -> EnhancementType {
        EnhancementType(
            id: "ai_auto_enhancement",
            name: "AI Auto Enhancement",
            description: "One-click smart improvements",
            icon: "wand.and.stars",
            category: .enhancement,
            processingTime: 30.0,
            qualityImpact: 0.8,
            options: [
                EnhancementOption(id: "low", title: "Low", description: "Subtle improvements", icon: "dial.low"),
                EnhancementOption(id: "medium", title: "Medium", description: "Balanced enhancement", icon: getIOSCompatibleSymbol("wand.and.stars", fallback: "wand.and.stars"), isRecommended: true),
                EnhancementOption(id: "high", title: "High", description: "Maximum enhancement", icon: "dial.high.fill")
            ],
            gradientType: .pinkGray
        )
    }
    
    private func createStabilizerType() -> EnhancementType {
        EnhancementType(
            id: "stabilizer",
            name: "Stabilizer",
            description: "Reduce camera shake",
            icon: "gyroscope",
            category: .stabilization,
            processingTime: 35.0,
            qualityImpact: 0.8,
            options: [
                EnhancementOption(id: "low", title: "Low", description: "Gentle stabilization", icon: "level"),
                EnhancementOption(id: "medium", title: "Medium", description: "Standard stabilization", icon: "gyroscope", isRecommended: true),
                EnhancementOption(id: "high", title: "High", description: "Aggressive stabilization", icon: "arrow.triangle.2.circlepath")
            ],
            gradientType: .gray
        )
    }
    
    private func createFrameInterpolationType() -> EnhancementType {
        EnhancementType(
            id: "frame_interpolation",
            name: "Frame Interpolation",
            description: "Smooth motion and increase frame rate",
            icon: getIOSCompatibleSymbol("timer.circle.fill", fallback: "timer"),
            category: .enhancement,
            processingTime: 45.0,
            qualityImpact: 0.9,
            options: [
                EnhancementOption(id: "smooth", title: "Smooth", description: "Enhanced motion smoothness", icon: "play.rectangle.fill", isRecommended: true),
                EnhancementOption(id: "fluid", title: "Fluid", description: "Ultra-smooth motion", icon: "forward.frame.fill")
            ],
            gradientType: .redPink
        )
    }
}
