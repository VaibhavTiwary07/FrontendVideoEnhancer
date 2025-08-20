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
                                .foregroundColor(.gray)
                            
                            Text("\(Int(trimEndTime - trimStartTime))s")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Total Duration")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Text("\(Int(videoDuration))s")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
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
                                selectedDuration = preset
                                updateTrimForPreset(preset)
                            }
                            .buttonStyle(PresetButtonStyle(
                                isSelected: selectedDuration == preset,
                                gradientType: gradientType
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
                        processVideo()
                    }) {
                        HStack(spacing: 12) {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: enhancementIcon)
                                    .font(.system(size: 20, weight: .medium))
                            }
                            
                            Text(isProcessing ? "Processing..." : "Process with \(enhancementType)")
                                .font(.system(size: 18, weight: .semibold))
                        }
                    }
                    .buttonStyle(GradientButtonStyle(gradientType: gradientType))
                    .disabled(isProcessing)
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
        .onAppear {
            setupVideo()
        }
        .onDisappear {
            playerManager.cleanup()
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
        
        // Simulate processing time
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            isProcessing = false
            // Navigate to results or show completion
            dismiss()
        }
    }
}

// Custom button style for preset buttons
struct PresetButtonStyle: ButtonStyle {
    let isSelected: Bool
    let gradientType: GradientType
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(isSelected ? .white : .gray)
            .frame(width: 80, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AnyShapeStyle(gradientType.base) : AnyShapeStyle(Color.white.opacity(0.1)))
                    .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        VideoTrimmingView(
            videoURL: URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!,
            enhancementType: "AI Upscale",
            enhancementIcon: "arrow.up.square",
            gradientType: .redPink
        )
    }
}