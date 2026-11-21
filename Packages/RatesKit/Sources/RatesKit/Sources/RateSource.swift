import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Источник курсов. Каждый сайт описывается отдельной реализацией.
public protocol RateSource: Sendable {
    var id: RateSourceID { get }
    func fetch() async throws -> RatesSnapshot
}

/// Тонкая обёртка над URLSession с таймаутами, подходящими для виджета.
struct HTTPClient: Sendable {
    var session: URLSession = .shared
    var timeout: TimeInterval = 15

    func get(_ url: URL, accept: String) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue("ru-RU,ru;q=0.9", forHTTPHeaderField: "Accept-Language")
        // Десктопный UA специально: на мобильный valuta.kg отдаёт другую вёрстку, а парсер написан под десктопную.
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RatesError.badStatus(http.statusCode)
        }
        return data
    }
}
