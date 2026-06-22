import Foundation

enum StickerStatus: String, Codable {
    case missing    // нету
    case pasted     // вклеено
    case duplicate  // повторка
}
