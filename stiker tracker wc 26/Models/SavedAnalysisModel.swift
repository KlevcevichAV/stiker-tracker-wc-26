import SwiftData
import Foundation

@Model
final class SavedAnalysisModel {
    @Attribute(.unique) var id: String
    var createdAt: Date
    var messageText: String
    var note: String

    init(messageText: String, note: String) {
        self.id = UUID().uuidString
        self.createdAt = Date()
        self.messageText = messageText
        self.note = note
    }
}
