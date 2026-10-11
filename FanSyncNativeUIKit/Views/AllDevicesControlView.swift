import UIKit

/// The expandable "All Devices" batch-control row shown above the device list. Tapping
/// the header toggles an inline panel (power + speed + breeze mode + fan direction)
/// whose changes are applied to every currently-visible device at once — matches the
/// real app's behavior (screenshot: tapping the chevron flips it up and reveals the
/// same controls as a per-device card, applied in batch, with a CLOSE bar instead of
/// MORE CONTROLS).
final class AllDevicesControlView: UIView {
    var devicesProvider: (() -> [FanDevice])?
    /// Fired after expand/collapse so the owning table view can recompute its header height.
    var onExpandedChange: (() -> Void)?
    private weak var store: FanSyncStore?

    private let headerLabel = UILabel()
    private let chevronBadge = UIView()
    private let chevronView = UIImageView()
    private let headerButton = UIButton(type: .system)

    private let expandedStack = UIStackView()
    private let powerSwitch = UISwitch()
    private let onOffLabel = UILabel()
    private let percentLabel = UILabel()
    private let speedSlider = UISlider()
    private let breezeControl = FanSyncSegmentedControl(options: ["Normal", "Fresh Air"])
    private let directionControl = FanSyncSegmentedControl(options: ["Forward", "Reverse"])
    private let closeButton = FanSyncBarButton(title: "Close")

    // Only one of these is active at a time, matching the collapsed/expanded state —
    // closeButton.isHidden alone isn't enough, since a hidden view's own constraints
    // (like pinning its bottom to the container's bottom) still apply and were
    // otherwise stretching the collapsed header down to the expanded panel's height.
    private var collapsedBottomConstraint: NSLayoutConstraint!
    private var expandedBottomConstraint: NSLayoutConstraint!

    private var isExpanded = false {
        didSet { setExpanded(isExpanded) }
    }

