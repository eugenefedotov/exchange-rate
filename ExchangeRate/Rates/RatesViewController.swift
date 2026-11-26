import RatesKit
import SafariServices
import UIKit
import WidgetKit

/// Главный экран: курсы обменок и банков к сому, источники и время обновления.
final class RatesViewController: UITableViewController {
    /// Чаще не дёргаем сайты при возврате в приложение.
    private static let foregroundRefreshInterval: TimeInterval = 10 * 60
    private static let footerReuseID = "RatesFooter"
    private static let sourceReuseID = "SourceCell"

    private let exchangeService = RatesService()
    private let bankServices = Bank.allCases.map(BankService.init(bank:))
    private let dongService = DongService()

    private var exchange: RatesSnapshot?
    private var exchangeError: String?
    private var banks: [Bank: BankRatesSnapshot] = [:]
    private var bankErrors: [Bank: String] = [:]
    private var dong: DongRates?
    private var dongError: String?
    /// Наличные или безнал, отдельно для каждого банка. Запоминается между запусками.
    private var bankKinds: [Bank: BankRateKind] = [:]

    private var refreshTask: Task<Void, Never>?
    /// Пока приложение на экране, обновляемся сами раз в 10 минут. В фоне iOS приложение не будит,
    /// за фоновые обновления отвечает виджет.
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
        tableView.register(DongCell.self, forCellReuseIdentifier: DongCell.reuseID)
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

