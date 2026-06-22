import SwiftData
import Foundation

/// Сборная или специальная секция (FWC).
@Model
final class TeamModel {

    @Attribute(.unique) var code: String   // "ARG", "FWC", ...
    var nameEN: String
    var nameRU: String
    var groupLetter: String                // "A"–"L"; "FWC" для стартовой секции
    var orderIndex: Int                    // для сортировки страниц в альбоме
    var flagEmoji: String

    // SwiftData inverse relationship — стикеры хранятся независимо,
    // выбираем через teamCode для простоты и быстрых fetch-запросов.

    init(code: String,
         nameEN: String,
         nameRU: String,
         groupLetter: String,
         orderIndex: Int,
         flagEmoji: String) {
        self.code = code
        self.nameEN = nameEN
        self.nameRU = nameRU
        self.groupLetter = groupLetter
        self.orderIndex = orderIndex
        self.flagEmoji = flagEmoji
    }
}
