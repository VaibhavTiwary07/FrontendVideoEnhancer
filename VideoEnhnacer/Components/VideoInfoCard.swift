import SwiftUI
import AVFoundation

struct VideoInfoCard: View {
    let videoURL: URL
    @State private var videoInfo: VideoInfo?
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Duration
            InfoItem(
                icon: "clock.fill",
                title: "Duration",
                value: videoInfo?.formattedDuration ?? "Loading..."
            )
            
            Divider()
                .frame(height: 40)
                .foregroundColor(.white.opacity(0.3))
            
            // Resolution
            InfoItem(
                icon: "viewfinder",
                title: "Resolution", 
                value: videoInfo?.formattedResolution ?? "Loading..."
            )
            
            Divider()
                .frame(height: 40)
                .foregroundColor(.white.opacity(0.3))
            
            // File Size
            InfoItem(
                icon: "doc.fill",
                title: "Size",
                value: videoInfo?.formattedFileSize ?? "Loading..."
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .onAppear {
            loadVideoInfo()
        }
    }
    
    private func loadVideoInfo() {
        Task {
            let asset = AVURLAsset(url: videoURL)
            
            do {
                let duration = try await asset.load(.duration)
                let tracks = try await asset.load(.tracks)
                
                var resolution = CGSize.zero
                if let videoTrack = tracks.first(where: { $0.mediaType == .video }) {
                    let naturalSize = try await videoTrack.load(.naturalSize)
                    resolution = naturalSize
                }
                
                let fileSize = try FileManager.default.attributesOfItem(atPath: videoURL.path)[.size] as? Int64 ?? 0
                
                let info = VideoInfo(
                    duration: duration,
                    resolution: resolution,
                    fileSize: fileSize
                )
                
                await MainActor.run {
                    self.videoInfo = info
                }
            } catch {
                print("Error loading video info: \(error)")
            }
        }
    }
}

struct InfoItem: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

struct VideoInfo {
    let duration: CMTime
    let resolution: CGSize
    let fileSize: Int64
    
    var formattedDuration: String {
        let seconds = CMTimeGetSeconds(duration)
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    var formattedResolution: String {
        return "\(Int(resolution.width))×\(Int(resolution.height))"
    }
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        VideoInfoCard(videoURL: URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!)
            .padding()
    }
}