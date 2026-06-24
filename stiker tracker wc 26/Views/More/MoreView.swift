import SwiftUI

struct MoreView: View {

    @Environment(\.appLanguage) private var language
    var achievements: AchievementsManager

    private var isRu: Bool { language.isRussian }

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    StatsView()
                } label: {
                    moreRow(icon: "chart.bar.fill", color: .blue,
                            title: isRu ? "Статистика" : "Statistics",
                            subtitle: isRu ? "Прогресс по группам и странам" : "Progress by groups and countries")
                }

                NavigationLink {
                    AchievementsView()
                        .environment(\.achievementsManager, achievements)
                } label: {
                    moreRow(icon: "medal.fill", color: .yellow,
                            title: isRu ? "Достижения" : "Achievements",
                            subtitle: isRu ? "Разблокированные награды" : "Unlocked awards")
                }

                NavigationLink {
                    DuplicatesView()
                        .environment(\.achievementsManager, achievements)
                } label: {
                    moreRow(icon: "square.on.square.fill", color: .orange,
                            title: isRu ? "Дубликаты" : "Duplicates",
                            subtitle: isRu ? "Лишние наклейки" : "Extra stickers")
                }

                NavigationLink {
                    ExchangeView()
                        .environment(\.achievementsManager, achievements)
                } label: {
                    moreRow(icon: "arrow.2.squarepath", color: .teal,
                            title: isRu ? "Обмен" : "Exchange",
                            subtitle: isRu ? "Создать и отслеживать обмены наклейками" : "Create and track sticker exchanges")
                }

                NavigationLink {
                    TradeAnalysisView()
                } label: {
                    moreRow(icon: "arrow.triangle.2.circlepath.circle.fill", color: .purple,
                            title: isRu ? "Анализ обменов" : "Trade Analysis",
                            subtitle: isRu ? "Сопоставить стикеры с другим коллекционером" : "Match stickers with others")
                }

                NavigationLink {
                    TradeMessageView()
                } label: {
                    moreRow(icon: "arrow.left.arrow.right.circle.fill", color: .green,
                            title: isRu ? "Сообщение для обмена" : "Trade Message",
                            subtitle: isRu ? "Список нужных и лишних наклеек" : "Needed and duplicate stickers")
                }

                NavigationLink {
                    FinanceView()
                        .environment(\.appLanguage, language)
                } label: {
                    moreRow(icon: "banknote.fill", color: .green,
                            title: isRu ? "Финансы" : "Finances",
                            subtitle: isRu ? "Учёт расходов на коллекцию" : "Track collection expenses")
                }

                NavigationLink {
                    SettingsView()
                } label: {
                    moreRow(icon: "gearshape.fill", color: .gray,
                            title: isRu ? "Настройки" : "Settings",
                            subtitle: isRu ? "Язык и параметры" : "Language and preferences")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(isRu ? "Ещё" : "More")
            .navigationBarTitleDisplayMode(.large)
        }
        .environment(\.appLanguage, language)
        .environment(\.achievementsManager, achievements)
    }

    private func moreRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
