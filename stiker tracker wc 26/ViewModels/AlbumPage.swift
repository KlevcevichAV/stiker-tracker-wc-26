import Foundation
import SwiftData

/// Данные одной страницы альбома — команда + её стикеры.
/// Передаётся из AlbumViewModel в UIPageViewController как value type.
struct AlbumPage: Identifiable {
    let id: String          // team.code
    let team: TeamModel
    let stickers: [StickerModel]   // отсортированы по number
}
