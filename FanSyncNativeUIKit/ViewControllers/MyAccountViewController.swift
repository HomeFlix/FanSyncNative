import UIKit

final class MyAccountViewController: UIViewController {
    private var is24h: Bool {
        get { UserDefaults.standard.object(forKey: "timeFormat24h") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "timeFormat24h") }
    }

    private let timeFormatLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "My Account"
        view.backgroundColor = .white
        setUpEggplantNavBar(self)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        timeFormatLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        timeFormatLabel.textColor = FanSyncTheme.onLabel
        updateTimeFormatLabel()
        stack.addArrangedSubview(timeFormatLabel)

        let setFormatButton = FanSyncPillButton(title: "Set Time Format")
        setFormatButton.addTarget(self, action: #selector(toggleTimeFormat), for: .touchUpInside)
        stack.addArrangedSubview(setFormatButton)

        let dataLabel = UILabel()
        dataLabel.text = "MY DATA"
        dataLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        dataLabel.textColor = FanSyncTheme.onLabel
        stack.addArrangedSubview(dataLabel)

        let deleteButton = FanSyncPillButton(title: "Delete My Account", background: .systemRed)
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        stack.addArrangedSubview(deleteButton)
    }

    private func updateTimeFormatLabel() {
        timeFormatLabel.text = "TIME FORMAT: \(is24h ? "24H" : "12H")"
    }

    @objc private func toggleTimeFormat() {
        is24h.toggle()
        updateTimeFormatLabel()
    }

    @objc private func deleteTapped() {
        let alert = UIAlertController(
            title: nil,
            message: "Deleting your account is irreversible and must be done through Fanimation's account portal, not from this unofficial client.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }
}
