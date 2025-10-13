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
    @State private var showingSettingsAlert = false
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isSmallScreen: Bool {
        // Detect iPhone SE and similar small screens
        let screenHeight = UIScreen.main.bounds.height
        return screenHeight <= 736 // iPhone SE (3rd gen) is 667pt, iPhone 8 Plus is 736pt
    }
    
    private var adaptiveVideoHeight: CGFloat {
        if isSmallScreen {
            return 160
        } else if horizontalSizeClass == .regular {
            return 220
        } else {
            return 200
        }
    }
    
    private var adaptiveSpacing: CGFloat {
        isSmallScreen ? 16 : 30
    }
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                content
            }
        } else {
            NavigationView {
                content
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
    
    private var content: some View {
            ZStack {
                Color.primarySoft
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                    // Enhanced Header
                    VStack(spacing: 20) {
                        // Icon with modern styling
                        ZStack {
                            Circle()
                                .fill(Color.cardSoft)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Circle()
                                        .stroke(Color.accentWarm.opacity(0.2), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                            
                            Image(systemName: enhancementIcon)
                                .font(.system(size: 40, weight: .medium))
                                .foregroundColor(.accentWarm)
                        }
                        
                        VStack(spacing: 8) {
                            Text("Select Video for")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.accentWarm.opacity(0.8))
                            
                            Text(enhancementType)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.accentWarm)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        }
                        
                        // Step indicator
                        HStack(spacing: 8) {
                            ForEach(1...4, id: \.self) { step in
                                Circle()
                                    .fill(step == 1 ? Color.accentWarm : Color.accentWarm.opacity(0.3))
                                    .frame(width: step == 1 ? 10 : 8, height: step == 1 ? 10 : 8)
                            }
                        }
                        .padding(.top, 10)
                    }
                    .padding(.top, isSmallScreen ? 20 : 40)
                    
                    // Enhanced Video selection area
                    VStack(spacing: adaptiveSpacing) {
                        if let videoURL = selectedVideoURL {
                            // Enhanced Video preview with info
                            VStack(spacing: 20) {
                                VideoPreviewView(videoURL: videoURL)
                                    .frame(height: adaptiveVideoHeight)
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.accentWarm.opacity(0.2), lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
                                    .padding(.horizontal, 20)
                                
                                // Video info card
                                VideoInfoCard(videoURL: videoURL, trimStartTime: nil, trimEndTime: nil)
                                    .padding(.horizontal, 20)
                            }
                            
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                impact.impactOccurred()
                                navigateToTrimming = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "scissors")
                                        .font(.system(size: 18, weight: .medium))
                                    
                                    Text("Continue to Video Trimming")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                            }
                            .buttonStyle(FloatingActionButtonStyle())
                            .padding(.horizontal, 20)
                            
                        } else {
                            // Enhanced video selection UI
                            if permissionManager.canAccessPhotoLibrary {
                                // Has permission - show enhanced video picker options
                                VStack(spacing: 24) {
                                    // Video selection card
                                    VStack(spacing: 20) {
                                        Image(systemName: "photo.on.rectangle")
                                            .font(.system(size: 50, weight: .light))
                                            .foregroundColor(.accentWarm.opacity(0.8))
                                        
                                        VStack(spacing: 8) {
                                            Text("Choose Your Video")
                                                .font(.system(size: 22, weight: .bold))
                                                .foregroundColor(.accentWarm)
                                            
                                            Text("Select a video from your library to enhance")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.accentWarm.opacity(0.7))
                                                .multilineTextAlignment(.center)
                                        }
                                    }
                                    .padding(.vertical, 40)
                                    .padding(.horizontal, 30)
                                    .background(
                                        RoundedRectangle(cornerRadius: 24)
                                            .fill(Color.cardSoft)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 24)
                                                    .stroke(Color.accentWarm.opacity(0.2), lineWidth: 1)
                                            )
                                    )
                                    .padding(.horizontal, 20)
                                    
                                    Button(action: {
                                        let impact = UIImpactFeedbackGenerator(style: .light)
                                        impact.impactOccurred()
                                        showingVideoPicker = true
                                    }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "video.circle.fill")
                                                .font(.system(size: 20, weight: .medium))
                                            
                                            Text("Select Video from Library")
                                                .font(.system(size: 18, weight: .semibold))
                                        }
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                                    }
                                    .buttonStyle(FloatingActionButtonStyle())
                                    .padding(.horizontal, 20)
                                    
                                    if permissionManager.hasLimitedAccess {
                                        HStack(spacing: 8) {
                                            Image(systemName: "info.circle")
                                                .foregroundColor(.orange.opacity(0.8))
                                            
                                            Text("Limited photo library access")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.accentWarm.opacity(0.8))
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                }
                                
                            } else if permissionManager.needsPermissionRequest {
                                // Need to request permission
                                VStack(spacing: 20) {
                                    VStack(spacing: 12) {
                                        Text("Photo Library Access")
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.accentWarm)
                                        
                                        Text("To enhance your videos, we need access to your photo library to select videos.")
                                            .font(.body)
                                            .foregroundColor(.accentWarm.opacity(0.7))
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 20)
                                    }
                                    
                                    Button("Allow Photo Library Access") {
                                        Task {
                                            await permissionManager.requestPhotoLibraryPermission()
                                        }
                                    }
                                    .buttonStyle(GradientButtonStyle())
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
                                            .foregroundColor(.accentWarm)
                                        
                                        Text(permissionManager.permissionStatusMessage)
                                            .font(.body)
                                            .foregroundColor(.accentWarm.opacity(0.7))
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 20)
                                    }
                                    
                                    if permissionManager.isPermissionDenied {
                                        Button("Open Settings") {
                                            showingSettingsAlert = true
                                        }
                                        .buttonStyle(GradientButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.bottom, isSmallScreen ? 80 : 100)
                }
            }
            }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.accentWarm)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Text("Step 1 of 4")
                    .font(.caption)
                    .foregroundColor(.accentWarm.opacity(0.7))
            }
        }
        .modifier(VideoPickerModifier(showingVideoPicker: $showingVideoPicker) { url in
            selectedVideoURL = url
        })
        .onAppear {
            permissionManager.checkCurrentStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Re-check permissions when user returns from Settings
            permissionManager.checkCurrentStatus()
        }
        .alert("Photos Access Required", isPresented: $showingSettingsAlert) {
            Button("Open Settings") {
                permissionManager.openAppSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("To select videos for enhancement, please enable Photos access in Settings > Privacy & Security > Photos > VideoEnhancer.")
        }
        .fullScreenCover(isPresented: $navigateToTrimming) {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    if let videoURL = selectedVideoURL {
                        VideoTrimmingView(
                            videoURL: videoURL,
                            enhancementType: enhancementType,
                            enhancementIcon: enhancementIcon,
                            gradientType: gradientType
                        )
                    }
                }
            } else {
                NavigationView {
                    if let videoURL = selectedVideoURL {
                        VideoTrimmingView(
                            videoURL: videoURL,
                            enhancementType: enhancementType,
                            enhancementIcon: enhancementIcon,
                            gradientType: gradientType
                        )
                    }
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
        }
    }
    
    @available(iOS 16.0, *)
    private func loadVideo(from item: PhotosPickerItem) {
        Task {
            do {
                if let originalURL = try await item.loadOriginalVideo() {
                    DispatchQueue.main.async {
                        self.selectedVideoURL = originalURL
                    }
                }
            } catch {
                print("Error loading original video: \(error)")
            }
        }
    }
}

