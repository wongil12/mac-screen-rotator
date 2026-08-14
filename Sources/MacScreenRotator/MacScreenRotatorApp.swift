import AppKit
import Carbon.HIToolbox
import OSLog
import ScreenRotationCore
import ServiceManagement
import SwiftUI

@main
struct MacScreenRotatorApp: App {
    @StateObject private var model = RotationMenuModel()

    var body: some Scene {
        MenuBarExtra {
            if let snapshot = model.snapshot {
                Text("내장 화면 · \(snapshot.rotation.rawValue)°")
                    .foregroundStyle(.secondary)
                Divider()
            }

            ForEach(RotationAngle.allCases, id: \.rawValue) { angle in
                Button {
                    model.rotate(to: angle)
                } label: {
                    if model.snapshot?.rotation == angle {
                        Label(angle.title, systemImage: "checkmark")
                    } else {
                        Text(angle.title)
                    }
                }
                .disabled(model.isWorking)
            }

            Divider()
            Button("다음 방향으로 회전") {
                model.rotateToNextAngle()
            }
            .keyboardShortcut("r", modifiers: [.command, .option])
            .disabled(model.isWorking)

            Button("화면 상태 새로고침") {
                model.refresh()
            }
            .disabled(model.isWorking)

            Button("긴급 0° 복구") {
                model.emergencyReset()
            }
            .disabled(model.isWorking)

            Toggle("로그인 시 실행", isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))

            if let message = model.message {
                Divider()
                Text(message)
                    .foregroundStyle(model.hasError ? .red : .secondary)
            }

            Divider()
            Button("종료") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image(systemName: model.isWorking ? "display.and.arrow.down" : "rectangle.portrait.rotate")
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class RotationMenuModel: ObservableObject {
    @Published private(set) var snapshot: DisplaySnapshot?
    @Published private(set) var isWorking = false
    @Published private(set) var message: String?
    @Published private(set) var hasError = false
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var controller: RotationController?
    private var observers: [NSObjectProtocol] = []
    private var globalHotKey: GlobalHotKey?
    private let logger = Logger(subsystem: "dev.wongil.MacScreenRotator", category: "rotation")
    private let preferredAngleKey = "preferredRotationAngle"

    init() {
        do {
            controller = try RotationController()
            globalHotKey = GlobalHotKey()
            installSystemObservers()
            recoverAndRefresh()
        } catch {
            report(error)
        }
    }

    func refresh() {
        guard !isWorking, let controller else { return }
        isWorking = true
        Task {
            do {
                snapshot = try await controller.current()
                succeed("화면 상태를 갱신했습니다.")
            } catch {
                report(error)
            }
            isWorking = false
        }
    }

    func rotate(to angle: RotationAngle) {
        guard !isWorking, let controller else { return }
        guard snapshot?.rotation != angle else {
            succeed("이미 \(angle.rawValue)°입니다.")
            return
        }
        isWorking = true
        message = "\(angle.rawValue)° 적용 중…"
        hasError = false
        Task {
            do {
                snapshot = try await controller.rotate(to: angle, requiresConfirmation: true)
                let keep = await requestRotationConfirmation(angle)
                if keep {
                    try await controller.confirmRotation()
                    UserDefaults.standard.set(angle.rawValue, forKey: preferredAngleKey)
                    succeed("\(angle.rawValue)° 회전을 유지합니다.")
                } else {
                    snapshot = try await controller.revertPendingRotation()
                    succeed("확인되지 않아 이전 방향으로 복구했습니다.")
                }
            } catch {
                report(error)
            }
            isWorking = false
        }
    }

    func rotateToNextAngle() {
        guard !isWorking else { return }
        let current = snapshot?.rotation ?? .standard
        let all = RotationAngle.allCases
        let index = all.firstIndex(of: current) ?? 0
        rotate(to: all[(index + 1) % all.count])
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            succeed(enabled ? "로그인 시 실행을 켰습니다." : "로그인 시 실행을 껐습니다.")
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            report(error)
        }
    }

    func emergencyReset() {
        guard !isWorking, let controller else { return }
        isWorking = true
        Task {
            do {
                try? await controller.confirmRotation()
                snapshot = try await controller.rotate(to: .standard)
                UserDefaults.standard.set(RotationAngle.standard.rawValue, forKey: preferredAngleKey)
                succeed("화면을 0°로 복구했습니다.")
            } catch {
                report(error)
            }
            isWorking = false
        }
    }

    private func recoverAndRefresh() {
        guard !isWorking, let controller else { return }
        isWorking = true
        Task {
            do {
                if let recovered = try await controller.recoverIfNeeded() {
                    snapshot = recovered
                    succeed("중단된 회전 상태를 복구했습니다.")
                } else {
                    snapshot = try await controller.current()
                }
            } catch {
                report(error)
            }
            isWorking = false
        }
    }

    private func installSystemObservers() {
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.restorePreferredAfterWake() }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: .rotateToNextDisplayAngle,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.rotateToNextAngle() }
        })
    }

    private func restorePreferredAfterWake() {
        guard !isWorking, let controller else { return }
        isWorking = true
        Task {
            do {
                if let recovered = try await controller.recoverIfNeeded() {
                    snapshot = recovered
                } else {
                    snapshot = try await controller.current()
                }
                let raw = UserDefaults.standard.integer(forKey: preferredAngleKey)
                let preferred = RotationAngle(rawValue: raw) ?? .standard
                if snapshot?.rotation != preferred {
                    snapshot = try await controller.rotate(to: preferred)
                }
                succeed("잠자기 해제 후 화면 상태를 복원했습니다.")
            } catch {
                report(error)
            }
            isWorking = false
        }
    }

    private func requestRotationConfirmation(_ angle: RotationAngle) async -> Bool {
        await withCheckedContinuation { continuation in
            let alert = NSAlert()
            alert.messageText = "\(angle.rawValue)° 회전을 유지할까요?"
            alert.informativeText = "15초 안에 확인하지 않으면 이전 방향으로 자동 복구합니다."
            alert.addButton(withTitle: "유지")
            alert.addButton(withTitle: "되돌리기")

            let state = ConfirmationState()
            let timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { _ in
                Task { @MainActor in
                    guard !state.completed else { return }
                    state.completed = true
                    NSApplication.shared.abortModal()
                    continuation.resume(returning: false)
                }
            }
            let response = alert.runModal()
            timer.invalidate()
            guard !state.completed else { return }
            state.completed = true
            continuation.resume(returning: response == .alertFirstButtonReturn)
        }
    }

    private func succeed(_ text: String) {
        message = text
        hasError = false
        logger.info("\(text, privacy: .public)")
    }

    private func report(_ error: Error) {
        message = error.localizedDescription
        hasError = true
        logger.error("\(error.localizedDescription, privacy: .public)")
    }
}

@MainActor
private final class ConfirmationState {
    var completed = false
}

private extension Notification.Name {
    static let rotateToNextDisplayAngle = Notification.Name("MacScreenRotator.rotateToNextAngle")
}

private final class GlobalHotKey {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?

    init?() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ in
                guard let event else { return noErr }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr, hotKeyID.id == 1 else { return status }
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .rotateToNextDisplayAngle, object: nil)
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &handler
        )
        guard status == noErr else { return nil }

        let hotKeyID = EventHotKeyID(signature: 0x4D535252, id: 1) // "MSRR"
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_R),
            UInt32(cmdKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard registerStatus == noErr else {
            if let handler { RemoveEventHandler(handler) }
            return nil
        }
    }

    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
    }
}
