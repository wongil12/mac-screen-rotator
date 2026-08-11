import Foundation

public struct CommandResult: Equatable, Sendable {
    public let status: Int32
    public let output: String

    public init(status: Int32, output: String) {
        self.status = status
        self.output = output
    }
}

public protocol CommandRunning: Sendable {
    func run(_ command: RotationCommand) throws -> CommandResult
}

public struct ProcessCommandRunner: CommandRunning {
    public init() {}

    public func run(_ command: RotationCommand) throws -> CommandResult {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = [command.argument]
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return CommandResult(
            status: process.terminationStatus,
            output: String(decoding: data, as: UTF8.self)
        )
    }
}
