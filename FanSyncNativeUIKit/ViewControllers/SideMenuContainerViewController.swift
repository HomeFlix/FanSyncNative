import UIKit

enum MainMenuDestination {
    case home
    case myGroups
    case settings
    case support
}

/// Hosts a primary navigation controller plus a left-edge slide-out menu, reused by every
/// top-level destination so the hamburger button behaves the same everywhere. Equivalent to
/// the SwiftUI version's `WithSideMenu`.
final class SideMenuContainerViewController: UIViewController {
    private let store: FanSyncStore
    private let groupStore: DeviceGroupStore
    private let rootContent: UIViewController

    private let navController: UINavigationController
    private let dimView = UIView()
    private let menuView: MainMenuView
    private var menuLeadingConstraint: NSLayoutConstraint!
    private let menuWidth: CGFloat = UIScreen.main.bounds.width * 0.78

    init(store: FanSyncStore, groupStore: DeviceGroupStore, rootContent: UIViewController) {
        self.store = store
        self.groupStore = groupStore
        self.rootContent = rootContent
        self.navController = UINavigationController(rootViewController: rootContent)
        self.menuView = MainMenuView(store: store)
        super.init(nibName: nil, bundle: nil)

        (rootContent as? DeviceListViewController)?.onMenuTapped = { [weak self] in self?.openMenu() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        navController.setNavigationBarHidden(true, animated: false)
        addChild(navController)
        navController.view.frame = view.bounds
        navController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(navController.view)
        navController.didMove(toParent: self)

        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        dimView.alpha = 0
        dimView.translatesAutoresizingMaskIntoConstraints = false
        dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(closeMenu)))
        view.addSubview(dimView)
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        menuView.translatesAutoresizingMaskIntoConstraints = false
        menuView.onSelect = { [weak self] dest in self?.select(dest) }
        view.addSubview(menuView)
        menuLeadingConstraint = menuView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -menuWidth)
        NSLayoutConstraint.activate([
            menuLeadingConstraint,
            menuView.topAnchor.constraint(equalTo: view.topAnchor),
            menuView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            menuView.widthAnchor.constraint(equalToConstant: menuWidth)
        ])
    }

    func openMenu() {
        menuView.refresh()
        menuLeadingConstraint.constant = 0
        UIView.animate(withDuration: 0.22) {
            self.dimView.alpha = 1
            self.view.layoutIfNeeded()
        }
    }

    @objc private func closeMenu() {
        menuLeadingConstraint.constant = -menuWidth
        UIView.animate(withDuration: 0.22) {
            self.dimView.alpha = 0
            self.view.layoutIfNeeded()
        }
    }

    private func select(_ dest: MainMenuDestination) {
        closeMenu()
        guard dest != .home else { return } // Home is the root screen itself

        let vc: UIViewController
        switch dest {
        case .home: return
        case .myGroups: vc = MyGroupsViewController(store: store, groupStore: groupStore)
        case .settings: vc = SettingsViewController(store: store)
        case .support: vc = SupportViewController()
        }
        navController.pushViewController(vc, animated: true)
    }
}

extension MainMenuDestination: Equatable {}
