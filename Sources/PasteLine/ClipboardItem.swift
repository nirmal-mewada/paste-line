import Foundation

enum ClipboardType: String, Codable {
    case text
    case url
    case code
}

struct ClipboardItem: Identifiable, Codable, Equatable {
    var id: UUID
    var content: String
    var type: ClipboardType
    var timestamp: Date
    
    init(id: UUID = UUID(), content: String, type: ClipboardType, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.type = type
        self.timestamp = timestamp
    }
}
