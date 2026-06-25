import SwiftUI
import SwiftData

struct ExchangeView: View {

    @Environment(\.modelContext)     private var context
    @Environment(\.achievementsManager) private var achievements
    @Environment(\.appLanguage)     private var language

    @Query(sort: \ExchangeModel.createdAt, order: .reverse)
    private var exchanges: [ExchangeModel]

    @Query
    private var allStickers: [StickerModel]

    @State private var showNewExchange  = false
    @State private var showHistory      = false
    @State private var editingExchange: ExchangeModel? = nil
    @State private var expandedActiveIDs: Set<String> = []
    @State private var expandedPastIDs: Set<String> = []
    @State private var showPartnerStats = false
    @State private var restoringExchange: ExchangeModel? = nil
    @State private var copiedExchangeID: String? = nil

    private var isRu: Bool { language.isRussian }

    private var activeExchanges: [ExchangeModel] {
        exchanges.filter { $0.status == .active }
    }

    private var pastExchanges: [ExchangeModel] {
        exchanges.filter { $0.status != .active }
    }

    private var stickerIndex: [String: StickerModel] {
        Dictionary(uniqueKeysWithValues: allStickers.map { ($0.id, $0) })
    }

    var body: some View {
        NavigationStack {
            Group {
                if exchanges.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle(isRu ? "Обмен" : "Exchange")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 4) {
                        if exchanges.contains(where: { !$0.partner.isEmpty }) {
                            Button {
                                showPartnerStats = true
                            } label: {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 14))
                            }
                        }
                        Button {
                            showNewExchange = true
                        } label: {
                            Image(systemName: "plus")
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .sheet(isPresented: $showPartnerStats) {
                PartnerStatsView(exchanges: exchanges)
                    .environment(\.appLanguage, language)
            }
            .sheet(isPresented: $showNewExchange) {
                NewExchangeView()
                    .environment(\.appLanguage, language)
            }
            .sheet(item: $editingExchange) { exchange in
                EditExchangeView(exchange: exchange)
                    .environment(\.appLanguage, language)
            }
            .sheet(item: $restoringExchange) { exchange in
                RestoreExchangeView(exchange: exchange)
                    .environment(\.appLanguage, language)
                    .environment(\.achievementsManager, achievements)
            }
        }
        .environment(\.appLanguage, language)
    }

    // MARK: - List

