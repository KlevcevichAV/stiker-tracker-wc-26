import SwiftUI
import SwiftData

struct CountriesView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.appLanguage)  private var language
    @Binding var selectedTab: Int
    @Binding var albumPageIndex: Int

    @State private var pages: [AlbumPage] = []
    @State private var searchText = ""

    private var isRu: Bool { language.isRussian }

    private var sorted: [AlbumPage] {
        let filtered: [AlbumPage]
        if searchText.isEmpty {
            filtered = pages
        } else {
            let q = searchText.lowercased()
            filtered = pages.filter {
                $0.team.nameEN.lowercased().contains(q) ||
                $0.team.nameRU.lowercased().contains(q)
            }
        }
        return filtered.sorted {
            let a = isRu ? $0.team.nameRU : $0.team.nameEN
            let b = isRu ? $1.team.nameRU : $1.team.nameEN
            return a < b
        }
    }

    var body: some View {
        NavigationStack {
            List(sorted, id: \.id) { page in
                teamRow(page)
            }
            .listStyle(.insetGrouped)
            .navigationTitle(isRu ? "Страны" : "Countries")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: isRu ? "Поиск" : "Search")
        }
        .onAppear { loadPages() }
    }

    // MARK: - Team row

    private func teamRow(_ page: AlbumPage) -> some View {
        let pasted = page.stickers.filter { $0.isPasted || $0.isDuplicate }.count
        let total  = page.stickers.count
        let ratio  = total > 0 ? Double(pasted) / Double(total) : 0

        return Button {
            if let idx = pages.firstIndex(where: { $0.id == page.id }) {
                albumPageIndex = idx
                selectedTab = 2
            }
        } label: {
            HStack(spacing: 12) {
                Text(page.team.flagEmoji)
                    .font(.title3)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(isRu ? page.team.nameRU : page.team.nameEN)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        if page.team.groupLetter != "FWC" {
                            Text("Group \(page.team.groupLetter)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(value: ratio)
                            .tint(ratio == 1 ? .green : .blue)
                            .frame(height: 3)
                    }
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
