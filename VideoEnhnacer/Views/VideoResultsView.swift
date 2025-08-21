import SwiftUI
import AVFoundation
import AVKit
import PhotosUI

struct VideoResultsView: View {
    let originalVideoURL: URL
    let processedVideoURL: URL
    let enhancementType: String
    let enhancementIcon: String
    let gradientType: GradientType

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var mode: ViewMode = .original
    @StateObject private var videoPlayerManager = VideoPlayerManager()
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showingError = false
    @State private var saveSuccess = false

    enum ViewMode { case original, compare, output }

    var body: some View {
        TabView(selection: $selectedTab) {
            comparisonPage.tag(0)
            finalPage.tag(1)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
    }

    private var comparisonPage: some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .foregroundColor(.white)
                Spacer()
            }
            .padding()

            Spacer()

            Group {
                switch mode {
                case .original:
                    VideoPreviewView(videoURL: originalVideoURL)
                case .compare:
                    VideoComparisonSlider(normalVideoName: "normal", enhancedVideoName: "enhanced", videoPlayerManager: videoPlayerManager)
                case .output:
                    VideoPreviewView(videoURL: processedVideoURL)
                }
            }
            .frame(height: 300)
            .padding()

            HStack(spacing: 20) {
                modeButton(title: "Original", mode: .original)
                modeButton(title: "Compare", mode: .compare)
                modeButton(title: "Output", mode: .output)
            }
            .padding()

            Spacer()

            Button("Save & Share") {
                selectedTab = 1
            }
            .buttonStyle(GradientButtonStyle())
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
    }

    private func modeButton(title: String, mode: ViewMode) -> some View {
        Button(title) { self.mode = mode }
            .foregroundColor(self.mode == mode ? .accentWarm : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(self.mode == mode ? Color.accentWarm.opacity(0.2) : Color.clear)
            )
    }

    private var finalPage: some View {
        VStack(spacing: 20) {
            VideoPreviewView(videoURL: processedVideoURL)
                .frame(height: 300)
                .padding()

            FavoriteButton(
                videoURL: processedVideoURL,
                enhancementType: enhancementType,
                enhancementIcon: enhancementIcon,
                title: "\(enhancementType) Enhanced Video"
            )

            if #available(iOS 16.0, *) {
                ShareLink(item: processedVideoURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(GradientButtonStyle())
            }

            Button(action: saveToPhotoLibrary) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text(isSaving ? "Saving..." : "Save to Photos")
                }
            }
            .buttonStyle(GradientButtonStyle())
            .disabled(isSaving)

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
        .alert("Save Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(saveError ?? "Unknown error occurred")
        }
        .alert("Saved Successfully", isPresented: $saveSuccess) {
            Button("OK") { }
        } message: {
            Text("Video has been saved to your photo library")
        }
    }

    private func saveToPhotoLibrary() {
        isSaving = true
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: processedVideoURL)
        }) { success, error in
            DispatchQueue.main.async {
                isSaving = false
                if success {
                    saveSuccess = true
                } else {
                    saveError = error?.localizedDescription ?? "Failed to save video"
                    showingError = true
                }
            }
        }
    }
}
