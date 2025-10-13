import Foundation
import SwiftUI

// MARK: - Favorite Item Model
struct FavoriteItem: Codable, Identifiable, Equatable {
    let id: UUID
    let videoURL: URL
    let enhancementType: String?
    let enhancementIcon: String?
    let thumbnailData: Data?
    let dateAdded: Date
    let title: String
    let duration: Double?
    
    init(videoURL: URL, enhancementType: String? = nil, enhancementIcon: String? = nil, thumbnailData: Data? = nil, title: String, duration: Double? = nil) {
        self.id = UUID()
        self.videoURL = videoURL
        self.enhancementType = enhancementType
        self.enhancementIcon = enhancementIcon
        self.thumbnailData = thumbnailData
        self.dateAdded = Date()
        self.title = title
        self.duration = duration
    }
    
    static func == (lhs: FavoriteItem, rhs: FavoriteItem) -> Bool {
        return lhs.videoURL == rhs.videoURL
    }
}

// MARK: - Favorites Manager
class FavoritesManager: ObservableObject {
    @Published var favoriteItems: [FavoriteItem] = []
    
    private let userDefaults = UserDefaults.standard
    private let favoritesKey = "VideoEnhancer_Favorites"
    
    init() {
        loadFavorites()
    }
    
    // MARK: - Public Methods
    
    func addToFavorites(_ item: FavoriteItem) {
        // Check if item already exists (by URL)
        if !favoriteItems.contains(where: { $0.videoURL == item.videoURL }) {
            favoriteItems.insert(item, at: 0) // Add to beginning
            saveFavorites()
            
            // Add haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        }
    }
    
    func removeFromFavorites(_ item: FavoriteItem) {
        favoriteItems.removeAll { $0.id == item.id }
        saveFavorites()
        
        // Add haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    func removeFromFavorites(by videoURL: URL) {
        favoriteItems.removeAll { $0.videoURL == videoURL }
        saveFavorites()
    }
    
    func isFavorite(_ videoURL: URL) -> Bool {
        return favoriteItems.contains { $0.videoURL == videoURL }
    }
    
    func toggleFavorite(videoURL: URL, enhancementType: String? = nil, enhancementIcon: String? = nil, title: String, duration: Double? = nil) {
        if isFavorite(videoURL) {
            removeFromFavorites(by: videoURL)
        } else {
            let newFavorite = FavoriteItem(
                videoURL: videoURL,
                enhancementType: enhancementType,
                enhancementIcon: enhancementIcon,
                title: title,
                duration: duration
            )
            addToFavorites(newFavorite)
        }
    }
    
    func clearAllFavorites() {
        favoriteItems.removeAll()
        saveFavorites()
    }
    
    // MARK: - Private Methods
    
    private func saveFavorites() {
        do {
            let data = try JSONEncoder().encode(favoriteItems)
            userDefaults.set(data, forKey: favoritesKey)
        } catch {
            print("Error saving favorites: \(error.localizedDescription)")
        }
    }
    
    private func loadFavorites() {
        guard let data = userDefaults.data(forKey: favoritesKey) else { return }
        
        do {
            favoriteItems = try JSONDecoder().decode([FavoriteItem].self, from: data)
        } catch {
            print("Error loading favorites: \(error.localizedDescription)")
            favoriteItems = []
        }
    }
}

// MARK: - Favorite Button Component
struct FavoriteButton: View {
    let videoURL: URL
    let enhancementType: String?
    let enhancementIcon: String?
    let title: String
    let duration: Double?
    
    @EnvironmentObject private var favoritesManager: FavoritesManager
    @State private var isAnimating = false
    
    private var isFavorite: Bool {
        favoritesManager.isFavorite(videoURL)
    }
    
    init(videoURL: URL, enhancementType: String? = nil, enhancementIcon: String? = nil, title: String, duration: Double? = nil) {
        self.videoURL = videoURL
        self.enhancementType = enhancementType
        self.enhancementIcon = enhancementIcon
        self.title = title
        self.duration = duration
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isAnimating = true
            }
            
            favoritesManager.toggleFavorite(
                videoURL: videoURL,
                enhancementType: enhancementType,
                enhancementIcon: enhancementIcon,
                title: title,
                duration: duration
            )
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isAnimating = false
                }
            }
        }) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(isFavorite ? Color(red: 1.0, green: 0.596, blue: 0.329) : .white.opacity(0.8))
                .scaleEffect(isAnimating ? 1.3 : 1.0)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}