import SwiftUI

struct SettingsView: View {

    @AppStorage("appLanguage") private var languageRaw: String = AppLanguage.system.rawValue

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
            }
            .listStyle(.insetGrouped)
            .navigationTitle(isRu ? "Настройки" : "Settings")
            .navigationBarTitleDisplayMode(.large)
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
}
