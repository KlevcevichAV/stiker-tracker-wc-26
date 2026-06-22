import SwiftUI
import SwiftData

// MARK: - View mode

private enum GroupViewMode: String, CaseIterable {
    case list   = "list.bullet"
    case scroll = "rectangle.3.group"
    case alpha  = "textformat.abc"
}

// MARK: - GroupsView

struct GroupsView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.appLanguage)  private var language
    @Binding var selectedTab: Int
    @Binding var albumPageIndex: Int

    @State private var pages: [AlbumPage] = []
    @State private var expandedGroups: Set<String> = []
    @State private var mode: GroupViewMode = .list
    @State private var searchText = ""

    private var isRu: Bool { language.isRussian }

    // MARK: - Grouped data

    private var grouped: [(letter: String, pages: [AlbumPage])] {
        var result: [(String, [AlbumPage])] = []
        var lastLetter = ""
        for page in pages {
            let letter = page.team.groupLetter
            if letter != lastLetter {
                result.append((letter, [page]))
                lastLetter = letter
            } else {
                result[result.count - 1].1.append(page)
            }
        }
        return result
    }

    private var filteredAlpha: [AlbumPage] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let all = pages.sorted {
            let a = isRu ? $0.team.nameRU : $0.team.nameEN
            let b = isRu ? $1.team.nameRU : $1.team.nameEN
            return a < b
        }
        guard !q.isEmpty else { return all }
        return all.filter {
            let name = isRu ? $0.team.nameRU : $0.team.nameEN
            return name.lowercased().contains(q)
                || $0.team.code.lowercased().contains(q)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .list:   listMode
                case .scroll: scrollMode
                case .alpha:  alphaMode
                }
            }
            .navigationTitle(isRu ? "Группы" : "Groups")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    modePicker
                }
            }
        }
        .onAppear { loadPages() }
    }

    // MARK: - Mode picker

    private var modePicker: some View {
        HStack(spacing: 2) {
            ForEach(GroupViewMode.allCases, id: \.self) { m in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { mode = m }
                } label: {
                    Image(systemName: m.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 32, height: 28)
                        .background(
                            mode == m
                                ? Color(.systemGray4)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 7)
                        )
                        .foregroundStyle(mode == m ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Mode 1: List (collapsible groups)

    private var listMode: some View {
        List {
            ForEach(grouped, id: \.letter) { group in
                listGroupSection(group)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func listGroupSection(_ group: (letter: String, pages: [AlbumPage])) -> some View {
        let letter = group.letter
        let isExpanded = expandedGroups.contains(letter)
        let totalPasted = group.pages.reduce(0) { acc, p in
            acc + p.stickers.filter { $0.isPasted || $0.isDuplicate }.count
        }
        let totalStickers = group.pages.reduce(0) { $0 + $1.stickers.count }
        let ratio = totalStickers > 0 ? Double(totalPasted) / Double(totalStickers) : 0

        return Section {
            if isExpanded {
                ForEach(group.pages, id: \.id) { page in
                    listTeamRow(page)
                }
            }
        } header: {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded { expandedGroups.remove(letter) }
                    else          { expandedGroups.insert(letter) }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 14)

                    Text(letter == "FWC" ? "🏆 FIFA World Cup" : "Group \(letter)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)
                        .textCase(nil)

                    Spacer()

                    Text("\(totalPasted)/\(totalStickers)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(nil)

                    ProgressView(value: ratio)
                        .tint(ratio == 1 ? .green : .blue)
                        .frame(width: 50)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func listTeamRow(_ page: AlbumPage) -> some View {
        let pasted = page.stickers.filter { $0.isPasted || $0.isDuplicate }.count
        let total  = page.stickers.count
        let ratio  = total > 0 ? Double(pasted) / Double(total) : 0

        return Button {
            navigateTo(page)
        } label: {
            HStack(spacing: 12) {
                Text(page.team.flagEmoji).font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(isRu ? page.team.nameRU : page.team.nameEN)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                    ProgressView(value: ratio)
                        .tint(ratio == 1 ? .green : .blue)
                        .frame(height: 4)
                }

                Spacer()

                Text("\(pasted)/\(total)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mode 2: Scroll (horizontal groups, teams in one row)

    private var scrollMode: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(grouped, id: \.letter) { group in
                    scrollGroupBlock(group)
                }
            }
            .padding(.vertical, 16)
        }
    }

    private func scrollGroupBlock(_ group: (letter: String, pages: [AlbumPage])) -> some View {
        let totalPasted = group.pages.reduce(0) { acc, p in
            acc + p.stickers.filter { $0.isPasted || $0.isDuplicate }.count
        }
        let totalStickers = group.pages.reduce(0) { $0 + $1.stickers.count }
        let ratio = totalStickers > 0 ? Double(totalPasted) / Double(totalStickers) : 0

        return VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 8) {
                Text(group.letter == "FWC" ? "🏆 FIFA World Cup" : "Group \(group.letter)")
                    .font(.system(size: 15, weight: .bold))
                    .padding(.leading, 16)

                Spacer()

                HStack(spacing: 6) {
                    Text("\(totalPasted)/\(totalStickers)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    ProgressView(value: ratio)
                        .tint(ratio == 1 ? .green : .blue)
                        .frame(width: 60)
                }
                .padding(.trailing, 16)
            }

            // Horizontal row of team cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(group.pages, id: \.id) { page in
                        scrollTeamCard(page)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
        }
    }

    private func scrollTeamCard(_ page: AlbumPage) -> some View {
        let pasted = page.stickers.filter { $0.isPasted || $0.isDuplicate }.count
        let total  = page.stickers.count
        let ratio  = total > 0 ? Double(pasted) / Double(total) : 0
        let color: Color = ratio == 1 ? .green : (ratio > 0 ? .blue : .secondary)

        return Button { navigateTo(page) } label: {
            HStack(spacing: 8) {
                Text(page.team.flagEmoji)
                    .font(.system(size: 22))

                VStack(alignment: .leading, spacing: 3) {
                    Text(isRu ? page.team.nameRU : page.team.nameEN)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(.systemGray5)).frame(height: 4)
                            Capsule()
                                .fill(color)
                                .frame(width: geo.size.width * ratio, height: 4)
                                .animation(.easeInOut(duration: 0.4), value: ratio)
                        }
                    }
                    .frame(height: 4)

                    Text("\(pasted)/\(total)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(width: 160)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mode 3: Alpha list + search

    private var alphaMode: some View {
        List {
            ForEach(filteredAlpha, id: \.id) { page in
                alphaTeamRow(page)
            }
        }
        .listStyle(.insetGrouped)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: isRu ? "Поиск сборной..." : "Search team..."
        )
    }

    private func alphaTeamRow(_ page: AlbumPage) -> some View {
        let pasted = page.stickers.filter { $0.isPasted || $0.isDuplicate }.count
        let total  = page.stickers.count
        let ratio  = total > 0 ? Double(pasted) / Double(total) : 0
        let color: Color = ratio == 1 ? .green : (ratio > 0 ? .blue : .secondary)

        return Button { navigateTo(page) } label: {
            HStack(spacing: 12) {
                Text(page.team.flagEmoji).font(.title3)

                VStack(alignment: .leading, spacing: 3) {
                    Text(isRu ? page.team.nameRU : page.team.nameEN)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)

                    Text(isRu
                         ? (page.team.groupLetter == "FWC" ? "🏆 FIFA World Cup" : "Группа \(page.team.groupLetter)")
                         : (page.team.groupLetter == "FWC" ? "🏆 FIFA World Cup" : "Group \(page.team.groupLetter)"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(pasted)/\(total)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(.systemGray5)).frame(height: 4)
                            Capsule()
                                .fill(color)
                                .frame(width: geo.size.width * ratio, height: 4)
                                .animation(.easeInOut(duration: 0.4), value: ratio)
                        }
                    }
                    .frame(width: 60, height: 4)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Navigation helper

    private func navigateTo(_ page: AlbumPage) {
        if let idx = pages.firstIndex(where: { $0.id == page.id }) {
            albumPageIndex = idx
            selectedTab = 1
        }
    }

    // MARK: - Load

    private func loadPages() {
        let teamDesc = FetchDescriptor<TeamModel>(sortBy: [SortDescriptor(\.orderIndex)])
        let teams = (try? context.fetch(teamDesc)) ?? []
        let stickerDesc = FetchDescriptor<StickerModel>(sortBy: [SortDescriptor(\.number)])
        let allStickers = (try? context.fetch(stickerDesc)) ?? []

        var byCode: [String: [StickerModel]] = [:]
        for s in allStickers { byCode[s.teamCode, default: []].append(s) }

        pages = teams.map { AlbumPage(id: $0.code, team: $0, stickers: byCode[$0.code] ?? []) }
    }
}
