import Foundation
import ScreenRotationCore
import Testing

@Suite("Recovery state persistence")
struct RecoveryStoreTests {
    @Test("Snapshot round-trips and clears")
    func roundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileRecoveryStore(fileURL: directory.appendingPathComponent("state.json"))
        let snapshot = DisplaySnapshot(
            contextualID: 7,
            builtIn: true,
            main: true,
            rotation: .clockwise270,
            logicalWidth: 982,
            logicalHeight: 1512,
            pixelWidth: 1964,
            pixelHeight: 3024,
            refreshRate: 120,
            scaled: true
        )

        try store.save(snapshot)
        #expect(try store.load() == snapshot)
        try store.clear()
        #expect(try store.load() == nil)
    }
}
