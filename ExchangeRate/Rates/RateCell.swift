import RatesKit
import UIKit

/// Строка с курсом: флаг, код и название валюты, покупка и продажа.
final class RateCell: UITableViewCell {
    static let reuseID = "RateCell"
    static let valueColumnWidth: CGFloat = 84

    private let flagLabel = UILabel()
    private let codeLabel = UILabel()
    private let titleLabel = UILabel()
    private let buyLabel = UILabel()
    private let sellLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with rate: ExchangeRate) {
        flagLabel.text = rate.currency.flag
        codeLabel.text = rate.currency.code
        titleLabel.text = rate.currency.title
        buyLabel.text = rate.buyText
        sellLabel.text = rate.sellText
        accessibilityLabel = "\(rate.currency.title): покупка \(rate.buyText), продажа \(rate.sellText) сом"
    }

    private func setupLayout() {
        isAccessibilityElement = true

        flagLabel.font = UIFontMetrics(forTextStyle: .title1).scaledFont(for: .systemFont(ofSize: 30))
        flagLabel.adjustsFontForContentSizeCategory = true
        flagLabel.setContentHuggingPriority(.required, for: .horizontal)

        codeLabel.font = .preferredFont(forTextStyle: .headline)
        codeLabel.adjustsFontForContentSizeCategory = true

        titleLabel.font = .preferredFont(forTextStyle: .footnote)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .secondaryLabel
        titleLabel.lineBreakMode = .byTruncatingTail

        let valueFont = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .medium)
        for label in [buyLabel, sellLabel] {
            label.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: valueFont)
            label.adjustsFontForContentSizeCategory = true
            label.textAlignment = .right
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.7
        }

        let namesStack = UIStackView(arrangedSubviews: [codeLabel, titleLabel])
        namesStack.axis = .vertical
        namesStack.spacing = 2

        let views = [flagLabel, namesStack, buyLabel, sellLabel]
        views.forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        let margins = contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            flagLabel.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            flagLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            namesStack.leadingAnchor.constraint(equalTo: flagLabel.trailingAnchor, constant: 12),
            namesStack.topAnchor.constraint(equalTo: margins.topAnchor, constant: 2),
            namesStack.bottomAnchor.constraint(equalTo: margins.bottomAnchor, constant: -2),
            namesStack.trailingAnchor.constraint(lessThanOrEqualTo: buyLabel.leadingAnchor, constant: -8),

            sellLabel.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            sellLabel.widthAnchor.constraint(equalToConstant: Self.valueColumnWidth),
            sellLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            buyLabel.trailingAnchor.constraint(equalTo: sellLabel.leadingAnchor),
            buyLabel.widthAnchor.constraint(equalToConstant: Self.valueColumnWidth),
            buyLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }
}
