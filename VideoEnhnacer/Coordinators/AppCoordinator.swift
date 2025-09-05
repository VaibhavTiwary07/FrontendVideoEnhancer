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
    
    // iOS 16+ Navigation Path management - using dynamic approach
    private var _internalNavigationPath: Any?
    
    @available(iOS 16.0, *)
    var navigationPath: NavigationPath {
        get {
            if let path = _internalNavigationPath as? NavigationPath {
                return path
            } else {
                let newPath = NavigationPath()
                _internalNavigationPath = newPath
                return newPath
            }
        }
        set {
            _internalNavigationPath = newValue
        }
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
                var path = navigationPath
                if !path.isEmpty {
                    path.removeLast()
                    _internalNavigationPath = path
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
            _internalNavigationPath = NavigationPath()
        }
        
        currentTab = 0
        finishCurrentFlow()
        
        // ✅ Show Home Ad after navigation reset
        if let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first?.rootViewController {
                
            AdsManager.shared.showInterstitialAd(for: .homeButtonClick, from: rootVC)
        }
    }
    
    func dismissCurrentModal() {
        navigationState = .dismissing
        presentedModal = nil
    }
    
    func resetToRoot() {
        navigationStack = []
        if #available(iOS 16.0, *) {
            _internalNavigationPath = NavigationPath()
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
                var path = navigationPath
                path.append(dest)
                _internalNavigationPath = path
            }
        case .videoTrimming(let data):
            let dest = VideoTrimmingDestination(data: data)
            navigationStack.append(dest)
            if #available(iOS 16.0, *) {
                var path = navigationPath
                path.append(dest)
                _internalNavigationPath = path
            }
        case .enhancementSelection(let data):
            let dest = EnhancementSelectionDestination(data: data)
            navigationStack.append(dest)
            if #available(iOS 16.0, *) {
                var path = navigationPath
                path.append(dest)
                _internalNavigationPath = path
            }
        case .videoResults(let result):
            let dest = VideoResultsDestination(result: result)
            navigationStack.append(dest)
            if #available(iOS 16.0, *) {
                var path = navigationPath
                path.append(dest)
                _internalNavigationPath = path
            }
        case .settings:
            let dest = SettingsDestination()
            navigationStack.append(dest)
            if #available(iOS 16.0, *) {
                var path = navigationPath
                path.append(dest)
                _internalNavigationPath = path
            }
        case .favorites:
            let dest = FavoritesDestination()
            navigationStack.append(dest)
            if #available(iOS 16.0, *) {
                var path = navigationPath
                path.append(dest)
                _internalNavigationPath = path
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


// MARK: - Preview Support
#if DEBUG
extension AppCoordinator {
    static var preview: AppCoordinator {
        AppCoordinator()
    }
}
#endif
