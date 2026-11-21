import Foundation

/// Курсы Бакай Банка из открытого API их сайта (тот же, что рисует виджет курсов на bakai.kg).
public struct BakaiService: Sendable {
    static let endpoint = URL(string: "https://bakai.kg/bbank/api/currencies/")!

    var http = HTTPClient()
    public var cache: RatesCache?

    public init(cache: RatesCache? = .bakai) {
        self.cache = cache
    }

    public func cached() -> BakaiRatesSnapshot? {
        cache?.load(BakaiRatesSnapshot.self)
    }

    public func fetch() async throws -> BakaiRatesSnapshot {
        let data = try await http.get(Self.endpoint, accept: "application/json")
        let snapshot = try BakaiParser.parse(json: data)
        let missing = RatesService.requiredCurrencies.filter { currency in
            !snapshot.cash.contains { $0.currency == currency }
        }
        guard missing.isEmpty else { throw RatesError.missingCurrencies(missing) }
        cache?.save(snapshot)
        return snapshot
    }
}

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

    public static func parse(json: Data, fetchedAt: Date = .now) throws -> BakaiRatesSnapshot {
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

        return BakaiRatesSnapshot(
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
        let trimmed = String(text.prefix(19))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Bishkek")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: trimmed)
    }
}
