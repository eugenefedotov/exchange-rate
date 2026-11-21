import AppIntents
import RatesKit
import WidgetKit

/// Что сейчас показывает виджет.
enum WidgetSource: String, AppEnum, CaseIterable {
    case exchange
    case bakai

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Источник"
    static let caseDisplayRepresentations: [WidgetSource: DisplayRepresentation] = [
        .exchange: "Обменки",
        .bakai: "Бакай",
    ]

    var title: String {
        switch self {
        case .exchange: "Обменки"
        case .bakai: "Бакай"
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
        return .result()
    }
}

enum BakaiKindOption: String, AppEnum {
    case cash
    case nonCash

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Курс Бакая"
    static let caseDisplayRepresentations: [BakaiKindOption: DisplayRepresentation] = [
        .cash: "Наличные",
        .nonCash: "Безнал",
    ]

    var kind: BakaiRateKind {
        switch self {
        case .cash: .cash
        case .nonCash: .nonCash
        }
    }
}

/// Настройки виджета (долгое нажатие > "Изменить виджет").
struct RatesWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Курсы Валют"
    static let description = IntentDescription("Какой курс Бакай Банка показывать.")

    @Parameter(title: "Курс Бакая", default: .cash)
    var bakaiKind: BakaiKindOption

    init() {}
}
