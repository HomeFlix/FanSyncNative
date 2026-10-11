import UIKit

final class LoginViewController: UIViewController, UITextFieldDelegate {
    private let store: FanSyncStore
    private var stateObserverToken: UUID?

    private let scrollView = UIScrollView()
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

        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil
        )
        // keyboardWillChangeFrame's frame can be reported before iOS appends the
        // password AutoFill suggestion bar ("Passwords" row with a key icon) on top
        // of the keyboard — that bar adds extra height after the initial animation,
        // which left the password field/login button still partly covered even
        // though our math was correct for the keyboard-only height. keyboardDidShow
        // fires once everything (keyboard + any accessory bars) has fully settled,
        // so re-running the same scroll logic there catches the final, true height.
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardDidShowNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil
        )
    }

    deinit {
        if let token = stateObserverToken { store.stateDidChange.removeObserver(token) }
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Keyboard avoidance
    //
    // iOS 12 has no keyboardLayoutGuide (iOS 15+), so this is done the traditional
    // way: wrap content in a UIScrollView and adjust its bottom contentInset to the
    // keyboard's height. Needed on small screens (iPhone 6) where the centered
    // content + keyboard combined exceed the available height and the password
    // field/login button end up hidden behind the keyboard with no way to scroll.

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let endFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        else { return }
        let keyboardHeightInView = max(0, view.bounds.maxY - view.convert(endFrame, from: nil).minY)
        scrollView.contentInset.bottom = keyboardHeightInView
        scrollView.verticalScrollIndicatorInsets.bottom = keyboardHeightInView
        // Force the new contentInset to actually apply before computing scroll
        // visibility below — without this, scrollRectToVisible can use stale
        // (pre-inset) bounds in the same run-loop pass and conclude the field is
        // already visible when it's actually about to be covered by the keyboard.
        scrollView.layoutIfNeeded()

        // contentInset only changes how far the scroll view CAN scroll — it does not
        // move the currently-focused field into view on its own. Without this, the
        // active field stays exactly where it was (covered by the keyboard) even
        // though there's now scrollable room to reveal it.
        if let activeField = [emailField, passwordField].first(where: { $0.isFirstResponder }) {
            let fieldFrameInScrollView = activeField.convert(activeField.bounds, to: scrollView)
            scrollView.scrollRectToVisible(fieldFrameInScrollView.insetBy(dx: 0, dy: -24), animated: true)
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
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

        scrollView.keyboardDismissMode = .interactive
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // The stack's .fill alignment generates its own width constraint for every
            // arranged subview (stretching it to the stack's full width); that
            // constraint and this explicit 100pt one are mutually exclusive once the
            // stack has a real, non-zero width. .required (1000) on our constraint vs.
            // the stack's internal UISV-fill constraint (also effectively required)
            // caused Auto Layout to pick one arbitrarily and log a conflict warning
            // every launch. Lowering ours to .defaultHigh lets the stack's constraint
            // win when they'd conflict, while still sizing logoMark correctly in
            // practice since .fill's generated constraint is itself non-required for
            // a view that also has centerX pinned (not leading/trailing).
            logoMark.widthAnchor.constraint(equalToConstant: 100).withPriority(.defaultHigh),
            logoMark.heightAnchor.constraint(equalToConstant: 100),
            logoMark.centerXAnchor.constraint(equalTo: mainStack.centerXAnchor),

            // mainStack's edges must pin directly to scrollView's contentLayoutGuide
            // (all four, equalTo, unconditional) — that's what UIScrollView uses to
            // derive contentSize automatically under Auto Layout. The previous
            // version anchored top/bottom to safeAreaLayoutGuide with
            // greaterThanOrEqualTo/centerY ("center when it fits, scroll when it
            // doesn't") instead, which left contentSize's height ambiguous/zero
            // (confirmed via device log: scrollView.contentSize was (375, 0)) — so
            // scrollRectToVisible had no real scrollable area and was a no-op the
            // whole time, even though the keyboard inset math itself was correct.
            mainStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 32),
            mainStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -32),
            mainStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            mainStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            mainStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -64),
            // Centers content vertically within the visible (non-scrolled) frame
            // when it's shorter than the screen; once content + keyboard inset
            // exceed that frame, this constraint simply can't be satisfied exactly
            // and the content scrolls instead — but contentSize itself (set above)
            // is never ambiguous, which is what actually matters for scrolling.
            mainStack.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor, constant: -48).withPriority(.defaultLow),
            mainStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24).withPriority(.defaultLow)
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
