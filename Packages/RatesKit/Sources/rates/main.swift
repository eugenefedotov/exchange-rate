import Foundation
import RatesKit

// Консольная утилита: `swift run rates`.
// Удобно проверять парсеры, и это задел под версию для Linux и macOS.

func printTable(_ title: String, _ rates: [ExchangeRate]) {
    print(title)
    print("         покупка   продажа")
    for rate in rates {
        let code = rate.currency.code.padding(toLength: 6, withPad: " ", startingAt: 0)
        print("\(rate.currency.flag) \(code)\(rate.buyText.leftPadded(to: 9)) \(rate.sellText.leftPadded(to: 9))")
    }
    print("")
}

func printError(_ title: String, _ error: Error) {
    FileHandle.standardError.write(Data("\(title): \(error.localizedDescription)\n\n".utf8))
}

async let exchange = RatesService(cache: nil).fetch()
async let bakai = BakaiService(cache: nil).fetch()

var failed = 0

do {
    let snapshot = try await exchange
    printTable("Обменки (\(snapshot.source.name)): \(snapshot.source.details)", snapshot.rates(in: Currency.displayOrder))
} catch {
    failed += 1
    printError("Обменки", error)
}

do {
    let snapshot = try await bakai
    let time = snapshot.updatedAt.ratesTimeText()
    for kind in BakaiRateKind.allCases {
        printTable("Бакай Банк, \(kind.title.lowercased()) (\(time))", snapshot.rates(kind))
    }
} catch {
    failed += 1
    printError("Бакай Банк", error)
}

exit(failed == 2 ? 1 : 0)

extension String {
    func leftPadded(to length: Int) -> String {
        count >= length ? self : String(repeating: " ", count: length - count) + self
    }
}
