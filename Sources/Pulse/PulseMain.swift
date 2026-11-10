import AppKit
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var notchController: NotchController!
    private var settingsController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
        buildMainMenu()

        notchController = NotchController(
            model: model,
            onSettings: { [weak self] in self?.openSettings() },
            onQuit: { NSApp.terminate(nil) }
        )
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowNotification(_:)),
            name: NSNotification.Name("com.sansi.lumeth.show"),
            object: nil
        )
        model.start()
        pulseLog(
            "items cpu=\(model.settings.showCPU) mem=\(model.settings.showMemory) net=\(model.settings.showNetwork) sensors=\(model.settings.showSensors)"
        )

        if ProcessInfo.processInfo.environment["PULSE_EXPAND_NOTCH"] == "1" {
            let requested = ProcessInfo.processInfo.environment["PULSE_TAB"] ?? "overview"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.model.selectedTab = DashboardTab(rawValue: requested) ?? .overview
                self?.notchController.expand()
            }
        }

        if ProcessInfo.processInfo.environment["PULSE_OPEN_SETTINGS"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.openSettings()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    @objc private func handleShowNotification(_ notification: Notification) {
        let raw = notification.userInfo?["tab"] as? String ?? "cpu"
        model.selectedTab = DashboardTab(rawValue: raw) ?? .cpu
        notchController.expand()
    }

    private func openSettings() {
        notchController.state.collapse()
        if settingsController == nil {
            settingsController = SettingsWindowController(settings: model.settings)
        }
        settingsController?.present()
    }

    private func buildMainMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: L("退出流衡"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }
}

// Native AppKit entry point.
@main
struct PulseMain {
    @MainActor
    static func main() {
        if ProcessInfo.processInfo.environment["PULSE_DUMP"] == "1" {
            let sampler = SystemSampler()
            _ = sampler.sample()
            Thread.sleep(forTimeInterval: 1)
            let started = CFAbsoluteTimeGetCurrent()
            let snapshot = sampler.sample()
            print(String(format: "sample_ms=%.1f", (CFAbsoluteTimeGetCurrent() - started) * 1000))
            print("cpu=\(snapshot.cpu.total) user=\(snapshot.cpu.user) system=\(snapshot.cpu.system) cores=\(snapshot.cpu.cores.count)")
            print("memory=\(snapshot.memory.usedFraction * 100) total=\(snapshot.memory.total) used=\(snapshot.memory.used)")
            print("network=\(snapshot.network.interfaceName) down=\(snapshot.network.downRate) up=\(snapshot.network.upRate)")
            for interface in snapshot.network.interfaces {
                print("  interface=\(interface.name) addresses=\(interface.addresses)")
            }
            print("disk=\(snapshot.disk.readRate)/\(snapshot.disk.writeRate) cap=\(snapshot.disk.capacity)")
            print("gpu=\(snapshot.gpu.available) \(snapshot.gpu.utilization)%")
            print("battery=\(snapshot.battery.percent)% health=\(snapshot.battery.health) cycles=\(snapshot.battery.cycleCount) sensors=\(snapshot.sensors.count)")
            let temperatures = snapshot.sensors.filter(\.isTemperature).map(\.value)
            if !temperatures.isEmpty {
                print(
                    String(
                        format: "temperature_avg=%.1f temperature_max=%.1f",
                        temperatures.reduce(0, +) / Double(temperatures.count),
                        temperatures.max() ?? 0
                    )
                )
            }
            for sensor in snapshot.sensors.prefix(8) {
                print("  \(sensor.name): \(sensor.value)")
            }
            print("processes=\(snapshot.processes.map(\.name))")
            return
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
