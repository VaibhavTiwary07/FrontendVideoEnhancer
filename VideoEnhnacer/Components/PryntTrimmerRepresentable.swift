import SwiftUI
import AVFoundation
import PryntTrimmerView

struct PryntTrimmerRepresentable: UIViewRepresentable {
    @Binding var startTime: CMTime
    @Binding var endTime: CMTime
    let asset: AVAsset

    func makeUIView(context: Context) -> TrimmerView {
        let trimmer = TrimmerView()
        trimmer.asset = asset
        trimmer.delegate = context.coordinator as! any TrimmerViewDelegate
        return trimmer
    }

    func updateUIView(_ uiView: TrimmerView, context: Context) {
        // Removed direct assignments to `startTime` and `endTime`.
        // Any programmatic updates should convert times to positions and update
        // handle constraints instead of setting the values directly.
        context.coordinator.syncTimes(from: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject {
        var parent: PryntTrimmerRepresentable

        init(parent: PryntTrimmerRepresentable) {
            self.parent = parent
        }

        func syncTimes(from trimmer: TrimmerView) {
            parent.startTime = trimmer.startTime ?? .zero
            Task { @MainActor in
                do {
                    let duration = try await parent.asset.load(.duration)
                    parent.endTime = trimmer.endTime ?? duration
                } catch {
                    print("Error loading asset duration: \(error)")
                }
            }
        }
    }
}
