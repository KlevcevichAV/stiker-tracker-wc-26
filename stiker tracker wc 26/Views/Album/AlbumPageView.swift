import SwiftUI

/// Одна страница альбома — шапка команды + сетка наклеек.
/// Имитирует страницу бумажного альбома Panini.
struct AlbumPageView: View {

    let page: AlbumPage

    // 4 колонки как в настоящем альбоме Panini
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    @Environment(\.appLanguage) private var language

    private var isRu: Bool { language.isRussian }

    private var localizedTeamName: String {
        isRu ? page.team.nameRU : page.team.nameEN
    }

    // Пересчитывается автоматически благодаря @Observable на StickerModel через SwiftData
    private var pastedCount: Int {
        page.stickers.filter { $0.status != .missing }.count
    }

    var body: some View {
        ZStack {
            pageBackground
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    pageHeader
                    stickerGrid
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Sub-views

    private var pageBackground: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.99, green: 0.98, blue: 0.94),
                        Color(red: 0.96, green: 0.95, blue: 0.90)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            // Тонкая тень по правому краю — имитация толщины бумаги
            .shadow(color: .black.opacity(0.12), radius: 4, x: 2, y: 0)
    }

    private var pageHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text(page.team.flagEmoji)
                    .font(.system(size: 28))

                VStack(alignment: .leading, spacing: 1) {
                    Text(localizedTeamName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    if page.team.groupLetter != "FWC" {
                        Text("Group \(page.team.groupLetter)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Прогресс-бейдж
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(pastedCount)/\(page.stickers.count)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(progressColor)

                    ProgressView(value: Double(pastedCount),
                                 total: Double(max(page.stickers.count, 1)))
                        .tint(progressColor)
                        .frame(width: 60)
                }
            }

            // Разделитель с декоративными линиями
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color(.systemGray3))
                    .frame(height: 1)
                Circle()
                    .fill(Color(.systemGray3))
                    .frame(width: 4, height: 4)
                Rectangle()
                    .fill(Color(.systemGray3))
                    .frame(height: 1)
            }
        }
        .padding(.bottom, 10)
    }

    private var stickerGrid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(page.stickers, id: \.id) { sticker in
                StickerCell(sticker: sticker)
            }
        }
    }

    private var progressColor: Color {
        let ratio = Double(pastedCount) / Double(max(page.stickers.count, 1))
        switch ratio {
        case 1.0:         return .green
        case 0.5..<1.0:   return .orange
        default:          return .secondary
        }
    }
}