    init(store: FanSyncStore) {
        self.store = store
        super.init(frame: .zero)
        backgroundColor = FanSyncTheme.cardBackground
        layer.cornerRadius = 10
        clipsToBounds = true
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildLayout() {
        headerLabel.text = "All Devices"
        headerLabel.font = .systemFont(ofSize: 17)
        headerLabel.textColor = FanSyncTheme.onLabel

        chevronBadge.backgroundColor = FanSyncTheme.eggplant
        chevronBadge.layer.cornerRadius = 11
        chevronBadge.translatesAutoresizingMaskIntoConstraints = false
        chevronView.image = IconFactory.chevronDown(size: 12)
        chevronView.tintColor = .white
        chevronView.translatesAutoresizingMaskIntoConstraints = false
        chevronBadge.addSubview(chevronView)

        let headerRow = UIStackView(arrangedSubviews: [headerLabel, chevronBadge])
        headerRow.axis = .horizontal
        headerRow.spacing = 8
        headerRow.alignment = .center
        headerRow.isUserInteractionEnabled = false
        headerRow.translatesAutoresizingMaskIntoConstraints = false

        headerButton.addTarget(self, action: #selector(headerTapped), for: .touchUpInside)
        headerButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(headerRow)
        addSubview(headerButton)

        NSLayoutConstraint.activate([
            headerRow.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            headerRow.centerXAnchor.constraint(equalTo: centerXAnchor),

            headerButton.topAnchor.constraint(equalTo: topAnchor),
            headerButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerButton.heightAnchor.constraint(equalToConstant: 56),

            chevronBadge.widthAnchor.constraint(equalToConstant: 22),
            chevronBadge.heightAnchor.constraint(equalToConstant: 22),
            chevronView.centerXAnchor.constraint(equalTo: chevronBadge.centerXAnchor),
            chevronView.centerYAnchor.constraint(equalTo: chevronBadge.centerYAnchor)
        ])

        // Expanded content
        onOffLabel.font = .systemFont(ofSize: 17, weight: .bold)
        onOffLabel.textColor = FanSyncTheme.onLabel
        percentLabel.font = .systemFont(ofSize: 17, weight: .bold)
        percentLabel.textColor = FanSyncTheme.onLabel
        powerSwitch.onTintColor = FanSyncTheme.eggplant
        powerSwitch.addTarget(self, action: #selector(powerChanged), for: .valueChanged)
        speedSlider.minimumValue = 0
        speedSlider.maximumValue = 100
        speedSlider.tintColor = FanSyncTheme.eggplant
        speedSlider.addTarget(self, action: #selector(speedChanged), for: .valueChanged)

        let statusRow = UIStackView(arrangedSubviews: [onOffLabel, UIView(), percentLabel])
        statusRow.axis = .horizontal
        statusRow.alignment = .center

        let controlsRow = UIStackView(arrangedSubviews: [powerSwitch, speedSlider])
        controlsRow.axis = .horizontal
        controlsRow.spacing = 12
        controlsRow.alignment = .center

        breezeControl.addTarget(self, action: #selector(breezeChanged), for: .valueChanged)
        directionControl.addTarget(self, action: #selector(directionChanged), for: .valueChanged)

        expandedStack.axis = .vertical
        expandedStack.spacing = 16
        expandedStack.isLayoutMarginsRelativeArrangement = true
        expandedStack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        expandedStack.translatesAutoresizingMaskIntoConstraints = false
        expandedStack.addArrangedSubview(statusRow)
        expandedStack.addArrangedSubview(controlsRow)
        expandedStack.addArrangedSubview(divider())
        expandedStack.addArrangedSubview(sectionLabel("Breeze Mode"))
        expandedStack.addArrangedSubview(breezeControl)
        expandedStack.addArrangedSubview(divider())
        expandedStack.addArrangedSubview(sectionLabel("Fan Direction"))
        expandedStack.addArrangedSubview(directionControl)
        addSubview(expandedStack)

        closeButton.addTarget(self, action: #selector(headerTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(closeButton)

        collapsedBottomConstraint = headerButton.bottomAnchor.constraint(equalTo: bottomAnchor)
        expandedBottomConstraint = closeButton.bottomAnchor.constraint(equalTo: bottomAnchor)

        NSLayoutConstraint.activate([
            expandedStack.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 8),
            expandedStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            expandedStack.trailingAnchor.constraint(equalTo: trailingAnchor),

            closeButton.topAnchor.constraint(equalTo: expandedStack.bottomAnchor),
            closeButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        setExpanded(false)
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

    private func setExpanded(_ expanded: Bool) {
        expandedStack.isHidden = !expanded
        closeButton.isHidden = !expanded
        chevronView.transform = expanded ? CGAffineTransform(rotationAngle: .pi) : .identity
        collapsedBottomConstraint.isActive = !expanded
        expandedBottomConstraint.isActive = expanded

        if expanded {
            onOffLabel.text = "OFF"
            percentLabel.text = "--"
            powerSwitch.setOn(false, animated: false)
            speedSlider.value = 0
            breezeControl.setSelectedIndex(0)
            directionControl.setSelectedIndex(0)
        }
    }

    @objc private func headerTapped() {
        isExpanded.toggle()
        onExpandedChange?()
    }

    private var visibleDevices: [FanDevice] {
        devicesProvider?() ?? []
    }

    @objc private func powerChanged() {
        guard let store else { return }
        onOffLabel.text = powerSwitch.isOn ? "ON" : "OFF"
        for device in visibleDevices { store.setFanPower(device, on: powerSwitch.isOn) }
    }

    @objc private func speedChanged() {
        guard let store else { return }
        let percent = Int(speedSlider.value)
        percentLabel.text = "\(percent)%"
        for device in visibleDevices { store.setFanPercent(device, percent: percent) }
    }

    @objc private func breezeChanged() {
        guard let store else { return }
        let mode: FanMode = breezeControl.selectedIndex == 1 ? .freshAir : .normal
        for device in visibleDevices { store.setFanMode(device, mode: mode) }
    }

    @objc private func directionChanged() {
        guard let store else { return }
        let direction: FanDirection = directionControl.selectedIndex == 1 ? .reverse : .forward
        for device in visibleDevices { store.setFanDirection(device, direction: direction) }
    }
}
