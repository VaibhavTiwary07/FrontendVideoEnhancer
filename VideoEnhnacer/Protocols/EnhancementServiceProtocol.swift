import Foundation
import Combine

// MARK: - Enhancement Service Protocol
/// Defines the contract for video enhancement operations following Open/Closed Principle
protocol EnhancementServiceProtocol: AnyObject {
    // MARK: - Published Properties
    var processingStatePublisher: Published<EnhancementProcessingState>.Publisher { get }
    var progressPublisher: Published<Double>.Publisher { get }
    
    // MARK: - Enhancement Operations
    func processVideo(
        at url: URL,
        with request: EnhancementRequest
    ) async throws -> EnhancementResult
    
    func cancelProcessing() async
    func getSupportedEnhancementTypes() -> [EnhancementType]
    func validateEnhancement(request: EnhancementRequest) throws
}

// MARK: - Enhancement Type
struct EnhancementType: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let category: EnhancementCategory
    let processingTime: Double
    let qualityImpact: Double
    let options: [EnhancementOption]
    
    // UI-specific properties
    var title: String { name } // Computed property for backwards compatibility
    var subtitle: String { description } // Computed property for backwards compatibility
    let gradientType: GradientType
    
    init(
        id: String,
        name: String,
        description: String,
        icon: String,
        category: EnhancementCategory = .enhancement,
        processingTime: Double = 30.0,
        qualityImpact: Double = 0.8,
        options: [EnhancementOption] = [],
        gradientType: GradientType = .redPink
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.category = category
        self.processingTime = processingTime
        self.qualityImpact = qualityImpact
        self.options = options
        self.gradientType = gradientType
    }
    
    static func == (lhs: EnhancementType, rhs: EnhancementType) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Enhancement Category
enum EnhancementCategory: String, CaseIterable, Hashable {
    case enhancement = "enhancement"
    case cleanup = "cleanup"
    case color = "color"
    case stabilization = "stabilization"
    case effects = "effects"
    
    var displayName: String {
        switch self {
        case .enhancement: return "Enhancement"
        case .cleanup: return "Cleanup"
        case .color: return "Color"
        case .stabilization: return "Stabilization"
        case .effects: return "Effects"
        }
    }
}

// MARK: - Enhancement Option
struct EnhancementOption: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let isRecommended: Bool
    let intensity: EnhancementIntensity
    
    init(
        id: String,
        title: String,
        description: String,
        icon: String,
        isRecommended: Bool = false,
        intensity: EnhancementIntensity = .medium
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.icon = icon
        self.isRecommended = isRecommended
        self.intensity = intensity
    }
}

// MARK: - Enhancement Intensity
enum EnhancementIntensity: String, CaseIterable, Hashable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

// MARK: - Enhancement Request
struct EnhancementRequest: Equatable {
    let enhancementType: EnhancementType
    let selectedOption: EnhancementOption
    let trimStartTime: Double?
    let trimEndTime: Double?
    let outputQuality: OutputQuality
    
    init(
        enhancementType: EnhancementType,
        selectedOption: EnhancementOption,
        trimStartTime: Double? = nil,
        trimEndTime: Double? = nil,
        outputQuality: OutputQuality = .high
    ) {
        self.enhancementType = enhancementType
        self.selectedOption = selectedOption
        self.trimStartTime = trimStartTime
        self.trimEndTime = trimEndTime
        self.outputQuality = outputQuality
    }
}

// MARK: - Enhancement Result
struct EnhancementResult: Equatable, Hashable {
    let originalURL: URL
    let processedURL: URL
    let enhancementType: EnhancementType
    let processingTime: TimeInterval
    let metadata: EnhancementMetadata
}

// MARK: - Enhancement Metadata
struct EnhancementMetadata: Equatable, Hashable {
    let processingTime: Double
    let enhancementStrength: Double
    let qualityScore: Double
    let fileSize: Int64
    let appliedSettings: [String: String]
    let processingStartTime: Date?
    let processingEndTime: Date?
    
    init(
        processingTime: Double,
        enhancementStrength: Double,
        qualityScore: Double,
        fileSize: Int64,
        appliedSettings: [String: String] = [:],
        processingStartTime: Date? = nil,
        processingEndTime: Date? = nil
    ) {
        self.processingTime = processingTime
        self.enhancementStrength = enhancementStrength
        self.qualityScore = qualityScore
        self.fileSize = fileSize
        self.appliedSettings = appliedSettings
        self.processingStartTime = processingStartTime
        self.processingEndTime = processingEndTime
    }
}

// MARK: - Output Quality
enum OutputQuality: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case original = "original"
    
    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Enhancement Processing State
enum EnhancementProcessingState: Equatable {
    case idle
    case preparing
    case processing(phase: ProcessingPhase)
    case completed(EnhancementResult)
    case failed(EnhancementError)
    case cancelled
}

// MARK: - Processing Phase
enum ProcessingPhase: String, Equatable {
    case initialization = "Initializing..."
    case analysis = "Analyzing video..."
    case enhancement = "Enhancing..."
    case export = "Exporting video..."
    case finalization = "Finalizing..."
    
    var displayName: String {
        rawValue
    }
}

// MARK: - Enhancement Error
enum EnhancementError: Error, Equatable, LocalizedError {
    case invalidInput(String)
    case processingFailed(String)
    case exportFailed(String)
    case cancelled
    case unsupportedFormat
    
    var errorDescription: String? {
        switch self {
        case .invalidInput(let reason):
            return "Invalid input: \(reason)"
        case .processingFailed(let reason):
            return "Processing failed: \(reason)"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .cancelled:
            return "Processing was cancelled"
        case .unsupportedFormat:
            return "Unsupported video format"
        }
    }
}