// Video transferable for PhotosPicker
@available(iOS 16.0, *)
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

// Custom button style for modern buttons
struct GradientButtonStyle: ButtonStyle {
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.accentWarm)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.cardSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.accentWarm.opacity(0.3), lineWidth: 1)
                    )
                    .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            )
            .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// FloatingActionButton style matching the existing FAB component
struct FloatingActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient.primaryTheme)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(
                        color: Color.black.opacity(0.15),
                        radius: configuration.isPressed ? 4 : 6,
                        x: 0,
                        y: configuration.isPressed ? 2 : 3
                    )
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Video Picker Modifier
struct VideoPickerModifier: ViewModifier {
    @Binding var showingVideoPicker: Bool
    let onVideoSelected: (URL) -> Void
    
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .photosPicker(isPresented: $showingVideoPicker, selection: Binding<PhotosPickerItem?>(
                    get: { nil },
                    set: { item in
                        if let item = item {
                            loadVideo(from: item)
                        }
                    }
                ), matching: .videos)
        } else {
            content
                .sheet(isPresented: $showingVideoPicker) {
                    UIKitVideoPickerWrapper { url in
                        onVideoSelected(url)
                        showingVideoPicker = false
                    }
                }
        }
    }
    
    @available(iOS 16.0, *)
    private func loadVideo(from item: PhotosPickerItem) {
        item.loadTransferable(type: VideoTransferable.self) { result in
            switch result {
            case .success(let video):
                if let video = video {
                    DispatchQueue.main.async {
                        onVideoSelected(video.url)
                    }
                }
            case .failure(let error):
                print("Error loading video: \(error)")
            }
        }
    }
}

// MARK: - UIKit Video Picker for iOS 15
struct UIKitVideoPickerWrapper: UIViewControllerRepresentable {
    let onVideoSelected: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false // Disable editing/trimming
        picker.mediaTypes = ["public.movie"]
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onVideoSelected: onVideoSelected)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onVideoSelected: (URL) -> Void
        
        init(onVideoSelected: @escaping (URL) -> Void) {
            self.onVideoSelected = onVideoSelected
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let url = info[.mediaURL] as? URL {
                onVideoSelected(url)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

@available(iOS 16.0, *)
extension PhotosPickerItem {
    func loadOriginalVideo() async throws -> URL? {
        guard let identifier = self.itemIdentifier else { return nil }
        
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else { return nil }
        
        return try await withCheckedThrowingContinuation { continuation in
            let resources = PHAssetResource.assetResources(for: asset)
            
            // Pick the full-quality movie resource
            guard let resource = resources.first(where: { $0.type == .video }) else {
                continuation.resume(returning: nil)
                return
            }
            
            let fileURL = URL.documentsDirectory.appendingPathComponent("video_\(UUID().uuidString).mov")
            
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true  // allow iCloud download
            
            PHAssetResourceManager.default().writeData(for: resource, toFile: fileURL, options: options) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: fileURL)
                }
            }
        }
    }
}


#Preview {
    VideoPickerView(
        enhancementType: "AI Upscale",
        enhancementIcon: "arrow.up.square",
        gradientType: .redPink
    )
}
