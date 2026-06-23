import SwiftUI
import SwiftData

// MARK: - Exchange prefill wrapper

private struct ExchangePrefill: Identifiable {
    let id = UUID()
    let giving: [StickerEntry]
    let wanting: [StickerEntry]
}

// MARK: - Analysis mode

private enum AnalysisMode: Int, CaseIterable {
    case mutual = 0
    case theirDuplicates = 1
    case theirSearch = 2

    func title(isRu: Bool) -> String {
        switch self {
        case .mutual:          return isRu ? "Взаимный" : "Mutual"
        case .theirDuplicates: return isRu ? "Их повторки" : "Their Dupes"
        case .theirSearch:     return isRu ? "Их поиск" : "Their Search"
        }
    }
}

// MARK: - TradeAnalysisView

struct TradeAnalysisView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.appLanguage)  private var language

    @State private var inputText  = ""
    @State private var mode: AnalysisMode = .mutual
    @State private var result: TradeAnalysisResult? = nil
    @State private var isAnalyzing = false
    @State private var exchangePrefill: ExchangePrefill? = nil

    private var isRu: Bool { language.isRussian }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                inputSection
                analyzeButton
                if let result {
                    modePicker
                    resultSection(result)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(isRu ? "Анализ обменов" : "Trade Analysis")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $exchangePrefill) { prefill in
            NewExchangeView(prefillGiving: prefill.giving, prefillWanting: prefill.wanting)
                .environment(\.appLanguage, language)
        }
    }

    // MARK: - Input

    private var inputSection: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))

            if inputText.isEmpty {
                Text(isRu ? "Вставьте сообщение об обмене..." : "Paste a trade message here...")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $inputText)
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(.clear)
                .frame(minHeight: 130, maxHeight: 220)
                .padding(8)
        }
        .frame(minHeight: 130, maxHeight: 220)
    }

    // MARK: - Analyze button

    private var analyzeButton: some View {
        Button {
            analyze()
        } label: {
            HStack(spacing: 8) {
                if isAnalyzing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                }
                Text(isRu ? "Анализировать" : "Analyze")
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color(.systemGray4) : Color.blue,
                        in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
        }
        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    // MARK: - Mode picker

    private var modePicker: some View {
        Picker("", selection: $mode) {
            ForEach(AnalysisMode.allCases, id: \.self) { m in
                Text(m.title(isRu: isRu)).tag(m)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Result

    @ViewBuilder
    private func resultSection(_ r: TradeAnalysisResult) -> some View {
        switch mode {
        case .mutual:
            mutualResultView(r.mutual)
        case .theirDuplicates:
            simpleResultView(
                items: r.theirDupesWeNeed,
                title: isRu ? "Из их повторок нам нужны" : "From their dupes, we need",
                emptyText: isRu ? "Из их повторок ничего не нужно" : "Nothing needed from their dupes",
                accentColor: .green,
                wantingItems: r.theirDupesWeNeed
            )
        case .theirSearch:
            simpleResultView(
                items: r.theirSearchWeHave,
                title: isRu ? "Из их поиска у нас в дублях" : "From their search, we have in dupes",
                emptyText: isRu ? "Ничего подходящего в наших дублях" : "Nothing matching in our dupes",
                accentColor: .orange,
                givingItems: r.theirSearchWeHave
            )
        }
    }

    // MARK: - Mutual result view

    @ViewBuilder
    private func mutualResultView(_ m: TradeMatch.MutualResult) -> some View {
        let canGive = m.weHaveTheyNeed
        let canGet  = m.theyHaveWeNeed

        // Счётчики
        HStack(spacing: 12) {
            counterBadge(
                value: canGet.count,
                label: isRu ? "Нам дадут" : "They give us",
                color: .green
            )
            counterBadge(
                value: canGive.count,
                label: isRu ? "Мы дадим" : "We give them",
                color: .blue
            )
        }

        if canGet.isEmpty && canGive.isEmpty {
            emptyCard(text: isRu ? "Совпадений не найдено" : "No matches found")
        } else {
            if !canGet.isEmpty {
                stickerCard(
                    title: isRu ? "Нам нужно, у них есть (\(canGet.count))" : "We need, they have (\(canGet.count))",
                    items: canGet,
                    color: .green
                )
            }
            if !canGive.isEmpty {
                stickerCard(
                    title: isRu ? "Им нужно, у нас в дублях (\(canGive.count))" : "They need, we have in dupes (\(canGive.count))",
                    items: canGive,
                    color: .blue
                )
            }
            createExchangeButton(giving: canGive, wanting: canGet)
        }

        // Дополнительно
        if !m.weNeedButTheyDontHave.isEmpty {
            stickerCard(
                title: isRu ? "Нам нужно, но у них нет (\(m.weNeedButTheyDontHave.count))" : "We need, but they don't have (\(m.weNeedButTheyDontHave.count))",
                items: m.weNeedButTheyDontHave,
                color: .secondary
            )
        }
        if !m.weHaveButTheyDontNeed.isEmpty {
            stickerCard(
                title: isRu ? "Можем предложить, но им не нужно (\(m.weHaveButTheyDontNeed.count))" : "We can offer, but they don't need (\(m.weHaveButTheyDontNeed.count))",
                items: m.weHaveButTheyDontNeed,
                color: .secondary
            )
        }
    }

    // MARK: - Simple result view

    @ViewBuilder
    private func simpleResultView(items: [StickerEntry], title: String, emptyText: String, accentColor: Color, givingItems: [StickerEntry] = [], wantingItems: [StickerEntry] = []) -> some View {
        if items.isEmpty {
            emptyCard(text: emptyText)
        } else {
            stickerCard(title: "\(title) (\(items.count))", items: items, color: accentColor)
            if !givingItems.isEmpty || !wantingItems.isEmpty {
                createExchangeButton(giving: givingItems, wanting: wantingItems)
            }
        }
    }

    // MARK: - Components

    private func counterBadge(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12))
    }

    private func stickerCard(title: String, items: [StickerEntry], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color == .secondary ? .secondary : color)

            // Группируем по команде
            let grouped = Dictionary(grouping: items, by: \.teamCode)
                .sorted { $0.key < $1.key }

            FlowLayout(spacing: 6) {
                ForEach(grouped, id: \.key) { code, entries in
                    stickerChip(code: code, entries: entries, color: color)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14))
    }

    private func stickerChip(code: String, entries: [StickerEntry], color: Color) -> some View {
        let numbers = entries.map { e in
            e.count > 1 ? "\(e.number)×\(e.count)" : "\(e.number)"
        }.joined(separator: ",")
        let chipColor: Color = color == .secondary ? Color(.systemGray4) : color.opacity(0.15)

        return Text("\(code) \(numbers)")
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(color == .secondary ? .primary : color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(chipColor, in: RoundedRectangle(cornerRadius: 7))
    }

    private func createExchangeButton(giving: [StickerEntry], wanting: [StickerEntry]) -> some View {
        Button {
            exchangePrefill = ExchangePrefill(giving: giving, wanting: wanting)
        } label: {
            Label(isRu ? "Создать обмен" : "Create exchange",
                  systemImage: "arrow.2.squarepath")
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.teal.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.teal)
        }
        .buttonStyle(.plain)
    }

    private func emptyCard(text: String) -> some View {
        HStack {
            Image(systemName: "tray")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Analyze logic

    private func analyze() {
        isAnalyzing = true
        let text = inputText

        // Загружаем все наши стикеры
        let allStickers = (try? context.fetch(FetchDescriptor<StickerModel>())) ?? []
        let ourMap = Dictionary(uniqueKeysWithValues: allStickers.map { ($0.id, $0) })

        // Парсим сообщение
        let parsed = TradeMessageParser.parse(text)

        // Сопоставляем
        result = TradeAnalysisMatcher.match(parsed: parsed, ourStickers: ourMap)
        isAnalyzing = false
    }
}

// MARK: - FlowLayout (wrapping HStack)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Result model

struct TradeAnalysisResult {
    var mutual = TradeMatch.MutualResult()
    var theirDupesWeNeed: [StickerEntry] = []
    var theirSearchWeHave: [StickerEntry] = []
}

// MARK: - Matcher

enum TradeAnalysisMatcher {

    static func match(parsed: ParsedTradeMessage, ourStickers: [String: StickerModel]) -> TradeAnalysisResult {
        var result = TradeAnalysisResult()

        // Режим 2: их повторки → что нам нужно
        let haveEntries = parsed.have
        result.theirDupesWeNeed = haveEntries.filter { entry in
            let key = "\(entry.teamCode)\(entry.number)"
            return ourStickers[key]?.status == .missing
        }

        // Режим 3: их поиск → что у нас в дублях
        let needEntries = parsed.need
        result.theirSearchWeHave = needEntries.filter { entry in
            let key = "\(entry.teamCode)\(entry.number)"
            return ourStickers[key]?.status == .duplicate
        }

        // Режим 1: взаимный
        // Что нам нужно и у них есть
        let theyHaveWeNeed = haveEntries.filter { entry in
            let key = "\(entry.teamCode)\(entry.number)"
            return ourStickers[key]?.status == .missing
        }
        // Что им нужно и у нас в дублях
        let weHaveTheyNeed = needEntries.filter { entry in
            let key = "\(entry.teamCode)\(entry.number)"
            return ourStickers[key]?.status == .duplicate
        }

        // Ключи для быстрых проверок
        let theyHaveWeNeedKeys = Set(theyHaveWeNeed.map { "\($0.teamCode)\($0.number)" })
        let weHaveTheyNeedKeys = Set(weHaveTheyNeed.map { "\($0.teamCode)\($0.number)" })

        // Нам нужно, но у них нет (нет в have, но наши стикеры missing)
        let ourMissingKeys = Set(ourStickers.values.filter { $0.status == .missing }.map { $0.id })
        let needKeysFromThem = Set(haveEntries.map { "\($0.teamCode)\($0.number)" })
        let weNeedButTheyDontHave = ourMissingKeys.subtracting(needKeysFromThem)

        // Наши дубли, которые им не нужны
        let ourDupeKeys = Set(ourStickers.values.filter { $0.status == .duplicate }.map { $0.id })
        let weHaveButTheyDontNeed = ourDupeKeys.subtracting(weHaveTheyNeedKeys)

        result.mutual = TradeMatch.MutualResult(
            theyHaveWeNeed: theyHaveWeNeed,
            weHaveTheyNeed: weHaveTheyNeed,
            weNeedButTheyDontHave: weNeedButTheyDontHave.sorted().compactMap { id in
                guard let s = ourStickers[id] else { return nil }
                return StickerEntry(teamCode: s.teamCode, number: s.number, count: 1)
            },
            weHaveButTheyDontNeed: weHaveButTheyDontNeed.sorted().compactMap { id in
                guard let s = ourStickers[id] else { return nil }
                return StickerEntry(teamCode: s.teamCode, number: s.number, count: s.duplicateCount)
            }
        )

        return result
    }
}
