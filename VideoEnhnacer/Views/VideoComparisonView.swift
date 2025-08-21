import SwiftUI
import PhotosUI

struct VideoComparisonView: View {
    enum ComparisonMode {
        case original, compare, after
    }

    @State var originalVideoURL: URL
    @State var processedVideoURL: URL
    @Binding var saveSuccess: Bool
    @State private var mode: ComparisonMode = .original

    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showingError = false
    @State private var showingSuccess = false

    var body: some View {
        VStack(spacing: 20) {
            Group {
                switch mode {
                case .original:
                    VideoPreviewView(videoURL: originalVideoURL)
                case .compare:
                    VideoComparisonSlider(
                        normalVideoName: originalVideoURL.deletingPathExtension().lastPathComponent,
                        enhancedVideoName: processedVideoURL.deletingPathExtension().lastPathComponent,
                        videoPlayerManager: VideoPlayerManager()
                    )
                case .after:
                    VideoPreviewView(videoURL: processedVideoURL)
                }
            }
            .frame(height: 320)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 20)

            modeButtons
                .padding(.horizontal, 20)

            ActionButtonsSection(
                processedVideoURL: processedVideoURL,
                isSaving: isSaving,
                saveToPhotoLibrary: saveToPhotoLibrary,
                dismissToHome: dismissToHome
            )
            .padding(.top, 10)
        }
        .alert("Save Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(saveError ?? "Unknown error occurred")
        }
        .alert("Saved Successfully", isPresented: $showingSuccess) {
            Button("OK") { saveSuccess = true }
        } message: {
            Text("Video has been saved to your photo library")
        }
    }

    private var modeButtons: some View {
        HStack {
            modeButton(title: "Original", for: .original)
            modeButton(title: "Compare", for: .compare)
            modeButton(title: "After", for: .after)
        }
    }

    private func modeButton(title: String, for selected: ComparisonMode) -> some View {
        Button(action: { mode = selected }) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(mode == selected ? .orange : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .overlay(
                    Rectangle()
                        .frame(height: 2)
                        .foregroundColor(mode == selected ? .orange : .clear)
                        .padding(.top, 30),
                    alignment: .bottom
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func saveToPhotoLibrary() {
        isSaving = true

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: processedVideoURL)
        }) { success, error in
            DispatchQueue.main.async {
                isSaving = false

                if success {
                    showingSuccess = true
                } else {
                    saveError = error?.localizedDescription ?? "Failed to save video"
                    showingError = true
                }
            }
        }
    }

    private func dismissToHome() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            if let presentingVC = window.rootViewController?.presentedViewController {
                presentingVC.dismiss(animated: true)
            }
        }
    }
}
