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

    @AppStorage("openModelAPIKey") private var openModelAPIKey: String = ""

    @State private var inputText  = ""
    @State private var mode: AnalysisMode = .mutual
    @State private var result: TradeAnalysisResult? = nil
    @State private var isAnalyzing = false
    @State private var isAIAnalyzing = false
    @State private var aiError: String? = nil
    @State private var exchangePrefill: ExchangePrefill? = nil
    @FocusState private var inputFocused: Bool

    private var isRu: Bool { language.isRussian }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                inputSection
                analyzeButtons
                if let aiError {
                    Text(aiError)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
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
                .focused($inputFocused)
        }
        .frame(minHeight: 130, maxHeight: 220)
    }

    // MARK: - Analyze buttons

    private var analyzeButtons: some View {
        let isEmpty = inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let busy = isAnalyzing || isAIAnalyzing
        let hasKey = !openModelAPIKey.isEmpty
        return VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    analyze()
                } label: {
                    HStack(spacing: 6) {
                        if isAnalyzing {
                            ProgressView().scaleEffect(0.8).tint(.white)
                        } else {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 14))
                        }
                        Text(isRu ? "Анализировать" : "Analyze")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isEmpty || busy ? Color(.systemGray4) : Color.blue,
                                in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                }
                .disabled(isEmpty || busy)

                Button {
                    analyzeWithAI()
                } label: {
                    HStack(spacing: 6) {
                        if isAIAnalyzing {
                            ProgressView().scaleEffect(0.8).tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14))
                        }
                        Text(isRu ? "Анализ ИИ" : "AI Analyze")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isEmpty || busy || !hasKey ? Color(.systemGray4) : Color.purple,
                                in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                }
                .disabled(isEmpty || busy || !hasKey)
            }

            if !hasKey {
                HStack(spacing: 6) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 12))
                    Text(isRu
                         ? "Добавьте API ключ в Настройках, чтобы использовать ИИ-анализ"
                         : "Add an API key in Settings to enable AI analysis")
                        .font(.system(size: 12))
                }
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }
        }
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
            mutualResultView(r.mutual, result: r)
        case .theirDuplicates:
            simpleResultView(
                items: r.theirDupesWeNeed,
                title: isRu ? "Из их повторок нам нужны" : "From their dupes, we need",
                emptyText: isRu ? "Из их повторок ничего не нужно" : "Nothing needed from their dupes",
                accentColor: .green,
                wantingItems: r.theirDupesWeNeed,
                incoming: r.alreadyIncoming
            )
        case .theirSearch:
            simpleResultView(
                items: r.theirSearchWeHave,
                title: isRu ? "Из их поиска у нас в дублях" : "From their search, we have in dupes",
                emptyText: isRu ? "Ничего подходящего в наших дублях" : "Nothing matching in our dupes",
                accentColor: .orange,
                givingItems: r.theirSearchWeHave,
                reserved: r.alreadyReserved,
                lastCopy: r.lastCopyWarning
            )
        }
    }

    // MARK: - Mutual result view

    @ViewBuilder
    private func mutualResultView(_ m: TradeMatch.MutualResult, result: TradeAnalysisResult) -> some View {
        let canGive = m.weHaveTheyNeed
        let canGet  = m.theyHaveWeNeed

        // Счётчики
        HStack(spacing: 12) {
            counterBadge(
                value: canGet.count,
                label: isRu ? "Нам дадут" : "They give us",
                color: .green,
                items: canGet
            )
            counterBadge(
                value: canGive.count,
                label: isRu ? "Мы дадим" : "We give them",
                color: .blue,
                items: canGive
            )
        }

        if canGet.isEmpty && canGive.isEmpty {
            emptyCard(text: isRu ? "Совпадений не найдено" : "No matches found")
        } else {
            if !canGet.isEmpty {
                stickerCard(
                    title: isRu ? "Нам нужно, у них есть (\(canGet.count))" : "We need, they have (\(canGet.count))",
                    items: canGet,
                    color: .green,
                    incoming: result.alreadyIncoming
                )
            }
            if !canGive.isEmpty {
                stickerCard(
                    title: isRu ? "Им нужно, у нас в дублях (\(canGive.count))" : "They need, we have in dupes (\(canGive.count))",
                    items: canGive,
                    color: .blue,
                    reserved: result.alreadyReserved,
                    lastCopy: result.lastCopyWarning
                )
            }
            exchangeButtons(giving: canGive, wanting: canGet,
                            reserved: result.alreadyReserved, incoming: result.alreadyIncoming)
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
    private func simpleResultView(items: [StickerEntry], title: String, emptyText: String, accentColor: Color,
                                   givingItems: [StickerEntry] = [], wantingItems: [StickerEntry] = [],
                                   reserved: Set<String> = [], incoming: Set<String> = [],
                                   lastCopy: Set<String> = []) -> some View {
        if items.isEmpty {
            emptyCard(text: emptyText)
        } else {
            stickerCard(title: "\(title) (\(items.count))", items: items, color: accentColor,
                        reserved: reserved, incoming: incoming, lastCopy: lastCopy)
            if !givingItems.isEmpty || !wantingItems.isEmpty {
                exchangeButtons(giving: givingItems, wanting: wantingItems,
                                reserved: reserved, incoming: incoming)
            }
        }
    }

    // MARK: - Components

    private func counterBadge(value: Int, label: String, color: Color, items: [StickerEntry] = []) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if !items.isEmpty {
                Button {
                    UIPasteboard.general.string = items
                        .map { e in e.count > 1 ? "\(e.teamCode) \(e.number)×\(e.count)" : "\(e.teamCode) \(e.number)" }
                        .joined(separator: ", ")
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundStyle(color.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12))
    }

    private func stickerCard(title: String, items: [StickerEntry], color: Color,
                              reserved: Set<String> = [], incoming: Set<String> = [],
                              lastCopy: Set<String> = []) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color == .secondary ? .secondary : color)

            // Группируем по команде
            let grouped = Dictionary(grouping: items, by: \.teamCode)
                .sorted { $0.key < $1.key }

            FlowLayout(spacing: 6) {
                ForEach(grouped, id: \.key) { code, entries in
                    ForEach(entries, id: \.id) { (entry: StickerEntry) in
                        stickerChip(
                            entry: entry,
                            color: color,
                            exchangeLabel: chipLabel(for: entry, incoming: incoming, lastCopy: lastCopy, reserved: reserved, isRu: isRu),
                            labelColor: chipLabelColor(for: entry, incoming: incoming, lastCopy: lastCopy, color: color)
                        )
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14))
    }

    private func chipLabel(for entry: StickerEntry, incoming: Set<String>, lastCopy: Set<String>, reserved: Set<String>, isRu: Bool) -> String? {
        let key = "\(entry.teamCode)\(entry.number)"
        if incoming.contains(key) { return isRu ? "получим" : "incoming" }
        if lastCopy.contains(key)  { return isRu ? "последняя" : "last copy" }
        if reserved.contains(key)  { return isRu ? "отдаём" : "reserved" }
        return nil
    }

    private func chipLabelColor(for entry: StickerEntry, incoming: Set<String>, lastCopy: Set<String>, color: Color) -> Color {
        let key = "\(entry.teamCode)\(entry.number)"
        if lastCopy.contains(key) { return .orange }
        return color == .secondary ? .primary : color
    }

    private func stickerChip(entry: StickerEntry, color: Color, exchangeLabel: String?, labelColor: Color? = nil) -> some View {
        let numberText = entry.count > 1 ? "\(entry.number)×\(entry.count)" : "\(entry.number)"
        let chipColor: Color = color == .secondary ? Color(.systemGray4) : color.opacity(0.15)
        let fgColor: Color = color == .secondary ? .primary : color
        let effectiveLabelColor = labelColor ?? fgColor
        let borderColor: Color = exchangeLabel != nil
            ? (labelColor == .orange ? .orange : (color == .secondary ? Color.primary : color))
            : .clear

        return VStack(spacing: 2) {
            Text("\(entry.teamCode) \(numberText)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(fgColor)
                .padding(.horizontal, 8)
                .padding(.vertical, exchangeLabel == nil ? 4 : 3)

            if let label = exchangeLabel {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(effectiveLabelColor)
                    .padding(.bottom, 3)
            }
        }
        .background(chipColor, in: RoundedRectangle(cornerRadius: 7))
        .overlay(
            exchangeLabel != nil
                ? RoundedRectangle(cornerRadius: 7).stroke(borderColor, lineWidth: 1.5)
                : nil
        )
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

    @ViewBuilder
    private func exchangeButtons(giving: [StickerEntry], wanting: [StickerEntry],
                                  reserved: Set<String>, incoming: Set<String>) -> some View {
        let cleanGiving  = giving.filter  { !reserved.contains("\($0.teamCode)\($0.number)") }
        let cleanWanting = wanting.filter { !incoming.contains("\($0.teamCode)\($0.number)") }
        let hasConflict  = cleanGiving.count < giving.count || cleanWanting.count < wanting.count

        createExchangeButton(giving: giving, wanting: wanting)

        if hasConflict && (!cleanGiving.isEmpty || !cleanWanting.isEmpty) {
            Button {
                exchangePrefill = ExchangePrefill(giving: cleanGiving, wanting: cleanWanting)
            } label: {
                Label(isRu ? "Создать без повторов" : "Create without duplicates",
                      systemImage: "arrow.2.squarepath.badge.minus")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
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
        inputFocused = false
        isAnalyzing = true
        let text = inputText

        // Загружаем все наши стикеры
        let allStickers = (try? context.fetch(FetchDescriptor<StickerModel>())) ?? []
        let ourMap = Dictionary(uniqueKeysWithValues: allStickers.map { ($0.id, $0) })

        // Загружаем активные обмены
        let activeExchanges = (try? context.fetch(
            FetchDescriptor<ExchangeModel>(predicate: #Predicate { $0.statusRaw == "active" })
        )) ?? []

        // Парсим сообщение
        let parsed = TradeMessageParser.parse(text)

        // Сопоставляем
        result = TradeAnalysisMatcher.match(parsed: parsed, ourStickers: ourMap, activeExchanges: activeExchanges)
        isAnalyzing = false
    }

    // MARK: - AI Analyze logic

    private func analyzeWithAI() {
        inputFocused = false
        isAIAnalyzing = true
        aiError = nil
        let text = inputText

        let allStickers = (try? context.fetch(FetchDescriptor<StickerModel>())) ?? []
        let ourMap = Dictionary(uniqueKeysWithValues: allStickers.map { ($0.id, $0) })
        let activeExchanges = (try? context.fetch(
            FetchDescriptor<ExchangeModel>(predicate: #Predicate { $0.statusRaw == "active" })
        )) ?? []

        Task {
            do {
                let parsed = try await AITradeParser.parse(text: text)
                await MainActor.run {
                    result = TradeAnalysisMatcher.match(parsed: parsed, ourStickers: ourMap, activeExchanges: activeExchanges)
                    isAIAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    aiError = error.localizedDescription
                    isAIAnalyzing = false
                }
            }
        }
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
    var alreadyReserved: Set<String> = []   // giving в активных обменах
    var alreadyIncoming: Set<String> = []   // wanting в активных обменах
    var lastCopyWarning: Set<String> = []   // отдаём последний экземпляр (duplicateCount - зарезервировано <= 1)
}

// MARK: - Matcher

enum TradeAnalysisMatcher {

    static func match(parsed: ParsedTradeMessage, ourStickers: [String: StickerModel], activeExchanges: [ExchangeModel] = []) -> TradeAnalysisResult {
        var result = TradeAnalysisResult()

        // Стикеры, которые уже ожидаем получить в активных обменах
        let alreadyIncoming = Set(
            activeExchanges
                .filter { $0.status == .active }
                .flatMap { $0.wanting }
                .map { "\($0.teamCode)\($0.number)" }
        )

        // Стикеры, уже зарезервированные для отдачи в активных обменах
        let alreadyReserved = Set(
            activeExchanges
                .filter { $0.status == .active }
                .flatMap { $0.giving }
                .map { "\($0.teamCode)\($0.number)" }
        )

        // Сколько экземпляров каждого стикера уже зарезервировано
        var reservedCount: [String: Int] = [:]
        for ex in activeExchanges where ex.status == .active {
            for entry in ex.giving {
                let key = "\(entry.teamCode)\(entry.number)"
                reservedCount[key, default: 0] += entry.count
            }
        }

        // Предупреждение: если после ещё одной отдачи останется 0 экземпляров
        let lastCopyWarning = Set(
            reservedCount.compactMap { key, reserved -> String? in
                guard let sticker = ourStickers[key] else { return nil }
                return sticker.duplicateCount - reserved <= 0 ? key : nil
            }
        )

        // Режим 2: их повторки → что нам нужно
        let haveEntries = parsed.have
        result.theirDupesWeNeed = haveEntries.filter { entry in
            let key = "\(entry.teamCode)\(entry.number)"
            return ourStickers[key]?.status == .missing || alreadyIncoming.contains(key)
        }

        // Режим 3: их поиск → что у нас в дублях
        let needEntries = parsed.need
        result.theirSearchWeHave = needEntries.filter { entry in
            let key = "\(entry.teamCode)\(entry.number)"
            return ourStickers[key]?.status == .duplicate || alreadyReserved.contains(key)
        }

        // Режим 1: взаимный
        // Что нам нужно и у них есть (включая уже ожидаемые — они подсветятся)
        let theyHaveWeNeed = haveEntries.filter { entry in
            let key = "\(entry.teamCode)\(entry.number)"
            return ourStickers[key]?.status == .missing || alreadyIncoming.contains(key)
        }
        // Что им нужно и у нас в дублях (включая уже зарезервированные)
        let weHaveTheyNeed = needEntries.filter { entry in
            let key = "\(entry.teamCode)\(entry.number)"
            return ourStickers[key]?.status == .duplicate || alreadyReserved.contains(key)
        }

        // Ключи для быстрых проверок
        let weHaveTheyNeedKeys = Set(weHaveTheyNeed.map { "\($0.teamCode)\($0.number)" })

        // Нам нужно, но у них нет — исключаем и уже ожидаемые, и те, что у них есть
        let ourMissingKeys = Set(ourStickers.values.filter { $0.status == .missing }.map { $0.id })
            .subtracting(alreadyIncoming)
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

        result.alreadyIncoming = alreadyIncoming
        result.alreadyReserved = alreadyReserved
        result.lastCopyWarning = lastCopyWarning

        return result
    }
}
