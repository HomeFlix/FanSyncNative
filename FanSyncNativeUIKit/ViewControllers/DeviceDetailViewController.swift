import UIKit

/// The "More Controls" modal, presented via a UINavigationController pushed modally
/// (matches the reference app's sheet-with-CLOSE-bar presentation).
final class DeviceDetailViewController: UIViewController {
    private let store: FanSyncStore
    private let deviceId: String
    private var devicesObserverToken: UUID?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let nameLabel = UILabel()
    private let onOffLabel = UILabel()
    private let percentLabel = UILabel()
    private let powerSwitch = UISwitch()
    private let speedSlider = UISlider()
    private let breezeControl = FanSyncSegmentedControl(options: ["Normal", "Fresh Air"])
    private let directionControl = FanSyncSegmentedControl(options: ["Forward", "Reverse"])
    private let lightSwitch = UISwitch()
    private let lightStatusLabel = UILabel()
    private let lightPercentLabel = UILabel()
    private let lightSlider = UISlider()
    private let homeAwaySwitch = UISwitch()
    private let homeAwayStatusLabel = UILabel()

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
        view.backgroundColor = FanSyncTheme.screenBackground
        buildLayout()

        devicesObserverToken = store.devicesDidChange.addObserver { [weak self] _ in
            self?.render()
        }
        render()
    }

    deinit {
        if let token = devicesObserverToken { store.devicesDidChange.removeObserver(token) }
    }

    private func buildLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let closeButton = UIButton(type: .system)
        closeButton.setTitle("CLOSE", for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = FanSyncTheme.eggplant
        closeButton.contentEdgeInsets = UIEdgeInsets(top: 18, left: 16, bottom: 18, right: 16)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: closeButton.topAnchor),

            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            closeButton.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        contentStack.axis = .vertical
        contentStack.spacing = 20
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])

        // Title row
        let fanIconView = UIImageView(image: UIImage(named: "FanIcon")?.withRenderingMode(.alwaysTemplate))
        fanIconView.tintColor = FanSyncTheme.onLabel
        fanIconView.contentMode = .scaleAspectFit
        fanIconView.translatesAutoresizingMaskIntoConstraints = false
        fanIconView.widthAnchor.constraint(equalToConstant: 40).isActive = true
        fanIconView.heightAnchor.constraint(equalToConstant: 37).isActive = true

        nameLabel.font = .systemFont(ofSize: 28, weight: .regular)
        nameLabel.textColor = FanSyncTheme.onLabel

        let titleRow = UIStackView(arrangedSubviews: [fanIconView, nameLabel])
        titleRow.axis = .horizontal
        titleRow.spacing = 14
        titleRow.alignment = .center
        contentStack.addArrangedSubview(titleRow)

        // Power + speed
        onOffLabel.font = .systemFont(ofSize: 20, weight: .bold)
        onOffLabel.textColor = FanSyncTheme.onLabel
        powerSwitch.onTintColor = FanSyncTheme.accent
        powerSwitch.addTarget(self, action: #selector(powerChanged), for: .valueChanged)
        percentLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        percentLabel.textColor = FanSyncTheme.onLabel

        let powerRow = UIStackView(arrangedSubviews: [powerSwitch, onOffLabel, UIView(), percentLabel])
        powerRow.axis = .horizontal
        powerRow.spacing = 8
        powerRow.alignment = .center
        contentStack.addArrangedSubview(powerRow)

        speedSlider.minimumValue = 0
        speedSlider.maximumValue = 100
        speedSlider.tintColor = FanSyncTheme.eggplant
        speedSlider.addTarget(self, action: #selector(speedChanged), for: .valueChanged)
        contentStack.addArrangedSubview(speedSlider)
        contentStack.addArrangedSubview(divider())

        // Breeze mode
        breezeControl.addTarget(self, action: #selector(breezeChanged), for: .valueChanged)
        contentStack.addArrangedSubview(sectionLabel("Breeze Mode"))
        contentStack.addArrangedSubview(breezeControl)
        contentStack.addArrangedSubview(divider())

        // Fan direction
        directionControl.addTarget(self, action: #selector(directionChanged), for: .valueChanged)
        contentStack.addArrangedSubview(sectionLabel("Fan Direction"))
        contentStack.addArrangedSubview(directionControl)
        contentStack.addArrangedSubview(divider())

        // Light
        lightSwitch.onTintColor = FanSyncTheme.accent
        lightSwitch.addTarget(self, action: #selector(lightChanged), for: .valueChanged)
        lightStatusLabel.font = .systemFont(ofSize: 20, weight: .bold)
        lightStatusLabel.textColor = FanSyncTheme.onLabel
        lightPercentLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        lightPercentLabel.textColor = FanSyncTheme.onLabel
        let lightRow = UIStackView(arrangedSubviews: [sectionLabel("Light"), UIView(), lightPercentLabel, lightStatusLabel, lightSwitch])
        lightRow.axis = .horizontal
        lightRow.spacing = 8
        lightRow.alignment = .center
        contentStack.addArrangedSubview(lightRow)

        // Dimming slider — hidden entirely for fixtures that don't support it
        // (FanDevice.hidesLightDimmer, from the real app's hideLightDimmer device
        // property), matching the real app rather than showing a slider that would
        // silently do nothing.
        lightSlider.minimumValue = 0
        lightSlider.maximumValue = 100
        lightSlider.tintColor = FanSyncTheme.eggplant
        lightSlider.addTarget(self, action: #selector(lightPercentChanged), for: .valueChanged)
        contentStack.addArrangedSubview(lightSlider)
        contentStack.addArrangedSubview(divider())

        // Home away
        homeAwaySwitch.onTintColor = FanSyncTheme.accent
        homeAwaySwitch.addTarget(self, action: #selector(homeAwayChanged), for: .valueChanged)
        homeAwayStatusLabel.font = .systemFont(ofSize: 20, weight: .bold)
        homeAwayStatusLabel.textColor = FanSyncTheme.onLabel
        let homeAwayRow = UIStackView(arrangedSubviews: [sectionLabel("Home Away"), UIView(), homeAwayStatusLabel, homeAwaySwitch])
        homeAwayRow.axis = .horizontal
        homeAwayRow.spacing = 8
        homeAwayRow.alignment = .center
        contentStack.addArrangedSubview(homeAwayRow)
        contentStack.addArrangedSubview(divider())

        // Settings / Schedules
        let settingsButton = FanSyncPillButton(title: "Settings", background: UIColor.gray.withAlphaComponent(0.6))
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        let schedulesButton = FanSyncPillButton(title: "Schedules", background: UIColor.gray.withAlphaComponent(0.6))
        schedulesButton.addTarget(self, action: #selector(schedulesTapped), for: .touchUpInside)
        let buttonsRow = UIStackView(arrangedSubviews: [settingsButton, schedulesButton])
        buttonsRow.axis = .horizontal
        buttonsRow.spacing = 16
        buttonsRow.distribution = .fillEqually
        contentStack.addArrangedSubview(buttonsRow)
    }

    private func sectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text.uppercased()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = FanSyncTheme.onLabel
        return label
    }

    private func divider() -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.1)
        view.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return view
    }

    private func render() {
        guard let device else { return }
        nameLabel.text = device.displayName
        onOffLabel.text = device.fanPower ? "ON" : "OFF"
        percentLabel.text = "\(device.fanPercent)%"
        powerSwitch.setOn(device.fanPower, animated: false)
        speedSlider.value = Float(device.fanPercent)
        breezeControl.setSelectedIndex(device.fanMode == .freshAir ? 1 : 0)
        directionControl.setSelectedIndex(device.fanDirection == .reverse ? 1 : 0)
        lightSwitch.setOn(device.lightPower, animated: false)
        lightStatusLabel.text = device.lightPower ? "ON" : "OFF"
        lightSlider.isHidden = device.hidesLightDimmer
        lightPercentLabel.isHidden = device.hidesLightDimmer
        lightPercentLabel.text = "\(device.lightPercent)%"
        lightSlider.value = Float(device.lightPercent)
        homeAwaySwitch.setOn(device.homeAway, animated: false)
        homeAwayStatusLabel.text = device.homeAway ? "ON" : "OFF"

        // See DeviceCardCell.configure for the same rules: unreachable devices gray
        // out power/speed, and Fresh Air mode disables the speed slider specifically.
        powerSwitch.isEnabled = device.isConnected
        speedSlider.isEnabled = device.isConnected && device.fanMode != .freshAir
        breezeControl.isEnabled = device.isConnected
        directionControl.isEnabled = device.isConnected
        lightSwitch.isEnabled = device.isConnected
        lightSlider.isEnabled = device.isConnected
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func powerChanged() {
        guard let device else { return }
        store.setFanPower(device, on: powerSwitch.isOn)
    }

    @objc private func speedChanged() {
        guard let device else { return }
        store.setFanPercent(device, percent: Int(speedSlider.value))
    }

    @objc private func breezeChanged() {
        guard let device else { return }
        store.setFanMode(device, mode: breezeControl.selectedIndex == 1 ? .freshAir : .normal)
    }

    @objc private func directionChanged() {
        guard let device else { return }
        store.setFanDirection(device, direction: directionControl.selectedIndex == 1 ? .reverse : .forward)
    }

    @objc private func lightChanged() {
        guard let device else { return }
        store.setLightPower(device, on: lightSwitch.isOn)
    }

    @objc private func lightPercentChanged() {
        guard let device else { return }
        store.setLightPercent(device, percent: Int(lightSlider.value))
    }

    @objc private func homeAwayChanged() {
        guard let device else { return }
        store.setHomeAway(device, on: homeAwaySwitch.isOn)
    }

    @objc private func settingsTapped() {
        navigationController?.pushViewController(DeviceSettingsViewController(store: store, deviceId: deviceId), animated: true)
    }

    @objc private func schedulesTapped() {
        guard let device else { return }
        navigationController?.pushViewController(ScheduleListViewController(deviceName: device.displayName), animated: true)
    }
}
