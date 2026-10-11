import UIKit

/// A device row within the My Groups screen, styled as a raised card to read as a
/// distinct entry nested inside its group's section — matches the device list's card
/// treatment rather than a plain table row directly on the screen background.
final class GroupDeviceCell: UITableViewCell {
    static let reuseId = "GroupDeviceCell"

    private let card = FanSyncCardView()
    private let nameLabel = UILabel()
    private let handleView = UIImageView(image: IconFactory.hamburger(size: 18))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildLayout() {
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])

        nameLabel.font = .systemFont(ofSize: 30, weight: .regular)
        nameLabel.textColor = FanSyncTheme.onLabel

        handleView.tintColor = FanSyncTheme.onLabel
        handleView.translatesAutoresizingMaskIntoConstraints = false
        handleView.widthAnchor.constraint(equalToConstant: 24).isActive = true
        handleView.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let row = UIStackView(arrangedSubviews: [nameLabel, UIView(), handleView])
        row.axis = .horizontal
        row.alignment = .center
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 18, left: 20, bottom: 18, right: 20)

        card.stack.addArrangedSubview(row)

        // Visible border so each row reads clearly as its own box, now that it's
        // inset from the screen edges rather than full-bleed.
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.black.withAlphaComponent(0.2).cgColor
    }

    func configure(title: String) {
        nameLabel.text = title
    }
}
