import RatesKit
import WidgetKit

/// Всё, что нужно виджету для отрисовки, независимо от источника.
struct WidgetRatesModel {
    var rates: [ExchangeRate]
    /// Подпись в подвале, например "valuta.kg" или "bakai.kg · нал".
    var sourceLabel: String
    /// То же для маленького виджета, где банк уже назван в шапке: "valuta.kg" или "нал".
    var compactSourceLabel: String
    var updatedAt: Date
    /// true, если сеть не ответила и показываем последнее сохранённое.
    var isStale: Bool
}

struct RatesEntry: TimelineEntry {
    let date: Date
    let source: WidgetSource
    /// nil, если по этому источнику ещё ни разу не удалось загрузить курсы.
    let model: WidgetRatesModel?
    /// Донг по курсу ЦБ РФ. Не зависит от выбранного источника, показывается в среднем виджете.
    var dong: DongRates? = nil
}

/// Виджет сам ходит за курсами: днём раз в 20 минут, ночью раз в час. Сокеты тут не нужны и невозможны:
/// расширение виджета не живёт постоянно, iOS будит его по расписанию из Timeline.
struct RatesProvider: AppIntentTimelineProvider {
    /// Днём (8:00-20:00 по Бишкеку) обменки и банки работают, обновляем чаще.
    /// Вместе с ночными получается около 48 обновлений в сутки: iOS даёт виджету примерно 40-70,
    /// лишние запросы она просто пропускает.
    static let dayRefreshInterval: TimeInterval = 20 * 60
    static let nightRefreshInterval: TimeInterval = 60 * 60
    static let dayHours = 8..<20
    static let retryInterval: TimeInterval = 15 * 60
    /// Если кэш свежее, переключатель показывает его сразу, без похода в сеть.
    static let freshCacheAge: TimeInterval = 10 * 60

    func placeholder(in context: Context) -> RatesEntry {
        RatesEntry(date: .now, source: .exchange, model: Self.model(.sample, isStale: false), dong: .sample)
    }

    func snapshot(for configuration: RatesWidgetIntent, in context: Context) async -> RatesEntry {
        let source = context.isPreview ? .exchange : WidgetSelection.current
        let kind = configuration.bankKind.kind
        let model: WidgetRatesModel
        if let bank = source.bank {
            model = Self.model(BankService(bank: bank).cached() ?? .sample(bank), kind: kind, isStale: false)
        } else {
            model = Self.model(context.isPreview ? .sample : (RatesService().cached() ?? .sample), isStale: false)
        }
        let dong = context.isPreview ? .sample : (DongService().cached() ?? .sample)
        return RatesEntry(date: .now, source: source, model: model, dong: dong)
    }

    func timeline(for configuration: RatesWidgetIntent, in context: Context) async -> Timeline<RatesEntry> {
        let entry = await Self.loadEntry(source: WidgetSelection.current, kind: configuration.bankKind.kind)
        let next = (entry.model?.isStale ?? true) ? .now.addingTimeInterval(Self.retryInterval) : Self.nextRefresh()
        return Timeline(entries: [entry], policy: .after(next))
    }

    /// Днём через 20 минут, ночью через час, но не позже начала дня.
    static func nextRefresh(after now: Date = .now) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Bishkek") ?? .current
        if dayHours.contains(calendar.component(.hour, from: now)) {
            return now.addingTimeInterval(dayRefreshInterval)
        }
        let inHour = now.addingTimeInterval(nightRefreshInterval)
        let dayStart = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: dayHours.lowerBound, minute: 0),
            matchingPolicy: .nextTime
        )
        return min(inHour, dayStart ?? inHour)
    }

    private static func loadEntry(source: WidgetSource, kind: BankRateKind) async -> RatesEntry {
        let exchangeService = RatesService()
        let bankServices = Bank.allCases.map(BankService.init(bank:))
        let dongService = DongService()

        // Быстрый путь для переключателя: свежий кэш выбранного источника показываем сразу.
        if let model = cachedModel(source: source, kind: kind, exchangeService: exchangeService, maxAge: freshCacheAge) {
            return RatesEntry(date: .now, source: source, model: model, dong: await loadDong(dongService))
        }

        // Иначе обновляем все источники параллельно, чтобы остальные были готовы к переключению.
        async let exchange = try? exchangeService.fetch()
        async let dong = try? dongService.fetch()
        let banks = await withTaskGroup(of: BankRatesSnapshot?.self) { group in
            for service in bankServices {
                group.addTask { try? await service.fetch() }
            }
            var result: [Bank: BankRatesSnapshot] = [:]
            for await snapshot in group {
                if let snapshot { result[snapshot.bank] = snapshot }
            }
            return result
        }
        let freshExchange = await exchange

        let fresh: WidgetRatesModel? = if let bank = source.bank {
            banks[bank].map { model($0, kind: kind, isStale: false) }
        } else {
            freshExchange.map { model($0, isStale: false) }
        }
        let model = fresh ?? cachedModel(source: source, kind: kind, exchangeService: exchangeService, maxAge: nil)
        let dongRates = await dong ?? dongService.cached()
        return RatesEntry(date: .now, source: source, model: model, dong: dongRates)
    }

    /// ЦБ меняет курс раз в день, поэтому донг из кэша моложе 3 часов не перезапрашиваем.
    private static func loadDong(_ service: DongService) async -> DongRates? {
        let cached = service.cached()
        if let cached, Date.now.timeIntervalSince(cached.fetchedAt) < 3 * 60 * 60 {
            return cached
        }
        return (try? await service.fetch()) ?? cached
    }

    /// Модель из кэша. С maxAge возвращает только достаточно свежий кэш, без него любой и помечает устаревшим.
    private static func cachedModel(
        source: WidgetSource,
        kind: BankRateKind,
        exchangeService: RatesService,
        maxAge: TimeInterval?
    ) -> WidgetRatesModel? {
        let isStale = maxAge == nil
        func fits(_ date: Date) -> Bool {
            maxAge.map { Date.now.timeIntervalSince(date) < $0 } ?? true
        }
        if let bank = source.bank {
            guard let cached = BankService(bank: bank).cached(), fits(cached.fetchedAt) else { return nil }
            return model(cached, kind: kind, isStale: isStale)
        }
        guard let cached = exchangeService.cached(), fits(cached.fetchedAt) else { return nil }
        return model(cached, isStale: isStale)
    }

    static func model(_ snapshot: RatesSnapshot, isStale: Bool) -> WidgetRatesModel {
        WidgetRatesModel(
            rates: snapshot.rates(in: Currency.displayOrder),
            sourceLabel: snapshot.source.name,
            compactSourceLabel: snapshot.source.name,
            updatedAt: snapshot.ratesChangedAt,
            isStale: isStale
        )
    }

    static func model(_ snapshot: BankRatesSnapshot, kind: BankRateKind, isStale: Bool) -> WidgetRatesModel {
        WidgetRatesModel(
            rates: snapshot.rates(kind),
            sourceLabel: "\(snapshot.bank.source.name) · \(kind.shortTitle)",
            compactSourceLabel: kind.shortTitle,
            updatedAt: snapshot.updatedAt,
            isStale: isStale
        )
    }
}
