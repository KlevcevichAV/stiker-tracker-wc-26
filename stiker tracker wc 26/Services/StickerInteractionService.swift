import UIKit
import SwiftData

/// Выполняет все мутации наклейки, сохраняет контекст и запускает проверку достижений.
struct StickerInteractionService {

    // MARK: - Actions

    static func paste(_ sticker: StickerModel,
                      context: ModelContext,
                      achievements: AchievementsManager) {
        sticker.status = .pasted
        sticker.duplicateCount = 0
        saveAndHaptic(context: context, style: .medium)
        playStickerSound()
        achievements.checkAfterPaste(sticker: sticker, context: context)
    }

    static func remove(_ sticker: StickerModel,
                       context: ModelContext,
                       achievements: AchievementsManager) {
        sticker.status = .missing
        sticker.duplicateCount = 0
        saveAndHaptic(context: context, style: .light)
        achievements.checkAfterRemove(sticker: sticker, context: context)
    }

    static func addDuplicate(_ sticker: StickerModel,
                             context: ModelContext,
                             achievements: AchievementsManager) {
        sticker.duplicateCount += 1
        sticker.status = .duplicate
        saveAndHaptic(context: context, style: .rigid)
        achievements.checkAfterPaste(sticker: sticker, context: context)
    }

    static func removeDuplicate(_ sticker: StickerModel,
                                context: ModelContext,
                                achievements: AchievementsManager) {
        if sticker.duplicateCount > 1 {
            sticker.duplicateCount -= 1
        } else {
            // Последний дубликат — откатываем в pasted
            sticker.duplicateCount = 0
            sticker.status = .pasted
        }
        saveAndHaptic(context: context, style: .light)
    }

    // MARK: - Private

    private static func saveAndHaptic(context: ModelContext,
                                      style: UIImpactFeedbackGenerator.FeedbackStyle) {
        try? context.save()
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private static func playStickerSound() {
        // TODO: воспроизвести звук шуршания бумаги
        //   guard let url = Bundle.main.url(forResource: "sticker_rustle", withExtension: "caf") else { return }
        //   var soundID: SystemSoundID = 0
        //   AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        //   AudioServicesPlaySystemSound(soundID)
    }
}
