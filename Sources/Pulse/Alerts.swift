import Foundation
import UserNotifications

enum AlertKind: String, CaseIterable {
    case cpu
    case memory
    case temperature
    case battery
}

@MainActor
final class AlertEngine {
    private var activeSince: [AlertKind: Date] = [:]
    private var notified: Set<AlertKind> = []
    private var lastNotification: [AlertKind: Date] = [:]

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound]
        ) { granted, error in
            if let error {
                pulseLog("notification permission failed: \(error.localizedDescription)")
            } else {
                pulseLog("notification permission granted=\(granted)")
            }
        }
    }

    func evaluate(
        snapshot: SystemSnapshot,
        settings: AppSettings,
        now: Date = Date()
    ) {
        evaluate(
            kind: .cpu,
            active: settings.alertCPU
                && snapshot.cpu.total >= Double(settings.cpuAlertThreshold),
            duration: settings.alertDuration,
            title: L("处理器负载持续偏高"),
            body: L(
                "处理器已高于 %@，持续 %@。",
                Format.percent(Double(settings.cpuAlertThreshold)),
                L("%d 秒", Int(settings.alertDuration))
            ),
            now: now
        )

        evaluate(
            kind: .memory,
            active: settings.alertMemory
                && (snapshot.memory.pressure == .warning || snapshot.memory.pressure == .critical),
            duration: settings.alertDuration,
            title: L("内存压力持续偏高"),
            body: L(
                "当前内存压力为 %@，已持续 %@。",
                snapshot.memory.pressure.title,
                L("%d 秒", Int(settings.alertDuration))
            ),
            now: now
        )

        let temperature = snapshot.sensors
            .filter(\.isTemperature)
            .map(\.value)
            .max() ?? 0
        evaluate(
            kind: .temperature,
            active: settings.alertTemperature
                && temperature >= Double(settings.temperatureAlertThreshold),
            duration: settings.alertDuration,
            title: L("温度持续偏高"),
            body: L(
                "最高传感器温度为 %@，已持续 %@。",
                String(format: "%.1f°C", temperature),
                L("%d 秒", Int(settings.alertDuration))
            ),
            now: now
        )

        evaluate(
            kind: .battery,
            active: settings.alertBattery
                && snapshot.battery.present
                && !snapshot.battery.charging
                && !snapshot.battery.onAC
                && snapshot.battery.percent <= Double(settings.batteryAlertThreshold),
            duration: settings.alertDuration,
            title: L("电池电量偏低"),
            body: L(
                "当前电量为 %@，请连接电源。",
                Format.percent(snapshot.battery.percent)
            ),
            now: now
        )
    }

    private func evaluate(
        kind: AlertKind,
        active: Bool,
        duration: TimeInterval,
        title: String,
        body: String,
        now: Date
    ) {
        guard active else {
            activeSince[kind] = nil
            notified.remove(kind)
            return
        }
        if activeSince[kind] == nil {
            activeSince[kind] = now
        }
        guard !notified.contains(kind),
              let started = activeSince[kind],
              now.timeIntervalSince(started) >= max(1, duration)
        else { return }
        if let last = lastNotification[kind], now.timeIntervalSince(last) < 300 {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "lumeth.\(kind.rawValue).\(Int(now.timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                pulseLog("notification failed: \(error.localizedDescription)")
            }
        }
        notified.insert(kind)
        lastNotification[kind] = now
    }
}

final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
