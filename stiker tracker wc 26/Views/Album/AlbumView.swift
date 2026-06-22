import SwiftUI
import SwiftData

struct AlbumView: View {

    @Environment(\.modelContext)  private var context
    @Environment(\.appLanguage)   private var language

    @Binding var currentPageIndex: Int
    var achievements: AchievementsManager

    @State private var viewModel = AlbumViewModel()
    @State private var stats     = StatsViewModel()

    // Этот query автоматически инвалидируется SwiftData при любом изменении стикера,
    // что позволяет триггерить пересчёт статистики через onChange.
    @Query private var allStickers: [StickerModel]

    var body: some View {
        ZStack {
            albumDeskBackground

            if viewModel.pages.isEmpty {
                ProgressView()
            } else {
                albumBook
            }

            if let banner = achievements.pendingBanner {
                AchievementBannerOverlay(definition: banner) {
                    achievements.dismissBanner()
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: achievements.pendingBanner?.id)
        .ignoresSafeArea(edges: .top)
        .environment(\.achievementsManager, achievements)
        .onAppear {
            viewModel.load(context: context)
            stats.refresh(context: context)
            achievements.load(context: context)
        }
        .onChange(of: allStickers.filter { $0.status != .missing }.count) { _, _ in
            stats.refresh(context: context)
        }
        .onChange(of: currentPageIndex) { _, newIndex in
            viewModel.goTo(index: newIndex)
            stats.refresh(context: context)
        }
        .onChange(of: viewModel.currentPageIndex) { _, newIndex in
            currentPageIndex = newIndex
            stats.refresh(context: context)
        }
    }

    // MARK: - Album book layout

    private var albumBook: some View {
        VStack(spacing: 0) {
            spineHeader
            AlbumPageViewController(
                pages: viewModel.pages,
                currentIndex: $viewModel.currentPageIndex,
                modelContainer: context.container
            )
            bottomNavigationBar
        }
    }

    private var spineHeader: some View {
        ZStack {
            Color(red: 0.12, green: 0.22, blue: 0.55)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

            HStack(spacing: 8) {
                if let page = viewModel.currentPage {
                    Text(page.team.flagEmoji)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(localizedName(page.team))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                        if page.team.groupLetter != "FWC" {
                            Text("Group \(page.team.groupLetter)")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }

                    Spacer()

                    if let pageStat = stats.teamProgress(code: page.team.code) {
                        PageProgressBadge(stat: pageStat)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Bottom nav bar

    private var bottomNavigationBar: some View {
        HStack {
            Button {
                let prev = viewModel.currentPageIndex - 1
                viewModel.goTo(index: prev)
                currentPageIndex = prev
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .padding(10)
            }
            .disabled(viewModel.currentPageIndex == 0)

            Spacer()

            VStack(spacing: 1) {
                Text(stats.album.absoluteString)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(stats.album.percentString)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                let next = viewModel.currentPageIndex + 1
                viewModel.goTo(index: next)
                currentPageIndex = next
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .padding(10)
            }
            .disabled(viewModel.currentPageIndex == viewModel.totalPages - 1)
        }
        .padding(.horizontal, 8)
        .frame(height: 48)
        .background(.ultraThinMaterial)
    }

    // MARK: - Background

    private var albumDeskBackground: some View {
        Color(red: 0.20, green: 0.16, blue: 0.12)
            .ignoresSafeArea()
            .overlay(
                LinearGradient(
                    colors: [.white.opacity(0.03), .clear, .white.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
    }

    // MARK: - Helpers

    private func localizedName(_ team: TeamModel) -> String {
        language.isRussian ? team.nameRU : team.nameEN
    }
}
