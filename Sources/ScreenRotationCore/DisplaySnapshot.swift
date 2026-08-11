import CoreGraphics
import Foundation

public struct DisplaySnapshot: Codable, Equatable, Sendable {
    public let contextualID: UInt32
    public let builtIn: Bool
    public let main: Bool
    public let rotation: RotationAngle
    public let logicalWidth: Int
    public let logicalHeight: Int
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let refreshRate: Int
    public let scaled: Bool

    public init(
        contextualID: UInt32,
        builtIn: Bool,
        main: Bool,
        rotation: RotationAngle,
        logicalWidth: Int,
        logicalHeight: Int,
        pixelWidth: Int,
        pixelHeight: Int,
        refreshRate: Int,
        scaled: Bool
    ) {
        self.contextualID = contextualID
        self.builtIn = builtIn
        self.main = main
        self.rotation = rotation
        self.logicalWidth = logicalWidth
        self.logicalHeight = logicalHeight
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.refreshRate = refreshRate
        self.scaled = scaled
    }

    public var summary: String {
        "ID \(contextualID), \(rotation.rawValue)°, \(logicalWidth)x\(logicalHeight), \(refreshRate)Hz, scaling \(scaled ? "on" : "off")"
    }
}
