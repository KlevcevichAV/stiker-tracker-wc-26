import SwiftUI
import SwiftData
import UIKit

/// Обёртка над UIPageViewController с эффектом Page Curl.
/// Управляется через Binding<Int> (текущий индекс страницы).
/// Принимает ModelContainer чтобы каждый UIHostingController
/// имел доступ к SwiftData через @Environment(\.modelContext).
struct AlbumPageViewController: UIViewControllerRepresentable {

    let pages: [AlbumPage]
    @Binding var currentIndex: Int
    let modelContainer: ModelContainer

    // MARK: - Make

    func makeUIViewController(context: Context) -> UIPageViewController {
        let vc = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        vc.dataSource = context.coordinator
        vc.delegate   = context.coordinator
        vc.view.backgroundColor = .clear

        if let initial = viewController(for: currentIndex) {
            vc.setViewControllers([initial], direction: .forward, animated: false)
        }
        return vc
    }

    func updateUIViewController(_ pageVC: UIPageViewController, context: Context) {
        guard let current = pageVC.viewControllers?.first as? HostingPageVC,
              current.pageIndex != currentIndex else { return }

        let direction: UIPageViewController.NavigationDirection =
            currentIndex > current.pageIndex ? .forward : .reverse

        if let target = viewController(for: currentIndex) {
            pageVC.setViewControllers([target], direction: direction, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    // MARK: - Helpers

    func viewController(for index: Int) -> HostingPageVC? {
        guard pages.indices.contains(index) else { return nil }
        let pageView = AnyView(
            AlbumPageView(page: pages[index])
                .modelContainer(modelContainer)
        )
        let hostVC = HostingPageVC(rootView: pageView)
        hostVC.pageIndex = index
        hostVC.view.backgroundColor = .clear
        return hostVC
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject,
                             UIPageViewControllerDataSource,
                             UIPageViewControllerDelegate {
        let parent: AlbumPageViewController
        init(parent: AlbumPageViewController) { self.parent = parent }

        func pageViewController(_ pvc: UIPageViewController,
                                viewControllerBefore vc: UIViewController) -> UIViewController? {
            guard let c = vc as? HostingPageVC else { return nil }
            return parent.viewController(for: c.pageIndex - 1)
        }

        func pageViewController(_ pvc: UIPageViewController,
                                viewControllerAfter vc: UIViewController) -> UIViewController? {
            guard let c = vc as? HostingPageVC else { return nil }
            return parent.viewController(for: c.pageIndex + 1)
        }

        func pageViewController(_ pvc: UIPageViewController,
                                didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController],
                                transitionCompleted completed: Bool) {
            guard completed,
                  let current = pvc.viewControllers?.first as? HostingPageVC
            else { return }
            parent.currentIndex = current.pageIndex
        }
    }
}

// MARK: - HostingPageVC

final class HostingPageVC: UIHostingController<AnyView> {
    var pageIndex: Int = 0
}
