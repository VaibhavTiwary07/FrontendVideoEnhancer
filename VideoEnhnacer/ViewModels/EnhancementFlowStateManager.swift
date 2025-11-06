import Foundation
import Combine

/// Manages state for the enhancement flow across modal and navigation boundaries
/// Persists VideoTrimmingViewModel so it survives view recreation in iOS 15 legacy mode
@MainActor
class EnhancementFlowStateManager: ObservableObject {
    @Published var trimmingViewModel: VideoTrimmingViewModel?

    /// Creates trimming view model if it doesn't exist, reuses if it does
    func createIfNeeded(url: URL, type: EnhancementType) {
        if trimmingViewModel == nil {
            let container = DIContainer.shared
            trimmingViewModel = container.makeVideoTrimmingViewModel(
                videoURL: url,
                enhancementType: type
            )
            LoadingDebugLogger.shared.log("🆕 CREATED in StateManager: VideoTrimmingViewModel for \(url.lastPathComponent)")
        } else {
            LoadingDebugLogger.shared.log("♻️ REUSING from StateManager: VideoTrimmingViewModel (duration:\(trimmingViewModel?.videoDuration ?? 0)s)")
        }
    }

    /// Resets state when enhancement flow is completed or cancelled
    func reset() {
        LoadingDebugLogger.shared.log("🧹 RESET: Clearing VideoTrimmingViewModel from StateManager")
        trimmingViewModel = nil
    }
}
