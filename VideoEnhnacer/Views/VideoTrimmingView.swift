import SwiftUI
import AVFoundation
import AVKit

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
    @State private var isProcessing = false
    @State private var processingProgress: Double = 0.0
    @State private var processedVideoURL: URL?
    @State private var showingResults = false
    @State private var processingError: String?
    @State private var showingError = false
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
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Video Preview Section
                VStack(spacing: 16) {
                    if let player = playerManager.player {
                        VideoPlayer(player: player)
                            .frame(height: isIPad ? 400 : 280)
                            .cornerRadius(16)
                            .padding(.horizontal, 20)
                            .onAppear {
                                player.play()
                            }
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: isIPad ? 400 : 280)
                            .padding(.horizontal, 20)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            )
                    }
                    
                    // Video info
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Selected Duration")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text("\(Int(trimEndTime - trimStartTime))s")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Total Duration")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text("\(Int(videoDuration))s")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        }
                    }
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
                        gradientType: gradientType
                    )
                    .frame(height: 60)
                    .padding(.horizontal, 20)
                    
                    // Process Button
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        processVideo()
                    }) {
                        HStack(spacing: 12) {
                            if isProcessing {
                                VStack(spacing: 8) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                    
                                    if processingProgress > 0 {
                                        Text("\(Int(processingProgress * 100))%")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white)
                                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                                    }
                                }
                            } else {
                                Image(systemName: enhancementIcon)
                                    .font(.system(size: 20, weight: .medium))
                            }
                            
                            Text(isProcessing ? "Processing..." : "Process with \(enhancementType)")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                        }
                    }
                    .buttonStyle(GradientButtonStyle())
                    .disabled(isProcessing)
                    .padding(.horizontal, 20)
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
                        Text("Back")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.1))
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
                                        .fill(step <= 2 ? LinearGradient.primaryTheme : LinearGradient(colors: [Color.white.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: step == 2 ? 10 : 8, height: step == 2 ? 10 : 8)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: step == 2 ? 2 : 1)
                                                .opacity(step == 2 ? 1 : 0.5)
                                        )
                                    
                                    // Connecting line (except for last step)
                                    if step < 3 {
                                        Rectangle()
                                            .fill(step < 2 ? LinearGradient.primaryTheme : LinearGradient(colors: [Color.white.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                                            .frame(width: 12, height: 2)
                                            .cornerRadius(1)
                                    }
                                }
                            }
                        }
                        
                        Text("Step 2 of 3")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    // Close button
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.15))
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
        .fullScreenCover(isPresented: $showingResults) {
            if let processedURL = processedVideoURL {
                VideoResultsView(
                    originalVideoURL: videoURL,
                    processedVideoURL: processedURL,
                    enhancementType: enhancementType,
                    enhancementIcon: enhancementIcon,
                    gradientType: gradientType
                )
            }
        }
        .alert("Processing Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(processingError ?? "Unknown error occurred")
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
                
                await MainActor.run {
                    self.videoDuration = durationSeconds
                    self.trimEndTime = min(30, durationSeconds) // Default to 30s or video length
                }
            } catch {
                print("Error loading video duration: \(error)")
            }
        }
    }
    
    private func updateTrimForPreset(_ preset: TimePreset) {
        let maxEnd = min(trimStartTime + preset.duration, videoDuration)
        trimEndTime = maxEnd
        
        // Update player to show the trimmed section
        if let player = playerManager.player {
            let startTime = CMTime(seconds: trimStartTime, preferredTimescale: 600)
            player.seek(to: startTime)
        }
    }
    
    private func processVideo() {
        isProcessing = true
        processingProgress = 0.0
        
        Task {
            do {
                let trimmedURL = try await trimVideo(
                    sourceURL: videoURL,
                    startTime: trimStartTime,
                    endTime: trimEndTime
                )
                
                await MainActor.run {
                    processedVideoURL = trimmedURL
                    isProcessing = false
                    showingResults = true
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    processingError = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func trimVideo(sourceURL: URL, startTime: Double, endTime: Double) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)
        
        // Create output URL
        let outputURL = try createOutputURL()
        
        // Remove any existing file at output URL
        try? FileManager.default.removeItem(at: outputURL)
        
        // Create export session
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoProcessingError.exportSessionCreationFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        
        // Set time range for trimming
        let start = CMTime(seconds: startTime, preferredTimescale: 600)
        let end = CMTime(seconds: endTime, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: start, end: end)
        exportSession.timeRange = timeRange
        
        // Create progress tracking
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                self.processingProgress = Double(exportSession.progress)
            }
        }
        
        // Export the video
        if #available(iOS 18.0, *) {
            try await exportSession.export(to: outputURL, as: .mp4)
        } else {
            await exportSession.export()
        }
        
        // Stop progress timer
        progressTimer.invalidate()
        
        // Check export status
        switch exportSession.status {
        case .completed:
            await MainActor.run {
                processingProgress = 1.0
            }
            return outputURL
        case .failed:
            throw VideoProcessingError.exportFailed(exportSession.error?.localizedDescription ?? "Unknown error")
        case .cancelled:
            throw VideoProcessingError.exportCancelled
        default:
            throw VideoProcessingError.exportFailed("Export incomplete")
        }
    }
    
    private func createOutputURL() throws -> URL {
        guard let documentsPath = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first else {
            throw VideoProcessingError.exportSessionCreationFailed
        }
        let outputFileName = "trimmed_video_\(UUID().uuidString).mp4"
        return documentsPath.appendingPathComponent(outputFileName)
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
}

enum VideoProcessingError: LocalizedError {
    case exportSessionCreationFailed
    case exportFailed(String)
    case exportCancelled
    
    var errorDescription: String? {
        switch self {
        case .exportSessionCreationFailed:
            return "Failed to create video export session"
        case .exportFailed(let message):
            return "Video export failed: \(message)"
        case .exportCancelled:
            return "Video export was cancelled"
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
                    .fill(isSelected ? AnyShapeStyle(LinearGradient.primaryTheme) : AnyShapeStyle(Color.white.opacity(0.15)))
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