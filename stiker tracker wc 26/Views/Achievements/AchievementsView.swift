import SwiftUI
import SwiftData

/// Экран достижений — сгруппированные карточки наград.
struct AchievementsView: View {

    @Environment(\.modelContext)        private var context
    @Environment(\.achievementsManager) private var manager
    @Environment(\.appLanguage)         private var language

    private var isRu: Bool { language.isRussian }

    // Группируем каталог по категориям
    private var grouped: [(AchievementCategory, [AchievementDefinition])] {
        let order: [AchievementCategory] = [
            .superstar, .starHunter, .team, .worldRuler, .centurion, .milestone
        ]
        return order.compactMap { cat in
            let items = AchievementDefinition.all.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }

    private var unlockedCount: Int {
        AchievementDefinition.all.filter { manager.isUnlocked($0.id) }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    globalProgressCard
                    ForEach(grouped, id: \.0) { cat, defs in
                        categorySection(cat, defs: defs)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isRu ? "Достижения" : "Achievements")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear { manager.load(context: context) }
    }

    // MARK: - Global progress card

    private var globalProgressCard: some View {
        let total    = AchievementDefinition.all.count
        let unlocked = unlockedCount
        let ratio    = total > 0 ? Double(unlocked) / Double(total) : 0

        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: ratio)
                    .stroke(
                        LinearGradient(colors: [.yellow, .orange],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: ratio)

                VStack(spacing: 0) {
                    Text("\(Int((ratio * 100).rounded()))%")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                    Text(isRu ? "готово" : "done")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(isRu ? "Всего достижений" : "Total Achievements")
                    .font(.system(size: 13, weight: .bold))
                Text("\(unlocked) / \(total)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Text(isRu ? "разблокировано" : "unlocked")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Category section

    private func categorySection(_ cat: AchievementCategory,
                                  defs: [AchievementDefinition]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(cat.localizedTitle(isRu: isRu).uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 8) {
                ForEach(defs) { def in
                    achievementCard(def)
                }
            }
        }
    }

    // MARK: - Achievement card

    private func achievementCard(_ def: AchievementDefinition) -> some View {
        let unlocked = manager.isUnlocked(def.id)
        let date     = unlocked ? manager.unlockedDate(for: def.id, context: context) : nil

        return HStack(spacing: 14) {
            // Иконка
            ZStack {
                Circle()
                    .fill(unlocked ? iconGradient(def) : AnyShapeStyle(Color(.systemGray5)))
                    .frame(width: 46, height: 46)

                Image(systemName: def.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(unlocked ? .white : Color(.systemGray3))
            }
            .overlay(
                unlocked
                    ? AnyView(Circle().strokeBorder(iconColor(def).opacity(0.4), lineWidth: 1.5))
                    : AnyView(EmptyView())
            )

            // Текст
            VStack(alignment: .leading, spacing: 3) {
                Text(def.localizedTitle(isRu: isRu))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(unlocked ? .primary : Color(.systemGray3))
                    .lineLimit(1)

                Text(def.localizedDesc(isRu: isRu))
                    .font(.system(size: 11))
                    .foregroundStyle(unlocked ? .secondary : Color(.systemGray4))
                    .lineLimit(2)

                if let date {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 10))
                        .foregroundStyle(iconColor(def).opacity(0.8))
                }
            }

            Spacer()

            // Статус
            if unlocked {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(iconColor(def))
                    .font(.system(size: 20))
            } else {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Color(.systemGray4))
                    .font(.system(size: 16))
            }
        }
        .padding(12)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay(
            unlocked
                ? AnyView(RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(iconColor(def).opacity(0.25), lineWidth: 1))
                : AnyView(EmptyView())
        )
    }

    // MARK: - Style helpers

    private func iconColor(_ def: AchievementDefinition) -> Color {
        switch def.category {
        case .superstar:   return .yellow
        case .starHunter:  return .orange
        case .team:        return .green
        case .worldRuler:  return .purple
        case .centurion:   return .blue
        case .milestone:   return .cyan
        }
    }

    private func iconGradient(_ def: AchievementDefinition) -> AnyShapeStyle {
        let c = iconColor(def)
        return AnyShapeStyle(
            LinearGradient(colors: [c.opacity(0.7), c],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
        )
    }
}
