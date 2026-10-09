import UIKit

final class SupportViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Support"
        view.backgroundColor = .white
        setUpEggplantNavBar(self)

        let icon = UIImageView(image: IconFactory.questionMarkCircle())
        icon.tintColor = FanSyncTheme.secondaryLabel
        icon.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = "Support"
        titleLabel.font = .systemFont(ofSize: 22, weight: .medium)

        let body = UILabel()
        body.text = "This is an unofficial client. For device support, contact Fanimation directly."
        body.font = .systemFont(ofSize: 15)
        body.textColor = FanSyncTheme.secondaryLabel
        body.numberOfLines = 0
        body.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [icon, titleLabel, body])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 48),
            icon.heightAnchor.constraint(equalToConstant: 48),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40)
        ])
    }
}

/// Shared nav-bar styling helper: eggplant background, white title/buttons, matching
/// every secondary screen in the reference app.
func setUpEggplantNavBar(_ viewController: UIViewController) {
    guard let navBar = viewController.navigationController?.navigationBar else { return }
    navBar.barTintColor = FanSyncTheme.eggplant
    navBar.isTranslucent = false
    navBar.tintColor = .white
    navBar.titleTextAttributes = [.foregroundColor: UIColor.white]
    viewController.navigationController?.setNavigationBarHidden(false, animated: false)
}
