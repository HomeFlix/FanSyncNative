import UIKit

final class SettingsViewController: UIViewController {
    private let store: FanSyncStore

    init(store: FanSyncStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        view.backgroundColor = .white
        setUpEggplantNavBar(self)

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

        stack.addArrangedSubview(sectionLabel("Connections"))
        // These integrations are configured through Fanimation's own cloud account
        // linking, not exposed by the reverse-engineered client protocol, so they're
        // inert placeholders rather than wired to anything.
        stack.addArrangedSubview(FanSyncPillButton(title: "Amazon Echo"))
        stack.addArrangedSubview(FanSyncPillButton(title: "IFTTT"))
        stack.addArrangedSubview(FanSyncPillButton(title: "Google Home"))
        stack.addArrangedSubview(FanSyncPillButton(title: "SmartThings"))

        stack.addArrangedSubview(sectionLabel("Account"))
        let myAccountButton = FanSyncPillButton(title: "My Account")
        myAccountButton.addTarget(self, action: #selector(myAccountTapped), for: .touchUpInside)
        stack.addArrangedSubview(myAccountButton)
        stack.addArrangedSubview(FanSyncPillButton(title: "Send Feedback"))

        let logoutButton = FanSyncPillButton(title: "Log Out", background: .systemRed)
        logoutButton.addTarget(self, action: #selector(logoutTapped), for: .touchUpInside)
        stack.addArrangedSubview(logoutButton)
    }

    private func sectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text.uppercased()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = FanSyncTheme.secondaryLabel
        return label
    }

    @objc private func myAccountTapped() {
        navigationController?.pushViewController(MyAccountViewController(), animated: true)
    }

    @objc private func logoutTapped() {
        store.logout()
        navigationController?.popToRootViewController(animated: true)
    }
}
