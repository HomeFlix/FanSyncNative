import UIKit

final class DeviceSettingsViewController: UIViewController, UITextFieldDelegate {
    private let store: FanSyncStore
    private let deviceId: String

    private var device: FanDevice? {
        store.devices.first(where: { $0.id == deviceId })
    }

    init(store: FanSyncStore, deviceId: String) {
        self.store = store
        self.deviceId = deviceId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        view.backgroundColor = .white
        setUpEggplantNavBar(self)

        guard let device else { return }

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -40)
        ])

        stack.addArrangedSubview(label("DEVICE NAME"))

        let nameField = UITextField()
        nameField.text = device.displayName
        nameField.font = .systemFont(ofSize: 18)
        nameField.borderStyle = .none
        nameField.delegate = self
        let bottomBorder = UIView()
        bottomBorder.backgroundColor = UIColor.black.withAlphaComponent(0.15)
        bottomBorder.translatesAutoresizingMaskIntoConstraints = false
        bottomBorder.heightAnchor.constraint(equalToConstant: 1).isActive = true
        let nameWrap = UIStackView(arrangedSubviews: [nameField, bottomBorder])
        nameWrap.axis = .vertical
        nameWrap.spacing = 8
        stack.addArrangedSubview(nameWrap)

        // Device rename isn't exposed by the reverse-engineered `set` protocol (only
        // status fields H00-H0E are known); this button is a placeholder until that
        // call is confirmed against the real app.
        stack.addArrangedSubview(FanSyncPillButton(title: "Save", background: FanSyncTheme.accent.withAlphaComponent(0.5)))

        stack.addArrangedSubview(label("EXTRA DEVICE CONTROLS"))

        let hideLightDimmerSwitch = UISwitch()
        hideLightDimmerSwitch.onTintColor = FanSyncTheme.eggplant
        let hideLightDimmerLabel = UILabel()
        hideLightDimmerLabel.text = "HIDE LIGHT DIMMER"
        hideLightDimmerLabel.font = .systemFont(ofSize: 14)
        hideLightDimmerLabel.textColor = FanSyncTheme.onLabel
        let hideRow = UIStackView(arrangedSubviews: [hideLightDimmerLabel, UIView(), hideLightDimmerSwitch])
        hideRow.axis = .horizontal
        stack.addArrangedSubview(hideRow)

        stack.addArrangedSubview(label("BLADE CALIBRATION"))
        stack.addArrangedSubview(FanSyncPillButton(title: "BLADE CALIBRATION"))

        stack.addArrangedSubview(label("FAMILY SHARING"))
        stack.addArrangedSubview(FanSyncPillButton(title: "SHARE DEVICE"))

        stack.addArrangedSubview(label("SOFTWARE VERSION"))
        let fwLabel = UILabel()
        fwLabel.text = "—"
        fwLabel.textColor = FanSyncTheme.secondaryLabel
        stack.addArrangedSubview(fwLabel)

        let checkUpdatesButton = FanSyncPillButton(title: "Check for Updates")
        checkUpdatesButton.addTarget(self, action: #selector(checkUpdatesTapped), for: .touchUpInside)
        stack.addArrangedSubview(checkUpdatesButton)

        stack.addArrangedSubview(label("MODEL #"))
        let modelLabel = UILabel()
        modelLabel.text = device.id
        modelLabel.textColor = FanSyncTheme.secondaryLabel
        modelLabel.numberOfLines = 0
        stack.addArrangedSubview(modelLabel)

        let deleteContainer = UIView()
        deleteContainer.backgroundColor = FanSyncTheme.screenBackground
        deleteContainer.layer.cornerRadius = 12

        let deleteTitle = UILabel()
        deleteTitle.text = "Delete Device"
        deleteTitle.font = .systemFont(ofSize: 20, weight: .medium)
        deleteTitle.textAlignment = .center

        let deleteBody = UILabel()
        deleteBody.text = "Note, as the device owner, removing this device will also remove access for anyone you have invited as a guest. Guests will need to be invited again."
        deleteBody.font = .systemFont(ofSize: 14)
        deleteBody.textColor = FanSyncTheme.secondaryLabel
        deleteBody.numberOfLines = 0
        deleteBody.textAlignment = .center

        let deleteButton = FanSyncPillButton(title: "✕  Delete Device", background: .systemRed)
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)

        let deleteStack = UIStackView(arrangedSubviews: [deleteTitle, deleteBody, deleteButton])
        deleteStack.axis = .vertical
        deleteStack.spacing = 12
        deleteStack.translatesAutoresizingMaskIntoConstraints = false
        deleteContainer.addSubview(deleteStack)
        NSLayoutConstraint.activate([
            deleteStack.topAnchor.constraint(equalTo: deleteContainer.topAnchor, constant: 20),
            deleteStack.bottomAnchor.constraint(equalTo: deleteContainer.bottomAnchor, constant: -20),
            deleteStack.leadingAnchor.constraint(equalTo: deleteContainer.leadingAnchor, constant: 20),
            deleteStack.trailingAnchor.constraint(equalTo: deleteContainer.trailingAnchor, constant: -20)
        ])
        stack.addArrangedSubview(deleteContainer)
    }

    private func label(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = FanSyncTheme.onLabel
        return label
    }

    @objc private func checkUpdatesTapped() {
        store.refreshDevices { _ in }
    }

    @objc private func deleteTapped() {
        let alert = UIAlertController(title: nil, message: "Deleting a device isn't supported by this client yet.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
