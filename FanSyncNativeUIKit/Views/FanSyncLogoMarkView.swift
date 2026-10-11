import UIKit

/// The Fanimation "F"-in-a-circle mark, matching the official app icon/login screen
/// glyph exactly. Backed by a template-rendered image asset (LogoMark, sourced from the
/// real fanSync app's icon art) rather than a hand-drawn path, so it's pixel-accurate and
/// stays in sync with the app icon.
final class FanSyncLogoMarkView: UIView {
    var color: UIColor = FanSyncTheme.eggplant {
        didSet { imageView.tintColor = color }
    }

    private let imageView = UIImageView(image: UIImage(named: "LogoMark")?.withRenderingMode(.alwaysTemplate))

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = color
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }
}
