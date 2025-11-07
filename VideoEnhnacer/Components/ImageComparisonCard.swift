import SwiftUI
import UIKit
import PhotosUI
import AVFoundation

struct ImageComparisonCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradientType: GradientType
    let showsSlider: Bool
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
    @State private var selectedPhotoItem: Any? // Holds PhotosPickerItem for iOS 16+
    @State private var showingPermissionAlert = false
    @State private var showingEnhancementInfo = false
    @StateObject private var permissionManager = PermissionManager()
    @EnvironmentObject var flowState: EnhancementFlowStateManager
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }


    private var isAssetIcon: Bool {
        UIImage(named: icon) != nil
    }

    private var iconImage: Image {
        if isAssetIcon {
            return Image(icon).renderingMode(.original)
        } else {
            return Image(systemName: icon)
        }
    }

    init(icon: String,
         title: String,
         subtitle: String,
         gradientType: GradientType,
         showsSlider: Bool = true,
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
        self.showsSlider = showsSlider
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
                    
                    // Content overlay with stable placement
                    HStack(alignment: .center, spacing: 8) {
                        // Compute reserved slider width and available text width based on total
                        let total = geometry.size.width
                        let minimumTextWidth: CGFloat = isIPad ? 150 : 110
                        let horizontalPadding: CGFloat = 32 // 16pt horizontal insets on both sides
                        let targetSliderWidth = total * 0.6
                        let minimumSliderWidth: CGFloat = isIPad ? 260 : 150
                        let maximumSliderWidth = max(0, total - minimumTextWidth - horizontalPadding)
                        let reserved = maximumSliderWidth > 0
                            ? min(max(targetSliderWidth, minimumSliderWidth), maximumSliderWidth)
                            : 0
                        let available = max(minimumTextWidth, total - reserved - horizontalPadding)

                        // Left: Text block flexes
                        textContentView(availableWidth: available)

                        // Right: Slider gets reserved width
                        sliderView(containerHeight: geometry.size.height)
                            .frame(width: reserved, height: geometry.size.height)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .padding(.horizontal, 12)
                    .padding(.vertical, isIPad ? 4 : 3)
                    } // End of geometry safety check
                }
            }
        }
        // Use a custom ButtonStyle to provide press feedback without hijacking scroll gestures
        .buttonStyle(PressableCardButtonStyle(scale: 0.98))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        .frame(minHeight: isIPad ? 180 : 130, maxHeight: isIPad ? 210 : 150)
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .padding(.horizontal, 16)
        .overlay(alignment: .topTrailing) {
            Button(action: {
                showingEnhancementInfo = true
            }) {
                ZStack {
                    // Background circle with shadow
                    Circle()
                        .fill(Color.white.opacity(0.95))
                        .frame(width: isIPad ? 36 : 32, height: isIPad ? 36 : 32)
                        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)

                    // Info icon
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: isIPad ? 24 : 20, weight: .medium))
                        .foregroundColor(Color.secondary)
                }
                .padding(.top, isIPad ? 16 : 14)
                .padding(.trailing, isIPad ? 18 : 16)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .onAppear {
            // Auto-slide handled by slider itself
        }
        .onDisappear {
            // Auto-slide handled by slider itself
        }
        .onAppear {
            permissionManager.checkCurrentStatus()
        }
        .modifier(ComparisonCardVideoPickerModifier(
            showingVideoPicker: $showingVideoPicker,
            selectedPhotoItem: $selectedPhotoItem,
            onVideoSelected: { url in
                print("🐞 WHITE_SCREEN_DEBUG: VideoPicker.onVideoSelected - URL: \(url.lastPathComponent)")
                logImageComparisonToFile("🎯 [ImageComparisonCard] onVideoSelected callback triggered")
                logImageComparisonToFile("🎯 [ImageComparisonCard] Selected video: \(url.lastPathComponent)")
                logImageComparisonToFile("🎯 [ImageComparisonCard] Full path: \(url.path)")
                logImageComparisonToFile("🎯 [ImageComparisonCard] Setting selectedVideoURL...")
                selectedVideoURL = url
                logImageComparisonToFile("🎯 [ImageComparisonCard] selectedVideoURL set successfully")
                logImageComparisonToFile("🎯 [ImageComparisonCard] Closing picker (showingVideoPicker = false)")
                showingVideoPicker = false
                logImageComparisonToFile("🎯 [ImageComparisonCard] This should trigger .fullScreenCover with VideoEnhancementModalView")
            },
            onCancelled: {
                print("🐞 WHITE_SCREEN_DEBUG: VideoPicker.onCancelled")
                logImageComparisonToFile("❌ [ImageComparisonCard] Video selection cancelled by user")
                showingVideoPicker = false
            }
        ))
        .fullScreenCover(item: $selectedVideoURL) { videoURL in
            VideoEnhancementModalView(
                videoURL: videoURL,
                enhancementType: resolvedEnhancementType()
            )
            .environmentObject(flowState)
            .onAppear {
                print("🐞 WHITE_SCREEN_DEBUG: ✅ SUPER SENIOR FIX - fullScreenCover using item binding with URL: \(videoURL.lastPathComponent)")
                print("🐞 WHITE_SCREEN_DEBUG: Enhancement type: \(resolvedEnhancementType().name)")
                logImageComparisonToFile("✅ [ImageComparisonCard] fullScreenCover appeared!")
                logImageComparisonToFile("✅ [ImageComparisonCard] VideoEnhancementModalView presented")
                logImageComparisonToFile("✅ [ImageComparisonCard] Video URL: \(videoURL.lastPathComponent)")
                logImageComparisonToFile("✅ [ImageComparisonCard] Enhancement type: \(resolvedEnhancementType().name)")
                logImageComparisonToFile("✅ [ImageComparisonCard] ==========================================")
            }
            .onDisappear {
                print("🐞 WHITE_SCREEN_DEBUG: fullScreenCover with item binding disappeared")
                logImageComparisonToFile("👋 [ImageComparisonCard] fullScreenCover dismissed")
                flowState.reset()
            }
        }
        .alert("Photos Access Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                permissionManager.openAppSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("To select videos for enhancement, please enable Photos access in Settings > Privacy & Security > Photos > VideoEnhancer.")
        }
        .popover(isPresented: $showingEnhancementInfo) {
            if #available(iOS 16.4, *) {
                EnhancementInfoPopover(enhancementType: resolvedEnhancementType())
                    .presentationCompactAdaptation(.popover)
            } else {
                EnhancementInfoPopover(enhancementType: resolvedEnhancementType())
            }
        }
    }
    
    // MARK: - Card Tap Handler
    private func handleCardTap() {
        logImageComparisonToFile("🎴 [ImageComparisonCard] ==========================================")
        logImageComparisonToFile("🎴 [ImageComparisonCard] Card tapped - Title: '\(title)'")
        print("🐞 WHITE_SCREEN_DEBUG: ImageComparisonCard.handleCardTap() - Card '\(title)' tapped")
        print("🐞 WHITE_SCREEN_DEBUG: Current states - selectedVideoURL: \(String(describing: selectedVideoURL)), showingVideoPicker: \(showingVideoPicker)")

        logImageComparisonToFile("🎴 [ImageComparisonCard] Current states:")
        logImageComparisonToFile("🎴 [ImageComparisonCard]   - selectedVideoURL: \(selectedVideoURL?.lastPathComponent ?? "nil")")
        logImageComparisonToFile("🎴 [ImageComparisonCard]   - showingVideoPicker: \(showingVideoPicker)")

        if permissionManager.canAccessPhotoLibrary {
            print("🐞 WHITE_SCREEN_DEBUG: Photo library access granted")
            logImageComparisonToFile("🎴 [ImageComparisonCard] ✅ Photo library access granted")
            // Clear any stale selection so cancel does not reuse previous video
            selectedVideoURL = nil
            logImageComparisonToFile("🎴 [ImageComparisonCard] Cleared selectedVideoURL")
            showingVideoPicker = true
            logImageComparisonToFile("🎴 [ImageComparisonCard] Set showingVideoPicker = true (opening picker)")
            print("🐞 WHITE_SCREEN_DEBUG: Set showingVideoPicker = true")
        } else if permissionManager.needsPermissionRequest {
            print("🐞 WHITE_SCREEN_DEBUG: Requesting photo library permission")
            logImageComparisonToFile("🎴 [ImageComparisonCard] ⚠️ Need to request photo library permission")
            Task {
                await permissionManager.requestPhotoLibraryPermission()
                if permissionManager.canAccessPhotoLibrary {
                    print("🐞 WHITE_SCREEN_DEBUG: Permission granted after request")
                    logImageComparisonToFile("🎴 [ImageComparisonCard] ✅ Permission granted after request")
                    selectedVideoURL = nil
                    showingVideoPicker = true
                    logImageComparisonToFile("🎴 [ImageComparisonCard] Opening picker after permission granted")
                } else {
                    print("🐞 WHITE_SCREEN_DEBUG: Permission denied after request")
                    logImageComparisonToFile("🎴 [ImageComparisonCard] ❌ Permission denied after request")
                    showingPermissionAlert = true
                }
            }
        } else {
            // Permission was denied, show settings alert
            print("🐞 WHITE_SCREEN_DEBUG: Photo library permission denied, showing alert")
            logImageComparisonToFile("🎴 [ImageComparisonCard] ❌ Photo library permission denied, showing alert")
            showingPermissionAlert = true
        }
    }

    private func logImageComparisonToFile(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)"

        print(logMessage)

        let projectLogFile = URL(fileURLWithPath: "/home/user/FrontendVideoEnhancer/video_selection_debug.log")
        if let data = (logMessage + "\n").data(using: .utf8) {
            if FileManager.default.fileExists(atPath: projectLogFile.path) {
                if let fileHandle = try? FileHandle(forWritingTo: projectLogFile) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: projectLogFile)
            }
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
        HStack(alignment: .top) {
            Spacer(minLength: 0)

            VStack(alignment: .center, spacing: isIPad ? 16 : 12) {
                // Icon uses asset when available, falling back to SF symbol
                if isAssetIcon {
                    iconImage
                        .resizable()
                        .scaledToFit()
                        .frame(width: isIPad ? 60 : 48, height: isIPad ? 60 : 48)
                } else {
                    iconImage
                        .font(.system(size: isIPad ? 34 : 24, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: isIPad ? 60 : 48, height: isIPad ? 60 : 48)
                }

                Text(title)
                    .font(.system(size: isIPad ? 20 : 16, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(width: availableWidth)
    }
    
    @ViewBuilder
    private func sliderView(containerHeight: CGFloat) -> some View {
        if showsSlider {
            sliderContent(containerHeight: containerHeight)
        } else {
            staticPreviewImage(width :.infinity,height: containerHeight)
        }
    }

    private func sliderContent(containerHeight _: CGFloat) -> some View {
        let canUseURLVideos = useVideoComparison && videoPlayerManager != nil && originalVideoURL != nil && processedVideoURL != nil
        let canUseAssetVideos = useVideoComparison && videoPlayerManager != nil && normalVideoName != nil && enhancedVideoName != nil
        let showsImageSlider = !canUseURLVideos && !canUseAssetVideos

        return ZStack {
            if canUseURLVideos,
               let manager = videoPlayerManager,
               let originalURL = originalVideoURL,
               let processedURL = processedVideoURL {
                VideoComparisonSlider(
                    normalVideoName: nil,
                    enhancedVideoName: nil,
                    originalURL: originalURL,
                    enhancedURL: processedURL,
                    videoPlayerManager: manager,
                    compact: true,
                    customKey: title
                )
                .onAppear {
                    print("🧩 ImageComparisonCard '\(title)' using URL videos; key='\(title)'\n     originalURL=\(originalURL)\n     processedURL=\(processedURL)")
                }
            } else if canUseAssetVideos,
                      let manager = videoPlayerManager,
                      let normal = normalVideoName,
                      let enhanced = enhancedVideoName {
                VideoComparisonSlider(
                    normalVideoName: normal,
                    enhancedVideoName: enhanced,
                    originalURL: nil,
                    enhancedURL: nil,
                    videoPlayerManager: manager,
                    compact: true,
                    customKey: title
                )
                .onAppear {
                    print("🧩 ImageComparisonCard '\(title)' using asset videos; key='\(title)'\n     normal='\(normal)' enhanced='\(enhanced)'")
                }
            } else {
                ImageComparisonSlider(
                    beforeImageName: beforeImageName,
                    afterImageName: afterImageName,
                    sliderValue: $sliderValue
                )
                .onAppear {
                    if useVideoComparison {
                        print("🧩 ImageComparisonCard '\(title)' falling back to image slider (no video sources)")
                    } else {
                        print("🧩 ImageComparisonCard '\(title)' using image slider (useVideoComparison=false)")
                    }
                }
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
                stops: [
                    .init(color: Color.white.opacity(0.0), location: 0.0),
                    .init(color: Color.white.opacity(1.0), location: 0.60),
                    .init(color: Color.white.opacity(1.0), location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay {
            if showsImageSlider {
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let verticalOffset: CGFloat = isIPad ? 16 : 12
                    let padding: CGFloat = isIPad ? 28 : 20

                    let crossFadeWidth: Double = 0.22
                    let lowerBound = max(0.0, 0.5 - crossFadeWidth)
                    let upperBound = min(1.0, 0.5 + crossFadeWidth)
                    let rawProgress = (sliderValue - lowerBound) / (upperBound - lowerBound)
                    let clampedProgress = min(max(rawProgress, 0), 1)
                    let beforeOpacity = max(0, 1 - clampedProgress)
                    let afterOpacity = max(0, clampedProgress)

                    let handleX = width * CGFloat(sliderValue)
                    let labelOffset: CGFloat = isIPad ? 48 : 34
                    let beforeX = max(padding, min(handleX - labelOffset, width - padding))
                    let afterX = min(width - padding, max(handleX + labelOffset, padding))

                    ZStack {
                        Text("Before")
                            .font(.system(size: isIPad ? 18 : 14, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.45), radius: 3, x: 0, y: 1)
                            .opacity(beforeOpacity)
                            .position(x: beforeX,
                                      y: height - verticalOffset)

                        Text("After")
                            .font(.system(size: isIPad ? 18 : 14, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.45), radius: 3, x: 0, y: 1)
                            .opacity(afterOpacity)
                            .position(x: afterX,
                                      y: height - verticalOffset)
                    }
                    .frame(width: width, height: height)
                }
                .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedCornerShape(radius: 20, corners: [.topRight, .bottomRight]))
    }

    private func staticPreviewImage(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            if let uiImage = UIImage(named: beforeImageName) {
                let cardImage = Image(uiImage: uiImage)

                // Background blurred image
                cardImage
                    .resizable()
                    .frame(width: width, height: height)
                    .blur(radius: isIPad ? 28 : 16)
                    .opacity(0.65)

                // Main image - stretches to fill exact dimensions
                cardImage
                    .resizable()
                    .frame(width: width, height: height)
            } else {
                // Placeholder when no image
                ZStack {
                    Color.white.opacity(0.12)
                    Image(systemName: "photo")
                        .font(.system(size: isIPad ? 46 : 34, weight: .light))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(width: width, height: height)
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .clipShape(RoundedCornerShape(radius: 20, corners: [.topRight, .bottomRight]))
        .mask(
            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0.0), location: 0.0),
                    .init(color: Color.white.opacity(1.0), location: 0.60),
                    .init(color: Color.white.opacity(1.0), location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
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
    let onCancelled: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.movie"]
        picker.videoQuality = .typeHigh
        picker.allowsEditing = false

        // iPad-specific configuration to prevent white screen
        if UIDevice.current.userInterfaceIdiom == .pad {
            picker.modalPresentationStyle = .overCurrentContext
        }

        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No popover configuration needed for .overCurrentContext
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onVideoSelected: onVideoSelected, onCancelled: onCancelled)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onVideoSelected: (URL) -> Void
        let onCancelled: () -> Void

        init(onVideoSelected: @escaping (URL) -> Void, onCancelled: @escaping () -> Void) {
            self.onVideoSelected = onVideoSelected
            self.onCancelled = onCancelled
        }

//        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
//            if let url = info[.mediaURL] as? URL {
//                picker.dismiss(animated: true) {
//                    self.onVideoSelected(url)
//                }
//            } else {
//                picker.dismiss(animated: true) {
//                    self.onCancelled()
//                }
//            }
//        }
        
        
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // Verify the media is a video
            guard let mediaType = info[.mediaType] as? String, mediaType == "public.movie" else {
                picker.dismiss(animated: true) {
                    self.onCancelled()
                }
                return
            }
            
            // Use PHAsset to request the original video resolution
            if let asset = info[.phAsset] as? PHAsset {
                let options = PHVideoRequestOptions()
                options.version = .original // Request the original, full-resolution video
                options.isNetworkAccessAllowed = true // Allow downloading from iCloud
                options.deliveryMode = .highQualityFormat // Ensure highest quality
                
                PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { (avAsset, _, _) in
                    DispatchQueue.main.async {
                        if let urlAsset = avAsset as? AVURLAsset {
                            // Verify resolution (optional, for debugging)
                            if let track = urlAsset.tracks(withMediaType: .video).first {
                                let size = track.naturalSize
                                print("Retrieved video resolution: \(size.width)x\(size.height)")
                            }
                            
                            picker.dismiss(animated: true) {
                                self.onVideoSelected(urlAsset.url)
                            }
                        } else {
                            picker.dismiss(animated: true) {
                                self.onCancelled()
                            }
                        }
                    }
                }
            } else {
                // Fallback for older iOS versions (pre-iOS 11) or if PHAsset is unavailable
                if let videoURL = info[.mediaURL] as? URL {
                    print("Warning: Using mediaURL, may not be original resolution")
                    picker.dismiss(animated: true) {
                        self.onVideoSelected(videoURL)
                    }
                } else {
                    picker.dismiss(animated: true) {
                        self.onCancelled()
                    }
                }
            }
        }
        

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) {
                self.onCancelled()
            }
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

// MARK: - Video Picker Presentation Modifier
fileprivate struct ComparisonCardVideoPickerModifier: ViewModifier {
    @Binding var showingVideoPicker: Bool
    @Binding var selectedPhotoItem: Any?
    let onVideoSelected: (URL) -> Void
    let onCancelled: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            // MODERN: Native SwiftUI PhotosPicker
            content
                .photosPicker(
                    isPresented: $showingVideoPicker,
                    selection: Binding<PhotosPickerItem?>(
                        get: {
                            let item = selectedPhotoItem as? PhotosPickerItem
                            logToFile("📸 [ComparisonCard] Binding getter called - current item: \(item != nil ? "exists" : "nil")")
                            return item
                        },
                        set: { newValue in
                            logToFile("📸 [ComparisonCard] ==========================================")
                            logToFile("📸 [ComparisonCard] Binding setter called with item: \(newValue != nil ? "EXISTS" : "NIL")")
                            if let item = newValue {
                                logToFile("📸 [ComparisonCard] Item identifier: \(item.itemIdentifier ?? "no identifier")")
                            }

                            selectedPhotoItem = newValue

                            if let item = newValue {
                                logToFile("📸 [ComparisonCard] Starting Task to load video...")
                                Task {
                                    logToFile("📸 [ComparisonCard] Task started - calling loadVideoModern...")
                                    await loadVideoModern(from: item)
                                }
                            } else {
                                logToFile("📸 [ComparisonCard] No item selected (user cancelled?)")
                                onCancelled()
                            }
                        }
                    ),
                    matching: .videos
                )
                .onChange(of: showingVideoPicker) { isShowing in
                    logToFile("📸 [ComparisonCard] Picker presentation changed: \(isShowing ? "SHOWING" : "HIDDEN")")
                }
        } else {
            // FALLBACK: UIKit picker for iOS 15
            content
                .sheet(isPresented: $showingVideoPicker) {
                    InlineUIKitVideoPicker(
                        onVideoSelected: { url in
                            logToFile("📸 [ComparisonCard] UIKit picker selected video: \(url.lastPathComponent)")
                            onVideoSelected(url)
                        },
                        onCancelled: {
                            logToFile("📸 [ComparisonCard] UIKit picker cancelled")
                            onCancelled()
                        }
                    )
                }
        }
    }

    @available(iOS 16.0, *)
    private func loadVideoModern(from item: PhotosPickerItem) async {
        let timestamp = Date()
        logToFile("📸 [ComparisonCard] loadVideoModern() called at \(timestamp)")
        logToFile("📸 [ComparisonCard] Item identifier: \(item.itemIdentifier ?? "unknown")")

        do {
            logToFile("📸 [ComparisonCard] Calling item.loadVideoURL()...")
            if let url = try await item.loadVideoURL(context: "ComparisonCard") {
                let elapsed = Date().timeIntervalSince(timestamp)
                logToFile("📸 [ComparisonCard] ✅ Successfully loaded video: \(url.lastPathComponent)")
                logToFile("📸 [ComparisonCard] Video URL: \(url.path)")
                logToFile("📸 [ComparisonCard] Load time: \(String(format: "%.2f", elapsed))s")

                await MainActor.run {
                    logToFile("📸 [ComparisonCard] On MainActor - calling onVideoSelected callback...")
                    onVideoSelected(url)
                    logToFile("📸 [ComparisonCard] onVideoSelected callback completed")
                    logToFile("📸 [ComparisonCard] Clearing selectedPhotoItem...")
                    selectedPhotoItem = nil
                    logToFile("📸 [ComparisonCard] ==========================================")
                }
            } else {
                logToFile("📸 [ComparisonCard] ❌ loadVideoURL returned nil")
                await MainActor.run {
                    onCancelled()
                }
            }
        } catch {
            logToFile("📸 [ComparisonCard] ❌ Error loading video: \(error.localizedDescription)")
            logToFile("📸 [ComparisonCard] Error details: \(error)")
            await MainActor.run {
                onCancelled()
            }
        }
    }

    private func logToFile(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)"

        print(logMessage)

        let projectLogFile = URL(fileURLWithPath: "/home/user/FrontendVideoEnhancer/video_selection_debug.log")
        if let data = (logMessage + "\n").data(using: .utf8) {
            if FileManager.default.fileExists(atPath: projectLogFile.path) {
                if let fileHandle = try? FileHandle(forWritingTo: projectLogFile) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: projectLogFile)
            }
        }
    }
}

// MARK: - Enhancement Info Popover
struct EnhancementInfoPopover: View {
    let enhancementType: EnhancementType
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: isIPad ? 20 : 16) {
                // Header with icon and title
                HStack(spacing: 12) {
                    if let uiImage = UIImage(named: enhancementType.icon) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: isIPad ? 50 : 40, height: isIPad ? 50 : 40)
                    } else {
                        Image(systemName: enhancementType.icon)
                            .font(.system(size: isIPad ? 36 : 28, weight: .medium))
                            .foregroundColor(.white)
                    }

                    Text(enhancementType.name)
                        .font(.system(size: isIPad ? 24 : 20, weight: .bold))
                        .foregroundColor(.white)
                }

                Divider()
                    .background(Color.white.opacity(0.3))

                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.system(size: isIPad ? 16 : 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))

                    Text(enhancementType.description)
                        .font(.system(size: isIPad ? 15 : 13))
                        .foregroundColor(.white.opacity(0.95))
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Available Options
                if !enhancementType.options.isEmpty {
                    Divider()
                        .background(Color.white.opacity(0.3))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Available Options")
                            .font(.system(size: isIPad ? 16 : 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))

                        ForEach(enhancementType.options, id: \.id) { option in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: option.icon)
                                    .font(.system(size: isIPad ? 16 : 14))
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: isIPad ? 24 : 20)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(option.title)
                                            .font(.system(size: isIPad ? 15 : 13, weight: .semibold))
                                            .foregroundColor(.white)

                                        if option.isRecommended {
                                            Text("RECOMMENDED")
                                                .font(.system(size: isIPad ? 10 : 9, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.green.opacity(0.8))
                                                )
                                        }
                                    }

                                    Text(option.description)
                                        .font(.system(size: isIPad ? 14 : 12))
                                        .foregroundColor(.white.opacity(0.8))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .padding(isIPad ? 24 : 20)
        }
        .frame(width: isIPad ? 400 : 320, height: isIPad ? 500 : 400)
        .background(Color.black.opacity(0.92))
        .cornerRadius(16)
    }
}

#Preview {
    VStack(spacing: 20) {
        ImageComparisonCard(
            icon: "upscalerIcon",
            title: "AI Upscale",
            subtitle: "Enhance image resolution",
            gradientType: .redPink,
            beforeImageName: "test",
            afterImageName: "testEnhanced"
        ) {
            print("Tapped AI Upscale")
        }

        ImageComparisonCard(
            icon: "DenoiseIcon",
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
