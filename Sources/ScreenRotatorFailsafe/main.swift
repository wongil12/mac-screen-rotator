import Foundation
import ScreenRotationCore

func fail(_ message: String) -> Never {
    fputs("screen-rotator-failsafe: \(message)\n", stderr)
    exit(2)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count == 10 else {
    fail("invalid arguments")
}
guard
    let contextualID = UInt32(arguments[1]),
    let rawAngle = Int(arguments[2]),
    let angle = RotationAngle(rawValue: rawAngle),
    let logicalWidth = Int(arguments[3]),
    let logicalHeight = Int(arguments[4]),
    let pixelWidth = Int(arguments[5]),
    let pixelHeight = Int(arguments[6]),
    let refreshRate = Int(arguments[7]),
    ["on", "off"].contains(arguments[8]),
    let delay = Int(arguments[9]),
    delay >= 0
else {
    fail("invalid display state")
}

let snapshot = DisplaySnapshot(
    contextualID: contextualID,
    builtIn: true,
    main: true,
    rotation: angle,
    logicalWidth: logicalWidth,
    logicalHeight: logicalHeight,
    pixelWidth: pixelWidth,
    pixelHeight: pixelHeight,
    refreshRate: refreshRate,
    scaled: arguments[8] == "on"
)

Thread.sleep(forTimeInterval: TimeInterval(delay))
let command = RotationCommandBuilder().command(
    executable: arguments[0],
    snapshot: snapshot,
    target: angle
)

do {
    let result = try ProcessCommandRunner().run(command)
    guard result.status == 0 else { fail(result.output) }
} catch {
    fail(error.localizedDescription)
}
