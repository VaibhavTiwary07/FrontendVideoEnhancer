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
    var displayName: String
    
    init(originalURL: URL, processedURL: URL, enhancementTitle: String, enhancementIcon: String) {
        self.id = UUID()
        self.date = Date()
        self.originalURL = originalURL
        self.processedURL = processedURL
        self.enhancementTitle = enhancementTitle
        self.enhancementIcon = enhancementIcon
        self.fileName = processedURL.lastPathComponent
        self.displayName = self.fileName
    }

    enum CodingKeys: String, CodingKey {
        case id, date, originalURL, processedURL, enhancementTitle, enhancementIcon, fileName, displayName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        originalURL = try container.decode(URL.self, forKey: .originalURL)
        processedURL = try container.decode(URL.self, forKey: .processedURL)
        enhancementTitle = try container.decode(String.self, forKey: .enhancementTitle)
        enhancementIcon = try container.decode(String.self, forKey: .enhancementIcon)
        fileName = try container.decode(String.self, forKey: .fileName)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? fileName
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(originalURL, forKey: .originalURL)
        try container.encode(processedURL, forKey: .processedURL)
        try container.encode(enhancementTitle, forKey: .enhancementTitle)
        try container.encode(enhancementIcon, forKey: .enhancementIcon)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(displayName, forKey: .displayName)
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
    
    func remove(_ item: HistoryItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func rename(_ item: HistoryItem, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }

        var updated = items[index]
        updated.displayName = trimmed
        items[index] = updated
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
