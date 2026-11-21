import AppIntents
import RatesKit
import WidgetKit

/// Что сейчас показывает виджет: сегменты переключателя в шапке.
enum WidgetSource: String, CaseIterable {
    case exchange
    case bakai
    case mbank

    var title: String {
        bank?.shortTitle ?? "Обменки"
    }

    var bank: Bank? {
        switch self {
        case .exchange: nil
        case .bakai: .bakai
        case .mbank: .mbank
        }
    }
}

/// Выбор источника живёт в UserDefaults расширения: кнопка на виджете и провайдер
/// работают в одном процессе, App Group для этого не нужен.
enum WidgetSelection {
    private static let key = "widgetSource"

    static var current: WidgetSource {
        get { UserDefaults.standard.string(forKey: key).flatMap(WidgetSource.init) ?? .exchange }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}

/// Нажатие на сегмент переключателя в шапке виджета. После perform() WidgetKit сам перерисует виджет.
/// Источник передаётся строкой: AppEnum-параметр в кнопке виджета приезжал пустым.
struct SelectSourceIntent: AppIntent {
    static let title: LocalizedStringResource = "Переключить источник курсов"
    static let isDiscoverable = false

    @Parameter(title: "Источник")
    var sourceID: String

    init() {}

    init(source: WidgetSource) {
        self.sourceID = source.rawValue
    }

    func perform() async throws -> some IntentResult {
        if let source = WidgetSource(rawValue: sourceID) {
            WidgetSelection.current = source
        }
        // Сам WidgetKit перерисует только нажатый виджет. Выбор общий для всех,
        // поэтому обновляем остальные (второй размер, экран блокировки) тоже.
        WidgetCenter.shared.reloadTimelines(ofKind: RatesWidget.kind)
        return .result()
    }
}

enum BankKindOption: String, AppEnum {
    case cash
    case nonCash

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Курс банков"
    static let caseDisplayRepresentations: [BankKindOption: DisplayRepresentation] = [
        .cash: "Наличные",
        .nonCash: "Безнал",
    ]

    var kind: BankRateKind {
        switch self {
        case .cash: .cash
        case .nonCash: .nonCash
        }
    }
}

/// Настройки виджета (долгое нажатие > "Изменить виджет").
struct RatesWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Курсы Валют"
    static let description = IntentDescription("Какой курс банков показывать: наличный или безналичный.")

    @Parameter(title: "Курс банков", default: .cash)
    var bankKind: BankKindOption

    init() {}
}
