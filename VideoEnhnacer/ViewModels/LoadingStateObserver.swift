import Foundation
import Combine

/// Observer that isolates the isLoading state from a ViewModel to prevent unnecessary body re-renders
/// This breaks the connection between other @Published property changes and the loading UI
@MainActor
final class LoadingStateObserver: ObservableObject {
    @Published private(set) var isLoading: Bool

    private var cancellable: AnyCancellable?

    init(viewModel: VideoTrimmingViewModel) {
        self.isLoading = viewModel.isLoading

        // Only observe isLoading changes, filter out redundant updates
        self.cancellable = viewModel.$isLoading
            .dropFirst() // Skip initial value
            .removeDuplicates() // Only emit when value actually changes
            .sink { [weak self] newValue in
                self?.isLoading = newValue
            }
    }

    deinit {
        cancellable?.cancel()
    }
}
