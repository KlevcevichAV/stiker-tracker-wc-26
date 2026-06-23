import SwiftUI
import SwiftData

struct EditExchangeView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.appLanguage)  private var language

    let exchange: ExchangeModel

    // true  — активный обмен (меняем всё)
    // false — завершённый/отменённый (только партнёр)
    private var isFullEdit: Bool { exchange.status == .active }

    @Query(sort: \TeamModel.orderIndex)
    private var teams: [TeamModel]

    @Query
    private var allStickers: [StickerModel]

    @Query(filter: #Predicate<ExchangeModel> { $0.statusRaw == "active" })
    private var activeExchanges: [ExchangeModel]

    @State private var givingSelections:  [StickerSelection] = []
    @State private var wantingSelections: [StickerSelection] = []
    @State private var partnerText: String = ""

    private var isRu: Bool { language.isRussian }

    private var canSave: Bool {
        !isFullEdit || (!givingSelections.isEmpty && !wantingSelections.isEmpty)
    }

    private var stickerIndex: [String: [Int: StickerModel]] {
        var idx: [String: [Int: StickerModel]] = [:]
        for s in allStickers { idx[s.teamCode, default: [:]][s.number] = s }
        return idx
    }

    // При редактировании активного обмена — исключаем сам редактируемый обмен из резервов,
    // чтобы не блокировать собственные карточки
    private func alreadyReserved(teamCode: String, number: Int) -> Int {
        let id = "\(teamCode)\(number)"
        let others = activeExchanges.filter { $0.id != exchange.id }
        return ExchangeService.reservedCount(for: id, in: others)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isFullEdit {
                        StickerPickerSection(
                            title: isRu ? "Что отдаю" : "I give",
                            icon: "arrow.up.circle.fill",
                            color: Color.teal,
                            mode: .giving,
                            selections: $givingSelections,
                            teams: teams,
                            stickerIndex: stickerIndex,
                            reservedFn: alreadyReserved,
                            isRu: isRu
                        )

                        Divider()

                        StickerPickerSection(
                            title: isRu ? "Что получаю" : "I receive",
                            icon: "arrow.down.circle.fill",
                            color: Color.green,
                            mode: .wanting,
                            selections: $wantingSelections,
                            teams: teams,
                            stickerIndex: stickerIndex,
                            reservedFn: alreadyReserved,
                            isRu: isRu
                        )

                        Divider()
                    }

                    partnerField
                }
                .padding(16)
            }
            .navigationTitle(isRu ? "Редактировать" : "Edit Exchange")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isRu ? "Отмена" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isRu ? "Сохранить" : "Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
        .onAppear { loadExisting() }
    }

    // MARK: - Partner field

    private var partnerField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(isRu ? "С кем обмен" : "Exchange partner",
                  systemImage: "person.circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Image(systemName: "at")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
                TextField(
                    isRu ? "Никнейм или телефон (необязательно)" : "Nickname or phone (optional)",
                    text: $partnerText
                )
                .font(.system(size: 14))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                if !partnerText.isEmpty {
                    Button { partnerText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Load existing data into state

    private func loadExisting() {
        partnerText = exchange.partner

        guard isFullEdit else { return }

        // Сгруппировать giving по teamCode → StickerSelection
        givingSelections  = entriesToSelections(exchange.giving)
        wantingSelections = entriesToSelections(exchange.wanting)
    }

    private func entriesToSelections(_ entries: [StickerEntry]) -> [StickerSelection] {
        let grouped = Dictionary(grouping: entries, by: \.teamCode)
        return grouped.keys.sorted().compactMap { code -> StickerSelection? in
            let items = grouped[code] ?? []
            let nums = Set(items.map { $0.number })
            guard !nums.isEmpty else { return nil }
            // Ищем команду для флага и имени
            let team = teams.first { $0.code == code }
            return StickerSelection(
                teamCode: code,
                teamName: isRu ? (team?.nameRU ?? code) : (team?.nameEN ?? code),
                teamFlag: team?.flagEmoji ?? "",
                numbers: nums
            )
        }
    }

    // MARK: - Save

    private func save() {
        exchange.partner = partnerText.trimmingCharacters(in: .whitespaces)

        if isFullEdit {
            exchange.giving  = givingSelections.flatMap { $0.toEntries() }
            exchange.wanting = wantingSelections.flatMap { $0.toEntries() }
        }

        try? context.save()
        dismiss()
    }
}
