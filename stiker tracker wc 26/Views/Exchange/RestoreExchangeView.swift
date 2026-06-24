import SwiftUI
import SwiftData

struct RestoreExchangeView: View {

    @Environment(\.modelContext)        private var context
    @Environment(\.dismiss)             private var dismiss
    @Environment(\.achievementsManager) private var achievements
    @Environment(\.appLanguage)         private var language

    let exchange: ExchangeModel

    @Query private var allStickers: [StickerModel]
    @Query(filter: #Predicate<ExchangeModel> { $0.statusRaw == "active" })
    private var activeExchanges: [ExchangeModel]

    private var isRu: Bool { language.isRussian }

    // MARK: - Validation

    private var stickerIndex: [String: StickerModel] {
        Dictionary(uniqueKeysWithValues: allStickers.map { ($0.id, $0) })
    }

    struct EntryIssue: Identifiable {
        let id: String      // stickerId
        let entry: StickerEntry
        let reason: String
    }

    /// Карточки в "Отдаю", для которых недостаточно дублей
    private var givingIssues: [EntryIssue] {
        exchange.giving.compactMap { entry in
            let sid = "\(entry.teamCode)\(entry.number)"
            let sticker = stickerIndex[sid]
            let dupes    = sticker?.duplicateCount ?? 0
            let reserved = ExchangeService.reservedCount(for: sid, in: activeExchanges)
            let available = dupes - reserved
            guard available < entry.count else { return nil }
            let reason = isRu
                ? "Нужно ×\(entry.count), доступно ×\(max(0, available))"
                : "Need ×\(entry.count), available ×\(max(0, available))"
            return EntryIssue(id: sid, entry: entry, reason: reason)
        }
    }

    /// Карточки в "Получаю", которые уже есть в альбоме (предупреждение, не блокировка)
    private var wantingWarnings: [EntryIssue] {
        exchange.wanting.compactMap { entry in
            let sid = "\(entry.teamCode)\(entry.number)"
            guard let sticker = stickerIndex[sid], sticker.status != .missing else { return nil }
            let reason = isRu
                ? sticker.status == .pasted ? "Уже вклеена" : "Уже есть дубль"
                : sticker.status == .pasted ? "Already pasted" : "Duplicate exists"
            return EntryIssue(id: sid, entry: entry, reason: reason)
        }
    }

    private var isValid: Bool { givingIssues.isEmpty }
    private var hasWarnings: Bool { !wantingWarnings.isEmpty }

    private var invalidGivingIDs: Set<String> { Set(givingIssues.map(\.id)) }
    private var warnWantingIDs:   Set<String> { Set(wantingWarnings.map(\.id)) }

    @State private var wantingAcknowledged = false

    private var canRestore: Bool {
        isValid && (wantingWarnings.isEmpty || wantingAcknowledged)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    validationBanner
                    exchangeColumns
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isRu ? "Восстановить обмен" : "Restore Exchange")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isRu ? "Отмена" : "Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                restoreButton
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
            }
        }
    }

    // MARK: - Validation banner

    private var validationBanner: some View {
        Group {
            if !isValid {
                // Красный — нет нужных дублей для отдачи
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.system(size: 20))
                        Text(isRu ? "Обмен невалиден" : "Exchange is invalid")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.red)
                        Spacer()
                    }
                    Text(isRu
                         ? "Некоторых карточек больше нет. Удалите их из обмена, чтобы восстановить."
                         : "Some stickers are no longer available. Remove them from the exchange to restore.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    ForEach(givingIssues) { issue in
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.system(size: 12))
                            Text("\(issue.entry.teamCode) #\(issue.entry.number): \(issue.reason)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(12)
                .background(Color.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.red.opacity(0.35), lineWidth: 1.5))

            } else if hasWarnings {
                // Жёлтый — giving ок, но часть получаемых уже есть в альбоме
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isRu ? "Некоторые карточки уже есть" : "Some stickers already collected")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.orange)
                            Text(isRu
                                 ? "Карточки, которые вы получаете, уже вклеены или есть дубли"
                                 : "Stickers you're receiving are already pasted or have duplicates")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    ForEach(wantingWarnings) { issue in
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.orange)
                                .font(.system(size: 12))
                            Text("\(issue.entry.teamCode) #\(issue.entry.number): \(issue.reason)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.orange)
                        }
                    }

                    Divider()

                    Toggle(isOn: $wantingAcknowledged) {
                        Text(isRu
                             ? "Я знаю об этом и хочу восстановить обмен"
                             : "I understand and want to restore the exchange")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .tint(.orange)
                }
                .padding(12)
                .background(Color.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.orange.opacity(0.35), lineWidth: 1.5))

            } else {
                // Зелёный — всё чисто
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isRu ? "Обмен актуален" : "Exchange is valid")
                            .font(.system(size: 14, weight: .semibold))
                        Text(isRu
                             ? "Все карточки проверены, обмен можно восстановить"
                             : "All stickers verified, exchange can be restored")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.green.opacity(0.3), lineWidth: 1))
            }
        }
    }

    // MARK: - Exchange columns

    private var exchangeColumns: some View {
        VStack(spacing: 16) {
            columnSection(
                title: isRu ? "Отдаю" : "I give",
                entries: exchange.giving,
                color: .teal,
                invalidIDs: invalidGivingIDs,
                warnIDs: []
            )

            HStack {
                Divider()
                Image(systemName: "arrow.down")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
                Divider()
            }

            columnSection(
                title: isRu ? "Получаю" : "I receive",
                entries: exchange.wanting,
                color: .green,
                invalidIDs: [],
                warnIDs: warnWantingIDs
            )
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func columnSection(title: String, entries: [StickerEntry],
                                color: Color, invalidIDs: Set<String>, warnIDs: Set<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            FlowLayout(spacing: 6) {
                ForEach(entries) { entry in
                    let sid     = "\(entry.teamCode)\(entry.number)"
                    let invalid = invalidIDs.contains(sid)
                    let warned  = warnIDs.contains(sid)

                    let issue = givingIssues.first(where: { $0.id == sid })
                                ?? wantingWarnings.first(where: { $0.id == sid })

                    stickerChip(entry: entry, color: color,
                                isInvalid: invalid, isWarned: warned,
                                tooltip: issue?.reason)
                }
            }
        }
    }

    private func stickerChip(entry: StickerEntry, color: Color,
                              isInvalid: Bool, isWarned: Bool,
                              tooltip: String?) -> some View {
        let accent: Color = isInvalid ? .red : isWarned ? .orange : color
        return VStack(spacing: 2) {
            Text("\(entry.teamCode) \(entry.number == 0 ? "00" : "\(entry.number)")" +
                 (entry.count > 1 ? "×\(entry.count)" : ""))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(isInvalid ? .red : isWarned ? .orange : color)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(
                            isInvalid ? Color.red.opacity(0.6) :
                            isWarned  ? Color.orange.opacity(0.4) : Color.clear,
                            lineWidth: isInvalid ? 1.5 : 1
                        )
                )
            if let tooltip, (isInvalid || isWarned) {
                Text(tooltip)
                    .font(.system(size: 9))
                    .foregroundStyle(accent)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Restore button

    private var restoreButton: some View {
        Button {
            exchange.status = .active
            try? context.save()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                Text(isRu ? "Восстановить обмен" : "Restore Exchange")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canRestore ? Color.green : Color(.systemGray5))
            .foregroundStyle(canRestore ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!canRestore)
    }
}

// MARK: - Simple flow layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
