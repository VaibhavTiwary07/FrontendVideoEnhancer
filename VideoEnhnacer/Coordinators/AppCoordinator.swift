import Foundation
import SwiftUI
import Combine

// MARK: - App Coordinator
/// Central navigation coordinator following Coordinator Pattern and Single Responsibility Principle
@MainActor
final class AppCoordinator: NavigationCoordinatorProtocol, ObservableObject {
    
    // MARK: - Published Properties
    @Published private var navigationState: NavigationState = .idle
    @Published private var currentFlow: NavigationFlow?
    
    // Universal Navigation State - works for both iOS versions
    @Published var navigationStack: [AnyHashable] = []
    
    // iOS 16+ Navigation Path (computed property to avoid @available on stored property)
    @available(iOS 16.0, *)
    private var _navigationPath = NavigationPath()
    
    @available(iOS 16.0, *)
    var navigationPath: NavigationPath {
        get { _navigationPath }
        set { _navigationPath = newValue }
    }
    
    @Published var presentedModal: NavigationModal?
    @Published var showingSidebar: Bool = false
    @Published var currentTab: Int = 0
    
    var navigationStatePublisher: Published<NavigationState>.Publisher { $navigationState }
    var currentFlowPublisher: Published<NavigationFlow?>.Publisher { $currentFlow }
    
    // MARK: - Private Properties
    private var flowHistory: [NavigationFlow] = []
    private weak var delegate: NavigationCoordinatorDelegate?
    private let deepLinkHandler = DeepLinkHandler()
    
    // MARK: - Initialization
    init(delegate: NavigationCoordinatorDelegate? = nil) {
        self.delegate = delegate
    }
    
    // MARK: - NavigationCoordinatorProtocol Implementation
    func startEnhancementFlow(with type: EnhancementType) {
        let flow = NavigationFlow.enhancement(type)
        startFlow(flow)
        
        let destination = NavigationDestination.videoPicker(type)
        navigateToDestination(destination)
    }
    
    func startVideoPickerFlow() {
        presentModal(.videoPropertyList)
    }
    
    func startTrimmingFlow(videoURL: URL, enhancement: EnhancementType) {
        let flowData = VideoTrimmingFlowData(videoURL: videoURL, enhancementType: enhancement)
        let flow = NavigationFlow.videoTrimming(flowData)
        startFlow(flow)
        
        let destination = NavigationDestination.videoTrimming(flowData)
        navigateToDestination(destination)
    }
    
    func startProcessingFlow(request: EnhancementRequest) {
        let flow = NavigationFlow.videoProcessing(request)
        startFlow(flow)
        
        presentModal(.processingOverlay(request))
    }
    
    func startResultsFlow(result: EnhancementResult) {
        let flow = NavigationFlow.videoResults(result)
        startFlow(flow)
        
        let destination = NavigationDestination.videoResults(result)
        navigateToDestination(destination)
    }
    
    func goBack() {
        navigationState = .navigating(to: .home)
        
        if !navigationStack.isEmpty {
            navigationStack.removeLast()
            if #available(iOS 16.0, *) {
                if !_navigationPath.isEmpty {
                    _navigationPath.removeLast()
                }
            }
        } else {
            goToHome()
        }
    }
    
    func goToHome() {
        navigationState = .navigating(to: .home)
        
        navigationStack = []
        if #available(iOS 16.0, *) {
            _navigationPath = NavigationPath()
        }
        
        currentTab = 0
        finishCurrentFlow()
    }
    
    func dismissCurrentModal() {
        navigationState = .dismissing
        presentedModal = nil
    }
    
    func resetToRoot() {
        navigationStack = []
        if #available(iOS 16.0, *) {
            _navigationPath = NavigationPath()
        }
        
        presentedModal = nil
        showingSidebar = false
        currentTab = 0
        currentFlow = nil
        flowHistory.removeAll()
        navigationState = .idle
    }
    
    func handleDeepLink(_ url: URL) -> Bool {
        return deepLinkHandler.handle(url: url, coordinator: self)
    }
    
    func canHandle(deepLink url: URL) -> Bool {
        return deepLinkHandler.canHandle(url: url)
    }
    
    // MARK: - Tab Navigation
    func switchTab(to index: Int) {
        currentTab = index
        
        switch index {
        case 0:
            navigateToDestination(.home)
        case 1:
            navigateToDestination(.myCreations)
        default:
            navigateToDestination(.home)
        }
    }
    
    // MARK: - Modal Presentation
    func presentModal(_ modal: NavigationModal) {
        navigationState = .presenting(modal)
        presentedModal = modal
    }
    
    func toggleSidebar() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showingSidebar.toggle()
        }
    }
    
    func showSettings() {
        navigateToDestination(.settings)
    }
    
    func showFavorites() {
        navigateToDestination(.favorites)
    }
    
    // MARK: - Error Handling
    func handleError(_ error: Error, title: String = "Error") {
        let navigationError = NavigationError(
            title: title,
            message: error.localizedDescription,
            recoveryAction: NavigationRecoveryAction(
                title: "OK",
                action: .dismiss
            )
        )
        
        presentModal(.errorAlert(navigationError))
        delegate?.coordinatorDidEncounterError(self, error: navigationError)
    }
    
    func handleRecoveryAction(_ action: NavigationRecoveryActionType) {
        switch action {
        case .goHome:
            goToHome()
        case .retry:
            // Retry logic would be implemented based on context
            break
        case .dismiss:
            dismissCurrentModal()
        case .goBack:
            goBack()
        }
    }
    
    // MARK: - Private Methods
    private func startFlow(_ flow: NavigationFlow) {
        currentFlow = flow
        flowHistory.append(flow)
        delegate?.coordinatorDidStartFlow(self, flow: flow)
        
        print("🧭 AppCoordinator - Started flow: \(flow.id)")
    }
    
    private func finishCurrentFlow() {
        if let flow = currentFlow {
            delegate?.coordinatorDidFinishFlow(self, flow: flow)
            print("🧭 AppCoordinator - Finished flow: \(flow.id)")
        }
        currentFlow = nil
    }
    
    private func navigateToDestination(_ destination: NavigationDestination) {
        navigationState = .navigating(to: destination)
        
        // Handle navigation based on destination type
        switch destination {
        case .home:
            currentTab = 0
        case .myCreations:
            currentTab = 1
        case .videoPicker(let type):
            let dest = VideoPickerDestination(enhancementType: type)
            navigationStack.append(dest)
            if #available(iOS 16.0, *) {
                _navigationPath.append(dest)
            }
        case .videoTrimming(let data):
            let dest = VideoTrimmingDestination(data: data)
            navigationStack.append(dest)
            if #available(iOS 16.0, *) {
                _navigationPath.append(dest)
            }
        case .enhancementSelection(let data):
            let dest = EnhancementSelectionDestination(data: data)
            navigationStack.append(dest)
            if #available(iOS 16.0, *) {
                _navigationPath.append(dest)
            }
        case .videoResults(let result):
            let dest = VideoResultsDestination(result: result)
            navigationStack.append(dest)
            if #available(iOS 16.0, *) {
                _navigationPath.append(dest)
            }
        case .settings:
            let dest = SettingsDestination()
            navigationStack.append(dest)
            if #available(iOS 16.0, *) {
                _navigationPath.append(dest)
            }
        case .favorites:
            let dest = FavoritesDestination()
            navigationStack.append(dest)
            if #available(iOS 16.0, *) {
                _navigationPath.append(dest)
            }
        }
        
        // Reset state after navigation
        Task {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            navigationState = .idle
        }
    }
}

