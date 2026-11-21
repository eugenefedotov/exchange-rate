import Foundation

/// akchabar.kg: открытый JSON API сайта, строка "mossovet" (сводный курс обменок Моссовета).
/// Обновляется реже, чем valuta.kg, поэтому используется как запасной источник.
public struct AkchabarSource: RateSource {
    public let id: RateSourceID = .akchabar
    static let endpoint = URL(string: "https://www.akchabar.kg/api/v2/rates/")!
    var http = HTTPClient()

    public init() {}

    public func fetch() async throws -> RatesSnapshot {
        let data = try await http.get(Self.endpoint, accept: "application/json")
        return RatesSnapshot(rates: try AkchabarParser.parse(json: data), source: id)
    }
}

public enum AkchabarParser {
    struct Entry: Decodable {
        let rateFrom: String
        let rateValues: [String: Double?]

        enum CodingKeys: String, CodingKey {
            case rateFrom = "rate_from"
            case rateValues = "rate_values"
        }
    }

    public static func parse(json: Data) throws -> [ExchangeRate] {
        let entries: [Entry]
        do {
            entries = try JSONDecoder().decode([Entry].self, from: json)
        } catch {
            throw RatesError.parsing("akchabar.kg: \(error.localizedDescription)")
        }
        guard let mossovet = entries.first(where: { $0.rateFrom == "mossovet" }) else {
            throw RatesError.parsing("akchabar.kg: нет строки mossovet")
        }
        return Currency.allCases.compactMap { currency in
            guard let buy = mossovet.rateValues["\(currency.rawValue)_buy_rate"] ?? nil,
                  let sell = mossovet.rateValues["\(currency.rawValue)_sell_rate"] ?? nil,
                  let buyValue = RateFormatter.decimal(from: buy),
                  let sellValue = RateFormatter.decimal(from: sell) else {
                return nil
            }
            return ExchangeRate(currency: currency, buy: buyValue, sell: sellValue)
        }
    }
}
