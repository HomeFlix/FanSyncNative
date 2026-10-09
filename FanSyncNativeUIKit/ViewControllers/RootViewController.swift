import UIKit

/// Swaps its single child view controller based on FanSyncStore.state, mirroring the
/// SwiftUI version's `ContentView` state-driven switch.
final class RootViewController: UIViewController {
    private let store: FanSyncStore
    private let groupStore: DeviceGroupStore

    private var currentChild: UIViewController?
    private var stateObserverToken: UUID?

    init(store: FanSyncStore, groupStore: DeviceGroupStore) {
        self.store = store
        self.groupStore = groupStore
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        stateObserverToken = store.stateDidChange.addObserver { [weak self] state in
            self?.render(state: state)
        }

        render(state: store.state)
        store.restoreSession()
    }

    deinit {
        if let token = stateObserverToken { store.stateDidChange.removeObserver(token) }
    }

    private func render(state: FanSyncStore.SessionState) {
        let next: UIViewController
        switch state {
        case .loggedOut, .loggingIn, .error:
            next = LoginViewController(store: store)
        case .connecting:
            next = ConnectingViewController()
        case .ready:
            next = SideMenuContainerViewController(
                store: store,
                groupStore: groupStore,
                rootContent: DeviceListViewController(store: store, groupStore: groupStore)
            )
        }
        transition(to: next)
    }

    private func transition(to next: UIViewController) {
        if let current = currentChild {
            current.willMove(toParent: nil)
            current.view.removeFromSuperview()
            current.removeFromParent()
        }

        addChild(next)
        next.view.frame = view.bounds
        next.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(next.view)
        next.didMove(toParent: self)
        currentChild = next
    }
}

final class ConnectingViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        let spinner = UIActivityIndicatorView(style: .whiteLarge)
        spinner.color = FanSyncTheme.eggplant
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()

        let label = UILabel()
        label.text = "Connecting…"
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = FanSyncTheme.secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(spinner)
        view.addSubview(label)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            label.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 12),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
}
