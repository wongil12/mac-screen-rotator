import Foundation

public enum RotationAngle: Int, CaseIterable, Codable, Sendable {
    case standard = 0
    case clockwise90 = 90
    case upsideDown = 180
    case clockwise270 = 270

    public var title: String {
        switch self {
        case .standard: "표준 (0°)"
        case .clockwise90: "90°"
        case .upsideDown: "180°"
        case .clockwise270: "270°"
        }
    }

    public func requiresDimensionSwap(from other: RotationAngle) -> Bool {
        abs(rawValue - other.rawValue) % 180 == 90
    }
}
