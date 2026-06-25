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
                let data = try await MainActor.run { try BackupService.exportData(context: context) }
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("sticker_backup_\(formattedDate()).json")
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
