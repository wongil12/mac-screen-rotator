import Foundation

public actor RotationController {
    private let displayProvider: any DisplayProviding
    private let commandRunner: any CommandRunning
    private let recoveryStore: any RecoveryStoring
    private let commandBuilder: RotationCommandBuilder
    private let executable: String
    private let failsafeExecutable: String?
    private var failsafeProcess: Process?

    public init(
        displayProvider: any DisplayProviding = CoreGraphicsDisplayProvider(),
        commandRunner: any CommandRunning = ProcessCommandRunner(),
        recoveryStore: any RecoveryStoring = FileRecoveryStore.applicationSupport(),
        executable: String? = nil,
        failsafeExecutable: String? = nil
    ) throws {
        let resolved = executable ?? Self.findDisplayPlacer()
        guard let resolved else { throw RotationError.executableNotFound }
        self.displayProvider = displayProvider
        self.commandRunner = commandRunner
        self.recoveryStore = recoveryStore
        self.commandBuilder = RotationCommandBuilder()
        self.executable = resolved
        self.failsafeExecutable = failsafeExecutable ?? Self.findFailsafe()
    }

    public func current() throws -> DisplaySnapshot {
        try displayProvider.builtInSnapshot()
    }

    @discardableResult
    public func rotate(
        to target: RotationAngle,
        requiresConfirmation: Bool = false
    ) throws -> DisplaySnapshot {
        let original = try displayProvider.builtInSnapshot()
        if original.rotation == target { return original }
        try recoveryStore.save(original)
        do {
            if requiresConfirmation { try launchFailsafe(for: original, delay: 15) }
            try execute(snapshot: original, target: target)
            let updated = try waitForRotation(target)
            if !requiresConfirmation {
                cancelFailsafe()
                try recoveryStore.clear()
            }
            return updated
        } catch {
            cancelFailsafe()
            try? execute(snapshot: original, target: original.rotation)
            throw error
        }
    }

    public func confirmRotation() throws {
        cancelFailsafe()
        try recoveryStore.clear()
    }

    @discardableResult
    public func revertPendingRotation() throws -> DisplaySnapshot {
        guard let original = try recoveryStore.load() else {
            throw RotationError.recoveryStateUnavailable
        }
        cancelFailsafe()
        try execute(snapshot: original, target: original.rotation)
        let restored = try waitForRotation(original.rotation)
        try recoveryStore.clear()
        return restored
    }

    public func recoverIfNeeded() throws -> DisplaySnapshot? {
        guard let original = try recoveryStore.load() else { return nil }
        try execute(snapshot: original, target: original.rotation)
        let restored = try waitForRotation(original.rotation)
        try recoveryStore.clear()
        return restored
    }

    private func launchFailsafe(for snapshot: DisplaySnapshot, delay: Int) throws {
        guard let failsafeExecutable else { return }
        cancelFailsafe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: failsafeExecutable)
        process.arguments = [
            executable,
            String(snapshot.contextualID),
            String(snapshot.rotation.rawValue),
            String(snapshot.logicalWidth),
            String(snapshot.logicalHeight),
            String(snapshot.pixelWidth),
            String(snapshot.pixelHeight),
            String(snapshot.refreshRate),
            snapshot.scaled ? "on" : "off",
            String(delay)
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        failsafeProcess = process
    }

    private func cancelFailsafe() {
        guard let process = failsafeProcess else { return }
        if process.isRunning { process.terminate() }
        failsafeProcess = nil
    }

    private func execute(snapshot: DisplaySnapshot, target: RotationAngle) throws {
        let command = commandBuilder.command(executable: executable, snapshot: snapshot, target: target)
        let result = try commandRunner.run(command)
        guard result.status == 0 else {
            throw RotationError.commandFailed(status: result.status, output: result.output)
        }
    }

    private func waitForRotation(_ expected: RotationAngle) throws -> DisplaySnapshot {
        let deadline = Date().addingTimeInterval(12)
        var latest = try displayProvider.builtInSnapshot()
        while Date() < deadline {
            latest = try displayProvider.builtInSnapshot()
            if latest.rotation == expected { return latest }
            Thread.sleep(forTimeInterval: 0.2)
        }
        throw RotationError.verificationTimedOut(expected: expected, actual: latest.rotation)
    }

    public static func findDisplayPlacer(environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        let bundledPath = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/displayplacer")
            .path
        let commonPaths = [bundledPath, "/opt/homebrew/bin/displayplacer", "/usr/local/bin/displayplacer"]
        let pathCandidates = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map { String($0) + "/displayplacer" }
        return (commonPaths + pathCandidates).first {
            FileManager.default.isExecutableFile(atPath: $0)
        }
    }

    public static func findFailsafe() -> String? {
        let bundled = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/screen-rotator-failsafe")
            .path
        let sibling = URL(fileURLWithPath: CommandLine.arguments[0])
            .standardizedFileURL
            .deletingLastPathComponent()
            .appendingPathComponent("screen-rotator-failsafe")
            .path
        return [bundled, sibling].first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
