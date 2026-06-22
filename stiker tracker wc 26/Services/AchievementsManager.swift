import Foundation
import SwiftData
import Observation
import UIKit

/// Проверяет триггеры достижений и управляет очередью баннеров.
/// Живёт как @State в корневом AlbumView — один на всё приложение.
@Observable
final class AchievementsManager {

    // Очередь разблокировок для показа баннеров (одно за раз)
    private(set) var pendingBanner: AchievementDefinition?
    private var bannerQueue: [AchievementDefinition] = []

    // Кэш уже разблокированных ID — чтобы не делать fetch на каждый тап
    private var unlockedIDs: Set<String> = []
    private var isLoaded = false

    // MARK: - Bootstrap

    func load(context: ModelContext) {
        guard !isLoaded else { return }
        let records = (try? context.fetch(FetchDescriptor<AchievementRecord>())) ?? []

        // Удаляем записи о достижениях, которые больше не выполнены
        // (защита от старых багов с неправильными ID)
        var toDelete: [AchievementRecord] = []
        for record in records {
            guard let def = AchievementDefinition.all.first(where: { $0.id == record.achievementID })
            else { toDelete.append(record); continue }

            switch def.trigger {
            case .stickerPasted(let id):
                let sticker = fetchSticker(id: id, context: context)
                if sticker == nil || sticker?.status == .missing {
                    toDelete.append(record)
                }
            case .allStarsPasted:
                let allPasted = AchievementDefinition.superstarStickerIDs.allSatisfy { id in
                    guard let s = fetchSticker(id: id, context: context) else { return false }
                    return s.status != .missing
                }
                if !allPasted { toDelete.append(record) }
            default:
                break
            }
        }

        if !toDelete.isEmpty {
            toDelete.forEach { context.delete($0) }
            try? context.save()
        }

        let remaining = (try? context.fetch(FetchDescriptor<AchievementRecord>())) ?? []
        unlockedIDs = Set(remaining.map(\.achievementID))
        isLoaded = true
    }

    // MARK: - Public check entry points

    /// Вызвать сразу после вклеивания наклейки.
    func checkAfterPaste(sticker: StickerModel, context: ModelContext) {
        load(context: context)

        // 1. Суперзвезда
        checkSuperstar(stickerID: sticker.id, context: context)

        // 2. Star Hunter (все 10 суперзвёзд)
        checkStarHunter(context: context)

        // 3. Команда завершена
        checkTeamCompleted(teamCode: sticker.teamCode, context: context)

        // 4. Все команды (World Ruler)
        checkAllTeams(context: context)

        // 5. totalPasted триггеры (first sticker, centurion)
        checkTotalPasted(context: context)

        // 6. Milestones (25 / 50 / 75 / 100 %)
        checkMilestones(context: context)
    }

    /// Вызвать после удаления наклейки (кэш unlockedIDs не трогаем — достижения не отнимаются).
    func checkAfterRemove(sticker: StickerModel, context: ModelContext) {
        load(context: context)
        // Milestones и centurion могут стать неактуальны визуально,
        // но согласно требованиям — достижения не отзываются. Ничего не делаем.
    }

    // MARK: - Banner queue

    func dismissBanner() {
        pendingBanner = nil
        // Небольшая пауза между баннерами
        if !bannerQueue.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.showNextBanner()
            }
        }
    }

    // MARK: - Private check logic

    private func checkSuperstar(stickerID: String, context: ModelContext) {
        for def in AchievementDefinition.all where def.category == .superstar {
            if case .stickerPasted(let id) = def.trigger, id == stickerID {
                unlock(def, context: context)
            }
        }
    }

    private func checkStarHunter(context: ModelContext) {
        let allPasted = AchievementDefinition.superstarStickerIDs.allSatisfy { id in
            guard let sticker = fetchSticker(id: id, context: context) else { return false }
            return sticker.status != .missing
        }
        if allPasted {
            unlock(AchievementDefinition.starHunter, context: context)
        }
    }

    private func checkTeamCompleted(teamCode: String, context: ModelContext) {
        let stickers = fetchTeamStickers(code: teamCode, context: context)
        guard !stickers.isEmpty else { return }
        let allDone = stickers.allSatisfy { $0.status != .missing }
        if allDone {
            let defID = "team_\(teamCode.lowercased())"
            if let def = AchievementDefinition.all.first(where: { $0.id == defID }) {
                unlock(def, context: context)
            }
        }
    }

    private func checkAllTeams(context: ModelContext) {
        let teams = (try? context.fetch(FetchDescriptor<TeamModel>())) ?? []
        let allComplete = teams.allSatisfy { team in
            let stickers = fetchTeamStickers(code: team.code, context: context)
            return !stickers.isEmpty && stickers.allSatisfy { $0.status != .missing }
        }
        if allComplete {
            unlock(AchievementDefinition.worldRuler, context: context)
        }
    }

    private func checkTotalPasted(context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<StickerModel>())) ?? []
        let count = all.filter { $0.status != .missing }.count
        for def in AchievementDefinition.all {
            if case .totalPasted(let threshold) = def.trigger, count >= threshold {
                unlock(def, context: context)
            }
        }
    }

    private func checkMilestones(context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<StickerModel>())) ?? []
        let pasted = all.filter { $0.status != .missing }.count
        let ratio  = Double(pasted) / Double(AlbumModel.totalStickers)

        for def in AchievementDefinition.all where def.category == .milestone {
            if case .albumPercent(let threshold) = def.trigger, ratio >= threshold {
                unlock(def, context: context)
            }
        }
    }

    // MARK: - Unlock

    private func unlock(_ def: AchievementDefinition, context: ModelContext) {
        guard !unlockedIDs.contains(def.id) else { return }
        unlockedIDs.insert(def.id)

        let record = AchievementRecord(achievementID: def.id)
        context.insert(record)
        try? context.save()

        playUnlockSound()
        enqueue(def)
    }

    private func enqueue(_ def: AchievementDefinition) {
        if pendingBanner == nil {
            showBanner(def)
        } else {
            bannerQueue.append(def)
        }
    }

    private func showNextBanner() {
        guard !bannerQueue.isEmpty else { return }
        showBanner(bannerQueue.removeFirst())
    }

    private func showBanner(_ def: AchievementDefinition) {
        pendingBanner = def
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        // Автоматически гасим через 3.5 с
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            guard self?.pendingBanner?.id == def.id else { return }
            self?.dismissBanner()
        }
    }

    private func playUnlockSound() {
        // TODO: воспроизвести звук разблокировки достижения
        //   guard let url = Bundle.main.url(forResource: "achievement_unlock", withExtension: "caf") else { return }
        //   var soundID: SystemSoundID = 0
        //   AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        //   AudioServicesPlaySystemSound(soundID)
    }

    // MARK: - Fetch helpers

    private func fetchSticker(id: String, context: ModelContext) -> StickerModel? {
        var descriptor = FetchDescriptor<StickerModel>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func fetchTeamStickers(code: String, context: ModelContext) -> [StickerModel] {
        let descriptor = FetchDescriptor<StickerModel>(
            predicate: #Predicate { $0.teamCode == code }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Query helpers for AchievementsView

    func isUnlocked(_ id: String) -> Bool { unlockedIDs.contains(id) }

    func unlockedDate(for id: String, context: ModelContext) -> Date? {
        var descriptor = FetchDescriptor<AchievementRecord>(
            predicate: #Predicate { $0.achievementID == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first?.unlockedAt
    }
}
