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
    @StateObject private var permissionManager = PermissionManager()
    @State private var showingOriginal = false
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showingError = false
    @State private var saveSuccess = false
    @State private var showingSuccess = false
    @State private var showingBackOptions = false
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: enhancementIcon)
                        .font(.system(size: 50, weight: .medium))
                        .foregroundStyle(LinearGradient.primaryTheme)
                    
                    Text("Processing Complete")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Your video has been processed with \(enhancementType)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 40)
                
                // Video Comparison
                VStack(spacing: 20) {
                    // Toggle buttons
                    HStack(spacing: 16) {
                        Button("Original") {
                            showingOriginal = true
                        }
                        .buttonStyle(ComparisonButtonStyle(
                            isSelected: showingOriginal
                        ))
                        
                        Button("Enhanced") {
                            showingOriginal = false
                        }
                        .buttonStyle(ComparisonButtonStyle(
                            isSelected: !showingOriginal
                        ))
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    // Video player
                    VideoPreviewView(videoURL: showingOriginal ? originalVideoURL : processedVideoURL)
                        .frame(height: isIPad ? 400 : 300)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                        .animation(.easeInOut(duration: 0.3), value: showingOriginal)
                }
                .padding(.top, 30)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 16) {
                    // Save to Library
                    Button(action: {
                        saveToPhotoLibrary()
                    }) {
                        HStack(spacing: 12) {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 20, weight: .medium))
                            }
                            
                            Text(isSaving ? "Saving..." : "Save to Photo Library")
                                .font(.system(size: 18, weight: .semibold))
                        }
                    }
                    .buttonStyle(GradientButtonStyle())
                    .disabled(isSaving)
                    .padding(.horizontal, 20)
                    
                    // Share button
                    ShareLink(item: processedVideoURL) {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 20, weight: .medium))
                            
                            Text("Share Video")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.15))
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Process Another Video
                    Button("Process Another Video") {
                        dismissToHome()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Button("Back to Trimming") {
                        dismiss()
                    }
                    
                    Button("Back to Home") {
                        dismissToHome()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.white)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Text("Step 3 of 3")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .alert("Save Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(saveError ?? "Unknown error occurred")
        }
        .alert("Success", isPresented: $showingSuccess) {
            Button("OK") { }
        } message: {
            Text("Video saved to Photo Library successfully!")
        }
    }
    
    private func dismissToHome() {
        // Dismiss all modal views to get back to home
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            if let presentingVC = window.rootViewController?.presentedViewController {
                // Dismiss all presented view controllers
                presentingVC.dismiss(animated: true)
            }
        }
    }
    
    private func saveToPhotoLibrary() {
        // Check photo library permissions first
        guard permissionManager.canAccessPhotoLibrary else {
            saveError = "Photo Library access is required to save videos"
            showingError = true
            return
        }
        
        isSaving = true
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: processedVideoURL)
        }) { success, error in
            DispatchQueue.main.async {
                isSaving = false
                
                if success {
                    saveSuccess = true
                    showingSuccess = true
                } else {
                    saveError = error?.localizedDescription ?? "Failed to save video"
                    showingError = true
                }
            }
        }
    }
}

// Custom button styles for the results view
struct ComparisonButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(isSelected ? .white : .gray)
            .frame(width: 100, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AnyShapeStyle(LinearGradient.primaryTheme) : AnyShapeStyle(Color.white.opacity(0.1)))
                    .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    NavigationView {
        VideoResultsView(
            originalVideoURL: URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!,
            processedVideoURL: URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!,
            enhancementType: "AI Upscale",
            enhancementIcon: "arrow.up.square",
            gradientType: .redPink
        )
    }
}