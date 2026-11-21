import UIKit

/// Строка курса донга: флаг и валюта слева, сколько донгов за 1 единицу справа.
/// Вёрстка как у RateCell, только вместо двух колонок одно значение.
final class DongCell: UITableViewCell {
    static let reuseID = "DongCell"

    private let flagLabel = UILabel()
    private let codeLabel = UILabel()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(flag: String, code: String, title: String, value: String) {
        flagLabel.text = flag
        codeLabel.text = code
        titleLabel.text = title
        valueLabel.text = "\(value) ₫"
        accessibilityLabel = "1 \(title.lowercased()): \(value) донгов"
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

        valueLabel.font = UIFontMetrics(forTextStyle: .body)
            .scaledFont(for: .monospacedDigitSystemFont(ofSize: 17, weight: .medium))
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.textAlignment = .right
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let namesStack = UIStackView(arrangedSubviews: [codeLabel, titleLabel])
        namesStack.axis = .vertical
        namesStack.spacing = 2

        [flagLabel, namesStack, valueLabel].forEach {
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
            namesStack.trailingAnchor.constraint(lessThanOrEqualTo: valueLabel.leadingAnchor, constant: -8),

            valueLabel.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }
}
