import SwiftUI
import PhotosUI

/// Container view that manages the entire video enhancement flow in a single modal
/// Provides seamless transition from picker to enhancement without modal dismissal/presentation
struct VideoEnhancementFlowView: View {

    // MARK: - Flow State
    enum FlowState {
        case picker
        case enhancement(URL)
    }

    // MARK: - Properties
    @Environment(\.dismiss) private var dismiss
    @State private var flowState: FlowState = .picker
    let enhancementType: EnhancementType

    // MARK: - Body
    var body: some View {
        switch flowState {
        case .picker:
            // Show video picker first
            InlineUIKitVideoPicker(
                onVideoSelected: { url in
                    print("🎬 VideoEnhancementFlowView: Video selected - \(url.lastPathComponent)")
                    // Instant transition to enhancement - no delay, no modal changes
                    flowState = .enhancement(url)
                },
                onCancelled: {
                    print("🎬 VideoEnhancementFlowView: Picker cancelled, dismissing flow")
                    dismiss()
                }
            )

        case .enhancement(let videoURL):
            // Show enhancement modal once video is selected
            VideoEnhancementModalView(
                videoURL: videoURL,
                enhancementType: enhancementType
            )
            .onAppear {
                print("🎬 VideoEnhancementFlowView: Enhancement view appeared for \(videoURL.lastPathComponent)")
            }
        }
    }
}
