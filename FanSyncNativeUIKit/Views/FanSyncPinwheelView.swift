import UIKit

/// The 4-blade pinwheel glyph used in place of a literal fan icon, matching the app's
/// device icon and header logo. Drawn with CAShapeLayer capsules rather than an asset
/// so it can be recolored/resized without needing image variants.
final class FanSyncPinwheelView: UIView {
    var color: UIColor = FanSyncTheme.eggplant {
        didSet { setNeedsLayout() }
    }

    private var bladeLayers: [CAShapeLayer] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        for _ in 0..<4 {
            let layer = CAShapeLayer()
            self.layer.addSublayer(layer)
            bladeLayers.append(layer)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = min(bounds.width, bounds.height)
        guard size > 0 else { return }

        let bladeWidth = size * 0.42
        let bladeHeight = size * 0.9
        let center = CGPoint(x: bounds.midX, y: bounds.midY)

        for (i, layer) in bladeLayers.enumerated() {
            let rect = CGRect(x: -bladeWidth / 2, y: -bladeHeight, width: bladeWidth, height: bladeHeight)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: bladeWidth / 2)

            var transform = CGAffineTransform(translationX: center.x, y: center.y + size * 0.23)
            transform = transform.rotated(by: CGFloat(i) * (.pi / 2))
            path.apply(transform)

            layer.path = path.cgPath
            layer.fillColor = color.cgColor
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }
}
