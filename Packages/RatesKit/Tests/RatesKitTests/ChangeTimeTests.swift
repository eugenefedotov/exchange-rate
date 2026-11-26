import Foundation
import Testing
@testable import RatesKit

/// Время изменения курса обменок: сайты его не отдают, считаем сами по сравнению с прошлым ответом.
struct ChangeTimeTests {
    private let earlier = Date(timeIntervalSince1970: 1_000_000)
    private let later = Date(timeIntervalSince1970: 1_003_600)

    private func snapshot(usd: String, cny: String = "13.40", source: RateSourceID = .valutaKG, at date: Date) -> RatesSnapshot {
        RatesSnapshot(
            rates: [
                ExchangeRate(currency: .usd, buy: Decimal(string: usd)!, sell: 88),
                ExchangeRate(currency: .rub, buy: 1, sell: 1.02),
                ExchangeRate(currency: .cny, buy: Decimal(string: cny)!, sell: 14),
            ],
            source: source,
            fetchedAt: date
        )
    }

    @Test func firstFetchUsesFetchTime() {
        let result = snapshot(usd: "87.5", at: later).keepingChangeTime(from: nil)
        #expect(result.ratesChangedAt == later)
    }

    @Test func sameRatesKeepPreviousTime() {
        let previous = snapshot(usd: "87.5", at: earlier).keepingChangeTime(from: nil)
        let result = snapshot(usd: "87.5", at: later).keepingChangeTime(from: previous)
        #expect(result.ratesChangedAt == earlier)
        #expect(result.fetchedAt == later)
    }

    @Test func changedRatesUseFetchTime() {
        let previous = snapshot(usd: "87.5", at: earlier).keepingChangeTime(from: nil)
        let result = snapshot(usd: "87.6", at: later).keepingChangeTime(from: previous)
        #expect(result.ratesChangedAt == later)
    }

    @Test func hiddenCurrencyDoesNotCount() {
        let previous = snapshot(usd: "87.5", cny: "13.40", at: earlier).keepingChangeTime(from: nil)
        let result = snapshot(usd: "87.5", cny: "13.50", at: later).keepingChangeTime(from: previous)
        #expect(result.ratesChangedAt == earlier)
    }

    @Test func otherSourceCountsAsChange() {
        let previous = snapshot(usd: "87.5", at: earlier).keepingChangeTime(from: nil)
        let result = snapshot(usd: "87.5", source: .akchabar, at: later).keepingChangeTime(from: previous)
        #expect(result.ratesChangedAt == later)
    }

    @Test func oldCacheWithoutChangeTimeDecodes() throws {
        let json = #"{"rates":[],"source":"valutaKG","fetchedAt":0}"#
        let decoded = try JSONDecoder().decode(RatesSnapshot.self, from: Data(json.utf8))
        #expect(decoded.changedAt == nil)
        #expect(decoded.ratesChangedAt == decoded.fetchedAt)
    }
}
