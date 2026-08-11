import Foundation

public struct RotationCommand: Equatable, Sendable {
    public let executable: String
    public let argument: String

    public init(executable: String, argument: String) {
        self.executable = executable
        self.argument = argument
    }
}

public struct RotationCommandBuilder: Sendable {
    public init() {}

    public func command(
        executable: String,
        snapshot: DisplaySnapshot,
        target: RotationAngle
    ) -> RotationCommand {
        let swap = target.requiresDimensionSwap(from: snapshot.rotation)
        let width = swap ? snapshot.logicalHeight : snapshot.logicalWidth
        let height = swap ? snapshot.logicalWidth : snapshot.logicalHeight
        let argument = [
            "id:\(snapshot.contextualID)",
            "res:\(width)x\(height)",
            "hz:\(snapshot.refreshRate)",
            "scaling:\(snapshot.scaled ? "on" : "off")",
            "degree:\(target.rawValue)"
        ].joined(separator: " ")
        return RotationCommand(executable: executable, argument: argument)
    }
}
