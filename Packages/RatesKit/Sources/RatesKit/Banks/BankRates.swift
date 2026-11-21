import Foundation

/// Банки, курсы которых показываем отдельными категориями.
public enum Bank: String, Codable, Sendable, CaseIterable, Hashable {
    case bakai
    case mbank

    public var title: String {
        switch self {
        case .bakai: "Бакай Банк"
        case .mbank: "МБанк"
        }
    }

    /// Для переключателя в виджете, где места мало.
    public var shortTitle: String {
        switch self {
        case .bakai: "Бакай"
        case .mbank: "МБанк"
        }
    }

    public var source: RateSourceID {
        switch self {
        case .bakai: .bakai
        case .mbank: .mbank
        }
    }
}

/// Какой курс банка показывать.
public enum BankRateKind: String, Codable, Sendable, CaseIterable, Hashable {
    /// Наличные в кассе головного отделения.
    case cash
    /// Безналичная конвертация: в мобильном приложении банка, между счетами и картами.
    case nonCash

    public var title: String {
        switch self {
        case .cash: "Наличные"
        case .nonCash: "Безнал"
        }
    }

    public var shortTitle: String {
        switch self {
        case .cash: "нал"
        case .nonCash: "безнал"
        }
    }

    public var details: String {
        switch self {
        case .cash: "Наличный курс головного отделения"
        case .nonCash: "Безналичный курс: конвертация в приложении банка и по картам"
        }
    }
}

/// Курсы одного банка за один запрос.
public struct BankRatesSnapshot: Codable, Sendable, Hashable {
    public var bank: Bank
    public var cash: [ExchangeRate]
    public var nonCash: [ExchangeRate]
    /// Время, с которого действуют курсы, по данным самого банка.
    public var bankUpdatedAt: Date?
    public var fetchedAt: Date

    public init(bank: Bank, cash: [ExchangeRate], nonCash: [ExchangeRate], bankUpdatedAt: Date?, fetchedAt: Date = .now) {
        self.bank = bank
        self.cash = cash
        self.nonCash = nonCash
        self.bankUpdatedAt = bankUpdatedAt
        self.fetchedAt = fetchedAt
    }

    public func rates(_ kind: BankRateKind, in order: [Currency] = Currency.displayOrder) -> [ExchangeRate] {
        let list = kind == .cash ? cash : nonCash
        return order.compactMap { currency in list.first { $0.currency == currency } }
    }

    /// Время для подписи: банковское, а если его нет, время загрузки.
    public var updatedAt: Date { bankUpdatedAt ?? fetchedAt }
}

extension BankRatesSnapshot {
    public static func sample(_ bank: Bank) -> BankRatesSnapshot {
        func rate(_ currency: Currency, _ buy: String, _ sell: String) -> ExchangeRate {
            ExchangeRate(currency: currency, buy: Decimal(string: buy)!, sell: Decimal(string: sell)!)
        }
        return BankRatesSnapshot(
            bank: bank,
            cash: [
                rate(.rub, "0.98", "1.09"),
                rate(.usd, "87.3", "87.8"),
                rate(.eur, "96", "97"),
                rate(.kzt, "0.19", "0.21"),
            ],
            nonCash: [
                rate(.rub, "1.01", "1.11"),
                rate(.usd, "87", "87.5"),
                rate(.eur, "96", "97"),
                rate(.kzt, "0.185", "0.205"),
            ],
            bankUpdatedAt: .now
        )
    }
}
