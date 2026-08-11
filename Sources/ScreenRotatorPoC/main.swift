import CoreGraphics
import Foundation

enum PoCError: Error, CustomStringConvertible {
    case usage(String)
    case coreGraphics(String, CGError)
    case noBuiltInDisplay
    case multipleBuiltInDisplays([CGDirectDisplayID])
    case missingDisplayPlacer
    case commandFailed(String, Int32)
    case rotationTimeout(expected: Int, actual: Int)

    var description: String {
        switch self {
        case let .usage(message): message
        case let .coreGraphics(operation, error): "\(operation) 실패 (CGError: \(error.rawValue))"
        case .noBuiltInDisplay: "활성 상태인 MacBook 내장 디스플레이를 찾지 못했습니다."
        case let .multipleBuiltInDisplays(ids): "내장 디스플레이가 여러 개 감지되었습니다: \(ids)"
        case .missingDisplayPlacer:
            "displayplacer를 찾지 못했습니다. `brew install displayplacer`로 설치하세요."
        case let .commandFailed(command, status): "명령 실패(종료 코드 \(status)): \(command)"
        case let .rotationTimeout(expected, actual):
            "회전 확인 시간 초과: 기대 \(expected)°, 현재 \(actual)°"
        }
    }
}

struct DisplaySnapshot {
    let id: CGDirectDisplayID
    let uuid: String
    let builtIn: Bool
    let main: Bool
    let rotation: Int
    let logicalWidth: Int
    let logicalHeight: Int
    let pixelWidth: Int
    let pixelHeight: Int
    let refreshRate: Double
    let scaled: Bool

    var description: String {
        let rate = refreshRate > 0 ? String(format: "%.2f Hz", refreshRate) : "가변/N/A"
        return """
        display \(id) [\(uuid)]
          type: \(builtIn ? "MacBook built-in" : "external/virtual")\(main ? ", main" : "")
          rotation: \(rotation)°
          logical: \(logicalWidth)x\(logicalHeight)
          pixels: \(pixelWidth)x\(pixelHeight)
          refresh: \(rate)
          scaling: \(scaled ? "on" : "off")
        """
    }
}

func activeDisplays() throws -> [CGDirectDisplayID] {
    var count: UInt32 = 0
    var result = CGGetActiveDisplayList(0, nil, &count)
    guard result == .success else { throw PoCError.coreGraphics("디스플레이 개수 조회", result) }

    var displays = Array(repeating: CGDirectDisplayID(), count: Int(count))
    result = CGGetActiveDisplayList(count, &displays, &count)
    guard result == .success else { throw PoCError.coreGraphics("디스플레이 목록 조회", result) }
    return Array(displays.prefix(Int(count)))
}

func displayUUID(_ id: CGDirectDisplayID) -> String {
    // displayplacer's contextual screen ID is the CGDirectDisplayID itself.
    // It is deliberately used for the short-lived PoC so no private UUID API is needed.
    String(id)
}

func snapshot(_ id: CGDirectDisplayID) -> DisplaySnapshot {
    let bounds = CGDisplayBounds(id)
    let mode = CGDisplayCopyDisplayMode(id)
    return DisplaySnapshot(
        id: id,
        uuid: displayUUID(id),
        builtIn: CGDisplayIsBuiltin(id) != 0,
        main: CGDisplayIsMain(id) != 0,
        rotation: Int(CGDisplayRotation(id).rounded()),
        logicalWidth: Int(bounds.width),
        logicalHeight: Int(bounds.height),
        pixelWidth: mode.map { $0.pixelWidth } ?? CGDisplayPixelsWide(id),
        pixelHeight: mode.map { $0.pixelHeight } ?? CGDisplayPixelsHigh(id),
        refreshRate: mode?.refreshRate ?? 0,
        scaled: (mode?.pixelWidth ?? CGDisplayPixelsWide(id)) > Int(bounds.width)
    )
}

func builtInDisplay() throws -> CGDirectDisplayID {
    let matches = try activeDisplays().filter { CGDisplayIsBuiltin($0) != 0 }
    guard !matches.isEmpty else { throw PoCError.noBuiltInDisplay }
    guard matches.count == 1 else { throw PoCError.multipleBuiltInDisplays(matches) }
    return matches[0]
}

func executable(named name: String) -> String? {
    let candidates = (ProcessInfo.processInfo.environment["PATH"] ?? "")
        .split(separator: ":")
        .map { String($0) + "/" + name }
    return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
}

@discardableResult
func run(_ executable: String, _ arguments: [String], quiet: Bool = false) throws -> String {
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = output
    process.standardError = output
    try process.run()
    process.waitUntilExit()
    let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    if !quiet, !text.isEmpty { print(text, terminator: text.hasSuffix("\n") ? "" : "\n") }
    guard process.terminationStatus == 0 else {
        throw PoCError.commandFailed(([executable] + arguments).joined(separator: " "), process.terminationStatus)
    }
    return text
}

func applyRotation(
    displayPlacer: String,
    uuid: String,
    angle: Int,
    width: Int,
    height: Int,
    refreshRate: Int,
    scaled: Bool
) throws {
    try run(displayPlacer, [
        "id:\(uuid) res:\(width)x\(height) hz:\(refreshRate) scaling:\(scaled ? "on" : "off") degree:\(angle)"
    ])
}

