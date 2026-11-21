import Foundation

extension ExchangeRate {
    public var buyText: String { RateFormatter.string(buy, digits: currency.fractionDigits) }
    public var sellText: String { RateFormatter.string(sell, digits: currency.fractionDigits) }
}

enum RateFormatter {
    static func string(_ value: Decimal, digits: Int) -> String {
        value.formatted(
            .number
                .precision(.fractionLength(digits))
                .grouping(.never)
                .locale(Locale(identifier: "en_US_POSIX"))
        )
    }

    /// Разбирает число вида "87.55" или "1,015". Пустые значения и прочерки дают nil.
    static func decimal(from text: String) -> Decimal? {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, let value = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")),
              value > 0 else {
            return nil
        }
        return value
    }

    static func decimal(from value: Double) -> Decimal? {
        guard value > 0 else { return nil }
        // Через строку, чтобы 87.42 не превратилось в 87.4199999...
        return Decimal(string: String(value), locale: Locale(identifier: "en_US_POSIX"))
    }
}
