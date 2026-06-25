import SwiftUI
import SwiftData

// MARK: - Data

struct StickerSelection: Identifiable {
    let id = UUID()
    var teamCode: String
    var teamName: String
    var teamFlag: String
    var numbers: Set<Int>

    func toEntries() -> [StickerEntry] {
        numbers.sorted().map { StickerEntry(teamCode: teamCode, number: $0, count: 1) }
    }
}

// MARK: - Main view

struct NewExchangeView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.appLanguage)  private var language

    @Query(sort: \TeamModel.orderIndex)
    private var teams: [TeamModel]

    @Query
    private var allStickers: [StickerModel]

    @Query(filter: #Predicate<ExchangeModel> { $0.statusRaw == "active" })
    private var activeExchanges: [ExchangeModel]

    @Query
    private var allExchanges: [ExchangeModel]

    @State private var givingSelections:  [StickerSelection]
    @State private var wantingSelections: [StickerSelection]
    @State private var partnerText: String = ""
    @State private var meetingDate: Date = Date()
    @State private var isArchive: Bool = false
    @State private var archiveCancelled: Bool = false
    @State private var archiveCancellationReason: CancellationReason? = nil

    /// Пустая форма
    init() {
        _givingSelections  = State(initialValue: [])
        _wantingSelections = State(initialValue: [])
    }

    /// Предзаполненная форма из анализа обмена
    init(prefillGiving: [StickerEntry], prefillWanting: [StickerEntry]) {
        _givingSelections  = State(initialValue: NewExchangeView.toSelections(prefillGiving))
        _wantingSelections = State(initialValue: NewExchangeView.toSelections(prefillWanting))
    }

    private static func toSelections(_ entries: [StickerEntry]) -> [StickerSelection] {
        let grouped = Dictionary(grouping: entries, by: \.teamCode)
        return grouped.keys.sorted().map { code in
            let nums = Set(grouped[code]!.map { $0.number })
            return StickerSelection(teamCode: code, teamName: code, teamFlag: "", numbers: nums)
        }
    }

    private var isRu: Bool { language.isRussian }

    private var canCreate: Bool {
        !givingSelections.isEmpty && !wantingSelections.isEmpty
    }

    /// Словарь: teamCode → (number → StickerModel)
    private var stickerIndex: [String: [Int: StickerModel]] {
        var idx: [String: [Int: StickerModel]] = [:]
        for s in allStickers {
            idx[s.teamCode, default: [:]][s.number] = s
        }
        return idx
    }

    /// Сколько уже зарезервировано в активных обменах для данного стикера
    private func alreadyReserved(teamCode: String, number: Int) -> Int {
        let id = "\(teamCode)\(number)"
        return ExchangeService.reservedCount(for: id, in: activeExchanges)
    }

    /// Сколько штук данного стикера уже ожидается в активных обменах
    private func alreadyIncoming(teamCode: String, number: Int) -> Int {
        let id = "\(teamCode)\(number)"
        return ExchangeService.incomingCount(for: id, in: activeExchanges)
    }

    /// Карточки из "Что получаю" которые уже ожидаются в другом активном обмене
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
                        color: .teal,
                        mode: .giving,
                        selections: $givingSelections,
                        teams: teams,
                        stickerIndex: stickerIndex,
                        reservedFn: alreadyReserved,
                        isRu: isRu,
                        isArchive: isArchive
                    )

                    Divider()

                    StickerPickerSection(
                        title: isRu ? "Что получаю" : "I receive",
                        icon: "arrow.down.circle.fill",
                        color: .green,
                        mode: .wanting,
                        selections: $wantingSelections,
                        teams: teams,
                        stickerIndex: stickerIndex,
                        reservedFn: alreadyReserved,
                        incomingFn: alreadyIncoming,
                        isRu: isRu
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

                    // Необязательное поле — с кем обмен
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
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground),
                                    in: RoundedRectangle(cornerRadius: 10))

                        if let trust = TrustLevel.compute(
                            for: partnerText.trimmingCharacters(in: .whitespaces),
                            in: allExchanges
                        ) {
                            trustBadge(trust)
                        }
                    }

                    // Дата встречи
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

                    // Архивный обмен
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $isArchive) {
                            Label(isRu ? "Архивный обмен" : "Archive entry",
                                  systemImage: "archivebox.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .tint(.orange)
                        .onChange(of: isArchive) { _, new in
                            if !new {
                                archiveCancelled = false
                                archiveCancellationReason = nil
                            }
                        }

                        if isArchive {
                            // Выбор исхода
                            HStack(spacing: 8) {
                                Button {
                                    archiveCancelled = false
                                    archiveCancellationReason = nil
                                } label: {
                                    Label(isRu ? "Завершён" : "Completed",
                                          systemImage: "checkmark.circle.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(!archiveCancelled ? Color.green.opacity(0.15) : Color(.secondarySystemBackground))
                                        .foregroundStyle(!archiveCancelled ? Color.green : Color.secondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    archiveCancelled = true
                                } label: {
                                    Label(isRu ? "Отменён" : "Cancelled",
                                          systemImage: "xmark.circle.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(archiveCancelled ? Color.red.opacity(0.12) : Color(.secondarySystemBackground))
                                        .foregroundStyle(archiveCancelled ? Color.red : Color.secondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }

                            if archiveCancelled {
                                VStack(spacing: 0) {
                                    ForEach(CancellationReason.allCases, id: \.self) { reason in
                                        Button {
                                            archiveCancellationReason = archiveCancellationReason == reason ? nil : reason
                                        } label: {
                                            HStack(spacing: 10) {
                                                Image(systemName: reason.icon)
                                                    .foregroundStyle(archiveCancellationReason == reason ? reason.color : .secondary)
                                                    .font(.system(size: 14))
                                                    .frame(width: 20)
                                                Text(isRu ? reason.nameRU : reason.nameEN)
                                                    .font(.system(size: 14))
                                                    .foregroundStyle(.primary)
                                                Spacer()
                                                if archiveCancellationReason == reason {
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

                            Text(archiveCancelled
                                 ? (isRu ? "Обмен будет сохранён как отменённый" : "Exchange will be saved as cancelled")
                                 : (isRu ? "Обмен будет сохранён как завершённый без изменения наклеек в альбоме" : "Exchange will be saved as completed without changing stickers in the album"))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle(isRu ? "Новый обмен" : "New Exchange")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isRu ? "Отмена" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isRu ? "Создать" : "Create") {
                        ExchangeService.create(
                            giving: givingSelections.flatMap { $0.toEntries() },
                            wanting: wantingSelections.flatMap { $0.toEntries() },
                            partner: partnerText.trimmingCharacters(in: .whitespaces),
                            meetingDate: meetingDate,
                            archived: isArchive,
                            archiveCancelled: archiveCancelled,
                            archiveCancellationReason: archiveCancellationReason,
                            context: context
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canCreate)
                }
            }
        }
        .onAppear { enrichSelectionsWithTeamData() }
    }

    private func trustBadge(_ trust: TrustLevel) -> some View {
        Label(isRu ? trust.nameRU : trust.nameEN, systemImage: trust.icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(trust.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(trust.color.opacity(0.1), in: Capsule())
    }

    /// Заполняет teamName и teamFlag в предзаполненных StickerSelection (они пустые до загрузки teams)
    private func enrichSelectionsWithTeamData() {
        guard !teams.isEmpty else { return }
        let teamMap = Dictionary(uniqueKeysWithValues: teams.map { ($0.code, $0) })
        givingSelections = givingSelections.map { sel in
            guard sel.teamFlag.isEmpty, let t = teamMap[sel.teamCode] else { return sel }
            return StickerSelection(teamCode: sel.teamCode,
                                    teamName: isRu ? t.nameRU : t.nameEN,
                                    teamFlag: t.flagEmoji,
                                    numbers: sel.numbers)
        }
        wantingSelections = wantingSelections.map { sel in
            guard sel.teamFlag.isEmpty, let t = teamMap[sel.teamCode] else { return sel }
            return StickerSelection(teamCode: sel.teamCode,
                                    teamName: isRu ? t.nameRU : t.nameEN,
                                    teamFlag: t.flagEmoji,
                                    numbers: sel.numbers)
        }
    }
}

// MARK: - Section mode

enum PickerMode { case giving, wanting }

// MARK: - Picker section

struct StickerPickerSection: View {

    let title: String
    let icon: String
    let color: Color
    let mode: PickerMode
    @Binding var selections: [StickerSelection]
    let teams: [TeamModel]
    let stickerIndex: [String: [Int: StickerModel]]
    let reservedFn: (String, Int) -> Int
    var incomingFn: (String, Int) -> Int = { _, _ in 0 }
    let isRu: Bool
    var isArchive: Bool = false

    @State private var searchText      = ""
    @State private var selectedTeam: TeamModel? = nil
    @State private var selectedNums: Set<Int>   = []
    @State private var isSearchFocused = false

    private var filteredTeams: [TeamModel] {
        guard !searchText.isEmpty else { return teams }
        let q = searchText.uppercased()
        return teams.filter {
            $0.code.contains(q) ||
            $0.nameEN.uppercased().contains(q) ||
            $0.nameRU.uppercased().contains(q)
        }
    }

    private var showDropdown: Bool {
        selectedTeam == nil && (isSearchFocused || !searchText.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)

            if !selections.isEmpty {
                addedChips
            }

            addBlock
        }
    }

    // MARK: Added chips

    private var addedChips: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(selections) { sel in
                let conflictNums: Set<Int> = mode == .wanting
                    ? Set(sel.numbers.filter { incomingFn(sel.teamCode, $0) > 0 })
                    : []
                let hasConflict = !conflictNums.isEmpty
                HStack(spacing: 6) {
                    Text(sel.teamFlag)
                        .font(.system(size: 16))
                    Text(sel.teamCode)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(hasConflict ? Color.yellow : color)
                    Text(":")
                        .foregroundStyle(.secondary)
                    // Числа: конфликтные — жёлтым, остальные — обычным цветом
                    HStack(spacing: 3) {
                        ForEach(sel.numbers.sorted(), id: \.self) { n in
                            let isConflict = conflictNums.contains(n)
                            Text(n == 0 ? "00" : "\(n)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(isConflict ? Color.yellow : color)
                                .padding(.horizontal, isConflict ? 5 : 0)
                                .padding(.vertical, isConflict ? 2 : 0)
                                .background(
                                    isConflict ? Color.yellow.opacity(0.2) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 4)
                                )
                        }
                    }
                    Spacer()
                    Button {
                        selections.removeAll { $0.id == sel.id }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 18))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    hasConflict ? Color.yellow.opacity(0.08) : color.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .overlay(
                    hasConflict
                        ? RoundedRectangle(cornerRadius: 10).strokeBorder(Color.yellow.opacity(0.4), lineWidth: 1)
                        : nil
                )
            }
        }
    }

    // MARK: Add block

    private var addBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Поисковое поле / выбранная команда
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))

                if let team = selectedTeam {
                    HStack(spacing: 4) {
                        Text(team.flagEmoji)
                        Text(team.code)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(color)
                        Text(isRu ? team.nameRU : team.nameEN)
                            .font(.system(size: 13))
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        selectedTeam = nil
                        selectedNums = []
                        searchText   = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    TextField(
                        isRu ? "Код или название команды" : "Team code or name",
                        text: $searchText
                    )
                    .font(.system(size: 14, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .onTapGesture { isSearchFocused = true }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

            if showDropdown { teamDropdown }

            if let team = selectedTeam {
                numberGrid(for: team)

                addButton(for: team)
            }
        }
    }

    // MARK: Team dropdown

    private var teamDropdown: some View {
        VStack(spacing: 0) {
            let list = filteredTeams.prefix(8)
            ForEach(Array(list), id: \.code) { team in
                Button {
                    selectedTeam    = team
                    searchText      = ""
                    isSearchFocused = false
                    selectedNums    = []
                } label: {
                    HStack(spacing: 10) {
                        Text(team.flagEmoji)
                            .font(.system(size: 18))
                        Text(team.code)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(color)
                            .frame(width: 36, alignment: .leading)
                        Text(isRu ? team.nameRU : team.nameEN)
                            .font(.system(size: 13))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                if team.code != list.last?.code {
                    Divider().padding(.leading, 52)
                }
            }
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: Number grid

    private func numberGrid(for team: TeamModel) -> some View {
        let teamStickers = stickerIndex[team.code] ?? [:]
        let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)
        return VStack(alignment: .leading, spacing: 6) {
            // Карточка 00 — отдельной строкой шириной одной ячейки
            GeometryReader { geo in
                let cellWidth = (geo.size.width - 6 * 4) / 5
                numberCell(n: 0, team: team, teamStickers: teamStickers)
                    .frame(width: cellWidth)
            }
            .frame(height: 36)
            // Карточки 1–20
            LazyVGrid(columns: cols, spacing: 6) {
                ForEach(1...20, id: \.self) { n in
                    numberCell(n: n, team: team, teamStickers: teamStickers)
                }
            }
        }
    }

    @ViewBuilder
    private func numberCell(n: Int, team: TeamModel, teamStickers: [Int: StickerModel]) -> some View {
        let sticker   = teamStickers[n]
        let isOn      = selectedNums.contains(n)

        switch mode {
        case .giving:
            let reserved  = reservedFn(team.code, n)
            let hasDuplicates = (sticker?.duplicateCount ?? 0) - reserved > 0
            let hasSticker    = sticker?.status == .pasted || (sticker?.duplicateCount ?? 0) > 0
            let disabled      = isArchive ? !hasSticker : !hasDuplicates
            let available: Int = isArchive
                ? (sticker == nil ? 0 : ((sticker!.status == .pasted ? 1 : 0) + sticker!.duplicateCount))
                : max(0, (sticker?.duplicateCount ?? 0) - reserved)

            Button {
                if !disabled {
                    if isOn { selectedNums.remove(n) }
                    else     { selectedNums.insert(n) }
                }
            } label: {
                ZStack(alignment: .topTrailing) {
                    Text(n == 0 ? "00" : "\(n)")
                        .font(.system(size: 13, weight: isOn ? .bold : .regular, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            isOn      ? color :
                            disabled  ? Color(.systemGray5) :
                                        Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .foregroundStyle(
                            isOn     ? .white :
                            disabled ? Color(.systemGray3) :
                                       .primary
                        )

                    // Бейдж с кол-вом доступных
                    if !disabled && !isOn {
                        Text("×\(available)")
                            .font(.system(size: 7, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(color.opacity(0.85), in: RoundedRectangle(cornerRadius: 3))
                            .padding(2)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(disabled)

        case .wanting:
            let dupCount = sticker?.duplicateCount ?? 0
            let isPasted = sticker?.status == .pasted || dupCount > 0
            let incoming = incomingFn(team.code, n)
            let disabledWanting = isArchive && !isPasted
            let bgColor: Color = isOn            ? (incoming > 0 ? Color.orange : color) :
                                 disabledWanting ? Color(.systemGray5) :
                                 incoming > 0    ? Color.orange.opacity(0.15) :
                                 isPasted        ? color.opacity(0.25) :
                                                   Color(.secondarySystemBackground)
            let fgColor: Color = isOn            ? .white :
                                 disabledWanting ? Color(.systemGray3) :
                                 incoming > 0    ? Color.orange :
                                 isPasted        ? color :
                                                   .primary

            Button {
                if !disabledWanting {
                    if isOn { selectedNums.remove(n) }
                    else     { selectedNums.insert(n) }
                }
            } label: {
                ZStack(alignment: .topTrailing) {
                    Text(n == 0 ? "00" : "\(n)")
                        .font(.system(size: 13, weight: isOn ? .bold : .regular, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(bgColor, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(fgColor)

                    if incoming > 0 && !isOn {
                        // Бейдж "уже ожидается в обмене"
                        Text("↓\(incoming)")
                            .font(.system(size: 7, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.9), in: RoundedRectangle(cornerRadius: 3))
                            .padding(2)
                    } else if isPasted && !isOn && !disabledWanting && incoming == 0 {
                        // Бейдж "уже есть"
                        Image(systemName: dupCount > 0 ? "square.on.square.fill" : "checkmark")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 2)
                            .background(color.opacity(0.85), in: RoundedRectangle(cornerRadius: 3))
                            .padding(2)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(disabledWanting)
        }
    }

    // MARK: Add button

    private func addButton(for team: TeamModel) -> some View {
        Button {
            if let idx = selections.firstIndex(where: { $0.teamCode == team.code }) {
                selections[idx].numbers.formUnion(selectedNums)
            } else {
                selections.append(StickerSelection(
                    teamCode: team.code,
                    teamName: isRu ? team.nameRU : team.nameEN,
                    teamFlag: team.flagEmoji,
                    numbers: selectedNums
                ))
            }
            selectedTeam    = nil
            selectedNums    = []
            searchText      = ""
            isSearchFocused = false
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text(isRu ? "Добавить" : "Add")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selectedNums.isEmpty ? Color(.systemGray5) : color.opacity(0.15))
            .foregroundStyle(selectedNums.isEmpty ? .secondary : color)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(selectedNums.isEmpty)
    }
}

// Начинается с +, цифры или скобки — скорее всего телефон
func looksLikePhone(_ text: String) -> Bool {
    guard let first = text.first else { return false }
    return first == "+" || first == "(" || first.isNumber
}
