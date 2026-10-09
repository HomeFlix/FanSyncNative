import UIKit

final class MyGroupsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let store: FanSyncStore
    private let groupStore: DeviceGroupStore
    private var groupsObserverToken: UUID?

    private let tableView = UITableView(frame: .zero, style: .grouped)

    init(store: FanSyncStore, groupStore: DeviceGroupStore) {
        self.store = store
        self.groupStore = groupStore
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "My Groups"
        view.backgroundColor = FanSyncTheme.screenBackground
        setUpEggplantNavBar(self)

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add, target: self, action: #selector(addGroupTapped)
        )

        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "row")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        groupsObserverToken = groupStore.didChange.addObserver { [weak self] _ in
            self?.tableView.reloadData()
        }
    }

    deinit {
        if let token = groupsObserverToken { groupStore.didChange.removeObserver(token) }
    }

    @objc private func addGroupTapped() {
        let alert = UIAlertController(title: "New Group", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Group name" }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self, weak alert] _ in
            guard let name = alert?.textFields?.first?.text, !name.isEmpty else { return }
            self?.groupStore.addGroup(name: name)
        })
        present(alert, animated: true)
    }

    // MARK: - Sections: one per group, plus a trailing "ungrouped" section.

    private var ungroupedIds: [String] {
        groupStore.ungroupedDeviceIds(allDeviceIds: store.devices.map(\.id))
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        groupStore.groups.count + 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section < groupStore.groups.count {
            return groupStore.groups[section].deviceIds.count
        }
        return ungroupedIds.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section < groupStore.groups.count ? groupStore.groups[section].name : "Device Not in Group"
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == groupStore.groups.count ? "Drag here to add" : nil
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section < groupStore.groups.count else { return nil }
        let group = groupStore.groups[section]

        let container = UIView()
        let label = UILabel()
        label.text = group.name
        label.font = .systemFont(ofSize: 15)
        label.textColor = FanSyncTheme.secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        let gearButton = UIButton(type: .system)
        gearButton.setImage(IconFactory.gear(size: 16), for: .normal)
        gearButton.tintColor = .white
        gearButton.backgroundColor = FanSyncTheme.eggplant
        gearButton.layer.cornerRadius = 14
        gearButton.translatesAutoresizingMaskIntoConstraints = false
        gearButton.tag = section
        gearButton.addTarget(self, action: #selector(gearTapped(_:)), for: .touchUpInside)

        container.addSubview(label)
        container.addSubview(gearButton)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            gearButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            gearButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            gearButton.widthAnchor.constraint(equalToConstant: 28),
            gearButton.heightAnchor.constraint(equalToConstant: 28)
        ])
        return container
    }

    @objc private func gearTapped(_ sender: UIButton) {
        let group = groupStore.groups[sender.tag]
        let sheet = UIAlertController(title: "Group", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Rename group", style: .default) { [weak self] _ in
            self?.renameGroup(group)
        })
        sheet.addAction(UIAlertAction(title: "Move group down one", style: .default) { [weak self] _ in
            self?.groupStore.moveDown(group)
        })
        sheet.addAction(UIAlertAction(title: "Delete group", style: .destructive) { [weak self] _ in
            self?.groupStore.delete(group)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }
        present(sheet, animated: true)
    }

    private func renameGroup(_ group: DeviceGroup) {
        let alert = UIAlertController(title: "Rename Group", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.text = group.name }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            guard let name = alert?.textFields?.first?.text, !name.isEmpty else { return }
            self?.groupStore.rename(group, to: name)
        })
        present(alert, animated: true)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath)
        let deviceId: String
        if indexPath.section < groupStore.groups.count {
            deviceId = groupStore.groups[indexPath.section].deviceIds[indexPath.row]
        } else {
            deviceId = ungroupedIds[indexPath.row]
        }
        cell.textLabel?.text = store.devices.first(where: { $0.id == deviceId })?.displayName ?? deviceId
        cell.textLabel?.font = .systemFont(ofSize: 20)
        cell.accessoryView = {
            let iv = UIImageView(image: IconFactory.hamburger(size: 20))
            iv.tintColor = FanSyncTheme.onLabel
            return iv
        }()
        cell.selectionStyle = .none
        return cell
    }
}
