import SwiftUI
import AVFoundation
import PryntTrimmerView

struct PryntTrimmerRepresentable: UIViewRepresentable {
    @Binding var startTime: Double
    @Binding var endTime: Double
    let asset: AVAsset

    func makeUIView(context: Context) -> TrimmerView {
        let trimmer = TrimmerView()
        trimmer.asset = asset
        trimmer.delegate = context.coordinator
        context.coordinator.trimmerView = trimmer
        return trimmer
    }

    func updateUIView(_ uiView: TrimmerView, context: Context) {
        if uiView.asset == nil {
            uiView.asset = asset
        }
        let start = CMTime(seconds: startTime, preferredTimescale: 600)
        let end = CMTime(seconds: endTime, preferredTimescale: 600)
        uiView.startTime = start
        uiView.endTime = end
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(startTime: $startTime, endTime: $endTime)
    }

    class Coordinator: NSObject, TrimmerViewDelegate {
        var startTime: Binding<Double>
        var endTime: Binding<Double>
        weak var trimmerView: TrimmerView?

        init(startTime: Binding<Double>, endTime: Binding<Double>) {
            self.startTime = startTime
            self.endTime = endTime
        }

        private func syncTimes() {
            guard let trimmer = trimmerView else { return }
            startTime.wrappedValue = trimmer.startTime?.seconds ?? 0
            endTime.wrappedValue = trimmer.endTime?.seconds ?? 0
        }

        func didChangePositionBar(_ playerTime: CMTime) {
            syncTimes()
        }

        func positionBarStoppedMoving(_ playerTime: CMTime) {
            syncTimes()
        }
    }
}

