import SwiftUI

/// Шит с полной статистикой: глобальный прогресс + разбивка по группам.
struct StatsSheet: View {

    @Environment(\.dismiss) private var dismiss
    let stats: StatsViewModel

    private var isRu: Bool {
        Locale.current.language.languageCode?.identifier == "ru"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    globalCard
                    groupsList
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isRu ? "Статистика" : "Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isRu ? "Готово" : "Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Global card

    private var globalCard: some View {
        VStack(spacing: 14) {
            HStack {
                Label(
                    isRu ? "Весь альбом" : "Full Album",
                    systemImage: "book.closed.fill"
                )
                .font(.system(size: 15, weight: .bold))
                Spacer()
                Text(stats.album.percentString)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(progressColor(stats.album.percent))
            }

            // Широкая полоса прогресса
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(height: 12)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(progressGradient(stats.album.percent))
                        .frame(width: geo.size.width * stats.album.percent, height: 12)
                        .animation(.easeInOut(duration: 0.5), value: stats.album.percent)
                }
            }
            .frame(height: 12)

            HStack {
                statPill(
                    label: isRu ? "Вклеено" : "Pasted",
                    value: "\(stats.album.pasted)",
                    color: .blue
                )
                statPill(
                    label: isRu ? "Осталось" : "Missing",
                    value: "\(stats.album.total - stats.album.pasted)",
                    color: .secondary
                )
                statPill(
                    label: isRu ? "Всего" : "Total",
                    value: "\(stats.album.total)",
                    color: .primary
                )
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Groups list

    private var groupsList: some View {
        VStack(spacing: 12) {
            ForEach(stats.groups, id: \.letter) { group in
                groupCard(group)
            }
        }
    }

    private func groupCard(_ group: GroupStat) -> some View {
        VStack(spacing: 10) {
            // Заголовок группы
            HStack {
                Text(group.letter == "FWC" ? "🏆 FIFA World Cup" : "Group \(group.letter)")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Text(group.progress.absoluteString)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(group.progress.percentString)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(progressColor(group.progress.percent))
                    .frame(minWidth: 38, alignment: .trailing)
            }

            // Суммарная полоса группы
            ProgressView(value: group.progress.percent)
                .tint(progressColor(group.progress.percent))
                .scaleEffect(x: 1, y: 1.4)

            // Команды группы
            VStack(spacing: 6) {
                ForEach(group.teams, id: \.code) { team in
                    teamRow(team)
                }
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14))
    }

    private func teamRow(_ team: TeamStat) -> some View {
        HStack(spacing: 10) {
            Text(team.flagEmoji)
                .font(.system(size: 18))

            Text(isRu ? team.nameRU : team.nameEN)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            Spacer()

            // Мини полоска
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5)).frame(height: 5)
                    Capsule()
                        .fill(progressColor(team.progress.percent))
                        .frame(width: geo.size.width * team.progress.percent, height: 5)
                        .animation(.easeInOut(duration: 0.4), value: team.progress.percent)
                }
            }
            .frame(width: 70, height: 5)

            Text(team.progress.absoluteString)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }

    // MARK: - Helpers

    private func statPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
    }

    private func progressColor(_ ratio: Double) -> Color {
        switch ratio {
        case 1.0:        return .green
        case 0.5..<1.0:  return .orange
        case 0.01..<0.5: return .blue
        default:         return .secondary
        }
    }

    private func progressGradient(_ ratio: Double) -> LinearGradient {
        let color = progressColor(ratio)
        return LinearGradient(
            colors: [color.opacity(0.7), color],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
