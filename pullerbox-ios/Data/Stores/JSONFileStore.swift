import Foundation

final class JSONFileStore<Value: Codable> {
    private let fileName: String
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileName: String, fileManager: FileManager = .default) {
        self.fileName = fileName
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() async -> Value? {
        do {
            let url = try fileURL()
            guard fileManager.fileExists(atPath: url.path) else {
                return nil
            }
            let data = try Data(contentsOf: url)
            return try decoder.decode(Value.self, from: data)
        } catch {
            return nil
        }
    }

    func save(_ value: Value) async {
        do {
            let url = try fileURL()
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try encoder.encode(value)
            try data.write(to: url, options: [.atomic])
        } catch {
            assertionFailure("Failed to save \(fileName): \(error)")
        }
    }

    private func fileURL() throws -> URL {
        let directory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return directory.appendingPathComponent("PullerBox", isDirectory: true).appendingPathComponent(fileName)
    }
}
