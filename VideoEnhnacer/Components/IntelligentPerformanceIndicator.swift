import SwiftUI
import AVFoundation
import UIKit

struct IntelligentPerformanceIndicator: View {
    let enhancementType: String
    let selectedOption: String
    let videoURL: URL
    
    @StateObject private var performanceEngine = PerformanceEstimationEngine()
    @State private var showDetailedMetrics = false
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Main performance card
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showDetailedMetrics.toggle()
                }
                
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            }) {
                MainPerformanceCard(
                    performanceData: performanceEngine.currentMetrics,
                    isExpanded: showDetailedMetrics
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Detailed metrics (expandable)
            if showDetailedMetrics {
                DetailedMetricsView(
                    performanceData: performanceEngine.currentMetrics,
                    enhancementType: enhancementType,
                    selectedOption: selectedOption
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .top)),
                    removal: .scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .top))
                ))
            }
            
            // Smart recommendations
            SmartRecommendationView(
                performanceData: performanceEngine.currentMetrics,
                enhancementType: enhancementType,
                selectedOption: selectedOption
            )
        }
        .onAppear {
            performanceEngine.analyzeVideo(url: videoURL, enhancement: enhancementType, option: selectedOption)
        }
        .onChange(of: selectedOption) { _, newOption in
            performanceEngine.updateOption(newOption, for: enhancementType)
        }
    }
}

struct MainPerformanceCard: View {
    let performanceData: PerformanceMetrics
    let isExpanded: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Performance indicator icon
            ZStack {
                Circle()
                    .fill(performanceData.riskColor.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                Circle()
                    .stroke(performanceData.riskColor, lineWidth: 2)
                    .frame(width: 48, height: 48)
                
                Image(systemName: performanceData.riskIcon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(performanceData.riskColor)
            }
            
            // Performance summary
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Processing Time")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.accentWarm)
                    
                    Spacer()
                    
                    Text(performanceData.estimatedTime)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(performanceData.riskColor)
                }
                
                HStack {
                    Text("Quality Impact")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.accentWarm.opacity(0.8))
                    
                    Spacer()
                    
                    QualityStars(rating: performanceData.qualityRating)
                }
                
                // Battery impact indicator
                HStack(spacing: 6) {
                    Image(systemName: "battery.50")
                        .font(.system(size: 12))
                        .foregroundColor(.accentWarm.opacity(0.6))
                    
                    Text("Battery: \(performanceData.batteryImpact)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.accentWarm.opacity(0.6))
                    
                    Spacer()
                }
            }
            
            // Expand indicator
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.accentWarm.opacity(0.6))
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                .animation(.easeInOut(duration: 0.3), value: isExpanded)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(performanceData.riskColor.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

struct DetailedMetricsView: View {
    let performanceData: PerformanceMetrics
    let enhancementType: String
    let selectedOption: String
    
    var body: some View {
        VStack(spacing: 16) {
            // Processing breakdown
            ProcessingBreakdownView(metrics: performanceData)
            
            // Resource usage
            ResourceUsageView(metrics: performanceData)
            
            // Comparison with other options
            if !performanceData.alternativeOptions.isEmpty {
                AlternativeOptionsView(
                    alternatives: performanceData.alternativeOptions,
                    currentOption: selectedOption
                )
            }
        }
    }
}

struct ProcessingBreakdownView: View {
    let metrics: PerformanceMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gearshape.2")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accentWarm.opacity(0.8))
                
                Text("Processing Breakdown")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.accentWarm)
                
                Spacer()
            }
            
            VStack(spacing: 8) {
                ForEach(metrics.processingSteps, id: \.name) { step in
                    ProcessingStepRow(step: step)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.overlaySoft.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentWarm.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct ProcessingStepRow: View {
    let step: ProcessingStep
    
    var body: some View {
        HStack {
            Circle()
                .fill(step.color)
                .frame(width: 8, height: 8)
            
            Text(step.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.accentWarm.opacity(0.8))
            
            Spacer()
            
            Text(step.duration)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.accentWarm)
        }
    }
}

struct ResourceUsageView: View {
    let metrics: PerformanceMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cpu")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accentWarm.opacity(0.8))
                
                Text("Resource Usage")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.accentWarm)
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                ResourceBar(
                    title: "CPU",
                    value: metrics.cpuUsage,
                    color: Color.blue.opacity(0.8)
                )
                
                ResourceBar(
                    title: "Memory",
                    value: metrics.memoryUsage,
                    color: Color.green.opacity(0.8)
                )
                
                ResourceBar(
                    title: "GPU",
                    value: metrics.gpuUsage,
                    color: Color.purple.opacity(0.8)
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.overlaySoft.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentWarm.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct ResourceBar: View {
    let title: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.accentWarm.opacity(0.7))
            
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.accentWarm.opacity(0.2))
                    .frame(width: 24, height: 60)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: 24, height: 60 * value)
                    .animation(.easeInOut(duration: 1.0), value: value)
            }
            
            Text("\(Int(value * 100))%")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.accentWarm)
        }
    }
}

