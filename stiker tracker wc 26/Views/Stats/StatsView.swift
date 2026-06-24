import SwiftUI
import SwiftData

struct StatsView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.appLanguage)  private var language

    @State private var stats = StatsViewModel()

    private var isRu: Bool { language.isRussian }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    overallCard
                    groupsSection
                    countriesSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isRu ? "Статистика" : "Statistics")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear { stats.refresh(context: context) }
    }

    // MARK: - Overall card

    private var overallCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                // Круговой прогресс
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: stats.album.percent)
                        .stroke(
                            LinearGradient(colors: [.blue, .cyan],
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.8), value: stats.album.percent)
                    VStack(spacing: 2) {
                        Text(stats.album.percentString)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                        Text(isRu ? "собрано" : "collected")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 90, height: 90)

                VStack(alignment: .leading, spacing: 10) {
                    statRow(icon: "checkmark.circle.fill", color: .green,
                            label: isRu ? "Вклеено" : "Pasted",
                            value: "\(stats.album.pasted)",
                            pending: stats.pendingIncoming > 0
                                ? "+\(stats.pendingIncoming)"
                                : nil,
                            pendingColor: .green)
                    statRow(icon: "circle.dashed", color: .secondary,
                            label: isRu ? "Осталось" : "Missing",
                            value: "\(stats.album.total - stats.album.pasted)",
                            pending: stats.pendingIncoming > 0
                                ? "-\(stats.pendingIncoming)"
                                : nil,
                            pendingColor: .green)
                    statRow(icon: "square.on.square.fill", color: .orange,
                            label: isRu ? "Дубликатов" : "Duplicates",
                            value: "\(stats.totalDuplicates)",
                            pending: stats.pendingReserved > 0
                                ? "-\(stats.pendingReserved)"
                                : nil,
                            pendingColor: .orange)
                }

                Spacer()
            }

            // Линейный прогресс
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(colors: [.blue, .cyan],
                                                 startPoint: .leading,
                                                 endPoint: .trailing))
                            .frame(width: geo.size.width * stats.album.percent)
                            .animation(.easeInOut(duration: 0.8), value: stats.album.percent)
                    }
                }
                .frame(height: 12)

                HStack {
                    Text("\(stats.album.pasted) / \(stats.album.total)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(isRu ? "📖 Panini WC 2026" : "📖 Panini WC 2026")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Groups slider

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isRu ? "По группам" : "By Group")
                .font(.system(size: 17, weight: .bold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(stats.groups, id: \.letter) { group in
                        groupCard(group)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
    }

    private func groupCard(_ group: GroupStat) -> some View {
        let title = group.letter == "FWC" ? "🏆 FIFA WC" : "Group \(group.letter)"
        let missing = group.progress.total - group.progress.pasted

        return VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)

            // Мини-круг
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: group.progress.percent)
                    .stroke(progressColor(group.progress.percent),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(group.progress.percentString)
                    .font(.system(size: 13, weight: .black, design: .rounded))
            }
            .frame(width: 60, height: 60)
            .frame(maxWidth: .infinity)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                miniStat(color: .green,  label: isRu ? "Собрано" : "Collected", value: group.progress.pasted)
                miniStat(color: .gray,   label: isRu ? "Осталось" : "Missing",  value: missing)
                miniStat(color: .orange, label: isRu ? "Дублей" : "Dupes",      value: group.duplicates)
            }
        }
        .padding(12)
        .frame(width: 140)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Countries slider

    private var countriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isRu ? "По странам" : "By Country")
                .font(.system(size: 17, weight: .bold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(stats.teamsSortedAlpha, id: \.code) { team in
                        countryCard(team)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
    }

    private func countryCard(_ team: TeamStat) -> some View {
        let missing = team.progress.total - team.progress.pasted

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(team.flagEmoji)
                    .font(.system(size: 20))
                Text(isRu ? team.nameRU : team.nameEN)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 8)
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor(team.progress.percent))
                        .frame(width: geo.size.width * team.progress.percent, height: 8)
                }
                .frame(height: 8)
            }

            Text(team.progress.percentString)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(progressColor(team.progress.percent))

            Divider()

            VStack(alignment: .leading, spacing: 3) {
                miniStat(color: .green,  label: isRu ? "Собрано" : "Collected", value: team.progress.pasted)
                miniStat(color: .gray,   label: isRu ? "Осталось" : "Missing",  value: missing)
                miniStat(color: .orange, label: isRu ? "Дублей" : "Dupes",      value: team.duplicates)
            }
        }
        .padding(12)
        .frame(width: 150)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Helpers

    private func statRow(icon: String, color: Color, label: String, value: String,
                         pending: String? = nil, pendingColor: Color = .secondary) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                if let pending {
                    Text("(\(pending))")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(pendingColor.opacity(0.8))
                }
            }
        }
    }

    private func miniStat(color: Color, label: String, value: Int) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
    }

    private func progressColor(_ percent: Double) -> Color {
        switch percent {
        case 1.0:       return .green
        case 0.5..<1.0: return .orange
        default:        return .blue
        }
    }
}
