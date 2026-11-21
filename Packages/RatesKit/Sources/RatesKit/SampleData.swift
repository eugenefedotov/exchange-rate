import Foundation

extension RatesSnapshot {
    /// Пример данных для плейсхолдера виджета и превью.
    public static let sample = RatesSnapshot(
        rates: [
            ExchangeRate(currency: .rub, buy: Decimal(string: "1.015")!, sell: Decimal(string: "1.025")!),
            ExchangeRate(currency: .usd, buy: Decimal(string: "87.55")!, sell: Decimal(string: "87.85")!),
            ExchangeRate(currency: .eur, buy: Decimal(string: "96.30")!, sell: Decimal(string: "97.30")!),
            ExchangeRate(currency: .kzt, buy: Decimal(string: "0.1940")!, sell: Decimal(string: "0.1980")!),
        ],
        source: .valutaKG,
        fetchedAt: .now
    )
}
