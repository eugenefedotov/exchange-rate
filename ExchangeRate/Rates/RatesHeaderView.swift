import UIKit

/// Шапка секции: название категории слева, подписи колонок "Покупка" и "Продажа" справа над значениями.
final class RatesHeaderView: UITableViewHeaderFooterView {
    static let reuseID = "RatesHeaderView"

    private let titleLabel = UILabel()
    private let buyLabel = UILabel()
    private let sellLabel = UILabel()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String?) {
        titleLabel.text = title
    }

    private func setupLayout() {
        titleLabel.font = UIFontMetrics(forTextStyle: .title3).scaledFont(for: .systemFont(ofSize: 20, weight: .bold))
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .label
        titleLabel.accessibilityTraits = .header
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        buyLabel.text = "Покупка"
        sellLabel.text = "Продажа"
        for label in [buyLabel, sellLabel] {
            label.font = .preferredFont(forTextStyle: .footnote)
            label.adjustsFontForContentSizeCategory = true
            label.textColor = .secondaryLabel
            label.textAlignment = .right
            label.isAccessibilityElement = false
        }

        [titleLabel, buyLabel, sellLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        // Шапка без фона, колонки совмещаются с ячейками через те же layoutMargins.
        let margins = contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: margins.topAnchor, constant: 8),
            titleLabel.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: buyLabel.leadingAnchor, constant: -8),

            sellLabel.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            sellLabel.widthAnchor.constraint(equalToConstant: RateCell.valueColumnWidth),
            sellLabel.lastBaselineAnchor.constraint(equalTo: titleLabel.lastBaselineAnchor),

            buyLabel.trailingAnchor.constraint(equalTo: sellLabel.leadingAnchor),
            buyLabel.widthAnchor.constraint(equalToConstant: RateCell.valueColumnWidth),
            buyLabel.lastBaselineAnchor.constraint(equalTo: titleLabel.lastBaselineAnchor),
        ])
    }
}
