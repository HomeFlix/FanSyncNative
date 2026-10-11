import UIKit

final class DeviceCardCell: UITableViewCell {
    static let reuseId = "DeviceCardCell"

    private let card = FanSyncCardView()
    private let fanIconView = UIImageView(image: UIImage(named: "FanIcon")?.withRenderingMode(.alwaysTemplate))
    private let nameLabel = UILabel()
    private let onOffLabel = UILabel()
    private let percentLabel = UILabel()
    private let powerSwitch = UISwitch()
    private let speedSlider = UISlider()
    private let moreControlsButton = FanSyncBarButton(title: "More Controls")

    private var device: FanDevice?
    private weak var store: FanSyncStore?
    private var onMoreControls: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildLayout() {
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])

        // Row 1: icon + name (no background circle — plain glyph, matches the real app)
        fanIconView.tintColor = FanSyncTheme.onLabel
        fanIconView.contentMode = .scaleAspectFit
        fanIconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            fanIconView.widthAnchor.constraint(equalToConstant: 48),
            fanIconView.heightAnchor.constraint(equalToConstant: 44)
        ])

        nameLabel.font = .systemFont(ofSize: 22, weight: .regular)
        nameLabel.textColor = FanSyncTheme.onLabel

        let nameRow = UIStackView(arrangedSubviews: [fanIconView, nameLabel, UIView()])
        nameRow.axis = .horizontal
        nameRow.spacing = 14
        nameRow.alignment = .center
        nameRow.isLayoutMarginsRelativeArrangement = true
        nameRow.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 0, right: 16)

        // Row 2: status
        onOffLabel.font = .systemFont(ofSize: 17, weight: .bold)
        onOffLabel.textColor = FanSyncTheme.onLabel
        percentLabel.font = .systemFont(ofSize: 17, weight: .bold)
        percentLabel.textColor = FanSyncTheme.onLabel

        let statusRow = UIStackView(arrangedSubviews: [onOffLabel, UIView(), percentLabel])
        statusRow.axis = .horizontal
        statusRow.alignment = .center
        statusRow.spacing = 8
        statusRow.isLayoutMarginsRelativeArrangement = true
        statusRow.layoutMargins = UIEdgeInsets(top: 14, left: 16, bottom: 0, right: 16)

        // Row 3: toggle + slider
        powerSwitch.onTintColor = FanSyncTheme.eggplant
        powerSwitch.addTarget(self, action: #selector(powerChanged), for: .valueChanged)
        speedSlider.minimumValue = 0
        speedSlider.maximumValue = 100
        speedSlider.tintColor = FanSyncTheme.eggplant
        speedSlider.addTarget(self, action: #selector(speedChanged), for: .valueChanged)

        let controlsRow = UIStackView(arrangedSubviews: [powerSwitch, speedSlider])
        controlsRow.axis = .horizontal
        controlsRow.spacing = 12
        controlsRow.alignment = .center
        controlsRow.isLayoutMarginsRelativeArrangement = true
        controlsRow.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 16, right: 16)

        moreControlsButton.addTarget(self, action: #selector(moreControlsTapped), for: .touchUpInside)

        card.stack.addArrangedSubview(nameRow)
        card.stack.addArrangedSubview(statusRow)
        card.stack.addArrangedSubview(controlsRow)
        card.stack.addArrangedSubview(moreControlsButton)
    }

    func configure(device: FanDevice, store: FanSyncStore, onMoreControls: @escaping () -> Void) {
        self.device = device
        self.store = store
        self.onMoreControls = onMoreControls

        nameLabel.text = device.displayName
        onOffLabel.text = device.fanPower ? "ON" : "OFF"
        percentLabel.text = "\(device.fanPercent)%"
        powerSwitch.setOn(device.fanPower, animated: false)
        speedSlider.value = Float(device.fanPercent)

        // Physically unreachable devices (powered off at the switch) gray out the
        // power toggle and speed slider, matching the real app — confirmed via packet
        // capture: the server's top-level `connected` field flips to 0, and controls
        // that would send a `set` to an unreachable device are disabled rather than
        // appearing to work and silently doing nothing.
        powerSwitch.isEnabled = device.isConnected
        // Fresh Air mode disables the speed slider in the real app (observed
        // behavior — the fan runs its own variable pattern in this mode rather than a
        // fixed user-set speed).
        speedSlider.isEnabled = device.isConnected && device.fanMode != .freshAir
    }

    @objc private func powerChanged() {
        guard let device, let store else { return }
        store.setFanPower(device, on: powerSwitch.isOn)
    }

    @objc private func speedChanged() {
        guard let device, let store else { return }
        store.setFanPercent(device, percent: Int(speedSlider.value))
    }

    @objc private func moreControlsTapped() {
        onMoreControls?()
    }
}
