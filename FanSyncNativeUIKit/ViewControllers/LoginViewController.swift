import UIKit

final class LoginViewController: UIViewController, UITextFieldDelegate {
    private let store: FanSyncStore
    private var stateObserverToken: UUID?

    private let pinwheel = FanSyncPinwheelView()
    private let titleLabel = UILabel()
    private let emailField = UITextField()
    private let passwordField = UITextField()
    private let rememberSwitch = UISwitch()
    private let errorLabel = UILabel()
    private let loginButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .white)

    init(store: FanSyncStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = FanSyncTheme.eggplant
        buildLayout()

        stateObserverToken = store.stateDidChange.addObserver { [weak self] state in
            self?.render(state: state)
        }
        render(state: store.state)
    }

    deinit {
        if let token = stateObserverToken { store.stateDidChange.removeObserver(token) }
    }

    private func buildLayout() {
        pinwheel.color = .white
        pinwheel.translatesAutoresizingMaskIntoConstraints = false

        let pinwheelRing = UIView()
        pinwheelRing.layer.borderColor = UIColor.white.cgColor
        pinwheelRing.layer.borderWidth = 1.5
        pinwheelRing.translatesAutoresizingMaskIntoConstraints = false
        pinwheelRing.addSubview(pinwheel)

        titleLabel.text = "FanSync"
        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        emailField.placeholder = "Email"
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none
        emailField.autocorrectionType = .no
        emailField.textContentType = .username
        styleTextField(emailField)

        passwordField.placeholder = "Password"
        passwordField.isSecureTextEntry = true
        passwordField.textContentType = .password
        styleTextField(passwordField)

        let rememberLabel = UILabel()
        rememberLabel.text = "Remember me"
        rememberLabel.textColor = .white
        rememberLabel.font = .systemFont(ofSize: 15)
        rememberSwitch.isOn = true
        rememberSwitch.onTintColor = FanSyncTheme.accent

        let rememberRow = UIStackView(arrangedSubviews: [rememberLabel, UIView(), rememberSwitch])
        rememberRow.axis = .horizontal
        rememberRow.alignment = .center

        errorLabel.textColor = .white
        errorLabel.font = .systemFont(ofSize: 13)
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center

        loginButton.setTitle("LOG IN", for: .normal)
        loginButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        loginButton.setTitleColor(FanSyncTheme.eggplant, for: .normal)
        loginButton.backgroundColor = .white
        loginButton.layer.cornerRadius = 10
        loginButton.contentEdgeInsets = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)

        spinner.hidesWhenStopped = true
        spinner.color = .white

        let fieldsStack = UIStackView(arrangedSubviews: [emailField, passwordField, rememberRow])
        fieldsStack.axis = .vertical
        fieldsStack.spacing = 14

        let mainStack = UIStackView(arrangedSubviews: [pinwheelRing, titleLabel, fieldsStack, errorLabel, loginButton, spinner])
        mainStack.axis = .vertical
        mainStack.alignment = .center
        mainStack.spacing = 24
        mainStack.setCustomSpacing(8, after: pinwheelRing)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)

        NSLayoutConstraint.activate([
            pinwheelRing.widthAnchor.constraint(equalToConstant: 100),
            pinwheelRing.heightAnchor.constraint(equalToConstant: 100),
            pinwheel.centerXAnchor.constraint(equalTo: pinwheelRing.centerXAnchor),
            pinwheel.centerYAnchor.constraint(equalTo: pinwheelRing.centerYAnchor),
            pinwheel.widthAnchor.constraint(equalToConstant: 64),
            pinwheel.heightAnchor.constraint(equalToConstant: 64),

            fieldsStack.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            loginButton.widthAnchor.constraint(equalTo: mainStack.widthAnchor),

            mainStack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])

        pinwheelRing.layer.cornerRadius = 50
    }

    private func styleTextField(_ field: UITextField) {
        field.borderStyle = .none
        field.backgroundColor = FanSyncTheme.cardBackground
        field.layer.cornerRadius = 10
        field.font = .systemFont(ofSize: 16)
        let padding = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.leftView = padding
        field.leftViewMode = .always
        field.heightAnchor.constraint(equalToConstant: 48).isActive = true
        field.delegate = self
    }

    private func render(state: FanSyncStore.SessionState) {
        switch state {
        case .loggingIn, .connecting:
            spinner.startAnimating()
            loginButton.isHidden = true
            errorLabel.text = nil
        case .error(let message):
            spinner.stopAnimating()
            loginButton.isHidden = false
            errorLabel.text = message
        case .loggedOut:
            spinner.stopAnimating()
            loginButton.isHidden = false
            errorLabel.text = nil
        case .ready:
            break
        }
    }

    @objc private func loginTapped() {
        view.endEditing(true)
        guard let email = emailField.text, !email.isEmpty,
              let password = passwordField.text, !password.isEmpty
        else { return }
        store.login(email: email, password: password, remember: rememberSwitch.isOn)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === emailField {
            passwordField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
            loginTapped()
        }
        return true
    }
}
