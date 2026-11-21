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

// Все источники параллельно.
async let exchange = capture { try await RatesService(cache: nil).fetch() }
async let bakai = capture { try await BankService(bank: .bakai, cache: nil).fetch() }
async let mbank = capture { try await BankService(bank: .mbank, cache: nil).fetch() }

var failed = 0

switch await exchange {
case .success(let snapshot):
    printTable("Обменки (\(snapshot.source.name)): \(snapshot.source.details)", snapshot.rates(in: Currency.displayOrder))
case .failure(let error):
    failed += 1
    printError("Обменки", error)
}

for result in await [bakai, mbank] {
    switch result {
    case .success(let snapshot):
        let time = snapshot.updatedAt.ratesTimeText()
        for kind in BankRateKind.allCases {
            printTable("\(snapshot.bank.title), \(kind.title.lowercased()) (\(time))", snapshot.rates(kind))
        }
    case .failure(let error):
        failed += 1
        printError("Банк", error)
    }
}

exit(failed == 3 ? 1 : 0)

func capture<T: Sendable>(_ body: @Sendable () async throws -> T) async -> Result<T, Error> {
    do {
        return .success(try await body())
    } catch {
        return .failure(error)
    }
}

extension String {
    func leftPadded(to length: Int) -> String {
        count >= length ? self : String(repeating: " ", count: length - count) + self
    }
}
