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

    @State private var givingSelections:  [StickerSelection]
    @State private var wantingSelections: [StickerSelection]
    @State private var partnerText: String = ""

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
                        isRu: isRu
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
                        isRu: isRu
                    )

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
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground),
                                    in: RoundedRectangle(cornerRadius: 10))
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
    let isRu: Bool

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
                HStack(spacing: 6) {
                    Text(sel.teamFlag)
                        .font(.system(size: 16))
                    Text(sel.teamCode)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(color)
                    Text(":")
                        .foregroundStyle(.secondary)
                    Text(sel.numbers.sorted().map { "\($0)" }.joined(separator: ", "))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(color)
                        .lineLimit(2)
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
                .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
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
        return LazyVGrid(columns: cols, spacing: 6) {
            ForEach(1...20, id: \.self) { n in
                numberCell(n: n, team: team, teamStickers: teamStickers)
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
            let available = max(0, (sticker?.duplicateCount ?? 0) - reserved)
            let disabled  = available == 0

            Button {
                if !disabled {
                    if isOn { selectedNums.remove(n) }
                    else     { selectedNums.insert(n) }
                }
            } label: {
                ZStack(alignment: .topTrailing) {
                    Text("\(n)")
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
            // Уже есть в альбоме — подсвечиваем темнее
            let bgColor: Color = isOn      ? color :
                                 isPasted  ? color.opacity(0.25) :
                                             Color(.secondarySystemBackground)
            let fgColor: Color = isOn      ? .white :
                                 isPasted  ? color :
                                             .primary

            Button {
                if isOn { selectedNums.remove(n) }
                else     { selectedNums.insert(n) }
            } label: {
                ZStack(alignment: .topTrailing) {
                    Text("\(n)")
                        .font(.system(size: 13, weight: isOn ? .bold : .regular, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(bgColor, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(fgColor)

                    // Бейдж "уже есть"
                    if isPasted && !isOn {
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
