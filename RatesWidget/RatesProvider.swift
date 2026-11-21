import RatesKit
import WidgetKit

/// Всё, что нужно виджету для отрисовки, независимо от источника.
struct WidgetRatesModel {
    var rates: [ExchangeRate]
    /// Подпись в подвале, например "valuta.kg" или "bakai.kg · нал".
    var sourceLabel: String
    var updatedAt: Date
    /// true, если сеть не ответила и показываем последнее сохранённое.
    var isStale: Bool
}

struct RatesEntry: TimelineEntry {
    let date: Date
    let source: WidgetSource
    /// nil, если по этому источнику ещё ни разу не удалось загрузить курсы.
    let model: WidgetRatesModel?
}

/// Виджет сам ходит за курсами раз в час. Сокеты тут не нужны и невозможны:
/// расширение виджета не живёт постоянно, iOS будит его по расписанию из Timeline.
struct RatesProvider: AppIntentTimelineProvider {
    static let refreshInterval: TimeInterval = 60 * 60
    static let retryInterval: TimeInterval = 15 * 60
    /// Если кэш свежее, переключатель показывает его сразу, без похода в сеть.
    static let freshCacheAge: TimeInterval = 10 * 60

    func placeholder(in context: Context) -> RatesEntry {
        RatesEntry(date: .now, source: .exchange, model: Self.model(.sample, isStale: false))
    }

    func snapshot(for configuration: RatesWidgetIntent, in context: Context) async -> RatesEntry {
        let source = context.isPreview ? .exchange : WidgetSelection.current
        let kind = configuration.bakaiKind.kind
        let model: WidgetRatesModel = switch source {
        case .exchange:
            Self.model(context.isPreview ? .sample : (RatesService().cached() ?? .sample), isStale: false)
        case .bakai:
            Self.model(BakaiService().cached() ?? .sample, kind: kind, isStale: false)
        }
        return RatesEntry(date: .now, source: source, model: model)
    }

    func timeline(for configuration: RatesWidgetIntent, in context: Context) async -> Timeline<RatesEntry> {
        let entry = await Self.loadEntry(source: WidgetSelection.current, kind: configuration.bakaiKind.kind)
        let delay = (entry.model?.isStale ?? true) ? Self.retryInterval : Self.refreshInterval
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(delay)))
    }

    private static func loadEntry(source: WidgetSource, kind: BakaiRateKind) async -> RatesEntry {
        let exchangeService = RatesService()
        let bakaiService = BakaiService()
        let cachedExchange = exchangeService.cached()
        let cachedBakai = bakaiService.cached()

        // Быстрый путь для переключателя: свежий кэш выбранного источника показываем сразу.
        switch source {
        case .exchange:
            if let cachedExchange, isFresh(cachedExchange.fetchedAt) {
                return RatesEntry(date: .now, source: source, model: model(cachedExchange, isStale: false))
            }
        case .bakai:
            if let cachedBakai, isFresh(cachedBakai.fetchedAt) {
                return RatesEntry(date: .now, source: source, model: model(cachedBakai, kind: kind, isStale: false))
            }
        }

        // Иначе обновляем оба источника параллельно, чтобы второй был готов к переключению.
        async let exchangeResult = try? exchangeService.fetch()
        async let bakaiResult = try? bakaiService.fetch()
        let (exchange, bakai) = await (exchangeResult, bakaiResult)

        let model: WidgetRatesModel? = switch source {
        case .exchange:
            exchange.map { model($0, isStale: false) } ?? cachedExchange.map { model($0, isStale: true) }
        case .bakai:
            bakai.map { model($0, kind: kind, isStale: false) } ?? cachedBakai.map { model($0, kind: kind, isStale: true) }
        }
        return RatesEntry(date: .now, source: source, model: model)
    }

    private static func isFresh(_ date: Date) -> Bool {
        Date.now.timeIntervalSince(date) < freshCacheAge
    }

    static func model(_ snapshot: RatesSnapshot, isStale: Bool) -> WidgetRatesModel {
        WidgetRatesModel(
            rates: snapshot.rates(in: Currency.displayOrder),
            sourceLabel: snapshot.source.name,
            updatedAt: snapshot.fetchedAt,
            isStale: isStale
        )
    }

    static func model(_ snapshot: BakaiRatesSnapshot, kind: BakaiRateKind, isStale: Bool) -> WidgetRatesModel {
        WidgetRatesModel(
            rates: snapshot.rates(kind),
            sourceLabel: "\(RateSourceID.bakai.name) · \(kind == .cash ? "нал" : "безнал")",
            updatedAt: snapshot.updatedAt,
            isStale: isStale
        )
    }
}
