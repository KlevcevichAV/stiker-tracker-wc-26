import Foundation
import SwiftData
import Observation

/// Вычисляет прогресс коллекции на основе актуального состояния SwiftData.
/// Вызывай refresh(context:) после каждого вклеивания или при появлении экрана.
@Observable
final class StatsViewModel {

    // MARK: - Published state

    private(set) var album  = ProgressStat(pasted: 0, total: AlbumModel.totalStickers)
    private(set) var groups: [GroupStat] = []
    private(set) var totalDuplicates: Int = 0

    // Все команды в алфавитном порядке (для слайдера стран)
    var teamsSortedAlpha: [TeamStat] {
        groups.flatMap(\.teams).sorted { $0.nameEN < $1.nameEN }
    }

    // MARK: - Refresh

    func refresh(context: ModelContext) {
        let allStickers = fetchAllStickers(context: context)
        let allTeams    = fetchAllTeams(context: context)

        // Индекс: teamCode → [StickerModel]
        var byTeam: [String: [StickerModel]] = [:]
        for s in allStickers {
            byTeam[s.teamCode, default: []].append(s)
        }

        // Строим TeamStat
        var teamStats: [TeamStat] = allTeams.map { team in
            let stickers  = byTeam[team.code] ?? []
            let pasted    = stickers.filter { $0.status != .missing }.count
            let dupes     = stickers.filter { $0.status == .duplicate }
                                    .reduce(0) { $0 + $1.duplicateCount }
            return TeamStat(
                code:        team.code,
                nameEN:      team.nameEN,
                nameRU:      team.nameRU,
                flagEmoji:   team.flagEmoji,
                groupLetter: team.groupLetter,
                progress:    ProgressStat(pasted: pasted, total: stickers.count),
                duplicates:  dupes
            )
        }

        // Группируем по groupLetter, порядок: FWC первым, затем A–L
        let groupOrder = groupLetterOrder(from: allTeams)
        var groupMap: [String: [TeamStat]] = [:]
        for ts in teamStats {
            let letter = allTeams.first(where: { $0.code == ts.code })?.groupLetter ?? "?"
            groupMap[letter, default: []].append(ts)
        }

        groups = groupOrder.compactMap { letter -> GroupStat? in
            guard let members = groupMap[letter] else { return nil }
            let totalPasted = members.reduce(0) { $0 + $1.progress.pasted }
            let totalAll    = members.reduce(0) { $0 + $1.progress.total }
            return GroupStat(
                letter:   letter,
                progress: ProgressStat(pasted: totalPasted, total: totalAll),
                teams:    members
            )
        }

        // Глобальный прогресс
        let totalPasted = allStickers.filter { $0.status != .missing }.count
        album = ProgressStat(pasted: totalPasted, total: AlbumModel.totalStickers)
        totalDuplicates = allStickers.filter { $0.status == .duplicate }
                                     .reduce(0) { $0 + $1.duplicateCount }
    }

    // MARK: - Convenience: прогресс одной команды по коду

    func teamProgress(code: String) -> ProgressStat? {
        groups
            .flatMap(\.teams)
            .first(where: { $0.code == code })
            .map(\.progress)
    }

    // MARK: - Private helpers

    private func fetchAllStickers(context: ModelContext) -> [StickerModel] {
        (try? context.fetch(FetchDescriptor<StickerModel>())) ?? []
    }

    private func fetchAllTeams(context: ModelContext) -> [TeamModel] {
        let descriptor = FetchDescriptor<TeamModel>(sortBy: [SortDescriptor(\.orderIndex)])
        return (try? context.fetch(descriptor)) ?? []
    }

    private func groupLetterOrder(from teams: [TeamModel]) -> [String] {
        var seen  = Set<String>()
        var order = [String]()
        // teams уже отсортированы по orderIndex → FWC первым, затем A, B, …
        for t in teams {
            if seen.insert(t.groupLetter).inserted {
                order.append(t.groupLetter)
            }
        }
        return order
    }
}
