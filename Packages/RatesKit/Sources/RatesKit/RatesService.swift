import Foundation

/// Опрашивает источники по очереди и возвращает первый полный ответ.
/// Полный - значит есть хотя бы рубль и доллар, ради них всё и затевалось.
public struct RatesService: Sendable {
    public static let requiredCurrencies: [Currency] = [.rub, .usd]

    public var sources: [any RateSource]
    public var cache: RatesCache?

    public init(
        sources: [any RateSource] = [ValutaKGSource(), AkchabarSource()],
        cache: RatesCache? = .standard
    ) {
        self.sources = sources
        self.cache = cache
    }

    public func cached() -> RatesSnapshot? {
        cache?.load(RatesSnapshot.self)
    }

    /// Свежие курсы. При успехе ответ сразу кладётся в кэш.
    /// Время изменения цифр считается по сравнению с кэшем, поэтому его точность равна частоте опроса.
    public func fetch() async throws -> RatesSnapshot {
        var failures: [String] = []
        let previous = cached()
        for source in sources {
            do {
                let snapshot = try await source.fetch().keepingChangeTime(from: previous)
                let missing = Self.requiredCurrencies.filter { snapshot.rate(for: $0) == nil }
                guard missing.isEmpty else { throw RatesError.missingCurrencies(missing) }
                cache?.save(snapshot)
                return snapshot
            } catch {
                failures.append("\(source.id.name): \(error.localizedDescription)")
            }
        }
        throw RatesError.allSourcesFailed(failures)
    }
}
