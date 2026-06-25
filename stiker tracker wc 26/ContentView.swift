import SwiftUI

struct ContentView: View {

    @State private var selectedTab: Int = 1
    @State private var albumPageIndex: Int = 0
    @State private var expandToGroup: String? = nil
    @State private var achievements = AchievementsManager()

    @AppStorage("appLanguage") private var languageRaw: String = AppLanguage.system.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRaw) ?? .system
    }

    private var isRu: Bool { language.isRussian }

    var body: some View {
        TabView(selection: $selectedTab) {

            // ── 1. Группы ────────────────────────────────────────────────
            GroupsView(selectedTab: $selectedTab,
                       albumPageIndex: $albumPageIndex,
                       expandToGroup: $expandToGroup)
                .environment(\.appLanguage, language)
                .tabItem {
                    Label(isRu ? "Группы" : "Groups",
                          systemImage: "rectangle.3.group.fill")
                }
                .tag(0)

            // ── 2. Журнал ────────────────────────────────────────────────
            AlbumView(currentPageIndex: $albumPageIndex,
                      achievements: achievements)
                .environment(\.appLanguage, language)
                .tabItem {
                    Label(isRu ? "Журнал" : "Album",
                          systemImage: "book.fill")
                }
                .tag(1)

            // ── 3. Ещё ───────────────────────────────────────────────────
            MoreView(achievements: achievements,
                     selectedTab: $selectedTab,
                     albumPageIndex: $albumPageIndex,
                     expandToGroup: $expandToGroup)
                .environment(\.appLanguage, language)
                .tabItem {
                    Label(isRu ? "Ещё" : "More",
                          systemImage: "ellipsis.circle.fill")
                }
                .tag(2)
        }
    }
}

#Preview {
    ContentView()
}
