import Foundation

final class BufferService {
    static let shared = BufferService()

    private let bufferDir: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        bufferDir = docs.appendingPathComponent("buffer", isDirectory: true)
        try? FileManager.default.createDirectory(at: bufferDir, withIntermediateDirectories: true)
    }

    func save(_ data: Data) {
        let name = "\(Int(Date().timeIntervalSince1970 * 1000)).bin"
        let url = bufferDir.appendingPathComponent(name)
        try? data.write(to: url)
    }

    func loadAll() -> [(url: URL, data: Data)] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: bufferDir,
            includingPropertiesForKeys: nil
        ) else { return [] }

        return files
            .filter { $0.pathExtension == "bin" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return (url, data)
            }
    }

    func remove(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    var count: Int {
        (try? FileManager.default.contentsOfDirectory(
            at: bufferDir,
            includingPropertiesForKeys: nil
        ))?.filter { $0.pathExtension == "bin" }.count ?? 0
    }
}
