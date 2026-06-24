import SwiftData
import UIKit

enum ExchangeService {

    // MARK: - Create

    static func create(giving: [StickerEntry],
                       wanting: [StickerEntry],
                       partner: String = "",
                       meetingDate: Date = Date(),
                       archived: Bool = false,
                       context: ModelContext) {
        let exchange = ExchangeModel(giving: giving, wanting: wanting, partner: partner, meetingDate: meetingDate)
        if archived { exchange.status = .completed }
        context.insert(exchange)
        try? context.save()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Complete

    static func complete(_ exchange: ExchangeModel,
                         context: ModelContext,
                         achievements: AchievementsManager) {
        // Уменьшить/удалить повторки для отдаваемых карточек
        for entry in exchange.giving {
            let stickerId = "\(entry.teamCode)\(entry.number)"
            let desc = FetchDescriptor<StickerModel>(
                predicate: #Predicate { $0.id == stickerId }
            )
            guard let sticker = (try? context.fetch(desc))?.first else { continue }
            for _ in 0..<entry.count {
                StickerInteractionService.removeDuplicate(sticker, context: context, achievements: achievements)
            }
        }

        // Вклеить полученные карточки
        for entry in exchange.wanting {
            let stickerId = "\(entry.teamCode)\(entry.number)"
            let desc = FetchDescriptor<StickerModel>(
                predicate: #Predicate { $0.id == stickerId }
            )
            guard let sticker = (try? context.fetch(desc))?.first else { continue }
            switch sticker.status {
            case .missing:
                StickerInteractionService.paste(sticker, context: context, achievements: achievements)
            case .pasted, .duplicate:
                StickerInteractionService.addDuplicate(sticker, context: context, achievements: achievements)
            }
        }

        exchange.status = .completed
        try? context.save()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Cancel

    static func cancel(_ exchange: ExchangeModel, context: ModelContext) {
        exchange.status = .cancelled
        try? context.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Query helpers

    /// Сколько штук данного стикера зарезервировано в активных обменах (в колонке "отдаю")
    static func reservedCount(for stickerId: String, in exchanges: [ExchangeModel]) -> Int {
        exchanges
            .filter { $0.status == .active }
            .flatMap { $0.giving }
            .filter { "\($0.teamCode)\($0.number)" == stickerId }
            .reduce(0) { $0 + $1.count }
    }

    /// Ожидается ли получение данного стикера в активных обменах (колонка "получаю")
    static func incomingCount(for stickerId: String, in exchanges: [ExchangeModel]) -> Int {
        exchanges
            .filter { $0.status == .active }
            .flatMap { $0.wanting }
            .filter { "\($0.teamCode)\($0.number)" == stickerId }
            .reduce(0) { $0 + $1.count }
    }
}
