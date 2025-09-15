import SwiftUI
import AVFoundation

struct MyCreationsView: View {
    @EnvironmentObject private var history: HistoryManager
    @Environment(\.horizontalSizeClass) private var hSize
    private var isIPad: Bool { hSize == .regular }
    private var recentItems: [HistoryItem] { Array(history.items.prefix(20)) }
    @State private var selectedItem: HistoryItem?
    
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header (Recent only)
                Text("Recent Creations")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                // Content
                if recentItems.isEmpty {
                    EmptyStateView()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: isIPad ? 240 : 160), spacing: 16)
                        ], spacing: 16) {
                            ForEach(recentItems) { item in
                                HistoryCard(item: item) {
                                    selectedItem = item
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedItem) { item in
            HistoryVideoPlayerView(item: item)
        }
    }
}

// FilterTab removed — Recent only

struct HistoryCard: View {
    let item: HistoryItem
    var onTap: () -> Void = {}
    @State private var thumbnail: UIImage?
    @State private var isLoadingThumbnail = true
    @Environment(\.horizontalSizeClass) private var hSize
    private var isIPad: Bool { hSize == .regular }
    
    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: item.date, relativeTo: Date())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Thumbnail with video preview (16:9, clipped; no play overlay)
            ZStack {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipped()
                } else if isLoadingThumbnail {
                    LoadingThumbnailView()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(16/9, contentMode: .fit)
                } else {
                    PlaceholderThumbnailView()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(16/9, contentMode: .fit)
                }

                // Play overlay
                Image(systemName: "play.circle.fill")
                    .font(.system(size: isIPad ? 42 : 36, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
            
            // Info
            VStack(alignment: .leading, spacing: isIPad ? 8 : 6) {
                // Title and file name
                Text(item.enhancementTitle)
                    .font(.system(size: isIPad ? 16 : 14, weight: .semibold))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                Text(item.fileName)
                    .font(.system(size: isIPad ? 12 : 11, weight: .regular))
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)

                // Enhancement meta + when
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: item.enhancementIcon)
                            .font(.system(size: isIPad ? 12 : 11, weight: .medium))
                            .foregroundColor(Color(red: 1.0, green: 0.596, blue: 0.329).opacity(0.85))

                        Text(item.enhancementTitle)
                            .font(.system(size: isIPad ? 12 : 11, weight: .medium))
                            .foregroundColor(Color(red: 1.0, green: 0.596, blue: 0.329).opacity(0.85))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(red: 1.0, green: 0.596, blue: 0.329).opacity(0.12))
                            )
                    }

                    Spacer()

                    Text(formattedDate)
                        .font(.system(size: isIPad ? 12 : 10, weight: .regular))
                        .foregroundColor(.secondaryText)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                )
                .shadow(
                    color: Color.black.opacity(0.06),
                    radius: isIPad ? 6 : 4,
                    x: 0,
                    y: 2
                )
        )
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        guard thumbnail == nil else { return }
        
        Task {
            do {
                let asset = AVURLAsset(url: item.processedURL)
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                imageGenerator.maximumSize = CGSize(width: 200, height: 120)
                
                let time = CMTime(seconds: 1, preferredTimescale: 60)
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                
                await MainActor.run {
                    self.thumbnail = UIImage(cgImage: cgImage)
                    self.isLoadingThumbnail = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingThumbnail = false
                }
            }
        }
    }
    
    // Tapping the card presents a full-screen player for the processed video
}

struct LoadingThumbnailView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color.gray.opacity(0.1)
            
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(Color.gray, lineWidth: 2)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: isAnimating)
                )
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct PlaceholderThumbnailView: View {
    var body: some View {
        ZStack {
            Color.gray.opacity(0.1)
            
            VStack(spacing: 8) {
                Image(systemName: "video.slash")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.gray.opacity(0.6))
                
                Text("No Preview")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray.opacity(0.6))
            }
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(.gray.opacity(0.5))
                
                VStack(spacing: 8) {
                    Text("No Creations Yet")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.primaryText)
                    
                    Text("Start enhancing videos to see your creations here")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            
            Spacer()
        }
    }
}

#Preview {
    MyCreationsView()
        .environmentObject(HistoryManager())
}
