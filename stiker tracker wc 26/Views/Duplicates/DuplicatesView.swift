import SwiftUI
import SwiftData

struct DuplicatesView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.achievementsManager) private var achievements
    @Environment(\.appLanguage) private var language

    @State private var duplicates: [StickerModel] = []
    @State private var teams: [TeamModel] = []
    @State private var activeExchanges: [ExchangeModel] = []
    @State private var sortByAlpha = false

    private var isRu: Bool { language.isRussian }

    /// Доступное кол-во повторок с учётом зарезервированных в обменах
    private func availableCount(_ sticker: StickerModel) -> Int {
        let reserved = ExchangeService.reservedCount(for: sticker.id, in: activeExchanges)
        return max(0, sticker.duplicateCount - reserved)
    }

    private var totalDuplicates: Int {
        duplicates.reduce(0) { $0 + availableCount($1) }
    }

    /// Только наклейки у которых есть хотя бы 1 доступная повторка
    private var visibleDuplicates: [StickerModel] {
        duplicates.filter { availableCount($0) > 0 }
    }

    private var grouped: [(teamCode: String, stickers: [StickerModel])] {
        var byCode: [String: [StickerModel]] = [:]
        for s in visibleDuplicates {
            byCode[s.teamCode, default: []].append(s)
        }
        let codes: [String]
        if sortByAlpha {
            codes = byCode.keys.sorted()
        } else {
            let orderMap = Dictionary(uniqueKeysWithValues: teams.map { ($0.code, $0.orderIndex) })
            codes = byCode.keys.sorted { (orderMap[$0] ?? 999) < (orderMap[$1] ?? 999) }
        }
        return codes.map { (teamCode: $0, stickers: byCode[$0]!) }
    }

    /// Группы по groupLetter: [(letter, [(teamCode, stickers)])]
    private var groupedBySection: [(letter: String, teams: [(teamCode: String, stickers: [StickerModel])])] {
        let teamMap = Dictionary(uniqueKeysWithValues: teams.map { ($0.code, $0) })
        var byLetter: [String: [(teamCode: String, stickers: [StickerModel])]] = [:]
        for item in grouped {
            let letter = teamMap[item.teamCode]?.groupLetter ?? "?"
            byLetter[letter, default: []].append(item)
        }
        // Сортируем секции по порядку букв
        let sortedLetters = byLetter.keys.sorted()
        return sortedLetters.map { (letter: $0, teams: byLetter[$0]!) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if visibleDuplicates.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle(isRu ? "Дубликаты" : "Duplicates")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Picker("", selection: $sortByAlpha) {
                        Image(systemName: "textformat.abc").tag(true)
                        Image(systemName: "list.number").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 80)
                }
            }
        }
        .onAppear { load() }
    }

    // MARK: - List

    private var list: some View {
        List {
            Section {
                HStack {
                    Text(isRu ? "Всего дубликатов" : "Total duplicates")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(totalDuplicates)")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.orange)
                }
                .padding(.vertical, 4)
            }

            ForEach(groupedBySection, id: \.letter) { section in
                Section {
                    ForEach(section.teams, id: \.teamCode) { group in
                        // Строка команды — заголовок + стикеры внутри
                        DisclosureGroup {
                            ForEach(group.stickers, id: \.id) { sticker in
                                duplicateRow(sticker)
                            }
                        } label: {
                            teamHeader(group.teamCode, stickers: group.stickers)
                        }
                    }
                } header: {
                    Text(isRu ? "Группа \(section.letter)" : "Group \(section.letter)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.orange)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Team header

    private func teamHeader(_ code: String, stickers: [StickerModel]) -> some View {
        let team = teams.first { $0.code == code }
        let flag = team?.flagEmoji ?? ""
        let name = (isRu ? team?.nameRU : team?.nameEN) ?? code
        let total = stickers.reduce(0) { $0 + availableCount($1) }

        return HStack {
            Text("\(flag) \(name)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .textCase(nil)
            Spacer()
            Text("×\(total)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.orange)
                .textCase(nil)
        }
    }

    // MARK: - Duplicate row

    private func duplicateRow(_ sticker: StickerModel) -> some View {
        let available = availableCount(sticker)
        let reserved  = sticker.duplicateCount - available

        return HStack(spacing: 12) {
            // Бейдж с количеством
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 44, height: 36)
                VStack(spacing: 0) {
                    Text("×\(available)")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.orange)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(isRu ? sticker.nameRU : sticker.nameEN)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(sticker.id)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if reserved > 0 {
                        Label(isRu ? "в обмене: \(reserved)" : "in exchange: \(reserved)",
                              systemImage: "arrow.2.squarepath")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.teal)
                    }
                }
            }

            Spacer()

            // Кнопка убрать один дубликат
            Button {
                StickerInteractionService.removeDuplicate(sticker, context: context, achievements: achievements)
                load()
            } label: {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.red.opacity(0.7))
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(isRu ? "Дубликатов нет" : "No duplicates")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(isRu
                 ? "Когда вклеишь повторные наклейки,\nони появятся здесь."
                 : "When you add duplicate stickers,\nthey'll appear here.")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Load

    private func load() {
        let desc = FetchDescriptor<StickerModel>(
            predicate: #Predicate { $0.statusRaw == "duplicate" },
            sortBy: [SortDescriptor(\.teamCode), SortDescriptor(\.number)]
        )
        duplicates = (try? context.fetch(desc)) ?? []
        teams = (try? context.fetch(FetchDescriptor<TeamModel>())) ?? []

        let exchDesc = FetchDescriptor<ExchangeModel>(
            predicate: #Predicate { $0.statusRaw == "active" }
        )
        activeExchanges = (try? context.fetch(exchDesc)) ?? []
    }
}
