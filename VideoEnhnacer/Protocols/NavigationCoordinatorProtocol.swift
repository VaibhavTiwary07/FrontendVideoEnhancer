import Foundation
import SwiftUI
import Combine

// MARK: - Navigation Coordinator Protocol
/// Defines the contract for app navigation following Single Responsibility Principle
@MainActor
protocol NavigationCoordinatorProtocol: AnyObject {
    // MARK: - Navigation State
    var navigationStatePublisher: Published<NavigationState>.Publisher { get }
    var currentFlowPublisher: Published<NavigationFlow?>.Publisher { get }
    
    // MARK: - Flow Management
    func startEnhancementFlow(with type: EnhancementType)
    func startVideoPickerFlow()
    func startTrimmingFlow(videoURL: URL, enhancement: EnhancementType)
    func startProcessingFlow(request: EnhancementRequest)
    func startResultsFlow(result: EnhancementResult)
    
    // MARK: - Navigation Actions
    func goBack()
    func goToHome()
    func dismissCurrentModal()
    func resetToRoot()
    
    // MARK: - Deep Linking
    func handleDeepLink(_ url: URL) -> Bool
    func canHandle(deepLink url: URL) -> Bool
}

// MARK: - Navigation State
enum NavigationState: Equatable {
    case idle
    case navigating(to: NavigationDestination)
    case presenting(NavigationModal)
    case dismissing
}

// MARK: - Navigation Flow
enum NavigationFlow: Equatable, Identifiable {
    case enhancement(EnhancementType)
    case videoPicker
    case videoTrimming(VideoTrimmingFlowData)
    case videoProcessing(EnhancementRequest)
    case videoResults(EnhancementResult)
    
    var id: String {
        switch self {
        case .enhancement(let type):
            return "enhancement_\(type.id)"
        case .videoPicker:
            return "video_picker"
        case .videoTrimming(let data):
            return "trimming_\(data.videoURL.lastPathComponent)"
        case .videoProcessing(let request):
            return "processing_\(request.enhancementType.id)"
        case .videoResults(let result):
            return "results_\(result.processedURL.lastPathComponent)"
        }
    }
}

// MARK: - Navigation Destination
enum NavigationDestination: Equatable {
    case home
    case videoPicker(EnhancementType)
    case videoTrimming(VideoTrimmingFlowData)
    case enhancementSelection(EnhancementSelectionFlowData)
    case videoResults(EnhancementResult)
    case settings
    case favorites
    case myCreations
}

// MARK: - Navigation Modal
enum NavigationModal: Equatable, Identifiable {
    case videoPropertyList
    case sidebar
    case processingOverlay(EnhancementRequest)
    case errorAlert(NavigationError)
    
    var id: String {
        switch self {
        case .videoPropertyList:
            return "video_property_list"
        case .sidebar:
            return "sidebar"
        case .processingOverlay(let request):
            return "processing_\(request.enhancementType.id)"
        case .errorAlert(let error):
            return "error_\(error.id)"
        }
    }
}

// MARK: - Flow Data Structures
struct VideoTrimmingFlowData: Equatable, Hashable {
    let videoURL: URL
    let enhancementType: EnhancementType
}

struct EnhancementSelectionFlowData: Equatable, Hashable {
    let videoURL: URL
    let enhancementType: EnhancementType
    let trimStartTime: Double?
    let trimEndTime: Double?
}

// MARK: - Navigation Error
struct NavigationError: Error, Equatable, Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let recoveryAction: NavigationRecoveryAction?
    
    static func == (lhs: NavigationError, rhs: NavigationError) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Navigation Recovery Action
struct NavigationRecoveryAction: Equatable {
    let title: String
    let action: NavigationRecoveryActionType
}

enum NavigationRecoveryActionType: Equatable {
    case goHome
    case retry
    case dismiss
    case goBack
}

// MARK: - Deep Link Support
protocol DeepLinkHandling {
    func canHandle(url: URL) -> Bool
    func handle(url: URL) -> NavigationDestination?
}

// MARK: - Navigation Delegate
protocol NavigationCoordinatorDelegate: AnyObject {
    func coordinatorDidStartFlow(_ coordinator: NavigationCoordinatorProtocol, flow: NavigationFlow)
    func coordinatorDidFinishFlow(_ coordinator: NavigationCoordinatorProtocol, flow: NavigationFlow)
    func coordinatorDidEncounterError(_ coordinator: NavigationCoordinatorProtocol, error: NavigationError)
}