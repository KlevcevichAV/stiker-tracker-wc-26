import SwiftUI

/// Лист-оглавление альбома: список всех команд/секций,
/// тап — прыжок на нужную страницу с закрытием шита.
struct TableOfContentsView: View {

    @Environment(\.dismiss) private var dismiss

    let pages: [AlbumPage]
    @Binding var currentIndex: Int

    // Группируем по groupLetter для секций
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

    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped, id: \.letter) { group in
                    Section(header: sectionHeader(group.letter)) {
                        ForEach(Array(group.pages.enumerated()), id: \.element.id) { _, page in
                            teamRow(page)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(
                Locale.current.language.languageCode?.identifier == "ru"
                    ? "Оглавление"
                    : "Contents"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sub-views

    private func sectionHeader(_ letter: String) -> some View {
        Text(letter == "FWC" ? "🏆 FIFA World Cup" : "Group \(letter)")
            .font(.system(size: 12, weight: .bold))
            .textCase(nil)
    }

    private func teamRow(_ page: AlbumPage) -> some View {
        let pasted = page.stickers.filter { $0.isPasted || $0.isDuplicate }.count
        let total  = page.stickers.count
        let ratio  = total > 0 ? Double(pasted) / Double(total) : 0

        return Button {
            if let idx = pages.firstIndex(where: { $0.id == page.id }) {
                currentIndex = idx
            }
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Text(page.team.flagEmoji)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(localizedName(page.team))
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

    private func localizedName(_ team: TeamModel) -> String {
        Locale.current.language.languageCode?.identifier == "ru"
            ? team.nameRU : team.nameEN
    }
}
