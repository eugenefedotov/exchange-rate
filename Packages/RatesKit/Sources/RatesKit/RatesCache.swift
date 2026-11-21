import Foundation

/// Последний удачный ответ на диске. Нужен, чтобы виджет и приложение показывали
/// хоть что-то без сети и не мигали пустым экраном.
public struct RatesCache: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Файлы в Caches текущего процесса. У приложения и виджета они свои, App Group не нужен.
    public static let standard = RatesCache(fileName: "rates-snapshot.json")
    public static let bakai = RatesCache(fileName: "bakai-snapshot.json")

    init(fileName: String) {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.init(fileURL: directory.appending(path: fileName))
    }

    public func load<T: Decodable>(_ type: T.Type = T.self) -> T? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    public func save<T: Encodable>(_ value: T) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }
}
