import SwiftUI
import SwiftData

struct SettingsView: View {

    @AppStorage("appLanguage") private var languageRaw: String = AppLanguage.system.rawValue
    @Environment(\.modelContext) private var context

    @State private var shareItem: URL?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var alertMessage: String?

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
