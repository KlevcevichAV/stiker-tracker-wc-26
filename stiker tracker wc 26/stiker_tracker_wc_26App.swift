import SwiftUI
import SwiftData
import UIKit

@main
struct stiker_tracker_wc_26App: App {

    let container: ModelContainer

    init() {
        let schema = Schema([
            AlbumModel.self,
            TeamModel.self,
            StickerModel.self,
            AchievementRecord.self,
            ExchangeModel.self,
            PurchaseModel.self,
        ])

        // Конфигурация с разрешённой лёгкой миграцией
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("SwiftData init failed: \(error)")
        }

        // Сброс флага при смене источника данных (stickers_db.json)
        Self.resetSeedFlagIfNeeded(context: container.mainContext)

        // Seed при первом запуске
        do {
            try SeedDataService.seedIfNeeded(context: container.mainContext)
        } catch {
            print("SeedDataService error: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    autoBackup()
                }
        }
    }

    private func autoBackup() {
        guard let data = try? BackupService.exportData(context: container.mainContext) else { return }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("sticker_backup_auto.json")
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Helpers

    private static func resetSeedFlagIfNeeded(context: ModelContext) {
        let teamCount = (try? context.fetchCount(FetchDescriptor<TeamModel>())) ?? 0
        guard teamCount < 49 else {
            // Команд достаточно — проверяем нет ли старых стикеров с пробелом в ID (initial_data.json)
            var legacyDesc = FetchDescriptor<StickerModel>(
                predicate: #Predicate { $0.id.contains(" ") }
            )
            let legacyStickers = (try? context.fetch(legacyDesc)) ?? []
            if !legacyStickers.isEmpty {
                legacyStickers.forEach { context.delete($0) }
                try? context.save()
            }
            return
        }
        // Команд меньше 49 — сбрасываем флаг чтобы пересидировать
        let albums = (try? context.fetch(FetchDescriptor<AlbumModel>())) ?? []
        albums.forEach { $0.isSeeded = false }
        try? context.save()
    }
}
