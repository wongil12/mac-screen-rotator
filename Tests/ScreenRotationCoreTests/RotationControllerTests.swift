import Foundation
import ScreenRotationCore
import Testing

@Suite("Rotation controller")
struct RotationControllerTests {
    @Test("Confirmed rotation clears recovery state")
    func confirmedRotation() async throws {
        let fixture = try Fixture()
        let controller = try RotationController(
            displayProvider: fixture.provider,
            commandRunner: fixture.runner,
            recoveryStore: fixture.store,
            executable: "/bin/true",
            failsafeExecutable: "/usr/bin/true"
        )

        let rotated = try await controller.rotate(to: .clockwise90, requiresConfirmation: true)
        #expect(rotated.rotation == .clockwise90)
        #expect(try fixture.store.load()?.rotation == .standard)

        try await controller.confirmRotation()
        #expect(try fixture.store.load() == nil)
    }

    @Test("Unconfirmed rotation can be reverted")
    func revertedRotation() async throws {
        let fixture = try Fixture()
        let controller = try RotationController(
            displayProvider: fixture.provider,
            commandRunner: fixture.runner,
            recoveryStore: fixture.store,
            executable: "/bin/true",
            failsafeExecutable: "/usr/bin/true"
        )

        _ = try await controller.rotate(to: .clockwise270, requiresConfirmation: true)
        let restored = try await controller.revertPendingRotation()
        #expect(restored.rotation == .standard)
        #expect(restored.logicalWidth == 1512)
        #expect(restored.logicalHeight == 982)
        #expect(try fixture.store.load() == nil)
    }
}

private struct Fixture {
    let directory: URL
    let provider: MockDisplayProvider
    let runner: MockCommandRunner
    let store: FileRecoveryStore

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        provider = MockDisplayProvider(snapshot: .landscapeFixture)
        runner = MockCommandRunner(provider: provider)
        store = FileRecoveryStore(fileURL: directory.appendingPathComponent("state.json"))
    }
}

private final class MockDisplayProvider: DisplayProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var value: DisplaySnapshot

    init(snapshot: DisplaySnapshot) { value = snapshot }

    func snapshots() throws -> [DisplaySnapshot] { [try builtInSnapshot()] }

    func builtInSnapshot() throws -> DisplaySnapshot {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func apply(angle: RotationAngle, width: Int, height: Int) {
        lock.lock()
        defer { lock.unlock() }
        value = DisplaySnapshot(
            contextualID: value.contextualID,
            builtIn: true,
            main: true,
            rotation: angle,
            logicalWidth: width,
            logicalHeight: height,
            pixelWidth: width * 2,
            pixelHeight: height * 2,
            refreshRate: value.refreshRate,
            scaled: value.scaled
        )
    }
}

private struct MockCommandRunner: CommandRunning {
    let provider: MockDisplayProvider

    func run(_ command: RotationCommand) throws -> CommandResult {
        let fields = Dictionary(uniqueKeysWithValues: command.argument.split(separator: " ").compactMap { field in
            let parts = field.split(separator: ":", maxSplits: 1).map(String.init)
            return parts.count == 2 ? (parts[0], parts[1]) : nil
        })
        guard
            let degree = fields["degree"].flatMap(Int.init),
            let angle = RotationAngle(rawValue: degree),
            let resolution = fields["res"]?.split(separator: "x").compactMap({ Int($0) }),
            resolution.count == 2
        else { return CommandResult(status: 2, output: "invalid command") }
        provider.apply(angle: angle, width: resolution[0], height: resolution[1])
        return CommandResult(status: 0, output: "")
    }
}

private extension DisplaySnapshot {
    static let landscapeFixture = DisplaySnapshot(
        contextualID: 1,
        builtIn: true,
        main: true,
        rotation: .standard,
        logicalWidth: 1512,
        logicalHeight: 982,
        pixelWidth: 3024,
        pixelHeight: 1964,
        refreshRate: 120,
        scaled: true
    )
}
