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

    @State private var tabSelection = 0
    @State private var comparisonMode: ComparisonMode = .original

    @Environment(\.dismiss) private var dismiss
    @StateObject private var permissionManager = PermissionManager()
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showingError = false
    @State private var saveSuccess = false
    @State private var showingSuccess = false

    enum ComparisonMode {
        case original, compare, output
    }

    var body: some View {
        TabView(selection: $tabSelection) {
            ComparisonScreen(
                originalVideoURL: originalVideoURL,
                processedVideoURL: processedVideoURL,
                mode: $comparisonMode,
                onOutput: {
                    tabSelection = 1
                }
            )
            .tag(0)

            FinalOutputScreen(
                processedVideoURL: processedVideoURL,
                enhancementType: enhancementType,
                isSaving: $isSaving,
                saveSuccess: $saveSuccess,
                saveError: $saveError,
                showingError: $showingError,
                showingSuccess: $showingSuccess,
                saveToPhotoLibrary: saveToPhotoLibrary,
                dismissToHome: dismissToHome
            )
            .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .alert("Save Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(saveError ?? "Unknown error occurred")
        }
        .alert("Saved Successfully", isPresented: $showingSuccess) {
            Button("OK") {
                saveSuccess = true
            }
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

struct ComparisonScreen: View {
    let originalVideoURL: URL
    let processedVideoURL: URL
    @Binding var mode: VideoResultsView.ComparisonMode
    var onOutput: () -> Void
    @StateObject private var videoPlayerManager = VideoPlayerManager()

    var body: some View {
        VStack(spacing: 30) {
            Group {
                switch mode {
                case .original:
                    VideoPreviewView(videoURL: originalVideoURL)
                case .compare:
                    VideoComparisonSlider(
                        normalVideoName: originalVideoURL.deletingPathExtension().lastPathComponent,
                        enhancedVideoName: processedVideoURL.deletingPathExtension().lastPathComponent,
                        videoPlayerManager: videoPlayerManager
                    )
                case .output:
                    VideoPreviewView(videoURL: processedVideoURL)
                }
            }
            .frame(height: 320)
            .cornerRadius(20)
            .padding(.horizontal, 20)

            HStack(spacing: 16) {
                Button("Original") { mode = .original }
                    .buttonStyle(ComparisonButtonStyle(isSelected: mode == .original))

                Button("Compare") { mode = .compare }
                    .buttonStyle(ComparisonButtonStyle(isSelected: mode == .compare))

                Button("Output") {
                    mode = .output
                    onOutput()
                }
                    .buttonStyle(ComparisonButtonStyle(isSelected: mode == .output))
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
}

struct ComparisonButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.orange : Color.white.opacity(0.2))
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

struct FinalOutputScreen: View {
    let processedVideoURL: URL
    let enhancementType: String
    @Binding var isSaving: Bool
    @Binding var saveSuccess: Bool
    @Binding var saveError: String?
    @Binding var showingError: Bool
    @Binding var showingSuccess: Bool
    let saveToPhotoLibrary: () -> Void
    let dismissToHome: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ResultsHeaderSection(
                    enhancementType: enhancementType,
                    saveSuccess: saveSuccess
                )
                .padding(.top, 40)

                VideoPreviewView(videoURL: processedVideoURL)
                    .frame(height: 320)
                    .cornerRadius(20)
                    .padding(.horizontal, 20)
                    .padding(.top, 30)

                Spacer(minLength: 40)

                ActionButtonsSection(
                    processedVideoURL: processedVideoURL,
                    isSaving: isSaving,
                    saveToPhotoLibrary: saveToPhotoLibrary,
                    dismissToHome: dismissToHome
                )
                .padding(.bottom, 40)
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
}

struct ResultsHeaderSection: View {
    let enhancementType: String
    let saveSuccess: Bool

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(LinearGradient.primaryTheme)
                    .frame(width: 100, height: 100)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
            }
            .scaleEffect(saveSuccess ? 1.1 : 1.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: saveSuccess)

            VStack(spacing: 8) {
                Text("Enhancement Complete!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

                Text("Your video has been enhanced with \(enhancementType)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            HStack(spacing: 8) {
                ForEach(1...4, id: \.self) { step in
                    Circle()
                        .fill(Color.white)
                        .frame(width: step == 4 ? 10 : 8, height: step == 4 ? 10 : 8)
                }
            }
            .padding(.top, 10)
        }
    }
}

struct ActionButtonsSection: View {
    let processedVideoURL: URL
    let isSaving: Bool
    let saveToPhotoLibrary: () -> Void
    let dismissToHome: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        saveToPhotoLibrary()
                    }) {
                        VStack(spacing: 6) {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                            } else {
                                Image(systemName: "square.and.arrow.down.fill")
                                    .font(.system(size: 20, weight: .medium))
                            }

                            Text(isSaving ? "Saving..." : "Save")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 72)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(LinearGradient.primaryTheme)
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                    }
                    .disabled(isSaving)

                    ShareLink(item: processedVideoURL) {
                        VStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up.fill")
                                .font(.system(size: 20, weight: .medium))

                            Text("Share")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 72)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        )
                    }

                    VStack(spacing: 6) {
                        FavoriteButton(
                            videoURL: processedVideoURL,
                            enhancementType: "Enhanced Video",
                            title: "Enhanced Video"
                        )
                        .scaleEffect(1.1)

                        Text("Favorite")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    )
                }
            }
            .padding(.horizontal, 20)

            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                dismissToHome()
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .medium))

                    Text("Process Another Video")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.8))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 20)
        }
    }
}

