import UIKit

final class DeviceListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let store: FanSyncStore
    private let groupStore: DeviceGroupStore

    /// Injected by SideMenuContainerViewController rather than discovered via parent-chain
    /// walking, since this view controller lives inside a UINavigationController whose
    /// parent is the side menu container — `self.parent` points at the nav controller, not it.
    var onMenuTapped: (() -> Void)?

    private var devicesObserverToken: UUID?
    private var groupsObserverToken: UUID?

    private let tabsScroll = UIScrollView()
    private let tabsStack = UIStackView()
    private var tabButtons: [UIButton] = []
    private var selectedTabIndex = 0 // 0 = All, 1... = groupStore.groups index

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()

    private var visibleDevices: [FanDevice] {
        guard selectedTabIndex > 0, selectedTabIndex - 1 < groupStore.groups.count else { return store.devices }
        let group = groupStore.groups[selectedTabIndex - 1]
        return store.devices.filter { group.deviceIds.contains($0.id) }
    }

    init(store: FanSyncStore, groupStore: DeviceGroupStore) {
        self.store = store
        self.groupStore = groupStore
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = FanSyncTheme.screenBackground
        navigationItem.hidesBackButton = true

        buildHeader()
        buildTabs()
        buildTable()
        buildEmptyState()

        devicesObserverToken = store.devicesDidChange.addObserver { [weak self] _ in
            self?.reload()
        }
        groupsObserverToken = groupStore.didChange.addObserver { [weak self] _ in
            self?.rebuildTabs()
        }

        reload()
    }

    deinit {
        if let token = devicesObserverToken { store.devicesDidChange.removeObserver(token) }
        if let token = groupsObserverToken { groupStore.didChange.removeObserver(token) }
    }

    // MARK: - Header

    private func buildHeader() {
        let header = UIView()
        header.backgroundColor = FanSyncTheme.eggplant
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        let menuButton = UIButton(type: .system)
        menuButton.setImage(IconFactory.hamburger(), for: .normal)
        menuButton.tintColor = .white
        menuButton.addTarget(self, action: #selector(menuTapped), for: .touchUpInside)
        menuButton.translatesAutoresizingMaskIntoConstraints = false

        let pinwheel = FanSyncPinwheelView()
        pinwheel.color = .white
        pinwheel.translatesAutoresizingMaskIntoConstraints = false

        let ring = UIView()
        ring.layer.borderColor = UIColor.white.cgColor
        ring.layer.borderWidth = 1.5
        ring.layer.cornerRadius = 17
        ring.translatesAutoresizingMaskIntoConstraints = false
        ring.addSubview(pinwheel)

        let addButton = UIButton(type: .system)
        addButton.setImage(IconFactory.plus(), for: .normal)
        addButton.tintColor = .white
        addButton.addTarget(self, action: #selector(addButtonTapped(_:)), for: .touchUpInside)
        addButton.translatesAutoresizingMaskIntoConstraints = false

        header.addSubview(menuButton)
        header.addSubview(ring)
        header.addSubview(addButton)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 56),

            menuButton.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            menuButton.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -16),

            ring.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            ring.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -12),
            ring.widthAnchor.constraint(equalToConstant: 34),
            ring.heightAnchor.constraint(equalToConstant: 34),
            pinwheel.centerXAnchor.constraint(equalTo: ring.centerXAnchor),
            pinwheel.centerYAnchor.constraint(equalTo: ring.centerYAnchor),
            pinwheel.widthAnchor.constraint(equalToConstant: 20),
            pinwheel.heightAnchor.constraint(equalToConstant: 20),

            addButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -20),
            addButton.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -16)
        ])

        self.headerView = header
    }

    private var headerView: UIView!

    @objc private func addButtonTapped(_ sender: UIButton) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Refresh", style: .default) { [weak self] _ in
            self?.store.refreshDevices { _ in }
        })
        sheet.addAction(UIAlertAction(title: "Log Out", style: .destructive) { [weak self] _ in
            self?.store.logout()
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }
        present(sheet, animated: true)
    }

    @objc private func menuTapped() {
        onMenuTapped?()
    }

    // MARK: - Tabs

    private func buildTabs() {
        tabsScroll.showsHorizontalScrollIndicator = false
        tabsScroll.backgroundColor = FanSyncTheme.eggplant
        tabsScroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabsScroll)

        tabsStack.axis = .horizontal
        tabsStack.spacing = 28
        tabsStack.translatesAutoresizingMaskIntoConstraints = false
        tabsScroll.addSubview(tabsStack)

        NSLayoutConstraint.activate([
            tabsScroll.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tabsScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabsScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabsScroll.heightAnchor.constraint(equalToConstant: 48),

            tabsStack.topAnchor.constraint(equalTo: tabsScroll.topAnchor),
            tabsStack.bottomAnchor.constraint(equalTo: tabsScroll.bottomAnchor),
            tabsStack.leadingAnchor.constraint(equalTo: tabsScroll.leadingAnchor, constant: 20),
            tabsStack.trailingAnchor.constraint(equalTo: tabsScroll.trailingAnchor, constant: -20),
            tabsStack.heightAnchor.constraint(equalTo: tabsScroll.heightAnchor)
        ])

        rebuildTabs()
    }

    private func rebuildTabs() {
        tabsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        tabButtons.removeAll()

        let titles = ["All"] + groupStore.groups.map(\.name)
        for (i, title) in titles.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 15, weight: i == selectedTabIndex ? .semibold : .regular)
            button.setTitleColor(.white, for: .normal)
            button.tag = i
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            tabsStack.addArrangedSubview(button)
            tabButtons.append(button)
        }

        if selectedTabIndex >= titles.count { selectedTabIndex = 0 }
        reload()
    }

    @objc private func tabTapped(_ sender: UIButton) {
        selectedTabIndex = sender.tag
        for button in tabButtons {
            button.titleLabel?.font = .systemFont(ofSize: 15, weight: button.tag == selectedTabIndex ? .semibold : .regular)
        }
        reload()
    }

    // MARK: - Table

    private func buildTable() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(DeviceCardCell.self, forCellReuseIdentifier: DeviceCardCell.reuseId)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 220
        tableView.translatesAutoresizingMaskIntoConstraints = false

        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        tableView.refreshControl = refresh

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: tabsScroll.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func buildEmptyState() {
        emptyLabel.text = "No Devices\nPull to refresh."
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.textColor = FanSyncTheme.secondaryLabel
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor)
        ])
    }

    @objc private func pullToRefresh() {
        store.refreshDevices { [weak self] _ in
            self?.tableView.refreshControl?.endRefreshing()
        }
    }

    private func reload() {
        emptyLabel.isHidden = !store.devices.isEmpty
        tableView.reloadData()
    }

    // MARK: - UITableViewDataSource / Delegate

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        visibleDevices.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DeviceCardCell.reuseId, for: indexPath) as! DeviceCardCell
        let device = visibleDevices[indexPath.row]
        cell.configure(device: device, store: store) { [weak self] in
            self?.presentDetail(for: device.id)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    private func presentDetail(for deviceId: String) {
        let sheet = DeviceDetailViewController(store: store, deviceId: deviceId)
        let nav = UINavigationController(rootViewController: sheet)
        present(nav, animated: true)
    }
}
