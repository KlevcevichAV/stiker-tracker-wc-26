import Foundation
import SwiftData

struct BackupService {

    // MARK: - Export

    static func exportData(context: ModelContext) throws -> Data {
        let stickers    = try context.fetch(FetchDescriptor<StickerModel>())
        let exchanges   = try context.fetch(FetchDescriptor<ExchangeModel>())
        let purchases   = try context.fetch(FetchDescriptor<PurchaseModel>())
        let sales       = try context.fetch(FetchDescriptor<SaleModel>())
        let achievements = try context.fetch(FetchDescriptor<AchievementRecord>())

        let stickerBackups = stickers
            .filter { $0.statusRaw != StickerStatus.missing.rawValue || $0.duplicateCount > 0 }
            .map { StickerBackup(id: $0.id, statusRaw: $0.statusRaw, duplicateCount: $0.duplicateCount) }

        let exchangeBackups = exchanges.map { ex in
            ExchangeBackup(
                id: ex.id,
                createdAt: ex.createdAt,
                givingRaw: ex.givingRaw,
                wantingRaw: ex.wantingRaw,
                statusRaw: ex.statusRaw,
                partner: ex.partner
            )
        }

        let purchaseBackups = purchases.map { p in
            PurchaseBackup(id: p.id, kindRaw: p.kindRaw, quantity: p.quantity, price: p.price, date: p.date)
        }

        let saleBackups = sales.map { s in
            SaleBackup(id: s.id, price: s.price, date: s.date, comment: s.comment)
        }

        let achievementBackups = achievements.map { a in
            AchievementBackup(achievementID: a.achievementID, unlockedAt: a.unlockedAt)
        }

        let backup = AlbumBackup(
            version: 2,
            exportedAt: Date(),
            stickers: stickerBackups,
            exchanges: exchangeBackups,
            purchases: purchaseBackups,
            sales: saleBackups,
            achievements: achievementBackups
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    // MARK: - Import

    static func importData(_ data: Data, context: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(AlbumBackup.self, from: data)

        // Restore sticker statuses
        let allStickers = try context.fetch(FetchDescriptor<StickerModel>())
        let stickerIndex = Dictionary(uniqueKeysWithValues: allStickers.map { ($0.id, $0) })

        for b in backup.stickers {
            guard let sticker = stickerIndex[b.id] else { continue }
            sticker.statusRaw = b.statusRaw
            sticker.duplicateCount = b.duplicateCount
        }

        // Restore exchanges — delete all current, re-insert from backup
        let existing = try context.fetch(FetchDescriptor<ExchangeModel>())
        existing.forEach { context.delete($0) }

        for b in backup.exchanges {
            let ex = ExchangeModel.__restore(
                id: b.id,
                createdAt: b.createdAt,
                givingRaw: b.givingRaw,
                wantingRaw: b.wantingRaw,
                statusRaw: b.statusRaw,
                partner: b.partner
            )
            context.insert(ex)
        }

        // Restore purchases
        let existingPurchases = try context.fetch(FetchDescriptor<PurchaseModel>())
        existingPurchases.forEach { context.delete($0) }

        for b in backup.purchases ?? [] {
            let p = PurchaseModel(kind: PurchaseKind(rawValue: b.kindRaw) ?? .pack,
                                  quantity: b.quantity,
                                  price: b.price,
                                  date: b.date)
            context.insert(p)
        }

        // Restore sales
        let existingSales = try context.fetch(FetchDescriptor<SaleModel>())
        existingSales.forEach { context.delete($0) }

        for b in backup.sales ?? [] {
            let s = SaleModel(price: b.price, date: b.date, comment: b.comment)
            context.insert(s)
        }

        // Restore achievements
        let existingAchievements = try context.fetch(FetchDescriptor<AchievementRecord>())
        existingAchievements.forEach { context.delete($0) }

        for b in backup.achievements ?? [] {
            let a = AchievementRecord(achievementID: b.achievementID)
            a.unlockedAt = b.unlockedAt
            context.insert(a)
        }

        try context.save()
    }
}

// MARK: - Codable DTOs

private struct AlbumBackup: Codable {
    let version: Int
    let exportedAt: Date
    let stickers: [StickerBackup]
    let exchanges: [ExchangeBackup]
    let purchases: [PurchaseBackup]?
    let sales: [SaleBackup]?
    let achievements: [AchievementBackup]?
}

private struct StickerBackup: Codable {
    let id: String
    let statusRaw: String
    let duplicateCount: Int
}

private struct ExchangeBackup: Codable {
    let id: String
    let createdAt: Date
    let givingRaw: String
    let wantingRaw: String
    let statusRaw: String
    let partner: String
}

private struct PurchaseBackup: Codable {
    let id: String
    let kindRaw: String
    let quantity: Int
    let price: Double
    let date: Date
}

private struct SaleBackup: Codable {
    let id: String
    let price: Double
    let date: Date
    let comment: String
}

private struct AchievementBackup: Codable {
    let achievementID: String
    let unlockedAt: Date
}
