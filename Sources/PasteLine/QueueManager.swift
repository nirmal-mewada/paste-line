import Foundation
import Combine

enum PasteMode: String, Codable {
    case fifo
    case lifo
}

class QueueManager: ObservableObject {
    @Published var items: [ClipboardItem] = [] {
        didSet {
            saveItems()
            onItemsChanged?()
        }
    }
    
    @Published var mode: PasteMode = .fifo {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "PasteLine_mode")
            onModeChanged?()
        }
    }
    
    @Published var isSessionActive: Bool = false {
        didSet {
            UserDefaults.standard.set(isSessionActive, forKey: "PasteLine_isSessionActive")
            onSessionStateChanged?()
        }
    }
    
    // Callbacks to notify AppDelegate/StatusBar when data changes
    var onItemsChanged: (() -> Void)?
    var onSessionStateChanged: (() -> Void)?
    var onModeChanged: (() -> Void)?
    
    init() {
        // Load mode
        if let modeStr = UserDefaults.standard.string(forKey: "PasteLine_mode"),
           let savedMode = PasteMode(rawValue: modeStr) {
            self.mode = savedMode
        }
        
        // Load session status
        self.isSessionActive = UserDefaults.standard.bool(forKey: "PasteLine_isSessionActive")
        
        // Load items (must be done after initializing published variables to prevent double-calls)
        if let data = UserDefaults.standard.data(forKey: "PasteLine_items") {
            do {
                let decoded = try JSONDecoder().decode([ClipboardItem].self, from: data)
                self.items = decoded
            } catch {
                print("Failed to load clipboard items: \(error)")
            }
        }
    }
    
    func startSession() {
        isSessionActive = true
    }
    
    func stopSession() {
        isSessionActive = false
    }
    
    func clearSession() {
        items.removeAll()
    }
    
    func addItem(content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Ignore consecutive duplicate capture
        if let lastItem = items.last, lastItem.content == content {
            return
        }
        
        // Classify type
        let isURL = content.lowercased().hasPrefix("http://") || content.lowercased().hasPrefix("https://")
        let isCode = content.contains("{") && content.contains("}") && content.contains("\n")
        let type: ClipboardType = isURL ? .url : (isCode ? .code : .text)
        
        let newItem = ClipboardItem(content: content, type: type)
        items.append(newItem)
    }
    
    func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
    }
    
    func reorder(fromOffsets: IndexSet, toOffset: Int) {
        items.move(fromOffsets: fromOffsets, toOffset: toOffset)
    }
    
    func updateItem(id: UUID, newContent: String) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].content = newContent
            let isURL = newContent.lowercased().hasPrefix("http://") || newContent.lowercased().hasPrefix("https://")
            let isCode = newContent.contains("{") && newContent.contains("}") && newContent.contains("\n")
            items[index].type = isURL ? .url : (isCode ? .code : .text)
        }
    }
    
    func popNextItem() -> ClipboardItem? {
        guard !items.isEmpty else { return nil }
        
        let item: ClipboardItem
        switch mode {
        case .fifo:
            item = items.removeFirst()
        case .lifo:
            item = items.removeLast()
        }
        return item
    }
    
    private func saveItems() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: "PasteLine_items")
        } catch {
            print("Failed to save clipboard items: \(error)")
        }
    }
}
