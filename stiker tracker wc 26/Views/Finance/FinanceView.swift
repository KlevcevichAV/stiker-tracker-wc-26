import SwiftUI
import SwiftData

struct FinanceView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.appLanguage)  private var language

    @Query(sort: \PurchaseModel.date, order: .reverse)
    private var purchases: [PurchaseModel]

    @Query
    private var allStickers: [StickerModel]

    @Query(filter: #Predicate<ExchangeModel> { $0.statusRaw == "completed" })
    private var completedExchanges: [ExchangeModel]

    @State private var showAdd = false
    @State private var editingPurchase: PurchaseModel? = nil

    private var isRu: Bool { language.isRussian }

    private var totalSpent: Double  { purchases.reduce(0) { $0 + $1.totalCost } }
    private var totalStickers: Int  { purchases.reduce(0) { $0 + $1.stickerCount } }

    /// Реальное кол-во наклеек: вклеенные + все дубли
    private var actualStickers: Int {
        allStickers.reduce(0) { sum, s in
            switch s.status {
            case .missing:   return sum
            case .pasted:    return sum + 1
            case .duplicate: return sum + 1 + s.duplicateCount
            }
        }
    }

    /// Суммарная дельта завершённых обменов (получено − отдано).
    /// При всех 1:1 обменах = 0. Учитывается в ожидаемом кол-ве.
    private var exchangeNetDelta: Int {
        completedExchanges.reduce(0) { $0 + $1.netStickerDelta }
    }

    /// Ожидаемое итоговое кол-во: куплено ± дельта обменов
    private var expectedStickers: Int { totalStickers + exchangeNetDelta }

    private var stickerDiff: Int { actualStickers - expectedStickers }

    var body: some View {
        NavigationStack {
            Group {
                if purchases.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .navigationTitle(isRu ? "Финансы" : "Finances")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus").fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddPurchaseView()
                    .environment(\.appLanguage, language)
            }
            .sheet(item: $editingPurchase) { purchase in
                AddPurchaseView(purchase: purchase)
                    .environment(\.appLanguage, language)
            }
        }
        .environment(\.appLanguage, language)
    }

    // MARK: - Summary + list

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                summaryCard
                if totalStickers > 0 {
                    stickerComparisonCard
                }
                purchaseList
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Sticker comparison card

    private var stickerComparisonCard: some View {
        let match = stickerDiff == 0
        let accent: Color = match ? .green : .orange

        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: match ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(accent)
                Text(isRu ? "Сверка наклеек" : "Sticker check")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                if !match {
                    Text(stickerDiff > 0
                         ? (isRu ? "+\(stickerDiff) лишних" : "+\(stickerDiff) extra")
                         : (isRu ? "\(stickerDiff) недостача" : "\(stickerDiff) missing"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(accent.opacity(0.12), in: Capsule())
                }
            }

            HStack(spacing: 0) {
                comparisonCell(
                    label: isRu ? "Куплено" : "Purchased",
                    value: totalStickers,
                    color: .secondary
                )
                Divider().frame(height: 32)
                if exchangeNetDelta != 0 {
                    comparisonCell(
                        label: isRu ? "Обмены" : "Trades",
                        value: exchangeNetDelta,
                        color: exchangeNetDelta > 0 ? .teal : .orange,
                        showSign: true
                    )
                    Divider().frame(height: 32)
                }
                comparisonCell(
                    label: isRu ? "Ожидается" : "Expected",
                    value: expectedStickers,
                    color: .secondary
                )
                Divider().frame(height: 32)
                comparisonCell(
                    label: isRu ? "В альбоме" : "In album",
                    value: actualStickers,
                    color: .secondary
                )
                Divider().frame(height: 32)
                comparisonCell(
                    label: isRu ? "Разница" : "Diff",
                    value: stickerDiff,
                    color: match ? .green : .orange,
                    showSign: true
                )
            }
            .padding(.vertical, 4)
            .background(accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))

            if !match {
                Text(stickerDiff > 0
                     ? (isRu
                        ? "В альбоме больше наклеек, чем ожидалось — возможно, не все покупки или обмены записаны"
                        : "More stickers in album than expected — some purchases or trades may not be recorded")
                     : (isRu
                        ? "В альбоме меньше наклеек, чем ожидалось — возможно, не все покупки или обмены записаны"
                        : "Fewer stickers in album than expected — some purchases or trades may not be recorded"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(match ? Color.clear : accent.opacity(0.35), lineWidth: 1.5)
        )
    }

    private func comparisonCell(label: String, value: Int, color: Color, showSign: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(showSign && value != 0 ? (value > 0 ? "+\(value)" : "\(value)") : "\(value)")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        HStack(spacing: 0) {
            summaryCell(
                icon: "banknote.fill",
                color: .green,
                title: isRu ? "Потрачено" : "Spent",
                value: formatMoney(totalSpent)
            )

            Divider().frame(height: 40)

            summaryCell(
                icon: "square.on.square.fill",
                color: .orange,
                title: isRu ? "Куплено наклеек" : "Stickers bought",
                value: "\(totalStickers)"
            )

            if totalStickers > 0 {
                Divider().frame(height: 40)

                summaryCell(
                    icon: "tag.fill",
                    color: .blue,
                    title: isRu ? "За наклейку" : "Per sticker",
                    value: formatMoney(totalSpent / Double(totalStickers))
                )
            }
        }
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16))
    }

    private func summaryCell(icon: String, color: Color, title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 17, weight: .black, design: .rounded))
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    // MARK: - List

    private var purchaseList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(purchases) { purchase in
                purchaseRow(purchase)
                    .contentShape(Rectangle())
                    .onTapGesture { editingPurchase = purchase }

                if purchase.id != purchases.last?.id {
                    Divider().padding(.leading, 52)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16))
    }

    private func purchaseRow(_ purchase: PurchaseModel) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(kindColor(purchase.kind).opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: purchase.kind.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(kindColor(purchase.kind))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(isRu ? purchase.kind.nameRU : purchase.kind.nameEN)
                        .font(.system(size: 14, weight: .semibold))
                    if purchase.quantity > 1 {
                        Text("×\(purchase.quantity)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    Text(purchase.date, style: .date)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    if purchase.stickerCount > 0 {
                        Text("·")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 11))
                        Text(isRu
                             ? "\(purchase.stickerCount) накл."
                             : "\(purchase.stickerCount) stickers")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatMoney(purchase.totalCost))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                if purchase.quantity > 1 {
                    Text(formatMoney(purchase.price) + (isRu ? "/ед." : "/ea"))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                context.delete(purchase)
                try? context.save()
            } label: {
                Label(isRu ? "Удалить" : "Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "banknote")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(isRu ? "Покупок нет" : "No purchases")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(isRu
                 ? "Нажми «+», чтобы добавить покупку"
                 : "Tap «+» to add a purchase")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button {
                showAdd = true
            } label: {
                Label(isRu ? "Добавить покупку" : "Add purchase", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.green.opacity(0.15))
                    .foregroundStyle(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showAdd) {
            AddPurchaseView()
                .environment(\.appLanguage, language)
        }
    }

    // MARK: - Helpers

    private func kindColor(_ kind: PurchaseKind) -> Color {
        switch kind {
        case .album:    return .blue
        case .pack:     return .teal
        case .blister3: return .orange
        case .blister8: return .purple
        }
    }

    private func formatMoney(_ value: Double) -> String {
        String(format: value.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f Br" : "%.2f Br", value)
    }
}
