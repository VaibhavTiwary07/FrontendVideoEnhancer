import SwiftUI
import UIKit
import PhotosUI
import AVFoundation

struct ImageComparisonCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradientType: GradientType
    let beforeImageName: String
    let afterImageName: String
    // Optional video comparison
    let useVideoComparison: Bool
    let normalVideoName: String?
    let enhancedVideoName: String?
    let originalVideoURL: URL?
    let processedVideoURL: URL?
    let videoPlayerManager: VideoPlayerManager?
    let action: () -> Void
    
    @State private var sliderValue: Double = 0.5
    @State private var showingVideoPicker = false
    @State private var selectedVideoURL: URL?
    @State private var navigateToTrimming = false
    @StateObject private var permissionManager = PermissionManager()
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    init(icon: String,
         title: String,
         subtitle: String,
         gradientType: GradientType,
         beforeImageName: String = "test",
         afterImageName: String = "testEnhanced",
         useVideoComparison: Bool = false,
         normalVideoName: String? = nil,
         enhancedVideoName: String? = nil,
         originalVideoURL: URL? = nil,
         processedVideoURL: URL? = nil,
         videoPlayerManager: VideoPlayerManager? = nil,
         action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.gradientType = gradientType
        self.beforeImageName = beforeImageName
        self.afterImageName = afterImageName
        self.useVideoComparison = useVideoComparison
        self.normalVideoName = normalVideoName
        self.enhancedVideoName = enhancedVideoName
        self.originalVideoURL = originalVideoURL
        self.processedVideoURL = processedVideoURL
        self.videoPlayerManager = videoPlayerManager
        self.action = action
    }
    
    var body: some View {
        Button(action: handleCardTap) {
            GeometryReader { geometry in
                ZStack {
                    // Safety check for geometry to prevent crashes
                    if geometry.size.width <= 0 || geometry.size.height <= 0 || 
                       geometry.size.width.isNaN || geometry.size.height.isNaN {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(Text("Loading...").foregroundColor(.secondary))
                    } else {
                    // Static gradient background without moving effect
                    ZStack {
                        // Static gradient background
                        LinearGradient(
                            gradient: Gradient(stops: getGradientStops(for: gradientType)),
                            startPoint: .leading,
                            endPoint: .trailing
                        )

                        // Background SF Symbols (static)
                        ZStack {
                            Image(systemName: "sparkles")
                                .font(.system(size: 60, weight: .ultraLight))
                                .position(x: max(30, geometry.size.width * 0.25),
                                          y: max(20, geometry.size.height * 0.3))

                            Image(systemName: getBackgroundSymbol())
                                .font(.system(size: 100, weight: .ultraLight))
                                .position(x: max(50, min(geometry.size.width - 50, geometry.size.width * 0.6)),
                                          y: max(50, min(geometry.size.height - 20, geometry.size.height * 0.7)))

                            Image(systemName: "circle.grid.2x2.fill")
                                .font(.system(size: 80, weight: .ultraLight))
                                .position(x: max(40, min(geometry.size.width - 40, geometry.size.width * 0.85)),
                                          y: max(40, geometry.size.height * 0.4))
                        }
                        .foregroundColor(.white.opacity(0.06))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    
                    // Content overlay with precise positioning
                    HStack(spacing: 0) {
                        Spacer(minLength: 10)
                        // Left side - Precisely centered text content
                        textContentView(availableWidth: textAreaWidth(totalWidth: geometry.size.width))
                        
//                        Spacer()
                        
                        // Right side - Image comparison slider with proper containment
                        sliderView(containerHeight: geometry.size.height)
                            .frame(minWidth: isIPad ? 200 : 120, maxWidth: isIPad ? 260 : 160)
                            .padding(.trailing, 12)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .padding(.vertical, isIPad ? 20 : 14)
                    } // End of geometry safety check
                }
            }
        }
        // Use a custom ButtonStyle to provide press feedback without hijacking scroll gestures
        .buttonStyle(PressableCardButtonStyle(scale: 0.98))
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.95))
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
        .frame(minHeight: isIPad ? 170 : 120, maxHeight: isIPad ? 200 : 140)
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .padding(.horizontal, 20)
        .onAppear {
            // Auto-slide handled by slider itself
        }
        .onDisappear {
            // Auto-slide handled by slider itself
        }
        .onAppear {
            permissionManager.checkCurrentStatus()
        }
        .sheet(isPresented: $showingVideoPicker) {
            InlineUIKitVideoPicker { url in
                // Capture selection and let onChange(of: showingVideoPicker)
                // perform the navigation after the sheet fully dismisses
                selectedVideoURL = url
                showingVideoPicker = false
            }
        }
        .onChange(of: showingVideoPicker) { isPresented in
            if !isPresented, selectedVideoURL != nil {
                // Defer a tick to ensure sheet dismissal completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    navigateToTrimming = true
                }
            }
        }
        .fullScreenCover(isPresented: $navigateToTrimming) {
            if let videoURL = selectedVideoURL {
                NavigationView {
                    RefactoredVideoTrimmingView(
                        videoURL: videoURL,
                        enhancementType: resolvedEnhancementType()
                    )
                }
            }
        }
    }
    
    // MARK: - Card Tap Handler
    private func handleCardTap() {
        if permissionManager.canAccessPhotoLibrary {
            showingVideoPicker = true
        } else if permissionManager.needsPermissionRequest {
            Task {
                await permissionManager.requestPhotoLibraryPermission()
                if permissionManager.canAccessPhotoLibrary {
                    showingVideoPicker = true
                }
            }
        } else {
            // Fallback to original action if permission denied
            action()
        }
    }
    
    // MARK: - Modern Layout Calculation Methods
    
    private func textAreaWidth(totalWidth: CGFloat) -> CGFloat {
        let assumedSliderWidth: CGFloat = (isIPad ? 220 : 140)
        let trailingPadding: CGFloat = 16
        let leadingPadding: CGFloat = 16
        return max(140, totalWidth - assumedSliderWidth - leadingPadding - trailingPadding)
    }
    
    @ViewBuilder
    private func textContentView(availableWidth: CGFloat) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                // Icon with background
                Image(systemName: icon)
                    .font(.system(size: isIPad ? 40 : 24, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: isIPad ? 76 : 48, height: isIPad ? 76 : 48)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.15))
                            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                    )
                
                // Title and subtitle with left alignment
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: isIPad ? 22 : 16, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    Text(subtitle)
                        .font(.system(size: isIPad ? 16 : 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
            }
            Spacer()
        }
        .frame(width: availableWidth)
        .padding(.leading, 16)
    }
    
    @ViewBuilder
    private func sliderView(containerHeight: CGFloat) -> some View {
        ZStack {
            if useVideoComparison, let manager = videoPlayerManager {
                // Prefer URL-based videos if provided, else fall back to asset names
                if let originalURL = originalVideoURL, let processedURL = processedVideoURL {
                    VideoComparisonSlider(
                        normalVideoName: nil,
                        enhancedVideoName: nil,
                        originalURL: originalURL,
                        enhancedURL: processedURL,
                        videoPlayerManager: manager,
                        compact: true,
                        customKey: title
                    )
                } else if let normal = normalVideoName, let enhanced = enhancedVideoName {
                    VideoComparisonSlider(
                        normalVideoName: normal,
                        enhancedVideoName: enhanced,
                        originalURL: nil,
                        enhancedURL: nil,
                        videoPlayerManager: manager,
                        compact: true,
                        customKey: title
                    )
                } else {
                    // Fallback to image slider if inputs missing
                    ImageComparisonSlider(
                        beforeImageName: beforeImageName,
                        afterImageName: afterImageName,
                        sliderValue: $sliderValue
                    )
                }
            } else {
                ImageComparisonSlider(
                    beforeImageName: beforeImageName,
                    afterImageName: afterImageName,
                    sliderValue: $sliderValue
                )
            }
        }
        .onAppear {
            if useVideoComparison {
                print("🧩 Card '\(title)' sliderView appear useVideoComparison=true originalURL=\(String(describing: originalVideoURL)) processedURL=\(String(describing: processedVideoURL))")
            }
        }
        .onDisappear {
            if useVideoComparison {
                print("🧩 Card '\(title)' sliderView disappear")
            }
        }
        .mask(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.2),
                    Color.white.opacity(1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedCornerShape(radius: 20, corners: [.topRight, .bottomRight]))
//        .frame(width: 150)
    }

    // MARK: - Custom shape for rounding selected corners
    private struct RoundedCornerShape: Shape {
        var radius: CGFloat = 0
        var corners: UIRectCorner = .allCorners
        func path(in rect: CGRect) -> Path {
            let path = UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: corners,
                cornerRadii: CGSize(width: radius, height: radius)
            )
            return Path(path.cgPath)
        }
    }
    
    private func getBackgroundSymbol() -> String {
        switch icon {
        case "arrow.up.square": return "arrow.up.circle.fill"
        case "face.smiling": return "person.crop.circle.fill"
        case "waveform.path": return "waveform.circle.fill"
        case "paintpalette.fill": return "paintpalette.fill"
        case "wand.and.stars": return getIOSCompatibleSymbol("wand.and.stars.fill", fallback: "wand.and.stars")
        case "gyroscope": return "gyroscope"
        case "timer.circle.fill": return getIOSCompatibleSymbol("timer.circle.fill", fallback: "timer")
        default: return "circle.fill"
        }
    }

    // MARK: - Enhancement type resolution using registry (restores backend + options)
    private func resolvedEnhancementType() -> EnhancementType {
        let id = mapTitleToId(title)
        let service = DIContainer.shared.enhancement
        let types = service.getSupportedEnhancementTypes()
        if let found = types.first(where: { $0.id == id }) {
            return found
        }
        // Fallback: construct minimal type if registry unavailable
        return EnhancementType(
            id: id,
            name: title,
            description: subtitle,
            icon: icon,
            options: [],
            gradientType: gradientType
        )
    }

    private func mapTitleToId(_ title: String) -> String {
        switch title {
        case "AI Upscale": return "ai_upscale"
        case "Face & Object Enhancer": return "face_enhancer"
        case "AI Denoise": return "ai_denoise"
        case "AI Color": return "ai_color"
        case "Stabilizer": return "stabilizer"
        case "Frame Interpolation": return "frame_interpolation"
        case "AI Auto Enhancement": return "ai_auto_enhancement"
        default:
            return title.lowercased()
                .replacingOccurrences(of: " & ", with: "_")
                .replacingOccurrences(of: " ", with: "_")
        }
    }
    
    private func getGradientStops(for gradientType: GradientType) -> [Gradient.Stop] {
        switch gradientType {
        case .redPink:
            return [
                .init(color: Color(red: 255/255, green: 16/255, blue: 0/255).opacity(0.91), location: 0.0),

                .init(color: Color(red: 255/255, green: 110/255, blue: 99/255).opacity(0.3), location: 0.7),

            ]
        case .gray:
            return [
                .init(color: Color(red: 100/255, green: 100/255, blue: 100/255).opacity(0.7), location: 0.0),
                .init(color: Color(red: 160/255, green: 160/255, blue: 160/255).opacity(0.4), location: 0.5),
                .init(color: Color(red: 245/255, green: 245/255, blue: 245/255).opacity(0.0), location: 0.65)
            ]
        case .yellowGray:
            return [
                .init(color: Color(red: 255/255, green: 170/255, blue: 0/255).opacity(0.8), location: 0.0),
                .init(color: Color(red: 255/255, green: 200/255, blue: 80/255).opacity(0.4), location: 0.5),
//                .init(color: Color(red: 255/255, green: 250/255, blue: 240/255).opacity(0.0), location: 0.6)
            ]
        case .purpleGray:
            return [
                .init(color: Color(red: 120/255, green: 80/255, blue: 200/255).opacity(0.6), location: 0.0),
                .init(color: Color(red: 160/255, green: 130/255, blue: 220/255).opacity(0.35), location: 0.6),
//                .init(color: Color(red: 245/255, green: 240/255, blue: 255/255).opacity(0.0), location: 0.6)
            ]
        case .cyanGray:
            return [
                .init(color: Color(red: 0/255, green: 132/255, blue: 255/255).opacity(0.45), location: 0.0),
                .init(color: Color(red: 46/255, green: 154/255, blue: 255/255).opacity(0.45), location: 0.3),
                .init(color: Color(red: 207/255, green: 232/255, blue: 255/255).opacity(0.0), location: 0.7)
            ]
        case .pinkGray:
            return [
                .init(color: Color(red: 220/255, green: 100/255, blue: 150/255).opacity(0.7), location: 0.0),
                .init(color: Color(red: 240/255, green: 150/255, blue: 180/255).opacity(0.35), location: 0.6),
//                .init(color: Color(red: 255/255, green: 245/255, blue: 250/255).opacity(0.0), location: 0.6)
            ]
        }
    }
    
    // MARK: - iOS Compatibility Helper
    private func getIOSCompatibleSymbol(_ preferredSymbol: String, fallback: String) -> String {
        if #available(iOS 16.0, *) {
            return preferredSymbol
        } else {
            return fallback
        }
    }
    
    // Auto-slide methods removed - handled by ImageComparisonSlider
}

// MARK: - UIKit Video Picker for Direct Selection
struct InlineUIKitVideoPicker: UIViewControllerRepresentable {
    let onVideoSelected: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
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

// MARK: - ButtonStyle for press feedback that doesn't conflict with ScrollView (iOS 15 friendly)
private struct PressableCardButtonStyle: ButtonStyle {
    let scale: CGFloat
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 20) {
        ImageComparisonCard(
            icon: "arrow.up.square",
            title: "AI Upscale",
            subtitle: "Enhance image resolution",
            gradientType: .redPink,
            beforeImageName: "test",
            afterImageName: "testEnhanced"
        ) {
            print("Tapped AI Upscale")
        }
        
        ImageComparisonCard(
            icon: "waveform.path",
            title: "AI Denoise",
            subtitle: "Remove grain and noise",
            gradientType: .purpleGray,
            beforeImageName: "AIDenoiseBefore",
            afterImageName: "AIDenoiseAfter"
        ) {
            print("Tapped AI Denoise")
        }
    }
    .background(Color.appBackground)
    .padding()
}
