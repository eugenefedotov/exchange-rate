import Foundation

/// Валюты, которые котируются к сому в обменках Бишкека.
public enum Currency: String, Codable, Sendable, CaseIterable, Hashable {
    case rub
    case usd
    case eur
    case kzt
    case cny
    case gbp

    /// Порядок вывода в приложении и виджете: сверху рубль, потом доллар, дальше популярные.
    /// Юань и фунт сайты тоже отдают, но мы их не показываем.
    public static let displayOrder: [Currency] = [.rub, .usd, .eur, .kzt]

    /// ISO-код, например "USD".
    public var code: String { rawValue.uppercased() }

    public var flag: String {
        switch self {
        case .rub: "🇷🇺"
        case .usd: "🇺🇸"
        case .eur: "🇪🇺"
        case .kzt: "🇰🇿"
        case .cny: "🇨🇳"
        case .gbp: "🇬🇧"
        }
    }

    public var title: String {
        switch self {
        case .rub: "Рубль"
        case .usd: "Доллар США"
        case .eur: "Евро"
        case .kzt: "Тенге"
        case .cny: "Юань"
        case .gbp: "Фунт"
        }
    }

    /// Сколько знаков после запятой показывать. Совпадает с тем, как курс пишут обменки.
    public var fractionDigits: Int {
        switch self {
        case .rub: 3
        case .kzt: 4
        case .usd, .eur, .cny, .gbp: 2
        }
    }
}
