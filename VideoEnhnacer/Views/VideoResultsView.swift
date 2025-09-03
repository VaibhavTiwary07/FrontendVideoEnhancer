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
                videoPlayerManager: videoPlayerManager,
                backgroundColor: Color.black
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
                    enhancementStyleModeButton(.original, title: "Original")
                    enhancementStyleModeButton(.compare, title: "Compare")
                    enhancementStyleModeButton(.output, title: "Enhanced")
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
        .onDisappear {
            // Clean up video players to prevent state conflicts with other views
            videoPlayerManager.cleanupPlayersForKey(generateVideoKey())
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

    private func enhancementStyleModeButton(_ target: ViewMode, title: String) -> some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            self.mode = target
        }) {
            let isSelected = (self.mode == target)
            VStack(spacing: 4) {
                Image(systemName: symbolForMode(target))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : Color.white.opacity(0.8))
                
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white : Color.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 70, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? LinearGradient.primaryTheme : LinearGradient(colors: [Color.white.opacity(0.08)], startPoint: .leading, endPoint: .trailing))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(isSelected ? 0.2 : 0.1), radius: isSelected ? 6 : 3, x: 0, y: isSelected ? 3 : 2)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
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
            return "rectangle.split.2x1"
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

#if DEBUG
struct VideoResultsView_Previews: PreviewProvider {
    static var previews: some View {
        // Fallback URLs in case bundle lookups fail
        let original = Bundle.main.url(forResource: "StablilizationBefore", withExtension: "mp4") ?? URL(fileURLWithPath: "/tmp/original.mp4")
        let processed = Bundle.main.url(forResource: "StabilizationAfter", withExtension: "mp4") ?? URL(fileURLWithPath: "/tmp/processed.mp4")
        
        return Group {
            VideoResultsView(
                originalVideoURL: original,
                processedVideoURL: processed,
                enhancementType: "Stabilizer",
                enhancementIcon: "gyroscope",
                gradientType: .gray
            )
            .environmentObject(VideoPlayerManager())
            .previewDisplayName("Stabilizer - Output")
            
            VideoResultsView(
                originalVideoURL: Bundle.main.url(forResource: "interpolation_Before", withExtension: "mp4") ?? original,
                processedVideoURL: Bundle.main.url(forResource: "interpolation_After", withExtension: "mp4") ?? processed,
                enhancementType: "Frame Interpolation",
                enhancementIcon: getIOSCompatibleSymbol("timer.circle.fill", fallback: "timer"),
                gradientType: .cyanGray
            )
            .environmentObject(VideoPlayerManager())
            .previewDisplayName("Interpolation - Output")
        }
        .background(Color.black)
    }
}
#endif
