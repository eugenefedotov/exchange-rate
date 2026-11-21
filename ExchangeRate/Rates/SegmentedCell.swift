import UIKit

/// Ячейка с сегментированным переключателем на всю ширину.
final class SegmentedCell: UITableViewCell {
    static let reuseID = "SegmentedCell"

    private let control = UISegmentedControl()
    private var onChange: ((Int) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        control.translatesAutoresizingMaskIntoConstraints = false
        control.addTarget(self, action: #selector(valueChanged), for: .valueChanged)
        contentView.addSubview(control)

        let margins = contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            control.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            control.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            control.topAnchor.constraint(equalTo: margins.topAnchor),
            control.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(items: [String], selectedIndex: Int, onChange: @escaping (Int) -> Void) {
        if control.numberOfSegments != items.count {
            control.removeAllSegments()
            for (index, title) in items.enumerated() {
                control.insertSegment(withTitle: title, at: index, animated: false)
            }
        }
        control.selectedSegmentIndex = selectedIndex
        self.onChange = onChange
    }

    @objc private func valueChanged() {
        onChange?(control.selectedSegmentIndex)
    }
}
