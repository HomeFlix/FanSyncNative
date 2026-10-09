import UIKit

/// Scheduling isn't covered by the reverse-engineered FanSync protocol (no schedule-related
/// request type was observed in the reference client), so this is a local-only UI stub that
/// matches the reference app's look. It does not currently read or write anything server-side.
final class ScheduleListViewController: UIViewController {
    private let deviceName: String

    init(deviceName: String) {
        self.deviceName = deviceName
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Schedule List"
        view.backgroundColor = .white
        setUpEggplantNavBar(self)

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add, target: self, action: #selector(createTapped)
        )

        let titleLabel = UILabel()
        titleLabel.text = "\(deviceName)'s Schedules"
        titleLabel.font = .systemFont(ofSize: 22, weight: .medium)
        titleLabel.textAlignment = .center

        let iconBackground = UIView()
        iconBackground.backgroundColor = UIColor.gray.withAlphaComponent(0.3)
        iconBackground.layer.cornerRadius = 50
        let icon = UIImageView(image: IconFactory.calendar())
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconBackground.addSubview(icon)
        iconBackground.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconBackground.widthAnchor.constraint(equalToConstant: 100),
            iconBackground.heightAnchor.constraint(equalToConstant: 100),
            icon.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 40),
            icon.heightAnchor.constraint(equalToConstant: 40)
        ])

        let noSchedulesLabel = UILabel()
        noSchedulesLabel.text = "No Schedules"
        noSchedulesLabel.font = .systemFont(ofSize: 18, weight: .semibold)

        let createButton = FanSyncPillButton(title: "Create a Schedule")
        createButton.addTarget(self, action: #selector(createTapped), for: .touchUpInside)
        createButton.translatesAutoresizingMaskIntoConstraints = false

        let emptyStack = UIStackView(arrangedSubviews: [iconBackground, noSchedulesLabel])
        emptyStack.axis = .vertical
        emptyStack.spacing = 16
        emptyStack.alignment = .center

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        view.addSubview(emptyStack)
        view.addSubview(createButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            emptyStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            createButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            createButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            createButton.topAnchor.constraint(equalTo: emptyStack.bottomAnchor, constant: 32)
        ])
    }

    @objc private func createTapped() {
        navigationController?.pushViewController(CreateScheduleViewController(), animated: true)
    }
}
