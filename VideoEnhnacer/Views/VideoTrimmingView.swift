import SwiftUI
import AVFoundation
import AVKit
import UIKit

struct VideoTrimmingView: View {
    let videoURL: URL
    let enhancementType: String
    let enhancementIcon: String
    let gradientType: GradientType
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var playerManager = VideoPreviewManager()
    @State private var trimStartTime: Double = 0
    @State private var trimEndTime: Double = 30
    @State private var videoDuration: Double = 0
    @State private var selectedDuration: TimePreset = .thirtySeconds
    @State private var navigateToEnhancement = false
    @State private var thumbnails: [UIImage] = []
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    enum TimePreset: CaseIterable {
        case thirtySeconds, fiveMinutes
        
        var duration: Double {
            switch self {
            case .thirtySeconds: return 30
            case .fiveMinutes: return 300
            }
        }
        
        var title: String {
            switch self {
            case .thirtySeconds: return "30s"
            case .fiveMinutes: return "5min"
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color.primarySoft
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Enhanced Video Preview Section - Senior-level implementation
                VStack(spacing: 16) {
                    ZStack {
                        AspectRatioVideoPlayer(
                            player: playerManager.player,
                            contentMode: .fit,
                            maxHeight: DynamicScaling.isTabletOrLarger ? 500 : 320,
                            minHeight: DynamicScaling.isCompactDevice ? 180 : 220,
                            cornerRadius: 20
                        )
                        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
                        .padding(.horizontal, 20)
                        .onAppear {
                            if let player = playerManager.player {
                                player.play()
                            }
                        }
                        
                        // Change Video Button - Positioned as overlay
                        VStack {
                            HStack {
                                Spacer()
                                
                                Button(action: {
                                    HapticFeedbackManager.impact(.light)
                                    dismiss()
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .dynamicFont(14, weight: .medium)
                                        
                                        Text("Change")
                                            .dynamicFont(14, weight: .semibold)
                                    }
                                    .foregroundColor(.white)
                                    .dynamicPadding(12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(LinearGradient.primaryTheme.opacity(0.9))
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                    )
                                    .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
                                }
                            }
                            .dynamicPadding(16)
                            
                            Spacer()
                        }
                    }
                    
                    // Enhanced Video info card - Senior-level responsive design
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "scissors")
                                    .dynamicFont(14, weight: .medium)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("Selected Duration")
                                    .dynamicFont(14, weight: .medium)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            Text(formatDuration(trimEndTime - trimStartTime))
                                .dynamicFont(24, weight: .bold)
                                .foregroundColor(.accentWarm)
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("Total Duration")
                                    .dynamicFont(14, weight: .medium)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Image(systemName: "clock")
                                    .dynamicFont(14, weight: .medium)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            Text(formatDuration(videoDuration))
                                .dynamicFont(24, weight: .bold)
                                .foregroundColor(.accentWarm)
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        }
                    }
                    .dynamicPadding(24)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.accentWarm.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.accentWarm.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .dynamicHorizontalPadding(20)
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Controls Section - Senior-level responsive implementation
                VStack(spacing: DynamicScaling.spacing(30, for: DynamicScaling.currentDeviceSize())) {
                    // Duration Preset Buttons
                    HStack(spacing: DynamicScaling.spacing(16, for: DynamicScaling.currentDeviceSize())) {
                        ForEach(TimePreset.allCases, id: \.title) { preset in
                            Button(preset.title) {
                                HapticFeedbackManager.impact(.light)
                                selectedDuration = preset
                                updateTrimForPreset(preset)
                            }
                            .buttonStyle(PresetButtonStyle(
                                isSelected: selectedDuration == preset
                            ))
                        }
                        
                        Spacer()
                    }
                    .dynamicHorizontalPadding(20)
                    
                    // Video Trimming Slider
                    VideoTrimmingSlider(
                        startTime: $trimStartTime,
                        endTime: $trimEndTime,
                        duration: videoDuration,
                        presetDuration: selectedDuration.duration,
                        gradientType: gradientType,
                        thumbnails: thumbnails
                    )
                    .dynamicFrame(height: 60)
                    .dynamicHorizontalPadding(20)
                    
                    // Process Button - Enhanced with senior-level styling
                    Button(action: {
                        HapticFeedbackManager.impact(.medium)
                        
                        // Debug: Log current trim values before navigation
                        print("🎬 VideoTrimmingView - Navigating with trimStartTime: \(trimStartTime), trimEndTime: \(trimEndTime)")
                        
                        navigateToEnhancement = true
                    }) {
                        HStack(spacing: DynamicScaling.spacing(12, for: DynamicScaling.currentDeviceSize())) {
                            Image(systemName: enhancementIcon)
                                .dynamicFont(20, weight: .medium)
                            
                            Text("Continue to \(enhancementType)")
                                .dynamicFont(18, weight: .semibold)
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                        }
                    }
                    .buttonStyle(FloatingActionButtonStyle())
                    .dynamicHorizontalPadding(20)
                }
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden()
        .gesture(
            DragGesture()
                .onEnded { value in
                    // Swipe to dismiss - right swipe from left edge
                    if value.startLocation.x < 50 && value.translation.width > 100 {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        dismiss()
                    }
                }
        )
        .navigationBarItems(
            leading: BackButton { dismiss() },
            trailing: HStack(spacing: 16) {
                // Enhanced step indicator
                VStack(spacing: 4) {
                    // Progress dots with connecting lines
                    HStack(spacing: 8) {
                        ForEach(1...3, id: \.self) { step in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(step <= 2 ? LinearGradient.primaryTheme : LinearGradient(colors: [Color.accentWarm.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: step == 2 ? 10 : 8, height: step == 2 ? 10 : 8)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.accentWarm, lineWidth: step == 2 ? 2 : 1)
                                            .opacity(step == 2 ? 1 : 0.5)
                                    )
                                
                                // Connecting line (except for last step)
                                if step < 3 {
                                    Rectangle()
                                        .fill(step < 2 ? LinearGradient.primaryTheme : LinearGradient(colors: [Color.accentWarm.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: 12, height: 2)
                                        .cornerRadius(1)
                                }
                            }
                        }
                    }
                    
                    Text("Step 2 of 3")
                        .dynamicFont(12, weight: .medium)
                        .foregroundColor(.accentWarm)
                }
                
                // Close button - Senior-level implementation
                Button(action: {
                    HapticFeedbackManager.impact(.medium)
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .dynamicFont(16, weight: .medium)
                        .foregroundColor(.accentWarm)
                        .dynamicFrame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.accentWarm.opacity(0.15))
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        )
        .onAppear {
            setupVideo()
        }
        .onDisappear {
            playerManager.cleanup()
        }
        .fullScreenCover(isPresented: $navigateToEnhancement) {
            NavigationView {
                RefactoredEnhancementSelectionView(
                    videoURL: videoURL,
                    enhancementType: getEnhancementType(from: enhancementType),
                    trimStartTime: trimStartTime,
                    trimEndTime: trimEndTime
                )
            }
        }
        .onChange(of: trimStartTime) { newValue in
            print("🎬 VideoTrimmingView - trimStartTime changed to: \(newValue)")
            playerManager.updateTrim(start: newValue, end: trimEndTime)
            if let player = playerManager.player {
                let time = CMTime(seconds: newValue, preferredTimescale: 600)
                player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
                player.play()
            }
        }
        .onChange(of: trimEndTime) { newValue in
            print("🎬 VideoTrimmingView - trimEndTime changed to: \(newValue)")
            playerManager.updateTrim(start: trimStartTime, end: newValue)
        }
    }
    
    private func setupVideo() {
        playerManager.setupPlayer(with: videoURL)

        // Get video duration
        let asset = AVURLAsset(url: videoURL)
        Task {
            do {
                let duration: CMTime
                if #available(iOS 16.0, *) {
                    duration = try await asset.load(.duration)
                } else {
                    try await withCheckedThrowingContinuation { continuation in
                        asset.loadValuesAsynchronously(forKeys: ["duration"]) {
                            var error: NSError?
                            let status = asset.statusOfValue(forKey: "duration", error: &error)
                            if let error = error {
                                continuation.resume(throwing: error)
                            } else if status == .loaded {
                                continuation.resume(returning: asset.duration)
                            } else {
                                continuation.resume(throwing: VideoProcessingError.processingFailed("Duration load failed"))
                            }
                        }
                    }
                }
                let durationSeconds = CMTimeGetSeconds(duration)
                let images = await generateThumbnails(for: asset, duration: durationSeconds)

                await MainActor.run {
                    self.videoDuration = durationSeconds
                    self.trimEndTime = min(selectedDuration.duration, durationSeconds)
                    self.thumbnails = images
                    self.playerManager.updateTrim(start: trimStartTime, end: trimEndTime)
                }
            } catch {
                print("Error loading video duration: \(error)")
            }
        }
    }

    private func generateThumbnails(for asset: AVAsset, duration: Double, count: Int = 10) async -> [UIImage] {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        var times: [NSValue] = []
        let increment = duration / Double(count)
        for i in 0..<count {
            let time = CMTime(seconds: Double(i) * increment, preferredTimescale: 600)
            times.append(NSValue(time: time))
        }

        var images: [UIImage] = []
        for time in times {
            do {
                let cgImage = try generator.copyCGImage(at: time.timeValue, actualTime: nil)
                images.append(UIImage(cgImage: cgImage))
            } catch {
                print("Thumbnail generation error: \(error)")
            }
        }

        return images
    }
    
    private func updateTrimForPreset(_ preset: TimePreset) {
        // Quick-set helper: Set trim window to preset duration starting from current position
        // But allow further adjustment with independent handles
        
        let newEndTime = min(trimStartTime + preset.duration, videoDuration)
        
        // If preset would go beyond video end, adjust start time
        if newEndTime >= videoDuration {
            trimStartTime = max(0, videoDuration - preset.duration)
            trimEndTime = videoDuration
        } else {
            trimEndTime = newEndTime
        }
        
        print("🎬 VideoTrimmingView - Preset \(preset.title): start=\(trimStartTime), end=\(trimEndTime)")
        
        playerManager.updateTrim(start: trimStartTime, end: trimEndTime)
        if let player = playerManager.player {
            let start = CMTime(seconds: trimStartTime, preferredTimescale: 600)
            player.seek(to: start)
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
    
    private func formatDuration(_ seconds: Double) -> String {
        if seconds < 60 {
            return String(format: "%.0fs", seconds)
        } else {
            let minutes = Int(seconds) / 60
            let remainingSeconds = Int(seconds) % 60
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }
    
    // Helper function to convert String enhancementType to EnhancementType struct
    private func getEnhancementType(from stringType: String) -> EnhancementType {
        let registry = EnhancementTypeRegistry.shared
        let supportedTypes = registry.getAllEnhancementTypes()
        
        // Map string names to enhancement IDs
        switch stringType {
        case "AI Upscale":
            return supportedTypes.first { $0.id == "ai_upscale" } ?? supportedTypes[0]
        case "AI Denoise":
            return supportedTypes.first { $0.id == "ai_denoise" } ?? supportedTypes[0]
        case "AI Auto Enhancement":
            return supportedTypes.first { $0.id == "ai_auto_enhancement" } ?? supportedTypes[0]
        case "Stabilizer":
            return supportedTypes.first { $0.id == "stabilizer" } ?? supportedTypes[0]
        case "Frame Interpolation":
            return supportedTypes.first { $0.id == "frame_interpolation" } ?? supportedTypes[0]
        default:
            return supportedTypes[0]
        }
    }
}


// Senior-level preset button style with dynamic scaling
struct PresetButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        let deviceSize = DynamicScaling.currentDeviceSize()
        
        configuration.label
            .font(.system(size: DynamicScaling.font(16, for: deviceSize), weight: .semibold))
            .foregroundColor(isSelected ? .white : .white.opacity(0.8))
            .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
            .frame(
                width: DynamicScaling.size(80, for: deviceSize),
                height: DynamicScaling.size(40, for: deviceSize)
            )
            .background(
                RoundedRectangle(cornerRadius: DynamicScaling.cornerRadius(12, for: deviceSize))
                    .fill(isSelected ? AnyShapeStyle(LinearGradient.primaryTheme) : AnyShapeStyle(Color.accentWarm.opacity(0.15)))
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}


#Preview {
    NavigationView {
        VideoTrimmingView(
            videoURL: URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!,
            enhancementType: "AI Upscale",
            enhancementIcon: "arrow.up.square",
            gradientType: .redPink
        )
    }
}
