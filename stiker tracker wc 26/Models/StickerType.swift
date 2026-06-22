import Foundation

enum StickerType: String, Codable {
    case logo       // #1 — логотип команды
    case teamPhoto  // #13 — командное фото
    case player     // все остальные — игрок
}
