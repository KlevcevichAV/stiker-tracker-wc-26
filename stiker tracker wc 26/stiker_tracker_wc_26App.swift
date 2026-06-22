import SwiftUI
import SwiftData

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
            // Миграция не удалась — стираем старый стор и стартуем с чистого листа.
            // Данные пересидируются из CSV при следующем запуске.
            Self.deleteStore(config: config)
            do {
                container = try ModelContainer(for: schema, configurations: config)
            } catch {
                fatalError("SwiftData init failed after store reset: \(error)")
            }
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
        }
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

    private static func deleteStore(config: ModelConfiguration) {
        let url = config.url
        let fm = FileManager.default
        let base = url.deletingPathExtension()
        for ext in ["store", "store-shm", "store-wal"] {
            try? fm.removeItem(at: base.appendingPathExtension(ext))
        }
        try? fm.removeItem(at: url)
    }
}
