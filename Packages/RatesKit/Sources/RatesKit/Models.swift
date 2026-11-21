import Foundation

/// Курс одной валюты в сомах: сколько сомов дают (buy) и просят (sell) за 1 единицу валюты.
public struct ExchangeRate: Codable, Sendable, Hashable, Identifiable {
    public var currency: Currency
    /// Обменка покупает валюту у вас по этому курсу.
    public var buy: Decimal
    /// Обменка продаёт валюту вам по этому курсу.
    public var sell: Decimal

    public var id: Currency { currency }

    public init(currency: Currency, buy: Decimal, sell: Decimal) {
        self.currency = currency
        self.buy = buy
        self.sell = sell
    }
}

/// Откуда взяли курсы.
public enum RateSourceID: String, Codable, Sendable, Hashable {
    case valutaKG
    case akchabar
    case bakai
    case mbank
    case cbr

    public var name: String {
        switch self {
        case .valutaKG: "valuta.kg"
        case .akchabar: "akchabar.kg"
        case .bakai: "bakai.kg"
        case .mbank: "mbank.kg"
        case .cbr: "cbr.ru"
        }
    }

    /// Короткое пояснение, что именно это за курс.
    public var details: String {
        switch self {
        case .valutaKG: "Средний курс обменок Бишкека за последние 2 часа"
        case .akchabar: "Средний курс обменок Моссовета"
        case .bakai: "Курс Бакай Банка"
        case .mbank: "Курс МБанка"
        case .cbr: "Официальный курс ЦБ РФ"
        }
    }

    public var url: URL {
        switch self {
        case .valutaKG: URL(string: "https://valuta.kg/")!
        case .akchabar: URL(string: "https://www.akchabar.kg/ru/currency-rate")!
        case .bakai: URL(string: "https://bakai.kg/")!
        case .mbank: URL(string: "https://mbank.kg/")!
        case .cbr: URL(string: "https://www.cbr.ru/currency_base/daily/")!
        }
    }
}

/// Набор курсов, полученный за один запрос.
public struct RatesSnapshot: Codable, Sendable, Hashable {
    public var rates: [ExchangeRate]
    public var source: RateSourceID
    public var fetchedAt: Date

    public init(rates: [ExchangeRate], source: RateSourceID, fetchedAt: Date = .now) {
        self.rates = rates
        self.source = source
        self.fetchedAt = fetchedAt
    }

    public func rate(for currency: Currency) -> ExchangeRate? {
        rates.first { $0.currency == currency }
    }

    /// Курсы в заданном порядке, отсутствующие валюты пропускаются.
    public func rates(in order: [Currency] = Currency.displayOrder) -> [ExchangeRate] {
        order.compactMap(rate(for:))
    }
}

public enum RatesError: Error, Sendable, LocalizedError {
    case badStatus(Int)
    case parsing(String)
    case missingCurrencies([Currency])
    case allSourcesFailed([String])

    public var errorDescription: String? {
        switch self {
        case .badStatus(let code):
            "Сервер ответил с кодом \(code)"
        case .parsing(let reason):
            "Не удалось разобрать ответ: \(reason)"
        case .missingCurrencies(let list):
            "Нет курсов для \(list.map(\.code).joined(separator: ", "))"
        case .allSourcesFailed(let reasons):
            "Ни один источник не ответил. " + reasons.joined(separator: "; ")
        }
    }
}
