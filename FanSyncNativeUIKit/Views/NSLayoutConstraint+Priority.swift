import UIKit

extension NSLayoutConstraint {
    /// Returns self with `priority` set, for inline use inside an
    /// `NSLayoutConstraint.activate([...])` array literal.
    func withPriority(_ priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}
