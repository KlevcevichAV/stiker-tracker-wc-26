import Foundation
import SwiftData
import Observation

@Observable
final class AlbumViewModel {

    private(set) var pages: [AlbumPage] = []
    var currentPageIndex: Int = 0

    // MARK: - Load

    func load(context: ModelContext) {
        let teamDescriptor = FetchDescriptor<TeamModel>(
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        let teams = (try? context.fetch(teamDescriptor)) ?? []

        let stickerDescriptor = FetchDescriptor<StickerModel>(
            sortBy: [SortDescriptor(\.number)]
        )
        let allStickers = (try? context.fetch(stickerDescriptor)) ?? []

        // Группируем стикеры по teamCode для O(1) доступа
        var stickersByCode: [String: [StickerModel]] = [:]
        for sticker in allStickers {
            stickersByCode[sticker.teamCode, default: []].append(sticker)
        }

        pages = teams.map { team in
            AlbumPage(
                id: team.code,
                team: team,
                stickers: stickersByCode[team.code] ?? []
            )
        }
    }

    // MARK: - Navigation helpers

    var currentPage: AlbumPage? { pages[safe: currentPageIndex] }
    var totalPages: Int { pages.count }

    func goTo(index: Int) {
        guard pages.indices.contains(index) else { return }
        currentPageIndex = index
    }
}

// MARK: - Safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