        for bank in Bank.allCases {
            bankKinds[bank] = UserDefaults.standard.string(forKey: Self.kindKey(bank)).flatMap(BankRateKind.init) ?? .cash
        }
        exchange = exchangeService.cached()
        for service in bankServices {
            banks[service.bank] = service.cached()
        }
        dong = dongService.cached()
        render(animated: false)
        refresh()
        startAutoRefresh()
    }

    private static func kindKey(_ bank: Bank) -> String {
        "bankRateKind.\(bank.rawValue)"
    }

    private func kind(for bank: Bank) -> BankRateKind {
        bankKinds[bank] ?? .cash
    }

    // MARK: - Загрузка

    @objc private func pullToRefresh() {
        refresh()
    }

    @objc private func willEnterForeground() {
        let dates = [exchange?.fetchedAt, dong?.fetchedAt] + Bank.allCases.map { banks[$0]?.fetchedAt }
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
        refreshTask = Task { [weak self, exchangeService, bankServices, dongService] in
            // Все источники параллельно: медленный сайт не задерживает остальные.
            async let exchange = Self.capture { try await exchangeService.fetch() }
            async let dong = Self.capture { try await dongService.fetch() }
            let banks = await withTaskGroup(of: (Bank, Result<BankRatesSnapshot, Error>).self) { group in
                for service in bankServices {
                    group.addTask { (service.bank, await Self.capture { try await service.fetch() }) }
                }
                var results: [Bank: Result<BankRatesSnapshot, Error>] = [:]
                for await (bank, result) in group {
                    results[bank] = result
                }
                return results
            }
            self?.apply(exchange: await exchange, banks: banks, dong: await dong)
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

    private func apply(
        exchange exchangeResult: Result<RatesSnapshot, Error>,
        banks bankResults: [Bank: Result<BankRatesSnapshot, Error>],
        dong dongResult: Result<DongRates, Error>
    ) {
        refreshTask = nil
        refreshControl?.endRefreshing()

        var anySuccess = false
        switch exchangeResult {
        case .success(let snapshot):
            exchange = snapshot
            exchangeError = nil
            anySuccess = true
        case .failure(let error):
            exchangeError = error.localizedDescription
        }
        for (bank, result) in bankResults {
            switch result {
            case .success(let snapshot):
                banks[bank] = snapshot
                bankErrors[bank] = nil
                anySuccess = true
            case .failure(let error):
                bankErrors[bank] = error.localizedDescription
            }
        }

        switch dongResult {
        case .success(let rates): dong = rates; dongError = nil
        case .failure(let error): dongError = error.localizedDescription
        }

        // У виджета свой кэш, общего без App Group нет. Просим его тоже сходить в сеть,
        // чтобы он увидел те же цифры и время изменения совпало с приложением.
        if anySuccess {
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
            case .bankRate(let bank, let currency):
                let rate = banks[bank]?.rates(kind(for: bank), in: [currency]).first
                return rateCell(tableView, indexPath, rate)
            case .bankKind(let bank):
                let cell = tableView.dequeueReusableCell(withIdentifier: SegmentedCell.reuseID, for: indexPath)
                let kinds = BankRateKind.allCases
                (cell as? SegmentedCell)?.configure(
                    items: kinds.map(\.title),
                    selectedIndex: kinds.firstIndex(of: kind(for: bank)) ?? 0
                ) { [weak self] index in
                    self?.select(kinds[index], for: bank)
                }
                return cell
            case .dong(let base):
                let cell = tableView.dequeueReusableCell(withIdentifier: DongCell.reuseID, for: indexPath)
                if let dong {
                    switch base {
                    case .ruble:
                        (cell as? DongCell)?.configure(flag: "🇷🇺", code: "1 RUB", title: "Рубль", value: dong.perRubleText)
                    case .som:
                        (cell as? DongCell)?.configure(flag: "🇰🇬", code: "1 KGS", title: "Сом", value: dong.perSomText)
                    }
                }
                return cell
            case .source(let source):
                let cell = tableView.dequeueReusableCell(withIdentifier: Self.sourceReuseID, for: indexPath)
                var content = UIListContentConfiguration.valueCell()
                content.text = Self.sourceTitle(source)
                content.secondaryText = source.name
                cell.contentConfiguration = content
                cell.accessoryType = .disclosureIndicator
                return cell
            }
        }
        dataSource.defaultRowAnimation = .fade
        return dataSource
    }

    private static func sourceTitle(_ source: RateSourceID) -> String {
        if source == DongRates.source { return "Донг" }
        return Bank.allCases.first { $0.source == source }?.title ?? "Обменки"
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
        var sources: [RateSourceID] = []

        if let exchange {
            diff.appendSections([.exchange])
            diff.appendItems(exchange.rates(in: Currency.displayOrder).map { .exchange($0.currency) }, toSection: .exchange)
            sources.append(exchange.source)
        }
        for bank in Bank.allCases {
            guard let snapshot = banks[bank] else { continue }
            let section = RatesSection.bank(bank)
            diff.appendSections([section])
            diff.appendItems([.bankKind(bank)], toSection: section)
            diff.appendItems(snapshot.rates(kind(for: bank)).map { .bankRate(bank, $0.currency) }, toSection: section)
            sources.append(bank.source)
        }
        if dong != nil {
            diff.appendSections([.dong])
            diff.appendItems(DongBase.allCases.map { .dong($0) }, toSection: .dong)
            sources.append(DongRates.source)
        }
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

    private func select(_ kind: BankRateKind, for bank: Bank) {
        guard kind != self.kind(for: bank) else { return }
        bankKinds[bank] = kind
        UserDefaults.standard.set(kind.rawValue, forKey: Self.kindKey(bank))
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
            lines.append("\(exchange.source.details). Курс изменился \(exchange.changedAtText()).")
            if let exchangeError { lines.append("Не удалось обновить: \(exchangeError)") }
        case .bank(let bank):
            guard let snapshot = banks[bank] else { return nil }
            lines.append("\(kind(for: bank).details). Курс банка обновлён \(snapshot.updatedAt.ratesTimeText()).")
            if let error = bankErrors[bank] { lines.append("Не удалось обновить: \(error)") }
        case .dong:
            guard let dong else { return nil }
            let date = (dong.rateDate ?? dong.fetchedAt).formatted(.dateTime.day(.twoDigits).month(.twoDigits))
            lines.append("Сколько донгов за 1 рубль или 1 сом по курсу ЦБ РФ на \(date). В обменках Бишкека донг не меняют, к сому курс пересчитан через рубль.")
            if let dongError { lines.append("Не удалось обновить: \(dongError)") }
        case .sources:
            lines.append("В обменках и банках указано, сколько сомов дают и просят за 1 единицу валюты.")
        }
        return lines.joined(separator: "\n")
    }

    private func makeEmptyView() -> UIView {
        let label = UILabel()
        let error = exchangeError ?? Bank.allCases.compactMap { bankErrors[$0] }.first
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
        header.configure(title: title, showsColumns: identifier != .dong)
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
