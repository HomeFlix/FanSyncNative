import UIKit

/// Two-option pill segmented control matching the "NORMAL / FRESH AIR" breeze mode selector.
final class FanSyncSegmentedControl: UIControl {
    private(set) var selectedIndex: Int = 0
    private var buttons: [UIButton] = []

    init(options: [String]) {
        super.init(frame: .zero)
        backgroundColor = UIColor.black.withAlphaComponent(0.06)
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = UIColor.black.withAlphaComponent(0.08).cgColor
        clipsToBounds = true

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        for (i, title) in options.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(title.uppercased(), for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
            button.tag = i
            button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
            button.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
            buttons.append(button)
        }

        updateAppearance()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setSelectedIndex(_ index: Int) {
        selectedIndex = index
        updateAppearance()
    }

    @objc private func tapped(_ sender: UIButton) {
        guard isEnabled else { return }
        selectedIndex = sender.tag
        updateAppearance()
        sendActions(for: .valueChanged)
    }

    // UIControl.isEnabled alone doesn't visually affect custom subviews — dim the
    // buttons and gate taps explicitly (see `tapped(_:)`'s guard above).
    override var isEnabled: Bool {
        didSet { updateAppearance() }
    }

    private func updateAppearance() {
        alpha = isEnabled ? 1.0 : 0.4
        for button in buttons {
            let selected = button.tag == selectedIndex
            button.setTitleColor(selected ? .white : FanSyncTheme.secondaryLabel, for: .normal)
            button.backgroundColor = selected ? FanSyncTheme.eggplant : .clear
        }
    }
}
