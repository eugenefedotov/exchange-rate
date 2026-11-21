import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Вьетнамский донг: сколько донгов дают за 1 рубль и за 1 сом.
/// Обменки и банки Бишкека донг не котируют, поэтому берём официальный курс ЦБ РФ.
/// Донг к сому считается через рубль: ЦБ РФ публикует курс сома в тот же день.
public struct DongRates: Codable, Sendable, Hashable {
    public var perRuble: Decimal
    public var perSom: Decimal
    /// Дата, на которую ЦБ РФ установил курс.
    public var rateDate: Date?
    public var fetchedAt: Date

    public init(perRuble: Decimal, perSom: Decimal, rateDate: Date?, fetchedAt: Date = .now) {
        self.perRuble = perRuble
        self.perSom = perSom
        self.rateDate = rateDate
        self.fetchedAt = fetchedAt
    }

    /// "312": донгов много, копейки тут не нужны.
    public var perRubleText: String { RateFormatter.string(perRuble, digits: 0) }
    public var perSomText: String { RateFormatter.string(perSom, digits: 0) }

    public static let source: RateSourceID = .cbr

    public static let sample = DongRates(
        perRuble: Decimal(312),
        perSom: Decimal(293),
        rateDate: .now
    )
}

public struct DongService: Sendable {
    static let endpoint = URL(string: "https://www.cbr.ru/scripts/XML_daily.asp")!

    var http = HTTPClient()
    public var cache: RatesCache?

    public init(cache: RatesCache? = .dong) {
        self.cache = cache
    }

    public func cached() -> DongRates? {
        cache?.load(DongRates.self)
    }

    public func fetch() async throws -> DongRates {
        let data = try await http.get(Self.endpoint, accept: "application/xml")
        let rates = try CBRParser.parse(xml: data)
        cache?.save(rates)
        return rates
    }
}

/// Ежедневные курсы ЦБ РФ (XML в windows-1251). Нужны только донг и сом.
public enum CBRParser {
    public static func parse(xml data: Data, fetchedAt: Date = .now) throws -> DongRates {
        guard let xml = String(data: data, encoding: .windowsCP1251) ?? String(data: data, encoding: .utf8) else {
            throw RatesError.parsing("cbr.ru: неизвестная кодировка")
        }
        guard let dongRub = rublesPerUnit(of: "VND", in: xml) else {
            throw RatesError.parsing("cbr.ru: нет курса донга")
        }
        guard let somRub = rublesPerUnit(of: "KGS", in: xml) else {
            throw RatesError.parsing("cbr.ru: нет курса сома")
        }
        return DongRates(
            perRuble: 1 / dongRub,
            perSom: somRub / dongRub,
            rateDate: rateDate(in: xml),
            fetchedAt: fetchedAt
        )
    }

    /// Сколько рублей стоит 1 единица валюты: Value / Nominal ("32,0321" за 10000 донгов).
    static func rublesPerUnit(of code: String, in xml: String) -> Decimal? {
        for block in xml.matches(of: #/<Valute[^>]*>(.*?)</Valute>/#.dotMatchesNewlines()) {
            let body = block.output.1
            guard body.contains("<CharCode>\(code)</CharCode>"),
                  let nominal = body.firstMatch(of: #/<Nominal>\s*(\d+)\s*</Nominal>/#).flatMap({ Decimal(string: String($0.output.1)) }),
                  let valueText = body.firstMatch(of: #/<Value>\s*([\d.,]+)\s*</Value>/#).map({ String($0.output.1) }),
                  let value = RateFormatter.decimal(from: valueText),
                  nominal > 0 else {
                continue
            }
            return value / nominal
        }
        return nil
    }

    /// <ValCurs Date="21.11.2026" ...>, дата по Москве.
    static func rateDate(in xml: String) -> Date? {
        guard let match = xml.firstMatch(of: #/<ValCurs[^>]*Date="(\d{2}\.\d{2}\.\d{4})"/#) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Moscow")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.date(from: String(match.output.1))
    }
}