struct AlternativeOptionsView: View {
    let alternatives: [AlternativeOption]
    let currentOption: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.swap")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accentWarm.opacity(0.8))
                
                Text("Consider These Alternatives")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.accentWarm)
                
                Spacer()
            }
            
            VStack(spacing: 8) {
                ForEach(alternatives, id: \.option) { alternative in
                    AlternativeOptionRow(
                        alternative: alternative,
                        isCurrent: alternative.option == currentOption
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.overlaySoft.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentWarm.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct AlternativeOptionRow: View {
    let alternative: AlternativeOption
    let isCurrent: Bool
    
    var body: some View {
        HStack {
            Text(alternative.option)
                .font(.system(size: 14, weight: isCurrent ? .bold : .medium))
                .foregroundColor(isCurrent ? Color(red: 1.0, green: 0.596, blue: 0.329) : .accentWarm)
            
            if isCurrent {
                Text("(Current)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.accentWarm.opacity(0.6))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(alternative.timeComparison)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(alternative.isFaster ? .green : .red)
                
                QualityStars(rating: alternative.qualityRating, size: 10)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SmartRecommendationView: View {
    let performanceData: PerformanceMetrics
    let enhancementType: String
    let selectedOption: String
    
    var body: some View {
        if let recommendation = performanceData.smartRecommendation {
            HStack(spacing: 12) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 1.0, green: 0.596, blue: 0.329))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Smart Recommendation")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.accentWarm)
                    
                    Text(recommendation)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.accentWarm.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 1.0, green: 0.596, blue: 0.329).opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(red: 1.0, green: 0.596, blue: 0.329).opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

struct QualityStars: View {
    let rating: Double
    let size: CGFloat
    
    init(rating: Double, size: CGFloat = 12) {
        self.rating = rating
        self.size = size
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Image(systemName: "star.fill")
                    .font(.system(size: size))
                    .foregroundColor(
                        Double(index) < rating 
                        ? Color(red: 1.0, green: 0.596, blue: 0.329)
                        : Color.accentWarm.opacity(0.3)
                    )
            }
        }
    }
}

// MARK: - Data Models

class PerformanceEstimationEngine: ObservableObject {
    @Published var currentMetrics: PerformanceMetrics = .default
    
    func analyzeVideo(url: URL, enhancement: String, option: String) {
        // Simulate video analysis
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.currentMetrics = self.generateMetrics(for: enhancement, option: option)
        }
    }
    
    func updateOption(_ option: String, for enhancement: String) {
        currentMetrics = generateMetrics(for: enhancement, option: option)
    }
    
    private func generateMetrics(for enhancement: String, option: String) -> PerformanceMetrics {
        switch enhancement {
        case "AI Upscale":
            return generateUpscaleMetrics(option: option)
        case "AI Denoise":
            return generateDenoiseMetrics(option: option)
        case "Frame Interpolation":
            return generateFrameInterpolationMetrics(option: option)
        default:
            return generateDefaultMetrics(option: option)
        }
    }
    
    private func generateUpscaleMetrics(option: String) -> PerformanceMetrics {
        switch option {
        case "2x":
            return PerformanceMetrics(
                estimatedTime: "2-3 min",
                qualityRating: 4.0,
                batteryImpact: "Moderate",
                riskLevel: .low,
                cpuUsage: 0.7,
                memoryUsage: 0.6,
                gpuUsage: 0.8,
                processingSteps: [
                    ProcessingStep(name: "Video Analysis", duration: "30s", color: .blue),
                    ProcessingStep(name: "AI Upscaling", duration: "2 min", color: .orange),
                    ProcessingStep(name: "Final Export", duration: "20s", color: .green)
                ],
                alternativeOptions: [
                    AlternativeOption(option: "3x", timeComparison: "+1-2 min", qualityRating: 4.5, isFaster: false),
                    AlternativeOption(option: "1080p", timeComparison: "-30s", qualityRating: 3.5, isFaster: true)
                ],
                smartRecommendation: "2x provides the best balance of quality and processing time for most videos."
            )
        case "4x":
            return PerformanceMetrics(
                estimatedTime: "5-7 min",
                qualityRating: 5.0,
                batteryImpact: "High",
                riskLevel: .high,
                cpuUsage: 0.9,
                memoryUsage: 0.8,
                gpuUsage: 0.95,
                processingSteps: [
                    ProcessingStep(name: "Video Analysis", duration: "45s", color: .blue),
                    ProcessingStep(name: "AI Upscaling", duration: "5 min", color: .orange),
                    ProcessingStep(name: "Final Export", duration: "45s", color: .green)
                ],
                alternativeOptions: [
                    AlternativeOption(option: "2x", timeComparison: "-3 min", qualityRating: 4.0, isFaster: true),
                    AlternativeOption(option: "3x", timeComparison: "-2 min", qualityRating: 4.5, isFaster: true)
                ],
                smartRecommendation: "Consider 3x for better performance while maintaining excellent quality."
            )
        default:
            return .default
        }
    }
    
    private func generateDenoiseMetrics(option: String) -> PerformanceMetrics {
        // Similar implementation for other enhancement types
        return .default
    }
    
    private func generateFrameInterpolationMetrics(option: String) -> PerformanceMetrics {
        // Similar implementation for frame interpolation
        return .default
    }
    
    private func generateDefaultMetrics(option: String) -> PerformanceMetrics {
        return .default
    }
}

struct PerformanceMetrics {
    let estimatedTime: String
    let qualityRating: Double
    let batteryImpact: String
    let riskLevel: RiskLevel
    let cpuUsage: Double
    let memoryUsage: Double
    let gpuUsage: Double
    let processingSteps: [ProcessingStep]
    let alternativeOptions: [AlternativeOption]
    let smartRecommendation: String?
    
    var riskColor: Color {
        switch riskLevel {
        case .low: return .green
        case .medium: return Color(red: 1.0, green: 0.596, blue: 0.329)
        case .high: return .red
        }
    }
    
    var riskIcon: String {
        switch riskLevel {
        case .low: return "checkmark.circle"
        case .medium: return "exclamationmark.triangle"
        case .high: return "xmark.octagon"
        }
    }
    
    static let `default` = PerformanceMetrics(
        estimatedTime: "1-2 min",
        qualityRating: 3.5,
        batteryImpact: "Low",
        riskLevel: .low,
        cpuUsage: 0.5,
        memoryUsage: 0.4,
        gpuUsage: 0.6,
        processingSteps: [
            ProcessingStep(name: "Processing", duration: "1 min", color: .orange)
        ],
        alternativeOptions: [],
        smartRecommendation: nil
    )
}

struct ProcessingStep {
    let name: String
    let duration: String
    let color: Color
}

struct AlternativeOption {
    let option: String
    let timeComparison: String
    let qualityRating: Double
    let isFaster: Bool
}

enum RiskLevel {
    case low, medium, high
}

#Preview {
    ZStack {
        Color.primarySoft
            .ignoresSafeArea()
        
        ScrollView {
            IntelligentPerformanceIndicator(
                enhancementType: "AI Upscale",
                selectedOption: "2x",
                videoURL: URL(string: "https://example.com/video.mp4")!
            )
            .padding()
        }
    }
}