    private var list: some View {
        List {
            if !activeExchanges.isEmpty {
                Section(header: Text(isRu ? "Активные" : "Active")
                    .font(.system(size: 12, weight: .bold))
                    .textCase(nil)) {
                    ForEach(activeExchanges) { exchange in
                        activeExchangeRow(exchange)
                    }
                }
            }

            if !pastExchanges.isEmpty {
                Section {
                    DisclosureGroup(
                        isExpanded: $showHistory,
                        content: {
                            ForEach(pastExchanges) { exchange in
                                pastExchangeRow(exchange)
                            }
                        },
                        label: {
                            HStack {
                                Text(isRu ? "История" : "History")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(pastExchanges.count)")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Active row

    private func activeExchangeRow(_ exchange: ExchangeModel) -> some View {
        let isExpanded = expandedActiveIDs.contains(exchange.id)

        return VStack(alignment: .leading, spacing: 6) {
            // Заголовок — всегда виден
            HStack(spacing: 10) {
                Image(systemName: "arrow.2.squarepath")
                    .foregroundStyle(.teal)
                    .font(.system(size: 16))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(exchange.effectiveMeetingDate, style: .date)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        if !exchange.partner.isEmpty {
                            Text("·")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 12))
                            Text(exchange.partner)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            if let trust = TrustLevel.compute(for: exchange.partner, in: exchanges) {
                                Image(systemName: trust.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(trust.color)
                            }
                        }
                    }
                    if !isExpanded {
                        Text(summaryText(exchange))
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                    }
                }

                Spacer()

                let isCopied = copiedExchangeID == exchange.id
                Button {
                    UIPasteboard.general.string = exchangeMessage(exchange)
                    copiedExchangeID = exchange.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        if copiedExchangeID == exchange.id { copiedExchangeID = nil }
                    }
                } label: {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13))
                        .foregroundStyle(isCopied ? Color.green : Color.secondary)
                }
                .buttonStyle(.plain)

                Button { editingExchange = exchange } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    if isExpanded { expandedActiveIDs.remove(exchange.id) }
                    else          { expandedActiveIDs.insert(exchange.id) }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Раскрытые колонки
            if isExpanded {
                HStack(alignment: .top, spacing: 12) {
                    stickerColumn(
                        title: isRu ? "Отдаю" : "I give",
                        entries: exchange.giving,
                        color: .teal
                    )
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, 18)
                    stickerColumn(
                        title: isRu ? "Получаю" : "I receive",
                        entries: exchange.wanting,
                        color: .green,
                        ownedIDs: Set(exchange.wanting.map { "\($0.teamCode)\($0.number)" }
                            .filter { sid in
                                let s = stickerIndex[sid]
                                return s?.status == .pasted || s?.status == .duplicate
                            }),
                        incomingIDs: Set(exchange.wanting.map { "\($0.teamCode)\($0.number)" }
                            .filter { sid in
                                let othersIncoming = activeExchanges
                                    .filter { $0.id != exchange.id }
                                    .flatMap { $0.wanting }
                                    .map { "\($0.teamCode)\($0.number)" }
                                return othersIncoming.contains(sid)
                            })
                    )
                }
                .padding(.leading, 26)

                HStack(spacing: 8) {
                    Button {
                        ExchangeService.complete(exchange, context: context, achievements: achievements)
                    } label: {
                        Label(isRu ? "Завершить" : "Complete", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    Button {
                        ExchangeService.cancel(exchange, context: context)
                    } label: {
                        Label(isRu ? "Отменить" : "Cancel", systemImage: "xmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.10))
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 26)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Past row

    private func pastExchangeRow(_ exchange: ExchangeModel) -> some View {
        let isExpanded = expandedPastIDs.contains(exchange.id)

        return VStack(alignment: .leading, spacing: 6) {
            // Заголовок — всегда виден
            HStack(spacing: 10) {
                Image(systemName: exchange.status == .completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(exchange.status == .completed ? .green : .red)
                    .font(.system(size: 16))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(exchange.effectiveMeetingDate, style: .date)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        if !exchange.partner.isEmpty {
                            Text("·")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 12))
                            Text(exchange.partner)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    if !isExpanded {
                        Text(summaryText(exchange))
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                    }
                }

                Spacer()

                Button {
                    if isExpanded {
                        expandedPastIDs.remove(exchange.id)
                    } else {
                        expandedPastIDs.insert(exchange.id)
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button { editingExchange = exchange } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Раскрытые колонки
            if isExpanded {
                HStack(alignment: .top, spacing: 12) {
                    stickerColumn(
                        title: isRu ? "Отдал" : "Gave",
                        entries: exchange.giving,
                        color: .teal
                    )
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, 18)
                    stickerColumn(
                        title: isRu ? "Получил" : "Received",
                        entries: exchange.wanting,
                        color: .green
                    )
                }
                .padding(.leading, 26)

                if exchange.status == .cancelled {
                    if let reason = exchange.cancellationReason {
                        Label(isRu ? reason.nameRU : reason.nameEN, systemImage: reason.icon)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(reason.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(reason.color.opacity(0.1), in: Capsule())
                            .padding(.leading, 26)
                    }

                    Button {
                        restoringExchange = exchange
                    } label: {
                        Label(isRu ? "Восстановить" : "Restore", systemImage: "arrow.uturn.backward.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.12))
                            .foregroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 26)
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Sticker column

    private func stickerColumn(title: String, entries: [StickerEntry],
                                color: Color, ownedIDs: Set<String> = [],
                                incomingIDs: Set<String> = []) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text("(\(entries.count))")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(color.opacity(0.8))
            }

            let grouped = Dictionary(grouping: entries, by: \.teamCode)
            ForEach(grouped.keys.sorted(), id: \.self) { code in
                let items = grouped[code] ?? []
                HStack(spacing: 3) {
                    Text(code)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(color)
                    ForEach(items) { entry in
                        let sid      = "\(entry.teamCode)\(entry.number)"
                        let owned    = ownedIDs.contains(sid)
                        let incoming = incomingIDs.contains(sid)
                        let label = entry.count > 1
                            ? "\(entry.number)×\(entry.count)"
                            : "\(entry.number)"
                        VStack(spacing: 1) {
                            Text(label)
                                .font(.system(size: 11, design: .monospaced))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    (owned || incoming ? Color.orange : color).opacity(0.15),
                                    in: RoundedRectangle(cornerRadius: 4)
                                )
                                .foregroundStyle(owned || incoming ? Color.orange : color)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(
                                            (owned || incoming) ? Color.orange.opacity(0.5) : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                            if owned {
                                Text(isRu ? "есть" : "owned")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(Color.orange)
                            } else if incoming {
                                Text(isRu ? "ждёшь" : "pending")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(Color.orange)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Summary text

    private func summaryText(_ exchange: ExchangeModel) -> String {
        let give = exchange.giving.reduce(0) { $0 + $1.count }
        let want = exchange.wanting.reduce(0) { $0 + $1.count }
        let total = give + want
        if isRu {
            return "\(total) \(cardWord(total, ru: true)) · \(give) отдаю, \(want) получаю"
        } else {
            return "\(total) \(cardWord(total, ru: false)) · \(give) give, \(want) receive"
        }
    }

    private func cardWord(_ n: Int, ru: Bool) -> String {
        guard ru else { return n == 1 ? "card" : "cards" }
        let mod10 = n % 10, mod100 = n % 100
        if mod100 >= 11 && mod100 <= 14 { return "карточек" }
        switch mod10 {
        case 1: return "карточка"
        case 2, 3, 4: return "карточки"
        default: return "карточек"
        }
    }

    private func exchangeMessage(_ exchange: ExchangeModel) -> String {
        let myLabel   = isRu ? "Мои карточки:"   : "My stickers:"
        let yourLabel = isRu ? "Ваши карточки:"  : "Your stickers:"
        let question  = isRu ? "Подскажите, устраивает ли Вас такой обмен?" : "Does this exchange work for you?"

        func formatEntries(_ entries: [StickerEntry]) -> String {
            let grouped = Dictionary(grouping: entries, by: \.teamCode)
            return grouped.keys.sorted().map { code in
                let nums = (grouped[code] ?? []).sorted { $0.number < $1.number }
                    .map { $0.number == 0 ? "00" : "\($0.number)" }
                    .joined(separator: ", ")
                return "\(code): \(nums)"
            }.joined(separator: "\n")
        }

        return "\(myLabel)(\(exchange.giving.count)):\n\(formatEntries(exchange.giving))\n\n\(yourLabel)(\(exchange.wanting.count)):\n\(formatEntries(exchange.wanting))\n\n\(question)"
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.2.squarepath")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(isRu ? "Обменов нет" : "No exchanges")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(isRu
                 ? "Нажми «+» чтобы создать новый обмен.\nУказанные карточки будут зарезервированы."
                 : "Tap «+» to create a new exchange.\nListed stickers will be reserved.")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button {
                showNewExchange = true
            } label: {
                Label(isRu ? "Создать обмен" : "Create exchange", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.teal.opacity(0.15))
                    .foregroundStyle(.teal)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showNewExchange) {
            NewExchangeView()
                .environment(\.appLanguage, language)
        }
    }
}
