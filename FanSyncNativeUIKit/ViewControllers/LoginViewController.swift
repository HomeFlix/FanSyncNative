import UIKit

final class LoginViewController: UIViewController, UITextFieldDelegate {
    private let store: FanSyncStore
    private var stateObserverToken: UUID?

    private let logoMark = FanSyncLogoMarkView()
    private let titleLabel = UILabel()
    private let emailLabel = UILabel()
    private let emailField = UITextField()
    private let passwordLabel = UILabel()
    private let passwordField = UITextField()
    private let passwordToggle = UIButton(type: .system)
    private let forgotPasswordButton = UIButton(type: .system)
    private let errorLabel = UILabel()
    private let loginButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .gray)

    init(store: FanSyncStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
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
        // LogoMark's image asset already includes the circle ring, so no separate
        // border view is needed here (unlike the old hand-drawn pinwheel glyph).
        logoMark.color = FanSyncTheme.eggplant
        logoMark.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = "Log In"
        titleLabel.font = .systemFont(ofSize: 34, weight: .regular)
        titleLabel.textColor = FanSyncTheme.eggplant
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Email field
        emailLabel.text = "EMAIL"
        emailLabel.font = .systemFont(ofSize: 12, weight: .bold)
        emailLabel.textColor = FanSyncTheme.fieldLabel

        emailField.placeholder = ""
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none
        emailField.autocorrectionType = .no
        emailField.textContentType = .username
        styleUnderlinedField(emailField)

        let emailStack = UIStackView(arrangedSubviews: [emailLabel, emailField])
        emailStack.axis = .vertical
        emailStack.spacing = 8

        // Password field
        passwordLabel.text = "PASSWORD"
        passwordLabel.font = .systemFont(ofSize: 12, weight: .bold)
        passwordLabel.textColor = FanSyncTheme.fieldLabel

        passwordField.placeholder = ""
        passwordField.isSecureTextEntry = true
        passwordField.textContentType = .password
        styleUnderlinedField(passwordField)

        passwordToggle.setImage(IconFactory.eye(size: 22, open: true), for: .normal)
        passwordToggle.tintColor = FanSyncTheme.fieldLabel
        passwordToggle.addTarget(self, action: #selector(togglePasswordVisibility), for: .touchUpInside)
        passwordToggle.translatesAutoresizingMaskIntoConstraints = false

        let passwordFieldRow = UIView()
        passwordFieldRow.addSubview(passwordField)
        passwordFieldRow.addSubview(passwordToggle)
        passwordField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            passwordField.leadingAnchor.constraint(equalTo: passwordFieldRow.leadingAnchor),
            passwordField.topAnchor.constraint(equalTo: passwordFieldRow.topAnchor),
            passwordField.bottomAnchor.constraint(equalTo: passwordFieldRow.bottomAnchor),
            passwordField.trailingAnchor.constraint(equalTo: passwordToggle.leadingAnchor, constant: -8),

            passwordToggle.trailingAnchor.constraint(equalTo: passwordFieldRow.trailingAnchor),
            passwordToggle.centerYAnchor.constraint(equalTo: passwordField.centerYAnchor),
            passwordToggle.widthAnchor.constraint(equalToConstant: 28),
            passwordToggle.heightAnchor.constraint(equalToConstant: 28)
        ])

        let passwordStack = UIStackView(arrangedSubviews: [passwordLabel, passwordFieldRow])
        passwordStack.axis = .vertical
        passwordStack.spacing = 8

        forgotPasswordButton.setTitle("Forgot Password?", for: .normal)
        forgotPasswordButton.titleLabel?.font = .systemFont(ofSize: 15)
        forgotPasswordButton.setTitleColor(FanSyncTheme.eggplant, for: .normal)
        forgotPasswordButton.contentHorizontalAlignment = .trailing
        forgotPasswordButton.translatesAutoresizingMaskIntoConstraints = false

        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: 13)
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center

        loginButton.setTitle("Log In", for: .normal)
        loginButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        loginButton.setTitleColor(.white, for: .normal)
        loginButton.backgroundColor = FanSyncTheme.eggplant
        loginButton.layer.cornerRadius = 26
        loginButton.contentEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)

        spinner.hidesWhenStopped = true
        spinner.color = FanSyncTheme.eggplant

        let fieldsStack = UIStackView(arrangedSubviews: [emailStack, passwordStack, forgotPasswordButton])
        fieldsStack.axis = .vertical
        fieldsStack.spacing = 20

        let mainStack = UIStackView(arrangedSubviews: [logoMark, titleLabel, fieldsStack, errorLabel, loginButton, spinner])
        mainStack.axis = .vertical
        mainStack.alignment = .fill
        mainStack.spacing = 28
        mainStack.setCustomSpacing(12, after: logoMark)
        mainStack.setCustomSpacing(32, after: titleLabel)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)

        NSLayoutConstraint.activate([
            logoMark.widthAnchor.constraint(equalToConstant: 100),
            logoMark.heightAnchor.constraint(equalToConstant: 100),
            logoMark.centerXAnchor.constraint(equalTo: mainStack.centerXAnchor),

            mainStack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }

    private func styleUnderlinedField(_ field: UITextField) {
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.font = .systemFont(ofSize: 18)
        field.textColor = FanSyncTheme.fieldText
        field.heightAnchor.constraint(equalToConstant: 32).isActive = true
        field.delegate = self

        let underline = UIView()
        underline.backgroundColor = FanSyncTheme.fieldUnderline
        underline.translatesAutoresizingMaskIntoConstraints = false
        field.addSubview(underline)
        NSLayoutConstraint.activate([
            underline.leadingAnchor.constraint(equalTo: field.leadingAnchor),
            underline.trailingAnchor.constraint(equalTo: field.trailingAnchor),
            underline.bottomAnchor.constraint(equalTo: field.bottomAnchor, constant: 8),
            underline.heightAnchor.constraint(equalToConstant: 1)
        ])
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

    @objc private func togglePasswordVisibility() {
        passwordField.isSecureTextEntry.toggle()
        passwordToggle.setImage(IconFactory.eye(size: 22, open: !passwordField.isSecureTextEntry), for: .normal)
    }

    @objc private func loginTapped() {
        view.endEditing(true)
        guard let email = emailField.text, !email.isEmpty,
              let password = passwordField.text, !password.isEmpty
        else { return }
        store.login(email: email, password: password, remember: true)
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
