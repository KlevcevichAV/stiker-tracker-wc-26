import SwiftUI

struct PartnerStat: Identifiable {
    let id: String  // partner name (or "" for anonymous)
    let completed: Int
    let active: Int
    let cancelled: Int

    // Детали для раскрывашки
    let stickersGiven: Int        // сколько наклеек отдал (завершённые + активные)
    let stickersReceived: Int     // сколько наклеек получил (завершённые + активные)
    let cancellationReasons: [(CancellationReason, Int)]  // [(reason, count)]
    let trust: TrustLevel?

    var total: Int { completed + active + cancelled }
    var displayName: String { id.isEmpty ? "—" : id }
    var hasDetails: Bool {
        (completed > 0 || active > 0) || !cancellationReasons.isEmpty
    }
}

struct PartnerStatsView: View {

    let exchanges: [ExchangeModel]
    @Environment(\.appLanguage) private var language

    @State private var expandedIDs: Set<String> = []

    private var isRu: Bool { language.isRussian }

    private var stats: [PartnerStat] {
        var groups: [String: [ExchangeModel]] = [:]
        for ex in exchanges {
            groups[ex.partner, default: []].append(ex)
        }
        return groups
            .map { name, list in
                let completedList = list.filter { $0.status == .completed }
                let activeList    = list.filter { $0.status == .active    }
                let cancelledList = list.filter { $0.status == .cancelled }

                let relevantForCount = completedList + activeList
                let given    = relevantForCount.reduce(0) { $0 + $1.giving.reduce(0)  { $0 + $1.count } }
                let received = relevantForCount.reduce(0) { $0 + $1.wanting.reduce(0) { $0 + $1.count } }

                var reasonCounts: [CancellationReason: Int] = [:]
                for ex in cancelledList {
                    if let r = ex.cancellationReason {
                        reasonCounts[r, default: 0] += 1
                    }
                }
                let reasons = CancellationReason.allCases
                    .compactMap { r -> (CancellationReason, Int)? in
                        guard let c = reasonCounts[r] else { return nil }
                        return (r, c)
                    }

                return PartnerStat(
                    id: name,
                    completed: completedList.count,
                    active:    activeList.count,
                    cancelled: cancelledList.count,
                    stickersGiven:    given,
                    stickersReceived: received,
                    cancellationReasons: reasons,
                    trust: TrustLevel.compute(for: name, in: list)
                )
            }
            .sorted { $0.total > $1.total }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(stats) { stat in
                    partnerRow(stat)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(isRu ? "Статистика партнёров" : "Partner Stats")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func partnerRow(_ stat: PartnerStat) -> some View {
        let isExpanded = expandedIDs.contains(stat.id)

        return VStack(alignment: .leading, spacing: 8) {
            // Заголовок
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .foregroundStyle(.teal)
                    .font(.system(size: 18))
                Text(stat.displayName)
                    .font(.system(size: 15, weight: .semibold))
                if let trust = stat.trust {
                    Label(isRu ? trust.nameRU : trust.nameEN, systemImage: trust.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(trust.color)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(trust.color.opacity(0.1), in: Capsule())
                }
                Spacer()
                Text(isRu ? "\(stat.total) обм." : "\(stat.total) exch.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                if stat.hasDetails {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard stat.hasDetails else { return }
                if isExpanded {
                    expandedIDs.remove(stat.id)
                } else {
                    expandedIDs.insert(stat.id)
                }
            }

            // Счётчики статусов
            HStack(spacing: 12) {
                statChip(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    value: stat.completed,
                    label: isRu ? "Завершено" : "Done"
                )
                statChip(
                    icon: "arrow.2.squarepath",
                    color: .teal,
                    value: stat.active,
                    label: isRu ? "Активных" : "Active"
                )
                statChip(
                    icon: "xmark.circle.fill",
                    color: .red,
                    value: stat.cancelled,
                    label: isRu ? "Отменено" : "Cancelled"
                )
            }

            // Раскрытые детали
            if isExpanded {
                Divider()

                // Кол-во обменянных наклеек
                if stat.completed > 0 || stat.active > 0 {
                    HStack(spacing: 16) {
                        stickerCountCell(
                            icon: "arrow.up.circle.fill",
                            color: .teal,
                            value: stat.stickersGiven,
                            label: isRu ? "Отдал" : "Gave"
                        )
                        stickerCountCell(
                            icon: "arrow.down.circle.fill",
                            color: .green,
                            value: stat.stickersReceived,
                            label: isRu ? "Получил" : "Received"
                        )
                    }
                    .padding(.horizontal, 4)
                }

                // Причины отказов
                if !stat.cancellationReasons.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isRu ? "Причины отказов" : "Cancellation reasons")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        ForEach(stat.cancellationReasons, id: \.0) { reason, count in
                            HStack(spacing: 8) {
                                Image(systemName: reason.icon)
                                    .font(.system(size: 13))
                                    .foregroundStyle(reason.color)
                                    .frame(width: 18)
                                Text(isRu ? reason.nameRU : reason.nameEN)
                                    .font(.system(size: 13))
                                Spacer()
                                Text("\(count)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(reason.color)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }

    private func statChip(icon: String, color: Color, value: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(value > 0 ? .primary : .secondary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private func stickerCountCell(icon: String, color: Color, value: Int, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}
