import SwiftUI
import SwiftData

struct TradeMessageView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.appLanguage) private var language

    @State private var message: String = ""
    @State private var missingText: String = ""
    @State private var dupText: String = ""
    @State private var copied = false
    @State private var copiedMissing = false
    @State private var copiedDup = false
    @State private var isLoading = true

    @AppStorage("tradeMessagePrefix") private var prefix: String = ""
    @AppStorage("tradeMessageSuffix") private var suffix: String = ""
    @AppStorage("tradeMessagePrefixEnabled") private var prefixEnabled: Bool = true
    @AppStorage("tradeMessageSuffixEnabled") private var suffixEnabled: Bool = true

    private var isRu: Bool { language.isRussian }

    private var fullMessage: String {
        wrappedMessage(message)
    }

    private func wrappedMessage(_ body: String) -> String {
        let parts = [
            prefixEnabled ? prefix.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            body,
            suffixEnabled ? suffix.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        ].filter { !$0.isEmpty }
        return parts.joined(separator: "\n\n")
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if missingText.isEmpty && dupText.isEmpty {
                    emptyState
                } else {
                    messageContent
                }
            }
            .navigationTitle(isRu ? "Сообщение для обмена" : "Trade Message")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear { generate() }
    }

    // MARK: - Message content

    private var messageContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {

                    // Префикс
                    prefixSuffixField(
                        title: isRu ? "Текст в начале" : "Text at the top",
                        placeholder: isRu ? "Например: Обмен, Минск" : "E.g. Trade, Berlin",
                        text: $prefix,
                        enabled: $prefixEnabled
                    )

                    // Блок "Ищу"
                    if !missingText.isEmpty {
                        messageBlock(
                            text: missingText,
                            copyLabel: isRu ? "Скопировать «Ищу»" : "Copy «Looking for»",
                            isCopied: $copiedMissing,
                            fullCopyText: wrappedMessage(missingText)
                        )
                    }

                    // Блок "Повторки"
                    if !dupText.isEmpty {
                        messageBlock(
                            text: dupText,
                            copyLabel: isRu ? "Скопировать «Повторки»" : "Copy «Duplicates»",
                            isCopied: $copiedDup,
                            fullCopyText: wrappedMessage(dupText)
                        )
                    }

                    // Суффикс
                    prefixSuffixField(
                        title: isRu ? "Текст в конце" : "Text at the bottom",
                        placeholder: isRu ? "Например: пишите в личку" : "E.g. DM me",
                        text: $suffix,
                        enabled: $suffixEnabled
                    )
                }
                .padding(16)
            }

            Button {
                UIPasteboard.general.string = fullMessage
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc.fill")
                    Text(copied
                         ? (isRu ? "Скопировано!" : "Copied!")
                         : (isRu ? "Скопировать всё" : "Copy All"))
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(copied ? Color.green : Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .animation(.easeInOut(duration: 0.2), value: copied)
        }
    }

    private func messageBlock(text: String, copyLabel: String, isCopied: Binding<Bool>, fullCopyText: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .font(.system(size: 14, design: .monospaced))
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Button {
                UIPasteboard.general.string = fullCopyText
                isCopied.wrappedValue = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { isCopied.wrappedValue = false }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isCopied.wrappedValue ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12, weight: .semibold))
                    Text(isCopied.wrappedValue ? (isRu ? "Скопировано" : "Copied") : copyLabel)
                        .font(.system(size: 13, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isCopied.wrappedValue ? Color.green.opacity(0.15) : Color(.secondarySystemBackground))
                .foregroundStyle(isCopied.wrappedValue ? .green : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.2), value: isCopied.wrappedValue)
        }
    }

    // MARK: - Prefix / Suffix field

    private func prefixSuffixField(title: String, placeholder: String,
                                   text: Binding<String>, enabled: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Toggle("", isOn: enabled)
                    .labelsHidden()
                    .scaleEffect(0.75)
                    .tint(.accentColor)
            }
            TextField(placeholder, text: text, axis: .vertical)
                .font(.system(size: 14))
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .lineLimit(1...4)
                .opacity(enabled.wrappedValue ? 1 : 0.4)
                .disabled(!enabled.wrappedValue)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.badge.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(isRu ? "Нечего показать" : "Nothing to show")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(isRu
                 ? "Вклей хотя бы одну наклейку,\nчтобы сформировать сообщение."
                 : "Paste at least one sticker\nto generate a trade message.")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Generate

    private func generate() {
        isLoading = true

        // Fetch teams ordered by orderIndex
        let teamDesc = FetchDescriptor<TeamModel>(sortBy: [SortDescriptor(\.orderIndex)])
        let teams = (try? context.fetch(teamDesc)) ?? []
        let teamByCode: [String: TeamModel] = Dictionary(uniqueKeysWithValues: teams.map { ($0.code, $0) })

        // Fetch all stickers sorted by team order then number
        let stickerDesc = FetchDescriptor<StickerModel>(
            sortBy: [SortDescriptor(\.teamCode), SortDescriptor(\.number)]
        )
        let allStickers = (try? context.fetch(stickerDesc)) ?? []

        // Fetch active exchanges to exclude reserved duplicates
        let exchDesc = FetchDescriptor<ExchangeModel>(
            predicate: #Predicate { $0.statusRaw == "active" }
        )
        let activeExchanges = (try? context.fetch(exchDesc)) ?? []

        // Build ordered team codes preserving album order
        let orderedCodes = teams.map { $0.code }

        // Group stickers by team
        var byCode: [String: [StickerModel]] = [:]
        for s in allStickers { byCode[s.teamCode, default: []].append(s) }

        // MISSING: teams with at least one missing sticker — exclude those already incoming in active exchanges
        var missingLines: [String] = []
        var lastMissingGroup: String? = nil
        for code in orderedCodes {
            let stickers = (byCode[code] ?? []).filter { s in
                guard s.status == .missing else { return false }
                // Не показываем в "Ищу" если уже ожидаем получить в обмене
                return ExchangeService.incomingCount(for: s.id, in: activeExchanges) == 0
            }
            guard !stickers.isEmpty else { continue }
            let team = teamByCode[code]
            let group = team?.groupLetter ?? ""
            if let last = lastMissingGroup, last != group { missingLines.append("") }
            lastMissingGroup = group
            let flag = team?.flagEmoji ?? ""
            let label = flag.isEmpty ? code : "\(code) \(flag)"
            let numbers = stickers.sorted { $0.number < $1.number }.map { "\($0.number)" }.joined(separator: ",")
            missingLines.append("\(label): \(numbers)")
        }

        // DUPLICATES: subtract reserved from exchanges, only show available qty > 0
        var dupLines: [String] = []
        var lastDupGroup: String? = nil
        for code in orderedCodes {
            let stickers = (byCode[code] ?? []).filter { $0.status == .duplicate }
            guard !stickers.isEmpty else { continue }

            var tokens: [String] = []
            for s in stickers.sorted(by: { $0.number < $1.number }) {
                let reserved = ExchangeService.reservedCount(for: s.id, in: activeExchanges)
                let available = max(0, s.duplicateCount - reserved)
                guard available > 0 else { continue }
                tokens.append(available > 1 ? "\(s.number)*\(available)" : "\(s.number)")
            }
            guard !tokens.isEmpty else { continue }

            let team = teamByCode[code]
            let group = team?.groupLetter ?? ""
            if let last = lastDupGroup, last != group { dupLines.append("") }
            lastDupGroup = group
            let flag = team?.flagEmoji ?? ""
            let label = flag.isEmpty ? code : "\(code) \(flag)"
            dupLines.append("\(label) \(tokens.joined(separator: ","))")
        }

        var parts: [String] = []
        if !missingLines.isEmpty {
            let block = (isRu ? "🔍 ИЩУ (Нужно):" : "Looking for:") + "\n" + missingLines.joined(separator: "\n")
            missingText = block
            parts.append(block)
        } else {
            missingText = ""
        }
        if !dupLines.isEmpty {
            let block = (isRu ? "🔄 ПОВТОРЫ (Есть):" : "Duplicates:") + "\n" + dupLines.joined(separator: "\n")
            dupText = block
            parts.append(block)
        } else {
            dupText = ""
        }

        message = parts.joined(separator: "\n\n")
        isLoading = false
    }
}
