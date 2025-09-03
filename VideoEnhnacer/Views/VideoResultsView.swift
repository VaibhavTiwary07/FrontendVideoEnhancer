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
    @State private var mode: ViewMode = .output
    @EnvironmentObject private var videoPlayerManager: VideoPlayerManager
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showingError = false
    @State private var saveSuccess = false
    @State private var showingExportOptions = false
    @State private var selectedResolution = "1080p"
    @State private var selectedFrameRate = "30fps"
    @State private var selectedFormat = "MP4"
    @State private var exportedVideoURL: URL? = nil

    enum ViewMode { case original, compare, output }
    
    @ViewBuilder
    private var currentModeView: some View {
        switch mode {
        case .original:
            VideoPreviewView(videoURL: originalVideoURL)
        case .compare:
            VideoComparisonSlider(
                normalVideoName: nil,
                enhancedVideoName: nil,
                originalURL: originalVideoURL,
                enhancedURL: processedVideoURL,
                videoPlayerManager: videoPlayerManager
            )
        case .output:
            VideoPreviewView(videoURL: processedVideoURL)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let playerHeight = max(360, geo.size.height * 0.78)
            VStack(spacing: 16) {
                // Top bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                    }
                    .foregroundColor(.white)
                    Spacer()
                    Button(action: { showingExportOptions = true }) {
                        Image(systemName: "arrow.down.to.line")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(LinearGradient.primaryTheme)
                            )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Player
                currentModeView
                    .frame(height: playerHeight)
                    .padding(.horizontal)

                // Mode buttons
                HStack(spacing: 12) {
                    squareModeButton(.original)
                    squareModeButton(.compare)
                    squareModeButton(.output)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.black.ignoresSafeArea())
            .overlay {
                if showingExportOptions {
                    ExportOptionsView(
                        isPresented: $showingExportOptions,
                        selectedResolution: $selectedResolution,
                        selectedFrameRate: $selectedFrameRate,
                        selectedFormat: $selectedFormat,
                        onExport: { },
                        videoURL: processedVideoURL,
                        onCompleted: { url in
                            self.exportedVideoURL = url
                        }
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(1)
                }
            }
        }
        .onAppear {
            // Pre-setup video players for comparison mode
            videoPlayerManager.setupVideoPlayers(forKey: generateVideoKey(), originalURL: originalVideoURL, processedURL: processedVideoURL)
            videoPlayerManager.setViewActive(forKey: generateVideoKey(), isActive: true)
        }
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

    private func squareModeButton(_ target: ViewMode) -> some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            self.mode = target
        }) {
            let selected = (self.mode == target)
            Image(systemName: symbolForMode(target))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(selected ? .white : .white.opacity(0.8))
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selected ? LinearGradient.primaryTheme : LinearGradient(colors: [Color.white.opacity(0.08)], startPoint: .top, endPoint: .bottom))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selected ? Color.white.opacity(0.25) : Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .shadow(color: selected ? Color.black.opacity(0.2) : .clear, radius: selected ? 4 : 0, x: 0, y: selected ? 2 : 0)
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
    
    private func generateVideoKey() -> String {
        return "\(originalVideoURL.absoluteString.hashValue)-\(processedVideoURL.absoluteString.hashValue)"
    }

    private var effectiveVideoURL: URL {
        return exportedVideoURL ?? processedVideoURL
    }

    private func saveToPhotoLibrary() {
        isSaving = true
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: effectiveVideoURL)
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
