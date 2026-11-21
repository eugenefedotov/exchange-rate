import RatesKit
import UIKit

enum RatesSection: Hashable {
    /// Средний курс обменок.
    case exchange
    /// Бакай Банк отдельной категорией.
    case bakai
    /// Ссылки на источники.
    case sources

    var title: String? {
        switch self {
        case .exchange: "Обменки"
        case .bakai: "Бакай Банк"
        case .sources: nil
        }
    }
}

/// Идентификаторы стабильные: строка курса привязана к валюте, а не к значениям.
/// Новые цифры прилетают через reconfigureItems без пересоздания ячеек.
enum RatesItem: Hashable {
    case exchange(Currency)
    case bakaiKind
    case bakai(Currency)
    case source(RateSourceID)
}

typealias RatesDataSource = UITableViewDiffableDataSource<RatesSection, RatesItem>
typealias RatesDiffSnapshot = NSDiffableDataSourceSnapshot<RatesSection, RatesItem>
