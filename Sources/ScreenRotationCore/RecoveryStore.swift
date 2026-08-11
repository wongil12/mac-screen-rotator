import Foundation

public protocol RecoveryStoring: Sendable {
    func save(_ snapshot: DisplaySnapshot) throws
    func load() throws -> DisplaySnapshot?
    func clear() throws
}

public struct FileRecoveryStore: RecoveryStoring {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func applicationSupport() -> FileRecoveryStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return FileRecoveryStore(
            fileURL: base
                .appendingPathComponent("MacScreenRotator", isDirectory: true)
                .appendingPathComponent("pending-recovery.json")
        )
    }

    public func save(_ snapshot: DisplaySnapshot) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }

    public func load() throws -> DisplaySnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try JSONDecoder().decode(DisplaySnapshot.self, from: Data(contentsOf: fileURL))
    }

    public func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}
