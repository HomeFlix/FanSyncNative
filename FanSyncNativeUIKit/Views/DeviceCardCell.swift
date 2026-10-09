import UIKit

final class DeviceCardCell: UITableViewCell {
    static let reuseId = "DeviceCardCell"

    private let card = FanSyncCardView()
    private let pinwheel = FanSyncPinwheelView()
    private let nameLabel = UILabel()
    private let onOffLabel = UILabel()
    private let percentLabel = UILabel()
    private let smallPinwheel = FanSyncPinwheelView()
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

        // Row 1: icon + name
        let iconBackground = UIView()
        iconBackground.backgroundColor = UIColor(red: 0.75, green: 0.8, blue: 0.95, alpha: 0.5)
        iconBackground.layer.cornerRadius = 24
        iconBackground.translatesAutoresizingMaskIntoConstraints = false
        pinwheel.translatesAutoresizingMaskIntoConstraints = false
        iconBackground.addSubview(pinwheel)
        NSLayoutConstraint.activate([
            iconBackground.widthAnchor.constraint(equalToConstant: 48),
            iconBackground.heightAnchor.constraint(equalToConstant: 48),
            pinwheel.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            pinwheel.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            pinwheel.widthAnchor.constraint(equalToConstant: 26),
            pinwheel.heightAnchor.constraint(equalToConstant: 26)
        ])

        nameLabel.font = .systemFont(ofSize: 20, weight: .medium)
        nameLabel.textColor = FanSyncTheme.onLabel

        let nameRow = UIStackView(arrangedSubviews: [iconBackground, nameLabel, UIView()])
        nameRow.axis = .horizontal
        nameRow.spacing = 14
        nameRow.alignment = .center
        nameRow.isLayoutMarginsRelativeArrangement = true
        nameRow.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 0, right: 16)

        // Row 2: status
        onOffLabel.font = .systemFont(ofSize: 15, weight: .bold)
        onOffLabel.textColor = FanSyncTheme.onLabel
        percentLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        percentLabel.textColor = FanSyncTheme.onLabel
        smallPinwheel.color = FanSyncTheme.secondaryLabel

        let statusRow = UIStackView(arrangedSubviews: [onOffLabel, UIView(), percentLabel, smallPinwheel])
        statusRow.axis = .horizontal
        statusRow.alignment = .center
        statusRow.spacing = 8
        statusRow.isLayoutMarginsRelativeArrangement = true
        statusRow.layoutMargins = UIEdgeInsets(top: 10, left: 16, bottom: 0, right: 16)
        smallPinwheel.widthAnchor.constraint(equalToConstant: 16).isActive = true
        smallPinwheel.heightAnchor.constraint(equalToConstant: 16).isActive = true

        // Row 3: toggle + slider
        powerSwitch.onTintColor = FanSyncTheme.accent
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
