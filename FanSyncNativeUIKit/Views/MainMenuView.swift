import UIKit

/// Slide-out side menu content matching the hamburger drawer in the reference app:
/// Home / My Groups / Settings / Support, with the logged-in account email and app
/// version pinned at the bottom.
final class MainMenuView: UIView {
    var onSelect: ((MainMenuDestination) -> Void)?

    private let store: FanSyncStore
    private let emailLabel = UILabel()
    private let versionLabel = UILabel()

    private let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"

    init(store: FanSyncStore) {
        self.store = store
        super.init(frame: .zero)
        backgroundColor = .white
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func refresh() {
        emailLabel.text = store.accountEmail ?? ""
    }

    private func buildLayout() {
        let pinwheel = FanSyncPinwheelView()
        pinwheel.color = FanSyncTheme.eggplant
        pinwheel.translatesAutoresizingMaskIntoConstraints = false

        let ring = UIView()
        ring.layer.borderColor = FanSyncTheme.eggplant.cgColor
        ring.layer.borderWidth = 1.5
        ring.layer.cornerRadius = 23
        ring.translatesAutoresizingMaskIntoConstraints = false
        ring.addSubview(pinwheel)

        let rows = UIStackView(arrangedSubviews: [
            menuRow(title: "Home", chevron: true) { [weak self] in self?.onSelect?(.home) },
            menuRow(title: "My Groups", chevron: true) { [weak self] in self?.onSelect?(.myGroups) },
            menuRow(title: "Settings", chevron: true) { [weak self] in self?.onSelect?(.settings) },
            menuRow(title: "Support", chevron: false) { [weak self] in self?.onSelect?(.support) }
        ])
        rows.axis = .vertical

        emailLabel.font = .systemFont(ofSize: 15)
        emailLabel.textColor = FanSyncTheme.onLabel

        versionLabel.text = "v\(appVersion)"
        versionLabel.font = .systemFont(ofSize: 12)
        versionLabel.textColor = FanSyncTheme.secondaryLabel

        let footer = UIStackView(arrangedSubviews: [emailLabel, versionLabel])
        footer.axis = .vertical
        footer.spacing = 4
        footer.translatesAutoresizingMaskIntoConstraints = false

        ring.translatesAutoresizingMaskIntoConstraints = false
        rows.translatesAutoresizingMaskIntoConstraints = false
        addSubview(ring)
        addSubview(rows)
        addSubview(footer)

        NSLayoutConstraint.activate([
            ring.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 20),
            ring.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            ring.widthAnchor.constraint(equalToConstant: 46),
            ring.heightAnchor.constraint(equalToConstant: 46),
            pinwheel.centerXAnchor.constraint(equalTo: ring.centerXAnchor),
            pinwheel.centerYAnchor.constraint(equalTo: ring.centerYAnchor),
            pinwheel.widthAnchor.constraint(equalToConstant: 26),
            pinwheel.heightAnchor.constraint(equalToConstant: 26),

            rows.topAnchor.constraint(equalTo: ring.bottomAnchor, constant: 20),
            rows.leadingAnchor.constraint(equalTo: leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: trailingAnchor),

            footer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            footer.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -32)
        ])
    }

    private func menuRow(title: String, chevron: Bool, action: @escaping () -> Void) -> UIView {
        let container = UIView()

        let label = UILabel()
        label.text = title.uppercased()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = FanSyncTheme.onLabel
        label.translatesAutoresizingMaskIntoConstraints = false

        let divider = UIView()
        divider.backgroundColor = UIColor.black.withAlphaComponent(0.1)
        divider.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        container.addSubview(divider)

        var constraints = [
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),

            divider.heightAnchor.constraint(equalToConstant: 1),
            divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ]

        if chevron {
            let chevronView = UIImageView(image: IconFactory.chevronRight())
            chevronView.tintColor = FanSyncTheme.secondaryLabel
            chevronView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(chevronView)
            constraints.append(contentsOf: [
                chevronView.centerYAnchor.constraint(equalTo: label.centerYAnchor),
                chevronView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
                label.trailingAnchor.constraint(lessThanOrEqualTo: chevronView.leadingAnchor, constant: -8)
            ])
        } else {
            constraints.append(label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20))
        }

        NSLayoutConstraint.activate(constraints)

        container.isUserInteractionEnabled = true
        container.addGestureRecognizer(TapAction(action: action))
        return container
    }
}

/// UITapGestureRecognizer subclass that carries its own closure target, avoiding a
/// separate Objective-C selector + associated-object dance for simple row taps.
private final class TapAction: UITapGestureRecognizer {
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        super.init(target: nil, action: nil)
        addTarget(self, action: #selector(handle))
    }

    @objc private func handle() { action() }
}
