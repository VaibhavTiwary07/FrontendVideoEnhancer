import SwiftUI
import AVFoundation

struct FavoritesView: View {
    @EnvironmentObject private var favoritesManager: FavoritesManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var showingClearConfirmation = false
    @State private var selectedVideo: URL?
    @State private var showingVideoPlayer = false
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                if favoritesManager.favoriteItems.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVGrid(columns: isIPad ? Array(repeating: GridItem(.flexible(), spacing: 20), count: 3) : columns, spacing: 20) {
                            ForEach(favoritesManager.favoriteItems) { favorite in
                                FavoriteVideoCard(favorite: favorite) {
                                    selectedVideo = favorite.videoURL
                                    showingVideoPlayer = true
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        dismiss()
                    }
                    .foregroundColor(Color(red: 1.0, green: 0.596, blue: 0.329))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !favoritesManager.favoriteItems.isEmpty {
                        Button("Clear All") {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            showingClearConfirmation = true
                        }
                        .foregroundColor(Color(red: 1.0, green: 0.596, blue: 0.329))
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingVideoPlayer) {
            if let videoURL = selectedVideo {
                VideoPlayerFullScreenView(videoURL: videoURL) {
                    showingVideoPlayer = false
                    selectedVideo = nil
                }
            }
        }
        .alert("Clear All Favorites", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                favoritesManager.clearAllFavorites()
            }
        } message: {
            Text("Are you sure you want to remove all favorites? This action cannot be undone.")
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "heart.slash")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(Color(red: 1.0, green: 0.596, blue: 0.329).opacity(0.6))
                
                VStack(spacing: 8) {
                    Text("No Favorites Yet")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primaryText)
                    
                    Text("Videos and projects you favorite will appear here for quick access.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                dismiss()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                    
                    Text("Start Creating")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient.primaryTheme)
                        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct FavoriteVideoCard: View {
    let favorite: FavoriteItem
    let onTap: () -> Void
    
    @EnvironmentObject private var favoritesManager: FavoritesManager
    @State private var thumbnailImage: UIImage?
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Video thumbnail
                ZStack {
                    if let thumbnailImage = thumbnailImage {
                        Image(uiImage: thumbnailImage)
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                            .frame(height: 120)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(LinearGradient.primaryTheme.opacity(0.3))
                            .frame(height: 120)
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "video.fill")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    Text("Loading...")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            )
                    }
                    
                    // Play overlay
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .offset(x: 2)
                        )
                    
                    // Favorite and enhancement indicators
                    VStack {
                        HStack {
                            if let enhancementType = favorite.enhancementType,
                               let enhancementIcon = favorite.enhancementIcon {
                                HStack(spacing: 4) {
                                    Image(systemName: enhancementIcon)
                                        .font(.system(size: 10, weight: .medium))
                                    Text(enhancementType)
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.6))
                                )
                                .padding(.top, 8)
                                .padding(.leading, 8)
                            }
                            
                            Spacer()
                            
                            FavoriteButton(
                                videoURL: favorite.videoURL,
                                enhancementType: favorite.enhancementType,
                                enhancementIcon: favorite.enhancementIcon,
                                title: favorite.title,
                                duration: favorite.duration
                            )
                            .padding(.top, 8)
                            .padding(.trailing, 8)
                        }
                        
                        Spacer()
                        
                        if let duration = favorite.duration {
                            HStack {
                                Spacer()
                                Text(formatDuration(duration))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color.black.opacity(0.6))
                                    )
                                    .padding(.bottom, 8)
                                    .padding(.trailing, 8)
                            }
                        }
                    }
                }
                .cornerRadius(12, corners: [.topLeft, .topRight])
                
                // Video info
                VStack(alignment: .leading, spacing: 8) {
                    Text(favorite.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(formatDate(favorite.dateAdded))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondaryText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        Task {
            let thumbnail = await generateThumbnail(for: favorite.videoURL)
            await MainActor.run {
                self.thumbnailImage = thumbnail
            }
        }
    }
    
    private func generateThumbnail(for url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 300, height: 168) // 16:9 aspect ratio
        
        return await withCheckedContinuation { continuation in
            imageGenerator.generateCGImageAsynchronously(for: .zero) { image, actualTime, error in
                if let image = image {
                    continuation.resume(returning: UIImage(cgImage: image))
                } else {
                    print("Error generating thumbnail: \(error?.localizedDescription ?? "Unknown error")")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDate(date, inSameDayAs: Date()) {
            return "Today"
        } else if calendar.isDate(date, inSameDayAs: Date().addingTimeInterval(-86400)) {
            return "Yesterday"
        } else if date.timeIntervalSinceNow > -7 * 24 * 60 * 60 { // Within a week
            formatter.dateFormat = "EEEE" // Day of week
        } else {
            formatter.dateFormat = "MMM d" // Month and day
        }
        return formatter.string(from: date)
    }
}

struct VideoPlayerFullScreenView: View {
    let videoURL: URL
    let onDismiss: () -> Void
    
    @StateObject private var playerManager = VideoPreviewManager()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let player = playerManager.player {
                VideoPlayerView(player: player)
                    .onAppear {
                        player.play()
                    }
            }
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.8))
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(width: 40, height: 40)
                            )
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                }
                Spacer()
            }
        }
        .onAppear {
            playerManager.setupPlayer(with: videoURL)
        }
        .onDisappear {
            playerManager.cleanup()
        }
    }
}

// Helper extension for corner radius on specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

#Preview {
    NavigationStack {
        FavoritesView()
    }
    .environmentObject(FavoritesManager())
}