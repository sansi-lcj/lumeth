import AppKit
import Combine
import SwiftUI

enum NotchPhase: Equatable {
    case compact
    case expanded
}

@MainActor
final class NotchState: ObservableObject {
    @Published private(set) var phase: NotchPhase = .compact
    var notchHeight: CGFloat = 32
    var notchWidth: CGFloat = 185
    var dashboardHeight: CGFloat = 692

    func tap() {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
            phase = phase == .expanded ? .compact : .expanded
        }
    }

    func expand() {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
            phase = .expanded
        }
    }

    func collapse() {
        withAnimation(.spring(response: 0.30, dampingFraction: 0.90)) {
            phase = .compact
        }
    }
}

@MainActor
final class NotchController {
    let state = NotchState()
    private let model: AppModel
    private let panel: NotchPanel
    private let hosting: NSHostingView<NotchRootView>
    private var cancellables: Set<AnyCancellable> = []
    private var eventMonitors: [Any] = []
    private var screenObserver: NSObjectProtocol?
    private var geometry: NotchGeometry

    init(model: AppModel, onSettings: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.model = model
        geometry = NotchGeometry.current()
        state.notchHeight = geometry.notchHeight
        state.notchWidth = geometry.notchWidth
        state.dashboardHeight = geometry.dashboardHeight

        panel = NotchPanel(
            contentRect: geometry.frame(for: .compact, state: state),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        hosting = NSHostingView(
            rootView: NotchRootView(
                model: model,
                state: state,
                onSettings: onSettings,
                onQuit: onQuit
            )
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.contentView = hosting
        panel.setFrame(geometry.frame(for: .compact, state: state), display: true)
        panel.orderFrontRegardless()

        state.$phase
            .removeDuplicates()
            .sink { [weak self] phase in
                guard let self else { return }
                self.applyFrame(for: phase)
                self.model.setDashboardVisible(phase == .expanded)
            }
            .store(in: &cancellables)

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshGeometry() }
        }

        installEventMonitors()
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        for monitor in eventMonitors {
            NSEvent.removeMonitor(monitor)
        }
    }

    func expand() {
        state.expand()
    }

    private func applyFrame(for phase: NotchPhase) {
        let frame = geometry.frame(for: phase, state: state)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = phase == .expanded ? 0.36 : 0.26
            context.timingFunction = CAMediaTimingFunction(
                controlPoints: 0.18, 0.92, 0.22, 1.0
            )
            panel.animator().setFrame(frame, display: true)
        }
    }

    private func refreshGeometry() {
        geometry = NotchGeometry.current()
        state.notchHeight = geometry.notchHeight
        state.notchWidth = geometry.notchWidth
        state.dashboardHeight = geometry.dashboardHeight
        applyFrame(for: state.phase)
    }

    private func installEventMonitors() {
        let global = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in self?.handleMouseDown(in: nil) }
        }
        let local = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown]
        ) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown, event.keyCode == 53 {
                Task { @MainActor in self.state.collapse() }
                return nil
            }
            if event.type == .leftMouseDown, event.window === self.panel {
                if self.state.phase == .compact {
                    Task { @MainActor in self.state.tap() }
                    return nil
                }
                return event
            }
            Task { @MainActor in self.handleMouseDown(in: nil) }
            return event
        }
        eventMonitors = [global, local].compactMap { $0 }
    }

    private func handleMouseDown(in window: NSWindow?) {
        let point = NSEvent.mouseLocation
        let inside = panel.frame.contains(point)
        if state.phase == .compact, inside {
            state.tap()
        } else if state.phase == .expanded, !inside {
            state.collapse()
        }
    }
}

private final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
private struct NotchGeometry {
    var notchHeight: CGFloat
    var notchWidth: CGFloat
    var screenFrame: NSRect
    var dashboardHeight: CGFloat

    static func current() -> NotchGeometry {
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main
        guard let screen else {
            return NotchGeometry(
                notchHeight: 32,
                notchWidth: 185,
                screenFrame: NSRect(x: 0, y: 0, width: 1440, height: 900),
                dashboardHeight: 692
            )
        }
        let height = max(30, screen.safeAreaInsets.top)
        let left = screen.auxiliaryTopLeftArea?.width ?? 0
        let right = screen.auxiliaryTopRightArea?.width ?? 0
        let measured = screen.frame.width - left - right
        let notchWidth = min(260, max(170, measured > 0 ? measured : 185))
        let available = screen.frame.height - height - 44 - 96
        let dashboardHeight = max(570, min(758, available))
        return NotchGeometry(
            notchHeight: height,
            notchWidth: notchWidth,
            screenFrame: screen.frame,
            dashboardHeight: dashboardHeight
        )
    }

