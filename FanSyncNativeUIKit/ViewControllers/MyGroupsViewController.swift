import UIKit

final class MyGroupsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITableViewDragDelegate, UITableViewDropDelegate {
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
        tableView.dragDelegate = self
        tableView.dropDelegate = self
        tableView.dragInteractionEnabled = true
        tableView.register(GroupDeviceCell.self, forCellReuseIdentifier: GroupDeviceCell.reuseId)
        tableView.sectionHeaderHeight = 64
        tableView.estimatedSectionHeaderHeight = 64
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

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == groupStore.groups.count ? "Drag here to add" : nil
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section < groupStore.groups.count else {
            let label = UILabel()
            label.text = "Device Not in Group"
            label.font = .systemFont(ofSize: 20, weight: .bold)
            label.textColor = FanSyncTheme.onLabel
            label.textAlignment = .center
            return label
        }
        let group = groupStore.groups[section]

        let container = UIView()
        let label = UILabel()
        label.text = group.name
        label.font = .systemFont(ofSize: 26, weight: .regular)
        label.textColor = FanSyncTheme.eggplant
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

    private func deviceId(at indexPath: IndexPath) -> String {
        if indexPath.section < groupStore.groups.count {
            return groupStore.groups[indexPath.section].deviceIds[indexPath.row]
        }
        return ungroupedIds[indexPath.row]
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: GroupDeviceCell.reuseId, for: indexPath) as! GroupDeviceCell
        let id = deviceId(at: indexPath)
        cell.configure(title: store.devices.first(where: { $0.id == id })?.displayName ?? id)
        return cell
    }

    // MARK: - Drag and drop (move a device between groups, or to/from "ungrouped")

    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let id = deviceId(at: indexPath)
        let provider = NSItemProvider(object: id as NSString)
        let item = UIDragItem(itemProvider: provider)
        item.localObject = id
        return [item]
    }

    func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
        session.localDragSession != nil
    }

    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }

    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        guard let item = coordinator.items.first,
              let sourceIndexPath = item.sourceIndexPath,
              let deviceId = item.dragItem.localObject as? String
        else { return }

        let destinationSection = coordinator.destinationIndexPath?.section ?? (groupStore.groups.count)

        // Moving within the same group, or within "ungrouped" — no server call needed,
        // just a local reorder (membership didn't change). Real reordering within a
        // group isn't synced (the server's set_group device order isn't shown to carry
        // meaning in the reference protocol), so this is a no-op beyond the UI move.
        guard destinationSection != sourceIndexPath.section else { return }

        if sourceIndexPath.section < groupStore.groups.count {
            let sourceGroup = groupStore.groups[sourceIndexPath.section]
            groupStore.removeDevice(deviceId, from: sourceGroup)
        }
        if destinationSection < groupStore.groups.count {
            let destinationGroup = groupStore.groups[destinationSection]
            groupStore.addDevice(deviceId, to: destinationGroup)
        }
        // Dropping into "ungrouped" needs no addDevice call — removing from the source
        // group is sufficient, since ungroupedDeviceIds is derived from what's NOT in
        // any group rather than being its own tracked list.
    }
}
