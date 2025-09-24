import SwiftUI

struct VideoEnhancementModalView: View {
    private struct TrimmedVideoData: Hashable {
        let videoURL: URL
        let startTime: Double?
        let endTime: Double?
    }

    private enum Route: Hashable {
        case enhancement(TrimmedVideoData)
        case results(EnhancementResult)
    }

    private enum LegacyStep {
        case trimming
        case enhancement(TrimmedVideoData)
        case results(EnhancementResult)
    }

    @Environment(\.dismiss) private var dismiss
    private let initialVideoURL: URL
    private let enhancementType: EnhancementType

    @State private var path: [Route] = []
    @State private var legacyStep: LegacyStep = .trimming
    @State private var legacyTrimmedData: TrimmedVideoData?

    init(videoURL: URL, enhancementType: EnhancementType) {
        self.initialVideoURL = videoURL
        self.enhancementType = enhancementType
    }

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                modernNavigation
            } else {
                legacyNavigation
            }
        }
        .interactiveDismissDisabled()
    }

    @available(iOS 16.0, *)
    private var modernNavigation: some View {
        NavigationStack(path: $path) {
            trimmingView(
                onBack: { dismiss() },
                onClose: { dismiss() },
                onContinue: { presentEnhancement(with: $0) }
            )
            .navigationDestination(for: Route.self, destination: destination)
            .background(Color.primarySoft.ignoresSafeArea())
        }
    }

    private var legacyNavigation: some View {
        ZStack {
            Color.primarySoft.ignoresSafeArea()
            legacyStepView
        }
    }

    @ViewBuilder
    private var legacyStepView: some View {
        switch legacyStep {
        case .trimming:
            legacyNavigationContainer {
                trimmingView(
                    onBack: { dismiss() },
                    onClose: { dismiss() },
                    onContinue: { data in
                        legacyTrimmedData = data
                        legacyStep = .enhancement(data)
                    }
                )
            }
        case .enhancement(let data):
            legacyNavigationContainer {
                enhancementSelectionView(
                    with: data,
                    onBack: {
                        legacyStep = .trimming
                    },
                    onClose: { dismiss() },
                    onShowResults: { result in
                        legacyTrimmedData = data
                        legacyStep = .results(result)
                    }
                )
            }
        case .results(let result):
            legacyNavigationContainer {
                resultsView(
                    for: result,
                    onBack: {
                        if let data = legacyTrimmedData {
                            legacyStep = .enhancement(data)
                        } else {
                            legacyStep = .trimming
                        }
                    },
                    onClose: { dismiss() }
                )
            }
        }
    }

    private func legacyNavigationContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        NavigationView {
            content()
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func trimmingView(
        onBack: @escaping () -> Void,
        onClose: @escaping () -> Void,
        onContinue: @escaping (TrimmedVideoData) -> Void
    ) -> some View {
        RefactoredVideoTrimmingView(
            videoURL: initialVideoURL,
            enhancementType: enhancementType,
            onBack: onBack,
            onClose: onClose,
            onContinue: { url, start, end in
                let data = TrimmedVideoData(
                    videoURL: url,
                    startTime: start,
                    endTime: end
                )
                legacyTrimmedData = data
                onContinue(data)
            }
        )
    }

    private func enhancementSelectionView(
        with data: TrimmedVideoData,
        onBack: @escaping () -> Void,
        onClose: @escaping () -> Void,
        onShowResults: @escaping (EnhancementResult) -> Void
    ) -> some View {
        RefactoredEnhancementSelectionView(
            videoURL: data.videoURL,
            enhancementType: enhancementType,
            trimStartTime: data.startTime,
            trimEndTime: data.endTime,
            onBack: onBack,
            onClose: onClose,
            onShowResults: onShowResults
        )
    }

    private func resultsView(
        for result: EnhancementResult,
        onBack: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) -> some View {
        VideoResultsView(
            originalVideoURL: result.originalURL,
            processedVideoURL: result.processedURL,
            enhancementType: result.enhancementType.title,
            enhancementIcon: result.enhancementType.icon,
            gradientType: result.enhancementType.gradientType,
            onBack: onBack,
            onClose: onClose
        )
        .navigationBarHidden(true)
    }

    @available(iOS 16.0, *)
    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .enhancement(let data):
            enhancementSelectionView(
                with: data,
                onBack: { popStep() },
                onClose: { dismiss() },
                onShowResults: presentResults
            )
        case .results(let result):
            resultsView(
                for: result,
                onBack: { popStep() },
                onClose: { dismiss() }
            )
        }
    }

    private func presentEnhancement(with data: TrimmedVideoData) {
        legacyTrimmedData = data
        if let last = path.last, case .enhancement = last {
            path[path.count - 1] = .enhancement(data)
        } else {
            path.append(.enhancement(data))
        }
    }

    private func presentResults(_ result: EnhancementResult) {
        if let last = path.last, case .results = last {
            path[path.count - 1] = .results(result)
        } else {
            path.append(.results(result))
        }
    }

    private func popStep() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
}
