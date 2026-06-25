import SwiftUI
import SwiftData

struct EditExchangeView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.appLanguage)  private var language

    let exchange: ExchangeModel

    private var isActive: Bool { exchange.status == .active }

    @Query(sort: \TeamModel.orderIndex)
    private var teams: [TeamModel]

    @Query
    private var allStickers: [StickerModel]

    @Query(filter: #Predicate<ExchangeModel> { $0.statusRaw == "active" })
    private var activeExchanges: [ExchangeModel]

    @Query
    private var allExchanges: [ExchangeModel]

    @State private var givingSelections:  [StickerSelection] = []
    @State private var wantingSelections: [StickerSelection] = []
    @State private var partnerText: String = ""
    @State private var meetingDate: Date = Date()
    @State private var cancellationReason: CancellationReason? = nil

    private var isRu: Bool { language.isRussian }

    private var canSave: Bool {
        !givingSelections.isEmpty && !wantingSelections.isEmpty
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

    private func alreadyIncoming(teamCode: String, number: Int) -> Int {
        let id = "\(teamCode)\(number)"
        let others = activeExchanges.filter { $0.id != exchange.id }
        return ExchangeService.incomingCount(for: id, in: others)
    }

    private var conflictingWanting: [(teamCode: String, number: Int)] {
        wantingSelections.flatMap { sel in
            sel.numbers.compactMap { n -> (String, Int)? in
                alreadyIncoming(teamCode: sel.teamCode, number: n) > 0 ? (sel.teamCode, n) : nil
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    StickerPickerSection(
                        title: isRu ? "Что отдаю" : "I give",
                        icon: "arrow.up.circle.fill",
                        color: Color.teal,
                        mode: .giving,
                        selections: $givingSelections,
                        teams: teams,
                        stickerIndex: stickerIndex,
                        reservedFn: alreadyReserved,
                        isRu: isRu,
                        isArchive: !isActive
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
                        incomingFn: alreadyIncoming,
                        isRu: isRu,
                        isArchive: !isActive
                    )

                    if !conflictingWanting.isEmpty {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                                .font(.system(size: 14))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isRu ? "Уже ожидается в другом обмене" : "Already pending in another exchange")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)
                                let names = conflictingWanting
                                    .map { "\($0.teamCode) \($0.number == 0 ? "00" : "\($0.number)")" }
                                    .joined(separator: ", ")
                                Text(names)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.yellow.opacity(0.4), lineWidth: 1))
                    }

                    Divider()

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
        VStack(alignment: .leading, spacing: 16) {
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
                    .onChange(of: partnerText) { _, new in
                        if !new.isEmpty && !new.hasPrefix("@") && !looksLikePhone(new) {
                            partnerText = "@" + new
                        }
                    }
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

                let trimmed = partnerText.trimmingCharacters(in: .whitespaces)
                let otherExchanges = allExchanges.filter { $0.id != exchange.id }
                if let trust = TrustLevel.compute(for: trimmed, in: otherExchanges) {
                    Label(isRu ? trust.nameRU : trust.nameEN, systemImage: trust.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(trust.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(trust.color.opacity(0.1), in: Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Label(isRu ? "Дата встречи" : "Meeting date",
                      systemImage: "calendar")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)

                DatePicker("", selection: $meetingDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 10))
            }

            if exchange.status == .cancelled {
                VStack(alignment: .leading, spacing: 6) {
                    Label(isRu ? "Причина отказа" : "Cancellation reason",
                          systemImage: "exclamationmark.circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 0) {
                        ForEach(CancellationReason.allCases, id: \.self) { reason in
                            Button {
                                cancellationReason = cancellationReason == reason ? nil : reason
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: reason.icon)
                                        .foregroundStyle(cancellationReason == reason ? reason.color : .secondary)
                                        .font(.system(size: 14))
                                        .frame(width: 20)
                                    Text(isRu ? reason.nameRU : reason.nameEN)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if cancellationReason == reason {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(reason.color)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)

                            if reason != CancellationReason.allCases.last {
                                Divider().padding(.leading, 42)
                            }
                        }
                    }
                    .background(Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: - Load existing data into state

    private func loadExisting() {
        partnerText        = exchange.partner
        meetingDate        = exchange.effectiveMeetingDate
        cancellationReason = exchange.cancellationReason
        givingSelections   = entriesToSelections(exchange.giving)
        wantingSelections  = entriesToSelections(exchange.wanting)
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
        exchange.partner            = partnerText.trimmingCharacters(in: .whitespaces)
        exchange.meetingDate        = meetingDate
        exchange.cancellationReason = cancellationReason
        exchange.giving             = givingSelections.flatMap { $0.toEntries() }
        exchange.wanting            = wantingSelections.flatMap { $0.toEntries() }

        try? context.save()
        dismiss()
    }
}
