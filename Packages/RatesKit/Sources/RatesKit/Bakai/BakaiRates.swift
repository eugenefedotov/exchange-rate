import Foundation

/// Какой курс Бакай Банка показывать.
public enum BakaiRateKind: String, Codable, Sendable, CaseIterable, Hashable {
    /// Наличные в кассе головного отделения.
    case cash
    /// Безналичная конвертация: в приложении BAKAI, между счетами и картами.
    case nonCash

    public var title: String {
        switch self {
        case .cash: "Наличные"
        case .nonCash: "Безнал"
        }
    }

    public var details: String {
        switch self {
        case .cash: "Наличный курс головного отделения"
        case .nonCash: "Безналичный курс: конвертация в приложении и по картам"
        }
    }
}

/// Курсы Бакай Банка за один запрос.
public struct BakaiRatesSnapshot: Codable, Sendable, Hashable {
    public var cash: [ExchangeRate]
    public var nonCash: [ExchangeRate]
    /// Время, на которое банк отдал курсы (по данным самого банка).
    public var bankUpdatedAt: Date?
    public var fetchedAt: Date

    public init(cash: [ExchangeRate], nonCash: [ExchangeRate], bankUpdatedAt: Date?, fetchedAt: Date = .now) {
        self.cash = cash
        self.nonCash = nonCash
        self.bankUpdatedAt = bankUpdatedAt
        self.fetchedAt = fetchedAt
    }

    public func rates(_ kind: BakaiRateKind, in order: [Currency] = Currency.displayOrder) -> [ExchangeRate] {
        let list = kind == .cash ? cash : nonCash
        return order.compactMap { currency in list.first { $0.currency == currency } }
    }

    /// Время для подписи: банковское, а если его нет, время загрузки.
    public var updatedAt: Date { bankUpdatedAt ?? fetchedAt }

    public static let source: RateSourceID = .bakai
}

extension BakaiRatesSnapshot {
    public static let sample = BakaiRatesSnapshot(
        cash: [
            ExchangeRate(currency: .rub, buy: Decimal(string: "0.98")!, sell: Decimal(string: "1.09")!),
            ExchangeRate(currency: .usd, buy: Decimal(string: "87.3")!, sell: Decimal(string: "87.8")!),
            ExchangeRate(currency: .eur, buy: Decimal(string: "96")!, sell: Decimal(string: "97")!),
            ExchangeRate(currency: .kzt, buy: Decimal(string: "0.19")!, sell: Decimal(string: "0.21")!),
            ExchangeRate(currency: .cny, buy: Decimal(string: "12.8")!, sell: Decimal(string: "13.8")!),
        ],
        nonCash: [
            ExchangeRate(currency: .rub, buy: Decimal(string: "1.01")!, sell: Decimal(string: "1.11")!),
            ExchangeRate(currency: .usd, buy: Decimal(string: "87")!, sell: Decimal(string: "87.5")!),
            ExchangeRate(currency: .eur, buy: Decimal(string: "96")!, sell: Decimal(string: "97")!),
            ExchangeRate(currency: .kzt, buy: Decimal(string: "0.185")!, sell: Decimal(string: "0.205")!),
            ExchangeRate(currency: .cny, buy: Decimal(string: "12.8")!, sell: Decimal(string: "13.8")!),
        ],
        bankUpdatedAt: .now
    )
}