// MARK: - Navigation Destinations for NavigationPath
struct VideoPickerDestination: Hashable {
    let enhancementType: EnhancementType
}

struct VideoTrimmingDestination: Hashable {
    let data: VideoTrimmingFlowData
    
    static func == (lhs: VideoTrimmingDestination, rhs: VideoTrimmingDestination) -> Bool {
        lhs.data == rhs.data
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(data)
    }
}

struct EnhancementSelectionDestination: Hashable {
    let data: EnhancementSelectionFlowData
    
    static func == (lhs: EnhancementSelectionDestination, rhs: EnhancementSelectionDestination) -> Bool {
        lhs.data == rhs.data
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(data)
    }
}

struct VideoResultsDestination: Hashable {
    let result: EnhancementResult
    
    static func == (lhs: VideoResultsDestination, rhs: VideoResultsDestination) -> Bool {
        lhs.result == rhs.result
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(result)
    }
}

struct SettingsDestination: Hashable {}
struct FavoritesDestination: Hashable {}

// MARK: - Deep Link Handler
final class DeepLinkHandler: DeepLinkHandling {
    func canHandle(url: URL) -> Bool {
        guard url.scheme == "videoenhancer" else { return false }
        
        let supportedHosts = ["enhancement", "video", "results"]
        return supportedHosts.contains(url.host ?? "")
    }
    
    func handle(url: URL, coordinator: AppCoordinator) -> Bool {
        guard canHandle(url: url) else { return false }
        
        switch url.host ?? "" {
        case "enhancement":
            return handleEnhancementDeepLink(url: url, coordinator: coordinator)
        case "video":
            return handleVideoDeepLink(url: url, coordinator: coordinator)
        case "results":
            return handleResultsDeepLink(url: url, coordinator: coordinator)
        default:
            return false
        }
    }
    
    func handle(url: URL) -> NavigationDestination? {
        // This method is for protocol conformance but not used in this implementation
        return nil
    }
    
    private func handleEnhancementDeepLink(url: URL, coordinator: AppCoordinator) -> Bool {
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        guard let enhancementId = pathComponents.first else { return false }
        
        // Get enhancement type from registry
        if let enhancementType = EnhancementTypeRegistry.shared.getEnhancementType(withId: enhancementId) {
            Task { @MainActor in
                coordinator.startEnhancementFlow(with: enhancementType)
            }
            return true
        }
        
        return false
    }
    
    private func handleVideoDeepLink(url: URL, coordinator: AppCoordinator) -> Bool {
        // Handle video-related deep links
        Task { @MainActor in
            coordinator.startVideoPickerFlow()
        }
        return true
    }
    
    private func handleResultsDeepLink(url: URL, coordinator: AppCoordinator) -> Bool {
        // Handle results deep links
        Task { @MainActor in
            coordinator.goToHome()
            coordinator.switchTab(to: 1) // My Creations tab
        }
        return true
    }
}

// MARK: - Preview Support
#if DEBUG
extension AppCoordinator {
    static var preview: AppCoordinator {
        AppCoordinator()
    }
}
#endif