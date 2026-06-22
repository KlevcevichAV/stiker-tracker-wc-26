import SwiftData
import Foundation

/// Одна наклейка в альбоме.
/// id — уникальный строковый ключ Panini, например "ARG 10" или "FWC 3".
@Model
final class StickerModel {

    @Attribute(.unique) var id: String
    var teamCode: String        // "ARG", "FWC", ...
    var number: Int             // порядковый номер внутри секции
    var typeRaw: String         // StickerType.rawValue
    var nameEN: String
    var nameRU: String
    var statusRaw: String       // StickerStatus.rawValue
    var duplicateCount: Int     // сколько повторок (0 пока не вклеено)
    @Attribute var isFoil: Bool = false   // голографическая / блестящая карточка

    init(id: String,
         teamCode: String,
         number: Int,
         type: StickerType,
         nameEN: String,
         nameRU: String,
         isFoil: Bool = false) {
        self.id = id
        self.teamCode = teamCode
        self.number = number
        self.typeRaw = type.rawValue
        self.nameEN = nameEN
        self.nameRU = nameRU
        self.statusRaw = StickerStatus.missing.rawValue
        self.duplicateCount = 0
        self.isFoil = isFoil
    }

    var type: StickerType {
        StickerType(rawValue: typeRaw) ?? .player
    }

    var status: StickerStatus {
        get { StickerStatus(rawValue: statusRaw) ?? .missing }
        set { statusRaw = newValue.rawValue }
    }

    var isPasted: Bool { status == .pasted }
    var isDuplicate: Bool { status == .duplicate }
}
