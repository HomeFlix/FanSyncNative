import UIKit

/// Rounded card container matching the device-list card background/corner radius.
final class FanSyncCardView: UIView {
    let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = FanSyncTheme.cardBackground
        layer.cornerRadius = 10
        clipsToBounds = false // allow shadow from a wrapper if needed

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 2)

        let inner = UIView()
        inner.backgroundColor = FanSyncTheme.cardBackground
        inner.layer.cornerRadius = 10
        inner.clipsToBounds = true
        inner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: topAnchor),
            inner.bottomAnchor.constraint(equalTo: bottomAnchor),
            inner.leadingAnchor.constraint(equalTo: leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        inner.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: inner.topAnchor),
            stack.bottomAnchor.constraint(equalTo: inner.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: inner.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: inner.trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// Full-width eggplant pill button, e.g. "MORE CONTROLS" / "CLOSE".
final class FanSyncBarButton: UIButton {
    init(title: String) {
        super.init(frame: .zero)
        setTitle(title.uppercased(), for: .normal)
        titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        setTitleColor(.white, for: .normal)
        backgroundColor = FanSyncTheme.eggplant
        contentEdgeInsets = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// Full-width rounded (capsule) filled button used throughout Settings-style screens.
final class FanSyncPillButton: UIButton {
    init(title: String, background: UIColor = FanSyncTheme.eggplant) {
        super.init(frame: .zero)
        setTitle(title, for: .normal)
        titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        setTitleColor(.white, for: .normal)
        backgroundColor = background
        contentEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
}
