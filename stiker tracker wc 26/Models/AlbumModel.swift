import SwiftData
import Foundation

/// Синглтон-запись, представляющая сам альбом.
/// Хранит глобальные метаданные и флаг первоначального сидирования.
@Model
final class AlbumModel {

    @Attribute(.unique) var id: String   // всегда "main"
    var isSeeded: Bool
    var createdAt: Date

    init() {
        self.id = "main"
        self.isSeeded = false
        self.createdAt = Date()
    }

    /// Полное количество наклеек в альбоме: 20 FWC + 48 команд × 20
    static let totalStickers = 980

    /// Количество наклеек в одной команде / секции FWC
    static let stickersPerSection = 20
}
