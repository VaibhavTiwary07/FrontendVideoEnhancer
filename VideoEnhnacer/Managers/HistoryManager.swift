import Foundation
import SwiftUI

struct HistoryItem: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let originalURL: URL
    let processedURL: URL
    let enhancementTitle: String
    let enhancementIcon: String
    let fileName: String
    
    init(originalURL: URL, processedURL: URL, enhancementTitle: String, enhancementIcon: String) {
        self.id = UUID()
        self.date = Date()
        self.originalURL = originalURL
        self.processedURL = processedURL
        self.enhancementTitle = enhancementTitle
        self.enhancementIcon = enhancementIcon
        self.fileName = processedURL.lastPathComponent
    }
}

final class HistoryManager: ObservableObject {
    @Published private(set) var items: [HistoryItem] = []
    
    private let storageKey = "VideoEnhancer_History_Items"
    private let maxItems = 200
    
    init() {
        load()
    }
    
    func add(_ item: HistoryItem) {
        // De-dup by processedURL
        items.removeAll { $0.processedURL == item.processedURL }
        items.insert(item, at: 0)
        if items.count > maxItems { items.removeLast(items.count - maxItems) }
        save()
    }
    
    func clear() {
        items.removeAll()
        save()
    }
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("HistoryManager save error: \(error)")
        }
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            items = try JSONDecoder().decode([HistoryItem].self, from: data)
        } catch {
            print("HistoryManager load error: \(error)")
            items = []
        }
    }
}

