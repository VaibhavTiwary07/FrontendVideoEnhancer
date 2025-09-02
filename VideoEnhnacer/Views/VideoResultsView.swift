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
                .onAppear {
                    print("🎥 Original mode appeared")
                }
        case .compare:
            VideoComparisonSlider(
                normalVideoName: nil,
                enhancedVideoName: nil,
                originalURL: originalVideoURL,
                enhancedURL: processedVideoURL,
                videoPlayerManager: videoPlayerManager
            )
            .onAppear {
                print("🎥 Compare mode appeared")
                print("🎥 normalVideoName: nil")
                print("🎥 enhancedVideoName: nil")
                print("🎥 originalURL: \(originalVideoURL)")
                print("🎥 enhancedURL: \(processedVideoURL)")
            }
        case .output:
            VideoPreviewView(videoURL: processedVideoURL)
                .onAppear {
                    print("🎥 Output mode appeared")
                }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            comparisonPage.tag(0)
            finalPage.tag(1)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .onAppear {
            print("🎬 VideoResultsView appeared")
            print("🎬 Current mode: \(mode)")
            print("🎬 Video key: \(generateVideoKey())")
            
            // Pre-setup video players for comparison mode
            videoPlayerManager.setupVideoPlayers(forKey: generateVideoKey(), originalURL: originalVideoURL, processedURL: processedVideoURL)
            videoPlayerManager.setViewActive(forKey: generateVideoKey(), isActive: true)
        }
    }

    private var comparisonPage: some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
//                    Text("Back")
                }
                .foregroundColor(.white)
                Spacer()

                // Export button moved to top-right
                Button(action: {
                    showingExportOptions = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.to.line")
                            .font(.system(size: 14, weight: .medium))
                        Text("Export")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 70, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(LinearGradient.primaryTheme)
                    )
                }
            }
            .padding()

            Spacer()

            currentModeView
            .frame(height: 300)
            .padding()

            HStack(spacing: 12) {
                modeButton(title: "Original", mode: .original)
                modeButton(title: "Compare", mode: .compare)
                modeButton(title: "Output", mode: .output)
            }
            .padding()

            Spacer()
        }
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
                        self.selectedTab = 1
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(1)
            }
        }
    }

    private func modeButton(title: String, mode: ViewMode) -> some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            
            print("🔄 Switching to mode: \(mode)")
            print("🔄 Original URL: \(originalVideoURL)")
            print("🔄 Processed URL: \(processedVideoURL)")
            print("🔄 VideoPlayerManager state before switch: \(videoPlayerManager.getPlayerState(forKey: generateVideoKey()))")
            
            self.mode = mode
            
            print("🔄 Mode switched to: \(self.mode)")
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
    
    private func generateVideoKey() -> String {
        return "\(originalVideoURL.absoluteString.hashValue)-\(processedVideoURL.absoluteString.hashValue)"
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
//                        Text("Back")
//                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
//                    .background(
//                        RoundedRectangle(cornerRadius: 12)
//                            .fill(LinearGradient.primaryTheme.opacity(0.8))
//                            .overlay(
//                                RoundedRectangle(cornerRadius: 12)
//                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
//                            )
//                    )
//                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
//                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            // Export settings chip (shown when exported video exists)
            if exportedVideoURL != nil {
                HStack(spacing: 8) {
                    Text("\(selectedResolution) • \(selectedFrameRate) • \(selectedFormat.uppercased())")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            
            VideoPreviewView(videoURL: effectiveVideoURL)
                .frame(height: 300)
                .padding()

            FavoriteButton(
                videoURL: effectiveVideoURL,
                enhancementType: enhancementType,
                enhancementIcon: enhancementIcon,
                title: "\(enhancementType) Enhanced Video"
            )

            if #available(iOS 16.0, *) {
                ShareLink(item: effectiveVideoURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(GradientButtonStyle())
            } else {
                Button(action: {
                    // iOS 15 sharing fallback
                    let activityController = UIActivityViewController(
                        activityItems: [effectiveVideoURL],
                        applicationActivities: nil
                    )
                    
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootViewController = windowScene.windows.first?.rootViewController {
                        rootViewController.present(activityController, animated: true)
                    }
                }) {
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
        // ExportOptionsView overlay is shown on the comparison page only
    }

    private func exportVideo() {
        print("🎬 Exporting video with settings:")
        print("Resolution: \(selectedResolution)")
        print("Frame Rate: \(selectedFrameRate)")
        print("Format: \(selectedFormat)")
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        // For now, we'll use the iOS native share functionality
        // In a full implementation, you would process the video with the selected settings
        let activityController = UIActivityViewController(
            activityItems: [processedVideoURL],
            applicationActivities: nil
        )
        
        // Present the share sheet
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            
            // For iPad, we need to set the popover presentation controller
            if let popover = activityController.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootViewController.present(activityController, animated: true)
        }
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
