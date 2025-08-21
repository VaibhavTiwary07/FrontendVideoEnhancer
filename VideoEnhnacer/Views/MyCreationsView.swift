import SwiftUI
import AVFoundation

struct MyCreationsView: View {
    @EnvironmentObject private var favoritesManager: FavoritesManager
    @State private var selectedFilter: CreationFilter = .all
    
    enum CreationFilter: String, CaseIterable {
        case all = "All"
        case recent = "Recent"
        case favorites = "Favorites"
    }
    
    private var filteredItems: [FavoriteItem] {
        switch selectedFilter {
        case .all:
            return favoritesManager.favoriteItems
        case .recent:
            return Array(favoritesManager.favoriteItems.prefix(10))
        case .favorites:
            return favoritesManager.favoriteItems
        }
    }
    
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 20) {
                    Text("My Creations")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Filter Tabs
                    HStack(spacing: 12) {
                        ForEach(CreationFilter.allCases, id: \.self) { filter in
                            FilterTab(
                                title: filter.rawValue,
                                isSelected: selectedFilter == filter
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedFilter = filter
                                }
                                
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                            }
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Content
                if filteredItems.isEmpty {
                    EmptyStateView()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(filteredItems) { item in
                                CreationCard(item: item)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                }
            }
        }
    }
}

struct FilterTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .secondaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? LinearGradient.primaryTheme : LinearGradient(colors: [Color.cardBackground], startPoint: .leading, endPoint: .trailing))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.gray.opacity(0.2), lineWidth: isSelected ? 0 : 1)
                        )
                )
                .scaleEffect(isSelected ? 1.0 : 0.98)
                .shadow(
                    color: Color.black.opacity(isSelected ? 0.08 : 0.04),
                    radius: isSelected ? 4 : 2,
                    x: 0,
                    y: isSelected ? 2 : 1
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CreationCard: View {
    let item: FavoriteItem
    @EnvironmentObject private var favoritesManager: FavoritesManager
    @State private var thumbnail: UIImage?
    @State private var isLoadingThumbnail = true
    
    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: item.dateAdded, relativeTo: Date())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Thumbnail with video preview
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.cardBackground)
                    .frame(height: 120)
                    .overlay(
                        Group {
                            if let thumbnail = thumbnail {
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 120)
                                    .clipped()
                                    .cornerRadius(12)
                            } else if isLoadingThumbnail {
                                LoadingThumbnailView()
                            } else {
                                PlaceholderThumbnailView()
                            }
                        }
                    )
                
                // Play overlay
                VStack {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.4))
                                .frame(width: 40, height: 40)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
            }
            
            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primaryText)
                    .lineLimit(1)
                
                Text(formattedDate)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondaryText)
                
                // Enhancement type if available
                if let enhancementType = item.enhancementType {
                    HStack(spacing: 6) {
                        if let enhancementIcon = item.enhancementIcon {
                            Image(systemName: enhancementIcon)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(red: 1.0, green: 0.596, blue: 0.329).opacity(0.8))
                        }
                        
                        Text(enhancementType)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(red: 1.0, green: 0.596, blue: 0.329).opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(red: 1.0, green: 0.596, blue: 0.329).opacity(0.1))
                            )
                        
                        Spacer()
                        
                        // Favorite button
                        Button(action: {
                            favoritesManager.removeFromFavorites(item)
                        }) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(red: 1.0, green: 0.596, blue: 0.329))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
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
                    radius: 4,
                    x: 0,
                    y: 2
                )
        )
        .onTapGesture {
            // Handle video playback or preview
            playVideo()
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        guard thumbnail == nil else { return }
        
        Task {
            do {
                let asset = AVURLAsset(url: item.videoURL)
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
    
    private func playVideo() {
        // Add haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        // Handle video playback - this could open a video player
        print("Playing video: \(item.title)")
    }
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
        .environmentObject(FavoritesManager())
}