func waitForRotation(_ id: CGDirectDisplayID, expected: Int, timeout: TimeInterval = 12) throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        let current = Int(CGDisplayRotation(id).rounded())
        if current == expected { return }
        Thread.sleep(forTimeInterval: 0.2)
    }
    throw PoCError.rotationTimeout(expected: expected, actual: Int(CGDisplayRotation(id).rounded()))
}

func launchFailsafe(selfPath: String, snapshot: DisplaySnapshot, delay: Int) throws -> Process {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: selfPath)
    process.arguments = [
        "revert", snapshot.uuid, String(snapshot.rotation), String(snapshot.logicalWidth),
        String(snapshot.logicalHeight), String(Int(snapshot.refreshRate.rounded())),
        snapshot.scaled ? "on" : "off", String(delay)
    ]
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError
    try process.run()
    return process
}

func inspect() throws {
    let displays = try activeDisplays().map(snapshot)
    print("활성 디스플레이: \(displays.count)개")
    for display in displays { print(display.description) }
    let internalDisplay = snapshot(try builtInDisplay())
    print("PoC 대상: \(internalDisplay.uuid), 현재 \(internalDisplay.rotation)°")
}

func rotateTest(angle: Int) throws {
    guard [0, 90, 180, 270].contains(angle) else {
        throw PoCError.usage("각도는 0, 90, 180, 270 중 하나여야 합니다.")
    }
    guard let displayPlacer = executable(named: "displayplacer") else { throw PoCError.missingDisplayPlacer }

    let id = try builtInDisplay()
    let before = snapshot(id)
    guard before.rotation != angle else {
        throw PoCError.usage("내장 디스플레이가 이미 \(angle)°입니다. 다른 각도로 시험하세요.")
    }

    let selfPath = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.path
    print("변경 전 상태:\n\(before.description)")
    print("안전 복구 프로세스 시작: 15초 후 \(before.rotation)°")
    let failsafe = try launchFailsafe(
        selfPath: selfPath,
        snapshot: before,
        delay: 15
    )

    do {
        print("\(angle)° 회전 적용 중...")
        let quarterTurn = abs(angle - before.rotation) % 180 == 90
        try applyRotation(
            displayPlacer: displayPlacer,
            uuid: before.uuid,
            angle: angle,
            width: quarterTurn ? before.logicalHeight : before.logicalWidth,
            height: quarterTurn ? before.logicalWidth : before.logicalHeight,
            refreshRate: Int(before.refreshRate.rounded()),
            scaled: before.scaled
        )
        try waitForRotation(id, expected: angle)
        print("회전 확인 완료. 3초간 유지한 뒤 원복합니다.")
        Thread.sleep(forTimeInterval: 3)
        try applyRotation(
            displayPlacer: displayPlacer,
            uuid: before.uuid,
            angle: before.rotation,
            width: before.logicalWidth,
            height: before.logicalHeight,
            refreshRate: Int(before.refreshRate.rounded()),
            scaled: before.scaled
        )
        try waitForRotation(id, expected: before.rotation)
        print("원복 확인 완료:\n\(snapshot(id).description)")
    } catch {
        print("시험 중 오류: \(error)\n즉시 원복을 시도합니다.")
        try? applyRotation(
            displayPlacer: displayPlacer,
            uuid: before.uuid,
            angle: before.rotation,
            width: before.logicalWidth,
            height: before.logicalHeight,
            refreshRate: Int(before.refreshRate.rounded()),
            scaled: before.scaled
        )
        throw error
    }

    failsafe.waitUntilExit()
}

func revert(
    uuid: String,
    angle: Int,
    width: Int,
    height: Int,
    refreshRate: Int,
    scaled: Bool,
    delay: Int
) throws {
    Thread.sleep(forTimeInterval: TimeInterval(delay))
    guard let displayPlacer = executable(named: "displayplacer") else { throw PoCError.missingDisplayPlacer }
    print("[failsafe] \(angle)° 원복 재확인")
    try applyRotation(
        displayPlacer: displayPlacer,
        uuid: uuid,
        angle: angle,
        width: width,
        height: height,
        refreshRate: refreshRate,
        scaled: scaled
    )
}

func printUsage() {
    print("""
    사용법:
      screen-rotator-poc inspect
      screen-rotator-poc rotate-test <0|90|180|270>

    rotate-test는 원래 각도를 저장하고 15초 뒤 실행되는 별도 복구 프로세스를
    먼저 시작합니다. 시험 회전은 3초간 유지한 뒤 즉시 원복합니다.
    """)
}

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    switch arguments.first {
    case "inspect" where arguments.count == 1:
        try inspect()
    case "rotate-test" where arguments.count == 2:
        let angleText = arguments[1]
        guard let angle = Int(angleText) else { throw PoCError.usage("올바르지 않은 각도: \(angleText)") }
        try rotateTest(angle: angle)
    case "revert" where arguments.count == 8:
        let uuid = arguments[1]
        let angleText = arguments[2]
        guard
            let angle = Int(angleText),
            let width = Int(arguments[3]),
            let height = Int(arguments[4]),
            let refreshRate = Int(arguments[5]),
            ["on", "off"].contains(arguments[6]),
            let delay = Int(arguments[7])
        else {
            throw PoCError.usage("복구 인자가 올바르지 않습니다.")
        }
        try revert(
            uuid: uuid,
            angle: angle,
            width: width,
            height: height,
            refreshRate: refreshRate,
            scaled: arguments[6] == "on",
            delay: delay
        )
    default:
        printUsage()
        exit(2)
    }
} catch {
    fputs("오류: \(error)\n", stderr)
    exit(1)
}