    func frame(for phase: NotchPhase, state: NotchState) -> NSRect {
        let top = screenFrame.maxY
        let size: NSSize
        switch phase {
        case .compact:
            size = NSSize(width: 440, height: state.notchHeight)
        case .expanded:
            size = NSSize(width: 520, height: state.notchHeight + state.dashboardHeight)
        }
        return NSRect(
            x: screenFrame.midX - size.width / 2,
            y: top - size.height,
            width: size.width,
            height: size.height
        )
    }
}

private struct NotchRootView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var state: NotchState
    let onSettings: () -> Void
    let onQuit: () -> Void
    @State private var hovering = false

    private var cornerRadius: CGFloat { state.phase == .expanded ? 28 : 16 }
    private var expandedWidth: CGFloat { 520 }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                shape
                    .fill(PulseTheme.island)
                    .overlay(alignment: .bottom) {
                        LinearGradient(
                            colors: [
                                .clear,
                                Color.white.opacity(hovering ? 0.10 : 0.035)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 1)
                        .padding(.horizontal, cornerRadius)
                    }

                content
                    .clipShape(shape)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .animation(.spring(response: 0.34, dampingFraction: 0.86), value: state.phase)
        }
        .background(Color.clear)
    }

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: cornerRadius,
            bottomTrailingRadius: cornerRadius,
            topTrailingRadius: 0,
            style: .continuous
        )
    }

    @ViewBuilder
    private var content: some View {
        switch state.phase {
        case .compact:
            compact
                .transition(.opacity)
        case .expanded:
            expanded
                .transition(.opacity)
        }
    }

    private var compact: some View {
        HStack(spacing: 0) {
            HStack(spacing: 7) {
                if model.settings.showCPU {
                    NotchReading(
                        label: "CPU",
                        value: String(format: "%.0f%%", model.snapshot.cpu.total),
                        color: PulseTheme.azure
                    )
                }
                if model.settings.showMemory {
                    NotchReading(
                        label: "MEM",
                        value: String(format: "%.0f%%", model.snapshot.memory.usedFraction * 100),
                        color: PulseTheme.violet
                    )
                }
            }
            .padding(.leading, 14)
            .frame(width: earWidth, alignment: .leading)

            Color.clear
                .frame(width: state.notchWidth)

            HStack(spacing: 5) {
                if model.settings.showNetwork {
                    NotchReading(
                        icon: "arrow.down",
                        value: Format.rate(model.snapshot.network.downRate),
                        color: PulseTheme.cyan
                    )
                }
                if model.settings.showSensors {
                    let temperature = model.snapshot.primaryTemperature ?? 0
                    NotchReading(
                        icon: "thermometer.medium",
                        value: model.snapshot.primaryTemperature.map { String(format: "%.0f°", $0) } ?? "—",
                        color: model.snapshot.primaryTemperature == nil
                            ? PulseTheme.secondary
                            : PulseTheme.temperature(temperature)
                    )
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(PulseTheme.tertiary)
            }
            .padding(.trailing, 14)
            .frame(width: earWidth, alignment: .trailing)
        }
        .frame(height: state.notchHeight)
        .environment(\.layoutDirection, .leftToRight)
        .contentShape(Rectangle())
        .onTapGesture { state.tap() }
    }

    private var earWidth: CGFloat {
        max(0, (state.phase == .expanded ? expandedWidth : 440) - state.notchWidth) / 2
    }

    private var expanded: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PulseTheme.azure)
                    Text(L("流衡"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PulseTheme.text)
                }
                .padding(.leading, 16)
                .frame(width: earWidth, alignment: .leading)

                Color.clear
                    .frame(width: state.notchWidth)

                HStack(spacing: 8) {
                    LivePill(text: L("实时"))
                    Button {
                        state.collapse()
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(PulseTheme.secondary)
                            .frame(width: 32, height: 30)
                            .contentShape(Rectangle())
                            .background(Circle().fill(Color.white.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                    .help(L("收起面板"))
                }
                .padding(.trailing, 16)
                .frame(width: earWidth, alignment: .trailing)
            }
            .frame(height: state.notchHeight)

            DashboardView(
                model: model,
                width: expandedWidth,
                height: state.dashboardHeight,
                onSettings: onSettings,
                onQuit: onQuit
            )
            .frame(width: expandedWidth, height: state.dashboardHeight)
        }
        .frame(width: expandedWidth, alignment: .top)
    }
}

private struct NotchReading: View {
    var icon: String?
    var label: String?
    var value: String
    var color: Color

    init(icon: String, value: String, color: Color) {
        self.icon = icon
        self.label = nil
        self.value = value
        self.color = color
    }

    init(label: String, value: String, color: Color) {
        self.icon = nil
        self.label = label
        self.value = value
        self.color = color
    }

    var body: some View {
        HStack(spacing: 3) {
            if let label {
                Text(label)
                    .font(.system(size: 7.5, weight: .bold, design: .rounded))
                    .foregroundStyle(color.opacity(0.75))
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(color.opacity(0.88))
            }
            Text(verbatim: "\u{200E}" + value)
                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
                .monospacedDigit()
        }
    }
}
