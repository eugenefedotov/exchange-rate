import RatesKit
import SwiftUI
import WidgetKit

/// Цвета только системные (primary, secondary, системные заливки), поэтому тёмная тема
/// и тонированные виджеты iOS 18+ работают без отдельного кода.
struct RatesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RatesEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                RectangularRatesView(entry: entry)
            case .accessoryInline:
                InlineRatesView(entry: entry)
            case .systemMedium:
                HomeRatesView(entry: entry, isCompact: false)
            default:
                HomeRatesView(entry: entry, isCompact: true)
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - Домашний экран

/// Маленький и средний виджет: переключатель источника в шапке, таблица курсов, подвал.
/// Маленький показывает рубль, доллар, евро и тенге без флагов и названий.
private struct HomeRatesView: View {
    let entry: RatesEntry
    let isCompact: Bool

    private var rates: [ExchangeRate] {
        let all = entry.model?.rates ?? []
        return isCompact ? all.filter { [.rub, .usd, .eur, .kzt].contains($0.currency) } : all
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 6 : 4) {
            if isCompact {
                SourceSwitcher(selected: entry.source)
            }

            Grid(alignment: .leading, horizontalSpacing: isCompact ? 6 : 10, verticalSpacing: isCompact ? 4 : 3) {
                if !isCompact {
                    GridRow {
                        SourceSwitcher(selected: entry.source)
                        Text("Покупка")
                            .gridColumnAlignment(.trailing)
                        Text("Продажа")
                            .gridColumnAlignment(.trailing)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                ForEach(rates) { rate in
                    GridRow {
                        currencyLabel(rate.currency)
                        Text(rate.buyText)
                            .gridColumnAlignment(.trailing)
                            .contentTransition(.numericText())
                        Text(rate.sellText)
                            .gridColumnAlignment(.trailing)
                            .contentTransition(.numericText())
                    }
                }
                .font(.system(.footnote, design: .rounded).monospacedDigit())
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            if entry.model == nil {
                Text("Нет данных. Откройте приложение")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
            if let model = entry.model {
                FooterView(model: model)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func currencyLabel(_ currency: Currency) -> some View {
        if isCompact {
            Text(currency.code)
                .font(.caption.weight(.semibold))
        } else {
            HStack(spacing: 6) {
                Text(currency.flag)
                Text(currency.code)
                    .fontWeight(.semibold)
                Text(currency.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Переключатель "Обменки | Бакай" в стиле системного сегмент-контрола.
/// Каждый сегмент это кнопка с AppIntent, приложение при нажатии не открывается.
private struct SourceSwitcher: View {
    let selected: WidgetSource

    /// Как у UISegmentedControl: белый бегунок в светлой теме и серый в тёмной.
    private static let thumbColor = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? .systemGray3 : .white
    })

    var body: some View {
        HStack(spacing: 0) {
            ForEach(WidgetSource.allCases, id: \.self) { source in
                let isSelected = source == selected
                Button(intent: SelectSourceIntent(source: source)) {
                    Text(source.title)
                        .font(.caption2.weight(isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Self.thumbColor)
                                    .shadow(color: .black.opacity(0.12), radius: 1.5, y: 1)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Capsule().fill(Color(uiColor: .tertiarySystemFill)))
        .widgetAccentable()
    }
}

private struct FooterView: View {
    let model: WidgetRatesModel

    var body: some View {
        HStack(spacing: 4) {
            if model.isStale {
                Image(systemName: "exclamationmark.arrow.trianglehead.counterclockwise")
            }
            Text("\(model.sourceLabel) · \(model.updatedAt, format: .dateTime.hour().minute())")
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .lineLimit(1)
    }
}

// MARK: - Экран блокировки

/// На экране блокировки кнопок нет, показываем источник, выбранный на домашнем экране.
private struct RectangularRatesView: View {
    let entry: RatesEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let model = entry.model {
                ForEach(model.rates.filter { [.rub, .usd].contains($0.currency) }) { rate in
                    HStack(spacing: 4) {
                        Text(rate.currency.code)
                            .fontWeight(.semibold)
                        Text("\(rate.buyText) / \(rate.sellText)")
                            .monospacedDigit()
                    }
                }
                Text("\(entry.source.title) · \(model.updatedAt, format: .dateTime.hour().minute())")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Нет данных")
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InlineRatesView: View {
    let entry: RatesEntry

    var body: some View {
        let rates = entry.model?.rates ?? []
        if let rub = rates.first(where: { $0.currency == .rub }), let usd = rates.first(where: { $0.currency == .usd }) {
            Text("RUB \(rub.sellText) · USD \(usd.sellText)")
        } else {
            Text("Курсы недоступны")
        }
    }
}

// MARK: - Превью

#Preview("Средний", as: .systemMedium) {
    RatesWidget()
} timeline: {
    RatesEntry(date: .now, source: .exchange, model: RatesProvider.model(.sample, isStale: false))
    RatesEntry(date: .now, source: .bakai, model: RatesProvider.model(.sample, kind: .cash, isStale: false))
}

#Preview("Маленький", as: .systemSmall) {
    RatesWidget()
} timeline: {
    RatesEntry(date: .now, source: .exchange, model: RatesProvider.model(.sample, isStale: false))
    RatesEntry(date: .now, source: .bakai, model: RatesProvider.model(.sample, kind: .nonCash, isStale: true))
}

#Preview("Экран блокировки", as: .accessoryRectangular) {
    RatesWidget()
} timeline: {
    RatesEntry(date: .now, source: .exchange, model: RatesProvider.model(.sample, isStale: false))
}
