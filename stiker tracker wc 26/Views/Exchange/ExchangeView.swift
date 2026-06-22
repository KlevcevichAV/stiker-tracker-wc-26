import SwiftUI
import SwiftData

struct ExchangeView: View {

    @Environment(\.modelContext)     private var context
    @Environment(\.achievementsManager) private var achievements
    @Environment(\.appLanguage)     private var language

    @Query(sort: \ExchangeModel.createdAt, order: .reverse)
    private var exchanges: [ExchangeModel]

    @State private var showNewExchange = false
    @State private var showHistory     = false

    private var isRu: Bool { language.isRussian }

    private var activeExchanges: [ExchangeModel] {
        exchanges.filter { $0.status == .active }
    }

    private var pastExchanges: [ExchangeModel] {
        exchanges.filter { $0.status != .active }
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
                    Button {
                        showNewExchange = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showNewExchange) {
                NewExchangeView()
                    .environment(\.appLanguage, language)
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
        VStack(alignment: .leading, spacing: 10) {
            // Заголовок с датой
            HStack {
                Image(systemName: "arrow.2.squarepath")
                    .foregroundStyle(.teal)
                    .font(.system(size: 14, weight: .semibold))
                Text(exchange.createdAt, style: .date)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // Карточки
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
                    color: .green
                )
            }

            // Кнопки действий
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
        }
        .padding(.vertical, 6)
    }

    // MARK: - Past row

    private func pastExchangeRow(_ exchange: ExchangeModel) -> some View {
        HStack(spacing: 10) {
            Image(systemName: exchange.status == .completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(exchange.status == .completed ? .green : .red)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 2) {
                Text(exchange.createdAt, style: .date)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(summaryText(exchange))
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Sticker column

    private func stickerColumn(title: String, entries: [StickerEntry], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            let grouped = Dictionary(grouping: entries, by: \.teamCode)
            ForEach(grouped.keys.sorted(), id: \.self) { code in
                let items = grouped[code] ?? []
                HStack(spacing: 3) {
                    Text(code)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(color)
                    ForEach(items) { entry in
                        Text(entry.count > 1 ? "\(entry.number)×\(entry.count)" : "\(entry.number)")
                            .font(.system(size: 11, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(color)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Summary text

    private func summaryText(_ exchange: ExchangeModel) -> String {
        let giveIDs = exchange.giving.map { "\($0.teamCode)\($0.number)" }.joined(separator: ",")
        let wantIDs = exchange.wanting.map { "\($0.teamCode)\($0.number)" }.joined(separator: ",")
        return "\(giveIDs) → \(wantIDs)"
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
