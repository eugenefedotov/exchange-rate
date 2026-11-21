import Foundation

/// Курсы банка из открытого JSON его собственного сайта (того же, из которого сайт рисует блок курсов).
public struct BankService: Sendable {
    public let bank: Bank
    var http = HTTPClient()
    public var cache: RatesCache?

    /// С кэшем по умолчанию: файл в Caches текущего процесса.
    public init(bank: Bank) {
        self.init(bank: bank, cache: .bank(bank))
    }

    /// Кэш задаётся явно, nil отключает его (например, в консольной утилите).
    public init(bank: Bank, cache: RatesCache?) {
        self.bank = bank
        self.cache = cache
    }

    var endpoint: URL {
        switch bank {
        case .bakai: URL(string: "https://bakai.kg/bbank/api/currencies/")!
        case .mbank: URL(string: "https://mbank.kg/api/welcome_page/?type=individual")!
        }
    }

    public func cached() -> BankRatesSnapshot? {
        cache?.load(BankRatesSnapshot.self)
    }

    public func fetch() async throws -> BankRatesSnapshot {
        let data = try await http.get(endpoint, accept: "application/json")
        let snapshot = switch bank {
        case .bakai: try BakaiParser.parse(json: data)
        case .mbank: try MBankParser.parse(json: data)
        }
        let missing = RatesService.requiredCurrencies.filter { currency in
            !snapshot.cash.contains { $0.currency == currency }
        }
        guard missing.isEmpty else { throw RatesError.missingCurrencies(missing) }
        cache?.save(snapshot)
        return snapshot
    }
}

// MARK: - Бакай Банк

public enum BakaiParser {
    struct Response: Decodable {
        struct UpdateTime: Decodable {
            let lastExecution: String?
            enum CodingKeys: String, CodingKey { case lastExecution = "last_execution" }
        }

        struct Pair: Decodable {
            let buy: Double?
            let sell: Double?
        }

        /// Все поля необязательные: в том же массиве лежат металлы со своей структурой.
        struct Entry: Decodable {
            let cash: Pair?
            let nonCash: Pair?
            enum CodingKeys: String, CodingKey {
                case cash
                case nonCash = "non_cash"
            }
        }

        let latestUpdateTime: UpdateTime?
        let result: [[String: Entry]]

        enum CodingKeys: String, CodingKey {
            case latestUpdateTime = "latest_update_time"
            case result
        }
    }

    public static func parse(json: Data, fetchedAt: Date = .now) throws -> BankRatesSnapshot {
        let response: Response
        do {
            response = try JSONDecoder().decode(Response.self, from: json)
        } catch {
            throw RatesError.parsing("bakai.kg: \(error.localizedDescription)")
        }

        var cash: [ExchangeRate] = []
        var nonCash: [ExchangeRate] = []
        for item in response.result {
            for (code, entry) in item {
                guard let currency = Currency(rawValue: code.lowercased()) else { continue }
                if let rate = makeRate(currency, entry.cash) { cash.append(rate) }
                if let rate = makeRate(currency, entry.nonCash) { nonCash.append(rate) }
            }
        }

        return BankRatesSnapshot(
            bank: .bakai,
            cash: cash,
            nonCash: nonCash,
            bankUpdatedAt: response.latestUpdateTime?.lastExecution.flatMap(parseBankDate),
            fetchedAt: fetchedAt
        )
    }

    private static func makeRate(_ currency: Currency, _ pair: Response.Pair?) -> ExchangeRate? {
        guard let buy = pair?.buy.flatMap(RateFormatter.decimal(from:)),
              let sell = pair?.sell.flatMap(RateFormatter.decimal(from:)) else {
            return nil
        }
        return ExchangeRate(currency: currency, buy: buy, sell: sell)
    }

    /// "2026-11-21T13:30:00.137917" без часового пояса, это время Бишкека.
    static func parseBankDate(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Bishkek")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: String(text.prefix(19)))
    }
}

// MARK: - МБанк

public enum MBankParser {
    struct Response: Decodable {
        struct Exchange: Decodable {
            let cashExchange: [Table]
            enum CodingKeys: String, CodingKey { case cashExchange = "cash_exchange" }
        }

        /// Таблица курсов: "Для операций с наличными" или "Безналичные курсы".
        struct Table: Decodable {
            let operationType: String
            let actualFrom: String?
            let values: [Value]
            enum CodingKeys: String, CodingKey {
                case operationType = "operation_type"
                case actualFrom = "actual_from"
                case values
            }
        }

        /// Числа приходят строками: "87.5000".
        struct Value: Decodable {
            let currency: String
            let buy: String?
            let sell: String?
        }

        let exchange: Exchange
    }

    public static func parse(json: Data, fetchedAt: Date = .now) throws -> BankRatesSnapshot {
        let response: Response
        do {
            response = try JSONDecoder().decode(Response.self, from: json)
        } catch {
            throw RatesError.parsing("mbank.kg: \(error.localizedDescription)")
        }

        let tables = response.exchange.cashExchange
        let nonCashTable = tables.first { $0.operationType.lowercased().contains("безнал") }
        let cashTable = tables.first { $0.operationType.lowercased().contains("налич") && !$0.operationType.lowercased().contains("безнал") }
        guard let cashTable else {
            throw RatesError.parsing("mbank.kg: нет таблицы наличных курсов")
        }

        let dates = [cashTable.actualFrom, nonCashTable?.actualFrom].compactMap { $0.flatMap(parseDate) }
        return BankRatesSnapshot(
            bank: .mbank,
            cash: rates(from: cashTable),
            nonCash: nonCashTable.map(rates(from:)) ?? [],
            bankUpdatedAt: dates.max(),
            fetchedAt: fetchedAt
        )
    }

    private static func rates(from table: Response.Table) -> [ExchangeRate] {
        table.values.compactMap { value in
            guard let currency = Currency(rawValue: value.currency.lowercased()),
                  let buy = value.buy.flatMap(RateFormatter.decimal(from:)),
                  let sell = value.sell.flatMap(RateFormatter.decimal(from:)) else {
                return nil
            }
            return ExchangeRate(currency: currency, buy: buy, sell: sell)
        }
    }

    /// "2026-11-20T08:30:00+06:00".
    static func parseDate(_ text: String) -> Date? {
        ISO8601DateFormatter().date(from: text)
    }
}
