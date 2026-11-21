import RatesKit
import UIKit

enum RatesSection: Hashable {
    /// Средний курс обменок.
    case exchange
    /// Банк отдельной категорией: Бакай, МБанк.
    case bank(Bank)
    /// Вьетнамский донг по курсу ЦБ РФ.
    case dong
    /// Ссылки на источники.
    case sources

    var title: String? {
        switch self {
        case .exchange: "Обменки"
        case .bank(let bank): bank.title
        case .dong: "Вьетнамский донг"
        case .sources: nil
        }
    }
}

/// Идентификаторы стабильные: строка курса привязана к валюте, а не к значениям.
/// Новые цифры прилетают через reconfigureItems без пересоздания ячеек.
enum RatesItem: Hashable {
    case exchange(Currency)
    case bankKind(Bank)
    case bankRate(Bank, Currency)
    case dong(DongBase)
    case source(RateSourceID)
}

/// За что считаем донги: за 1 рубль или за 1 сом.
enum DongBase: CaseIterable, Hashable {
    case ruble
    case som
}

typealias RatesDataSource = UITableViewDiffableDataSource<RatesSection, RatesItem>
typealias RatesDiffSnapshot = NSDiffableDataSourceSnapshot<RatesSection, RatesItem>
