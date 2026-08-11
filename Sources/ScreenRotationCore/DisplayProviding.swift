import CoreGraphics
import Foundation

public protocol DisplayProviding: Sendable {
    func snapshots() throws -> [DisplaySnapshot]
    func builtInSnapshot() throws -> DisplaySnapshot
}

public struct CoreGraphicsDisplayProvider: DisplayProviding {
    public init() {}

    public func snapshots() throws -> [DisplaySnapshot] {
        var count: UInt32 = 0
        var result = CGGetActiveDisplayList(0, nil, &count)
        guard result == .success else {
            throw RotationError.coreGraphics(operation: "디스플레이 개수 조회", code: result.rawValue)
        }

        var identifiers = Array(repeating: CGDirectDisplayID(), count: Int(count))
        result = CGGetActiveDisplayList(count, &identifiers, &count)
        guard result == .success else {
            throw RotationError.coreGraphics(operation: "디스플레이 목록 조회", code: result.rawValue)
        }
        return identifiers.prefix(Int(count)).map(makeSnapshot)
    }

    public func builtInSnapshot() throws -> DisplaySnapshot {
        let matches = try snapshots().filter(\.builtIn)
        guard !matches.isEmpty else { throw RotationError.noBuiltInDisplay }
        guard matches.count == 1 else {
            throw RotationError.multipleBuiltInDisplays(matches.map(\.contextualID))
        }
        return matches[0]
    }

    private func makeSnapshot(id: CGDirectDisplayID) -> DisplaySnapshot {
        let bounds = CGDisplayBounds(id)
        let mode = CGDisplayCopyDisplayMode(id)
        let rawRotation = Int(CGDisplayRotation(id).rounded())
        let rotation = RotationAngle(rawValue: rawRotation) ?? .standard
        let pixelWidth = mode?.pixelWidth ?? CGDisplayPixelsWide(id)
        let pixelHeight = mode?.pixelHeight ?? CGDisplayPixelsHigh(id)
        return DisplaySnapshot(
            contextualID: id,
            builtIn: CGDisplayIsBuiltin(id) != 0,
            main: CGDisplayIsMain(id) != 0,
            rotation: rotation,
            logicalWidth: Int(bounds.width),
            logicalHeight: Int(bounds.height),
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            refreshRate: Int((mode?.refreshRate ?? 0).rounded()),
            scaled: pixelWidth > Int(bounds.width)
        )
    }
}
