import Foundation
import SwiftData

struct BackupService {

    // MARK: - Export

    static func exportData(context: ModelContext) throws -> Data {
        let stickers = try context.fetch(FetchDescriptor<StickerModel>())
        let exchanges = try context.fetch(FetchDescriptor<ExchangeModel>())

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

        let backup = AlbumBackup(
            version: 1,
            exportedAt: Date(),
            stickers: stickerBackups,
            exchanges: exchangeBackups
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

        try context.save()
    }
}

// MARK: - Codable DTOs

private struct AlbumBackup: Codable {
    let version: Int
    let exportedAt: Date
    let stickers: [StickerBackup]
    let exchanges: [ExchangeBackup]
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
