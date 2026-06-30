import SwiftUI
import SwiftData
internal import UniformTypeIdentifiers

struct SettingsView: View {

    @AppStorage("appLanguage") private var languageRaw: String = AppLanguage.system.rawValue
    @Environment(\.modelContext) private var context

    @State private var shareItem: URL?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var alertMessage: String?
    @State private var showAPIKeySheet = false
    @State private var showSheetsSheet = false
    @State private var isSyncing = false
    @State private var syncProgress: Double = 0
    @State private var syncTotal: Int = 0
    @State private var syncMessage: String?

    private var language: Binding<AppLanguage> {
        Binding(
            get: { AppLanguage(rawValue: languageRaw) ?? .system },
            set: { languageRaw = $0.rawValue }
        )
    }

    private var isRu: Bool {
        (AppLanguage(rawValue: languageRaw) ?? .system).isRussian
    }

    var body: some View {
        NavigationStack {
            List {
                languageSection
                apiKeySection
                sheetsSection
                backupSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(isRu ? "Настройки" : "Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(item: $shareItem) { url in
            ShareSheet(items: [url])
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert(isRu ? "Импорт данных" : "Import Data", isPresented: .constant(alertMessage != nil)) {
            Button("OK") { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
        .sheet(isPresented: $showAPIKeySheet) {
            APIKeyEntryView()
        }
        .sheet(isPresented: $showSheetsSheet) {
            SheetsURLEntryView()
        }
    }

    // MARK: - Language section

    private var languageSection: some View {
        Section {
            ForEach(AppLanguage.allCases, id: \.rawValue) { lang in
                Button {
                    language.wrappedValue = lang
                } label: {
                    HStack {
                        Text(lang.displayName)
                            .foregroundStyle(.primary)
                        Spacer()
                        if language.wrappedValue == lang {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(isRu ? "Язык интерфейса" : "Interface Language")
        } footer: {
            Text(isRu
                 ? "Изменение применяется мгновенно."
                 : "Change applies instantly.")
                .font(.footnote)
        }
    }

    // MARK: - API Key section

    private var apiKeySection: some View {
        Section {
            Button {
                showAPIKeySheet = true
            } label: {
                HStack {
                    Label(isRu ? "Добавить API ключ" : "Add API Key",
                          systemImage: "key.fill")
                    Spacer()
                    if UserDefaults.standard.string(forKey: "openModelAPIKey")?.isEmpty == false {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 16))
                    }
                }
            }
        } header: {
            Text(isRu ? "ИИ-анализ обменов" : "AI Trade Analysis")
        } footer: {
            let hasKey = UserDefaults.standard.string(forKey: "openModelAPIKey")?.isEmpty == false
            Text(hasKey
                 ? (isRu ? "API ключ сохранён. Кнопка «Анализ ИИ» доступна." : "API key saved. \"AI Analyze\" button is enabled.")
                 : (isRu ? "Введите API ключ openmodel.ai, чтобы использовать ИИ-анализ обменов." : "Enter your openmodel.ai API key to enable AI trade analysis."))
                .font(.footnote)
        }
    }

    // MARK: - Google Sheets section

    private var sheetsSection: some View {
        Section {
            Button {
                showSheetsSheet = true
            } label: {
                HStack {
                    Label("Google Sheets URL", systemImage: "tablecells")
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 16))
                }
            }

            Button {
                syncAllToSheets()
            } label: {
                HStack {
                    Label(isRu ? "Синхронизировать всё" : "Sync all data", systemImage: "arrow.triangle.2.circlepath")
                    if isSyncing {
                        Spacer()
                        Text("\(Int(syncProgress))/\(syncTotal)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        ProgressView(value: syncTotal > 0 ? syncProgress / Double(syncTotal) : 0)
                            .frame(width: 50)
                    }
                }
            }
            .disabled(isSyncing)

            if let msg = syncMessage {
                Text(msg)
                    .font(.system(size: 13))
                    .foregroundStyle(.green)
            }
        } header: {
            Text("Google Sheets")
        } footer: {
            Text(isRu
                 ? "Новые обмены и покупки отправляются автоматически. «Синхронизировать всё» отправит все текущие данные."
                 : "New exchanges and purchases are sent automatically. \"Sync all\" sends all existing data.")
                .font(.footnote)
        }
    }

    private func syncAllToSheets() {
        isSyncing = true
        syncProgress = 0
        syncTotal = 0
        syncMessage = nil

        let exchanges = (try? context.fetch(FetchDescriptor<ExchangeModel>())) ?? []
        let purchases = (try? context.fetch(FetchDescriptor<PurchaseModel>())) ?? []
        let stickers  = (try? context.fetch(FetchDescriptor<StickerModel>())) ?? []
        let teams     = (try? context.fetch(FetchDescriptor<TeamModel>())) ?? []

        let recordCount = exchanges.filter { $0.status == .active || $0.status == .completed }.count + purchases.count
        syncTotal = recordCount + 1 // +1 для коллекции

        Task {
            await SheetsService.syncAll(
                exchanges: exchanges,
                purchases: purchases,
                stickers: stickers,
                teams: teams,
                isRu: isRu
            ) { done, total in
                Task { @MainActor in
                    syncProgress = Double(done)
                }
            }
            await MainActor.run {
                isSyncing = false
                syncMessage = isRu
                    ? "Готово: \(recordCount) записей + коллекция"
                    : "Done: \(recordCount) records + collection"
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run { syncMessage = nil }
        }
    }

    // MARK: - Backup section

    private var backupSection: some View {
        Section {
            Button {
                exportBackup()
            } label: {
                HStack {
                    Label(isRu ? "Экспорт данных" : "Export Data",
                          systemImage: "square.and.arrow.up")
                    if isExporting {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isExporting)

            Button {
                isImporting = true
            } label: {
                Label(isRu ? "Импорт данных" : "Import Data",
                      systemImage: "square.and.arrow.down")
            }
            .foregroundStyle(.orange)
        } header: {
            Text(isRu ? "Резервная копия" : "Backup")
        } footer: {
            Text(isRu
                 ? "Экспорт сохраняет статусы наклеек и обмены в файл JSON. Импорт перезаписывает текущие данные."
                 : "Export saves sticker statuses and exchanges to a JSON file. Import overwrites current data.")
                .font(.footnote)
        }
    }

    // MARK: - Actions

    private func exportBackup() {
        isExporting = true
        Task.detached(priority: .userInitiated) {
            do {
                let (data, fileName) = try await MainActor.run {
                    (try BackupService.exportData(context: context), "sticker_backup_\(formattedDate()).json")
                }
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent(fileName)
                try data.write(to: url, options: .atomic)
                await MainActor.run {
                    isExporting = false
                    shareItem = url
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    alertMessage = error.localizedDescription
                }
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            alertMessage = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let data = try Data(contentsOf: url)
                try BackupService.importData(data, context: context)
                alertMessage = isRu ? "Данные успешно восстановлены." : "Data restored successfully."
            } catch {
                alertMessage = (isRu ? "Ошибка импорта: " : "Import error: ") + error.localizedDescription
            }
        }
    }

    private func formattedDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

// MARK: - API Key Entry Sheet

private struct APIKeyEntryView: View {

    @AppStorage("openModelAPIKey") private var savedKey: String = ""
    @AppStorage("appLanguage") private var languageRaw: String = AppLanguage.system.rawValue
    @Environment(\.dismiss) private var dismiss

    @State private var draftKey: String = ""
    @State private var isRevealed = false

    private var isRu: Bool { (AppLanguage(rawValue: languageRaw) ?? .system).isRussian }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Group {
                            if isRevealed {
                                TextField(isRu ? "Вставьте API ключ..." : "Paste API key...", text: $draftKey)
                            } else {
                                SecureField(isRu ? "Вставьте API ключ..." : "Paste API key...", text: $draftKey)
                            }
                        }
                        .font(.system(size: 14, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                        Button {
                            isRevealed.toggle()
                        } label: {
                            Image(systemName: isRevealed ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    if !savedKey.isEmpty {
                        Button(role: .destructive) {
                            savedKey = ""
                            draftKey = ""
                        } label: {
                            Label(isRu ? "Удалить ключ" : "Remove Key",
                                  systemImage: "trash")
                        }
                    }
                } header: {
                    Text("openmodel.ai API Key")
                } footer: {
                    Text(isRu
                         ? "Ключ хранится локально на устройстве и используется только для ИИ-анализа обменов."
                         : "The key is stored locally on your device and used only for AI trade analysis.")
                        .font(.footnote)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(isRu ? "API Ключ" : "API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isRu ? "Отмена" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isRu ? "Сохранить" : "Save") {
                        savedKey = draftKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }
                    .disabled(draftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear { draftKey = savedKey }
    }
}

// MARK: - Sheets URL Entry Sheet

private struct SheetsURLEntryView: View {

    @AppStorage("appLanguage") private var languageRaw: String = AppLanguage.system.rawValue
    @Environment(\.dismiss) private var dismiss

    @State private var draftURL: String = SheetsService.scriptURL
    @FocusState private var textFocused: Bool

    private var isRu: Bool { (AppLanguage(rawValue: languageRaw) ?? .system).isRussian }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // Нативная кнопка — работает на реальном устройстве без запроса разрешений
                    PasteButton(payloadType: String.self) { strings in
                        if let str = strings.first {
                            draftURL = str.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                    .labelStyle(.titleAndIcon)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Поле для ручного ввода / вставки через контекстное меню
                    TextField(
                        isRu ? "Или введите URL вручную..." : "Or type URL manually...",
                        text: $draftURL,
                        axis: .vertical
                    )
                    .lineLimit(2...5)
                    .font(.system(size: 12, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .focused($textFocused)

                    Button(role: .destructive) {
                        UserDefaults.standard.removeObject(forKey: "sheetsScriptURL")
                        draftURL = SheetsService.scriptURL
                    } label: {
                        Label(isRu ? "Сбросить до дефолтного" : "Reset to default", systemImage: "arrow.counterclockwise")
                    }
                } header: {
                    Text("Apps Script URL")
                } footer: {
                    if draftURL.isEmpty {
                        Text(isRu
                             ? "Скопируй URL скрипта и нажми «Вставить» — или тапни на текстовое поле и выбери Paste"
                             : "Copy the script URL and tap Paste — or tap the text field and choose Paste")
                            .font(.footnote)
                    } else {
                        Text(isRu ? "URL сохранится при нажатии «Сохранить»" : "URL will be saved when you tap Save")
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Google Sheets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isRu ? "Отмена" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isRu ? "Сохранить" : "Save") {
                        SheetsService.scriptURL = draftURL.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(draftURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear { draftURL = SheetsService.scriptURL }
    }
}

// MARK: - ShareSheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - URL Identifiable

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
