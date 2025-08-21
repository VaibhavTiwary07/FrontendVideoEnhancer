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
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    HeaderSection(
                        enhancementType: enhancementType,
                        saveSuccess: saveSuccess
                    )
                    .padding(.top, 40)
                
                    VideoComparisonSection(
                        originalVideoURL: originalVideoURL,
                        processedVideoURL: processedVideoURL,
                        enhancementType: enhancementType,
                        showingOriginal: $showingOriginal,
                        isIPad: isIPad
                    )
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
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                }
            }
        }
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

struct HeaderSection: View {
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

struct VideoComparisonSection: View {
    let originalVideoURL: URL
    let processedVideoURL: URL
    let enhancementType: String
    @Binding var showingOriginal: Bool
    let isIPad: Bool
    
    var body: some View {
        LazyVStack(spacing: 24) {
            ToggleButtons(showingOriginal: $showingOriginal)
            
            VideoPreviewView(videoURL: showingOriginal ? originalVideoURL : processedVideoURL)
                .frame(height: isIPad ? 400 : 320)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
                .padding(.horizontal, 20)
                .animation(.smooth(duration: 0.4), value: showingOriginal)
            
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(showingOriginal ? LinearGradient(colors: [Color.gray], startPoint: .leading, endPoint: .trailing) : LinearGradient.primaryTheme)
                        .frame(width: 8, height: 8)
                    
                    Text(showingOriginal ? "Original Video" : "Enhanced with \(enhancementType)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
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
            HStack(spacing: 16) {
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    saveToPhotoLibrary()
                }) {
                    HStack(spacing: 10) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 18, weight: .medium))
                        }
                        
                        Text(isSaving ? "Saving..." : "Save")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                }
                .buttonStyle(GradientButtonStyle())
                .disabled(isSaving)
                
                ShareLink(item: processedVideoURL) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up.fill")
                            .font(.system(size: 18, weight: .medium))
                        
                        Text("Share")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
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

struct ToggleButtons: View {
    @Binding var showingOriginal: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            Button("Original") {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                showingOriginal = true
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(showingOriginal ? Color.orange : Color.clear)
            .foregroundColor(.white)
            
            Button("Enhanced") {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                showingOriginal = false
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(!showingOriginal ? Color.orange : Color.clear)
            .foregroundColor(.white)
        }
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 20)
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