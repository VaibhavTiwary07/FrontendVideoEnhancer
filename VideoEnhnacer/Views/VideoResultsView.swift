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

            HStack(spacing: 12) {
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
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            self.mode = mode
        }) {
            HStack(spacing: 8) {
                Image(systemName: symbolForMode(mode))
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(self.mode == mode ? .white : .white.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(self.mode == mode ? LinearGradient.primaryTheme : LinearGradient(colors: [Color.white.opacity(0.1)], startPoint: .leading, endPoint: .trailing))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(self.mode == mode ? Color.white.opacity(0.2) : Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(
                color: self.mode == mode ? Color.black.opacity(0.2) : Color.clear,
                radius: self.mode == mode ? 4 : 0,
                x: 0,
                y: self.mode == mode ? 2 : 0
            )
            .scaleEffect(self.mode == mode ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: self.mode == mode)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func symbolForMode(_ mode: ViewMode) -> String {
        switch mode {
        case .original:
            return "video.fill"
        case .compare:
            return "slider.horizontal.below.rectangle"
        case .output:
            return "wand.and.stars"
        }
    }

    private var finalPage: some View {
        VStack(spacing: 20) {
            // Back button header
            HStack {
                Button(action: { 
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    selectedTab = 0 
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient.primaryTheme.opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
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
