import SwiftUI
import Combine
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
    
    private var isSmallScreen: Bool {
        let screenHeight = UIScreen.main.bounds.height
        return screenHeight <= 736
    }
    
    private var adaptiveVideoHeight: CGFloat {
        if isIPad {
            return 400
        } else if isSmallScreen {
            return 240
        } else {
            return 320
        }
    }
    
    private var adaptiveBottomPadding: CGFloat {
        isSmallScreen ? 20 : 40
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
            
            ScrollView {
                VStack(spacing: 0) {
                // Enhanced Video Preview Section
                VStack(spacing: 16) {
                    ZStack {
                        if let player = playerManager.player {
                            VideoPlayer(player: player)
                                .frame(height: adaptiveVideoHeight)
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.accentWarm.opacity(0.2), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
                                .padding(.horizontal, 20)
                                .onAppear {
                                    player.play()
                                }
                        } else {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.accentWarm.opacity(0.1))
                                .frame(height: adaptiveVideoHeight)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.accentWarm.opacity(0.2), lineWidth: 1)
                                )
                                .padding(.horizontal, 20)
                                .overlay(
                                    VStack(spacing: 12) {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(1.2)
                                        
                                        Text("Loading Video...")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                )
                        }
                        
                        // Change Video Button
                        VStack {
                            HStack {
                                Spacer()
                                
                                Button(action: {
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                    dismiss()
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 14, weight: .medium))
                                        
                                        Text("Change")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
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
                            .padding(.trailing, 32)
                            .padding(.top, 16)
                            
                            Spacer()
                        }
                    }
                    
                    // Enhanced Video info card
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "scissors")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("Selected Duration")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            Text(formatDuration(trimEndTime - trimStartTime))
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.accentWarm)
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("Total Duration")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Image(systemName: "clock")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            Text(formatDuration(videoDuration))
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.accentWarm)
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        }
                    }
                    .padding(.horizontal, 24)
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
                    .padding(.horizontal, 20)
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Controls Section
                VStack(spacing: 30) {
                    // Duration Preset Buttons
                    HStack(spacing: 16) {
                        ForEach(TimePreset.allCases, id: \.title) { preset in
                            Button(preset.title) {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                selectedDuration = preset
                                updateTrimForPreset(preset)
                            }
                            .buttonStyle(PresetButtonStyle(
                                isSelected: selectedDuration == preset
                            ))
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    // Video Trimming Slider
                    VideoTrimmingSlider(
                        startTime: $trimStartTime,
                        endTime: $trimEndTime,
                        duration: videoDuration,
                        presetDuration: selectedDuration.duration,
                        gradientType: gradientType,
                        thumbnails: thumbnails
                    )
                    .frame(height: 60)
                    .padding(.horizontal, 20)
                    
                    // Process Button
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        
                        // Debug: Log current trim values before navigation
                        print("🎬 VideoTrimmingView - Navigating with trimStartTime: \(trimStartTime), trimEndTime: \(trimEndTime)")
                        
                        navigateToEnhancement = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: enhancementIcon)
                                .font(.system(size: 20, weight: .medium))
                            
                            Text("Continue to \(enhancementType)")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                        }
                    }
                    .buttonStyle(FloatingActionButtonStyle())
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, adaptiveBottomPadding)
            }
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
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    // Add haptic feedback
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    dismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
//                        Text("Back")
//                            .font(.system(size: 17, weight: .medium))
                    }
                    .foregroundColor(.accentWarm)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentWarm.opacity(0.1))
                    )
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
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
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.accentWarm)
                    }
                    
                    // Close button
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.accentWarm)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.accentWarm.opacity(0.15))
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .onAppear {
            setupVideo()
        }
        .onDisappear {
            playerManager.cleanup()
        }
        // If a global go-home is requested, dismiss this screen too
        .onReceive(NotificationCenter.default.publisher(for: .goHomeRequested)) { _ in
            dismiss()
        }
        .fullScreenCover(isPresented: $navigateToEnhancement) {
            NavigationView {
                EnhancementSelectionView(
                    videoURL: videoURL,
                    enhancementType: enhancementType,
                    enhancementIcon: enhancementIcon,
                    gradientType: gradientType,
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
                let duration = try await asset.load(.duration)
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
}


// Custom button style for preset buttons
struct PresetButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(isSelected ? .white : .white.opacity(0.8))
            .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
            .frame(width: 80, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 12)
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
