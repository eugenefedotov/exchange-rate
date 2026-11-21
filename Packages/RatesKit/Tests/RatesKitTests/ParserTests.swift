import Foundation
import Testing
@testable import RatesKit

/// Парсеры проверяются на сохранённых копиях страниц. Если сайт поменяет вёрстку,
/// обновите фикстуры и поправьте парсер.
struct ParserTests {
    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    @Test func valutaKGAverageRates() throws {
        let html = String(decoding: try fixture("valuta-kg.html"), as: UTF8.self)
        let rates = try ValutaKGParser.parse(html: html)

        #expect(rates.map(\.currency) == [.usd, .eur, .rub, .kzt, .cny, .gbp])
        #expect(rates.first { $0.currency == .rub }?.buyText == "1.015")
        #expect(rates.first { $0.currency == .rub }?.sellText == "1.025")
        #expect(rates.first { $0.currency == .usd }?.sell == Decimal(string: "87.85"))
        #expect(rates.first { $0.currency == .kzt }?.buyText == "0.1940")
    }

    @Test func valutaKGWithoutBlockThrows() {
        #expect(throws: RatesError.self) {
            try ValutaKGParser.parse(html: "<html><body>Технические работы</body></html>")
        }
    }

    @Test func valutaKGSkipsEmptyValues() throws {
        let html = """
        <div class="kurs-bar__item kurs-bar__item--rate-names">
          <div class="rate-name -with-icon -usd">usd</div>
          <div class="rate-name -with-icon -rub">rub</div>
        </div>
        <h2>Средний курс в Бишкеке</h2>
        <table><tbody>
          <tr><td>87.50</td><td>87.90</td></tr>
          <tr><td>-</td><td></td></tr>
        </tbody></table>
        """
        let rates = try ValutaKGParser.parse(html: html)
        #expect(rates.map(\.currency) == [.usd])
    }

    @Test func bakaiCashAndNonCash() throws {
        let snapshot = try BakaiParser.parse(json: try fixture("bakai.json"))

        let cashRub = try #require(snapshot.rates(.cash).first)
        #expect(cashRub.currency == .rub)
        #expect(cashRub.buy == Decimal(string: "0.98"))
        #expect(cashRub.sell == Decimal(string: "1.09"))

        let nonCashRub = try #require(snapshot.rates(.nonCash).first)
        #expect(nonCashRub.buy == Decimal(string: "1.01"))

        #expect(snapshot.rates(.cash).map(\.currency) == Currency.displayOrder)
        // 13:35 по Бишкеку (UTC+6) это 07:35 UTC.
        let expected = try #require(ISO8601DateFormatter().date(from: "2026-11-21T07:35:00Z"))
        #expect(snapshot.bankUpdatedAt == expected)
    }

    @Test func akchabarMossovetRow() throws {
        let rates = try AkchabarParser.parse(json: try fixture("akchabar.json"))

        let usd = try #require(rates.first { $0.currency == .usd })
        #expect(usd.buy == Decimal(string: "87.42"))
        #expect(usd.sell == Decimal(string: "87.81"))
        #expect(rates.first { $0.currency == .rub }?.buyText == "0.988")
    }
}
