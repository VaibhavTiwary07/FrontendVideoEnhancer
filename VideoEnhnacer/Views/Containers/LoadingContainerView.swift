import SwiftUI

/// Isolated view that manages loading/content state with minimal dependencies
/// Only observes a single boolean binding - prevents unnecessary re-renders from other properties
struct LoadingContainerView: View {
    @Binding var isLoading: Bool
    let loadingView: AnyView
    let contentView: AnyView

    var body: some View {
        let _ = isLoading ? LoadingDebugLogger.shared.log("🔄 LOADING OVERLAY SHOWING - isLoading=true") : LoadingDebugLogger.shared.log("✅ CONTENT SHOWING - isLoading=false")

        Group {
            if isLoading {
                loadingView
            } else {
                contentView
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

// MARK: - Convenience Initializer

extension LoadingContainerView {
    init<LoadingContent: View, ContentView: View>(
        isLoading: Binding<Bool>,
        @ViewBuilder loadingView: @escaping () -> LoadingContent,
        @ViewBuilder contentView: @escaping () -> ContentView
    ) {
        self._isLoading = isLoading
        self.loadingView = AnyView(loadingView())
        self.contentView = AnyView(contentView())
    }
}
