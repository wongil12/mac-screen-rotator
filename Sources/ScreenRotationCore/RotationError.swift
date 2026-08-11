import CoreGraphics
import Foundation

public enum RotationError: LocalizedError, Equatable {
    case coreGraphics(operation: String, code: Int32)
    case noBuiltInDisplay
    case multipleBuiltInDisplays([UInt32])
    case unsupportedAngle(Int)
    case executableNotFound
    case commandFailed(status: Int32, output: String)
    case verificationTimedOut(expected: RotationAngle, actual: RotationAngle)
    case recoveryStateUnavailable

    public var errorDescription: String? {
        switch self {
        case let .coreGraphics(operation, code): "\(operation) 실패 (CGError: \(code))"
        case .noBuiltInDisplay: "활성 상태인 MacBook 내장 디스플레이를 찾지 못했습니다."
        case let .multipleBuiltInDisplays(ids): "내장 디스플레이가 여러 개 감지되었습니다: \(ids)"
        case let .unsupportedAngle(angle): "지원하지 않는 회전 각도입니다: \(angle)°"
        case .executableNotFound: "회전 엔진(displayplacer)을 찾지 못했습니다."
        case let .commandFailed(status, output): "회전 명령 실패(\(status)): \(output)"
        case let .verificationTimedOut(expected, actual):
            "회전 확인 시간 초과: 기대 \(expected.rawValue)°, 현재 \(actual.rawValue)°"
        case .recoveryStateUnavailable: "복구할 디스플레이 상태가 없습니다."
        }
    }
}
