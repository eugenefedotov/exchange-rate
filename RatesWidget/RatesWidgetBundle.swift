import SwiftUI
import WidgetKit

@main
struct RatesWidgetBundle: WidgetBundle {
    var body: some Widget {
        RatesWidget()
    }
}

/// Один виджет на оба источника: в шапке переключатель "Обменки | Бакай".
/// Наличный или безналичный курс Бакая выбирается в настройках виджета.
struct RatesWidget: Widget {
    /// Тот же kind, что был у первого виджета, чтобы уже добавленные виджеты не пропали.
    static let kind = "RatesWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: RatesWidgetIntent.self, provider: RatesProvider()) { entry in
            RatesWidgetView(entry: entry)
        }
        .configurationDisplayName("Курсы Валют")
        .description("Курс рубля, доллара и других валют к сому: обменки Бишкека или Бакай Банк, переключается прямо на виджете.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}
