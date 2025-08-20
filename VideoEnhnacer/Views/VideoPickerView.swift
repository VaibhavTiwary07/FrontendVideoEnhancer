import SwiftUI
import PhotosUI
import AVFoundation

struct VideoPickerView: View {
    let enhancementType: String
    let enhancementIcon: String
    let gradientType: GradientType
    @Environment(\.dismiss) private var dismiss
    @State private var selectedVideoURL: URL?
    @State private var showingVideoPicker = false
    @State private var navigateToTrimming = false
    @StateObject private var permissionManager = PermissionManager()
    @State private var showingPermissionAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: enhancementIcon)
                            .font(.system(size: 60, weight: .medium))
                            .foregroundStyle(gradientType.base)
                        
                        Text("Select Video for \(enhancementType)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                    
                    Spacer()
                    
                    // Video selection area
                    VStack(spacing: 30) {
                        if let videoURL = selectedVideoURL {
                            // Video preview
                            VideoPreviewView(videoURL: videoURL)
                                .frame(height: 200)
                                .cornerRadius(16)
                                .padding(.horizontal, 20)
                            
                            Button("Continue to Trimming") {
                                navigateToTrimming = true
                            }
                            .buttonStyle(GradientButtonStyle(gradientType: gradientType))
                            .padding(.horizontal, 20)
                            
                        } else {
                            // Permission and video selection UI
                            if permissionManager.canAccessPhotoLibrary {
                                // Has permission - show video picker
                                Button("Select Video from Library") {
                                    showingVideoPicker = true
                                }
                                .buttonStyle(GradientButtonStyle(gradientType: gradientType))
                                .padding(.horizontal, 20)
                                
                                if permissionManager.hasLimitedAccess {
                                    Text("Limited photo library access")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .padding(.top, 8)
                                }
                                
                            } else if permissionManager.needsPermissionRequest {
                                // Need to request permission
                                VStack(spacing: 20) {
                                    VStack(spacing: 12) {
                                        Text("Photo Library Access")
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                        
                                        Text("To enhance your videos, we need access to your photo library to select videos.")
                                            .font(.body)
                                            .foregroundColor(.gray)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 20)
                                    }
                                    
                                    Button("Allow Photo Library Access") {
                                        Task {
                                            await permissionManager.requestPhotoLibraryPermission()
                                        }
                                    }
                                    .buttonStyle(GradientButtonStyle(gradientType: gradientType))
                                    .disabled(permissionManager.isCheckingPermissions)
                                }
                                .padding(.horizontal, 20)
                                
                            } else {
                                // Permission denied or restricted
                                VStack(spacing: 20) {
                                    VStack(spacing: 12) {
                                        Image(systemName: "exclamationmark.triangle")
                                            .font(.system(size: 40))
                                            .foregroundColor(.orange)
                                        
                                        Text("Photo Library Access Required")
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                        
                                        Text(permissionManager.permissionStatusMessage)
                                            .font(.body)
                                            .foregroundColor(.gray)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 20)
                                    }
                                    
                                    if permissionManager.isPermissionDenied {
                                        Button("Open Settings") {
                                            permissionManager.openAppSettings()
                                        }
                                        .buttonStyle(GradientButtonStyle(gradientType: gradientType))
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .photosPicker(isPresented: $showingVideoPicker, selection: Binding<PhotosPickerItem?>(
            get: { nil },
            set: { item in
                if let item = item {
                    loadVideo(from: item)
                }
            }
        ), matching: .videos)
        .onAppear {
            permissionManager.checkCurrentStatus()
        }
        .navigationDestination(isPresented: $navigateToTrimming) {
            if let videoURL = selectedVideoURL {
                VideoTrimmingView(
                    videoURL: videoURL,
                    enhancementType: enhancementType,
                    enhancementIcon: enhancementIcon,
                    gradientType: gradientType
                )
            }
        }
    }
    
    private func loadVideo(from item: PhotosPickerItem) {
        item.loadTransferable(type: VideoTransferable.self) { result in
            switch result {
            case .success(let video):
                if let video = video {
                    DispatchQueue.main.async {
                        self.selectedVideoURL = video.url
                    }
                }
            case .failure(let error):
                print("Error loading video: \(error)")
            }
        }
    }
}

// Video transferable for PhotosPicker
struct VideoTransferable: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let copy = URL.documentsDirectory.appending(path: "video_\(UUID().uuidString).mov")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}

// Custom button style for gradient buttons
struct GradientButtonStyle: ButtonStyle {
    let gradientType: GradientType
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(gradientType.base)
                    .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    VideoPickerView(
        enhancementType: "AI Upscale",
        enhancementIcon: "arrow.up.square",
        gradientType: .redPink
    )
}