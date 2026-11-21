import RatesKit
import SafariServices
import UIKit
import WidgetKit

/// Главный экран: курсы обменок и Бакай Банка к сому, источники и время обновления.
final class RatesViewController: UITableViewController {
    /// Чаще не дёргаем сайты при возврате в приложение.
    private static let foregroundRefreshInterval: TimeInterval = 10 * 60
    private static let footerReuseID = "RatesFooter"
    private static let sourceReuseID = "SourceCell"
    private static let bakaiKindKey = "bakaiRateKind"

    private let exchangeService = RatesService()
    private let bakaiService = BakaiService()

    private var exchange: RatesSnapshot?
    private var exchangeError: String?
    private var bakai: BakaiRatesSnapshot?
    private var bakaiError: String?
    private var bakaiKind: BakaiRateKind = .cash {
        didSet { UserDefaults.standard.set(bakaiKind.rawValue, forKey: Self.bakaiKindKey) }
    }

    private var refreshTask: Task<Void, Never>?
    /// Пока приложение на экране, обновляемся сами раз в 10 минут. В фоне iOS приложение не будит,
    /// за фоновые обновления отвечают виджеты.
    private var autoRefreshTask: Task<Void, Never>?
    private lazy var dataSource = makeDataSource()

    init() {
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Курсы Валют"
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true

        tableView.register(RateCell.self, forCellReuseIdentifier: RateCell.reuseID)
        tableView.register(SegmentedCell.self, forCellReuseIdentifier: SegmentedCell.reuseID)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.sourceReuseID)
        tableView.register(RatesHeaderView.self, forHeaderFooterViewReuseIdentifier: RatesHeaderView.reuseID)
        tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: Self.footerReuseID)
        tableView.dataSource = dataSource

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        self.refreshControl = refreshControl

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        if let saved = UserDefaults.standard.string(forKey: Self.bakaiKindKey).flatMap(BakaiRateKind.init) {
            bakaiKind = saved
        }
        exchange = exchangeService.cached()
        bakai = bakaiService.cached()
        render(animated: false)
        refresh()
        startAutoRefresh()
    }

    // MARK: - Загрузка

    @objc private func pullToRefresh() {
        refresh()
    }

    @objc private func willEnterForeground() {
        let dates = [exchange?.fetchedAt, bakai?.fetchedAt]
        let oldest = dates.map { $0 ?? .distantPast }.min() ?? .distantPast
        if Date.now.timeIntervalSince(oldest) > Self.foregroundRefreshInterval {
            refresh()
        }
        startAutoRefresh()
    }

    @objc private func didEnterBackground() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    private func startAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.foregroundRefreshInterval))
                guard !Task.isCancelled else { return }
                self?.refresh()
            }
        }
    }

    private func refresh() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self, exchangeService, bakaiService] in
            // Оба источника параллельно: медленный сайт не задерживает второй.
            async let exchange = Self.capture { try await exchangeService.fetch() }
            async let bakai = Self.capture { try await bakaiService.fetch() }
            let results = await (exchange, bakai)
            self?.apply(exchange: results.0, bakai: results.1)
        }
    }

    private nonisolated static func capture<T: Sendable>(
        _ operation: @Sendable () async throws -> T
    ) async -> Result<T, Error> {
        do {
            return .success(try await operation())
        } catch {
            return .failure(error)
        }
    }

    private func apply(exchange exchangeResult: Result<RatesSnapshot, Error>, bakai bakaiResult: Result<BakaiRatesSnapshot, Error>) {
        refreshTask = nil
        refreshControl?.endRefreshing()

        switch exchangeResult {
        case .success(let snapshot): exchange = snapshot; exchangeError = nil
        case .failure(let error): exchangeError = error.localizedDescription
        }
        switch bakaiResult {
        case .success(let snapshot): bakai = snapshot; bakaiError = nil
        case .failure(let error): bakaiError = error.localizedDescription
        }

        // Виджеты живут своей жизнью, но раз уж данные свежие, пусть обновятся и они.
        if exchangeError == nil || bakaiError == nil {
            WidgetCenter.shared.reloadAllTimelines()
        }
        render(animated: true)
    }

    // MARK: - Данные таблицы

    private func makeDataSource() -> RatesDataSource {
        let dataSource = RatesDataSource(tableView: tableView) { [weak self] tableView, indexPath, item in
            guard let self else { return UITableViewCell() }
            switch item {
            case .exchange(let currency):
                return rateCell(tableView, indexPath, exchange?.rate(for: currency))
            case .bakai(let currency):
                let rate = bakai?.rates(bakaiKind, in: [currency]).first
                return rateCell(tableView, indexPath, rate)
            case .bakaiKind:
                let cell = tableView.dequeueReusableCell(withIdentifier: SegmentedCell.reuseID, for: indexPath)
                let kinds = BakaiRateKind.allCases
                (cell as? SegmentedCell)?.configure(
                    items: kinds.map(\.title),
                    selectedIndex: kinds.firstIndex(of: bakaiKind) ?? 0
                ) { [weak self] index in
                    self?.selectBakaiKind(kinds[index])
                }
                return cell
            case .source(let source):
                let cell = tableView.dequeueReusableCell(withIdentifier: Self.sourceReuseID, for: indexPath)
                var content = UIListContentConfiguration.valueCell()
                content.text = source == .bakai ? "Бакай Банк" : "Обменки"
                content.secondaryText = source.name
                cell.contentConfiguration = content
                cell.accessoryType = .disclosureIndicator
                return cell
            }
        }
        dataSource.defaultRowAnimation = .fade
        return dataSource
    }

    private func rateCell(_ tableView: UITableView, _ indexPath: IndexPath, _ rate: ExchangeRate?) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: RateCell.reuseID, for: indexPath)
        if let rate {
            (cell as? RateCell)?.configure(with: rate)
        }
        return cell
    }

    private func render(animated: Bool) {
        let previous = dataSource.snapshot()
        var diff = RatesDiffSnapshot()

        if let exchange {
            diff.appendSections([.exchange])
            diff.appendItems(exchange.rates(in: Currency.displayOrder).map { .exchange($0.currency) }, toSection: .exchange)
        }
        if let bakai {
            diff.appendSections([.bakai])
            diff.appendItems([.bakaiKind], toSection: .bakai)
            diff.appendItems(bakai.rates(bakaiKind).map { .bakai($0.currency) }, toSection: .bakai)
        }
        let sources = [exchange.map(\.source), bakai.map { _ in RateSourceID.bakai }].compactMap { $0 }
        if !sources.isEmpty {
            diff.appendSections([.sources])
            diff.appendItems(sources.map { .source($0) }, toSection: .sources)
        }

        // Строки, которые уже были на экране, получают новые цифры без пересоздания ячеек.
        diff.reconfigureItems(diff.itemIdentifiers.filter { previous.indexOfItem($0) != nil })
        dataSource.apply(diff, animatingDifferences: animated) { [weak self] in
            self?.updateVisibleFooters()
        }
        tableView.backgroundView = sources.isEmpty ? makeEmptyView() : nil
    }

    private func selectBakaiKind(_ kind: BakaiRateKind) {
        guard kind != bakaiKind else { return }
        bakaiKind = kind
        render(animated: true)
    }

    // MARK: - Подвалы

    /// Подвалы с временем обновления не входят в diffable-снимок, поэтому обновляем их руками.
    private func updateVisibleFooters() {
        for section in dataSource.snapshot().sectionIdentifiers {
            guard let index = dataSource.index(for: section),
                  let footer = tableView.footerView(forSection: index) else { continue }
            configureFooter(footer, for: section)
        }
        tableView.performBatchUpdates(nil)
    }

    private func configureFooter(_ footer: UITableViewHeaderFooterView, for section: RatesSection) {
        var content = UIListContentConfiguration.groupedFooter()
        content.text = footerText(for: section)
        footer.contentConfiguration = content
    }

    private func footerText(for section: RatesSection) -> String? {
        var lines: [String] = []
        switch section {
        case .exchange:
            guard let exchange else { return nil }
            lines.append("\(exchange.source.details). Обновлено \(exchange.fetchedAtText()).")
            if let exchangeError { lines.append("Не удалось обновить: \(exchangeError)") }
        case .bakai:
            guard let bakai else { return nil }
            lines.append("\(bakaiKind.details). Данные банка на \(bakai.updatedAt.ratesTimeText()).")
            if let bakaiError { lines.append("Не удалось обновить: \(bakaiError)") }
        case .sources:
            lines.append("Везде указано, сколько сомов дают и просят за 1 единицу валюты.")
        }
        return lines.joined(separator: "\n")
    }

    private func makeEmptyView() -> UIView {
        let label = UILabel()
        let error = exchangeError ?? bakaiError
        label.text = error.map { "Не удалось загрузить курсы.\n\($0)" } ?? "Загружаем курсы..."
        label.textColor = .secondaryLabel
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        let container = UIView()
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: container.layoutMarginsGuide.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: container.layoutMarginsGuide.trailingAnchor, constant: -16),
        ])
        return container
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let identifier = dataSource.sectionIdentifier(for: section), let title = identifier.title,
              let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: RatesHeaderView.reuseID)
                as? RatesHeaderView else {
            return nil
        }
        header.configure(title: title)
        return header
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard let identifier = dataSource.sectionIdentifier(for: section),
              let footer = tableView.dequeueReusableHeaderFooterView(withIdentifier: Self.footerReuseID) else {
            return nil
        }
        configureFooter(footer, for: identifier)
        return footer
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        if case .source = dataSource.itemIdentifier(for: indexPath) { return true }
        return false
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard case .source(let source) = dataSource.itemIdentifier(for: indexPath) else { return }
        present(SFSafariViewController(url: source.url), animated: true)
    }
}
