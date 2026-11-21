import Foundation

/// valuta.kg: блок "Средний курс в Бишкеке" на главной странице.
/// Это средний курс по активным обменным пунктам Бишкека за последние два часа.
/// API у сайта нет, поэтому разбираем HTML. Сайт просит ссылку на источник, она есть в приложении и виджете.
public struct ValutaKGSource: RateSource {
    public let id: RateSourceID = .valutaKG
    var http = HTTPClient()

    public init() {}

    public func fetch() async throws -> RatesSnapshot {
        let data = try await http.get(id.url, accept: "text/html")
        guard let html = String(data: data, encoding: .utf8) else {
            throw RatesError.parsing("страница valuta.kg не в UTF-8")
        }
        return RatesSnapshot(rates: try ValutaKGParser.parse(html: html), source: id)
    }
}

public enum ValutaKGParser {
    static let averageTitle = "Средний курс в Бишкеке"

    public static func parse(html: String) throws -> [ExchangeRate] {
        guard let titleRange = html.range(of: averageTitle) else {
            throw RatesError.parsing("нет блока \"\(averageTitle)\"")
        }

        // Названия валют стоят в отдельной таблице прямо перед блоком со средним курсом.
        let before = html[..<titleRange.lowerBound]
        guard let namesStart = before.range(of: "kurs-bar__item--rate-names", options: .backwards) else {
            throw RatesError.parsing("нет списка валют")
        }
        let codes = before[namesStart.upperBound...]
            .matches(of: #/rate-name\s+-with-icon\s+-([a-z]{3})/#)
            .map { String($0.output.1) }

        // Значения: первая таблица после заголовка, строки вида <td>покупка</td><td>продажа</td>.
        let after = html[titleRange.upperBound...]
        guard let bodyStart = after.range(of: "<tbody>"),
              let bodyEnd = after.range(of: "</tbody>", range: bodyStart.upperBound..<after.endIndex) else {
            throw RatesError.parsing("нет таблицы среднего курса")
        }
        let rows = after[bodyStart.upperBound..<bodyEnd.lowerBound]
            .matches(of: #/<tr>\s*<td>\s*([^<]*?)\s*</td>\s*<td>\s*([^<]*?)\s*</td>\s*</tr>/#)
            .map { (String($0.output.1), String($0.output.2)) }

        guard !codes.isEmpty, codes.count == rows.count else {
            throw RatesError.parsing("валют \(codes.count), строк \(rows.count)")
        }

        return zip(codes, rows).compactMap { code, row in
            guard let currency = Currency(rawValue: code),
                  let buy = RateFormatter.decimal(from: row.0),
                  let sell = RateFormatter.decimal(from: row.1) else {
                return nil
            }
            return ExchangeRate(currency: currency, buy: buy, sell: sell)
        }
    }
}
