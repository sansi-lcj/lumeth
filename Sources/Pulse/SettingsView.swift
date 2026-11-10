import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        ZStack {
            SettingsBackground()
            VStack(alignment: .leading, spacing: 18) {
                header
                notchPanel
                items
                refresh
                footer
            }
            .padding(.horizontal, 22)
            .padding(.top, 34)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 460, height: 700)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [PulseTheme.azure, PulseTheme.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.78))
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(L("流衡设置"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.text)
                Text(L("刘海面板、折叠内容与采样频率"))
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.tertiary)
            }
            Spacer()
            Text("1.1")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(PulseTheme.tertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.05)))
        }
    }

    private var notchPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("刘海面板")
            HStack(spacing: 14) {
                ZStack {
                    UnevenRoundedRectangle(
                        bottomLeadingRadius: 10,
                        bottomTrailingRadius: 10,
                        style: .continuous
                    )
                    .fill(Color.black)
                    HStack(spacing: 6) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(PulseTheme.azure)
                        Text("30%")
                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            .foregroundStyle(PulseTheme.azure)
                        Text("61°")
                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            .foregroundStyle(PulseTheme.azure)
                        Circle().fill(PulseTheme.azure).frame(width: 3, height: 3)
                    }
                }
                .frame(width: 150, height: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Dynamic Island")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(PulseTheme.text)
                        Text(L("待机贴合刘海；点击展开完整面板。点击外部或按 Esc 收回。"))
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(PulseTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(PulseTheme.stroke, lineWidth: 1)
                    )
            )
        }
    }

    private var items: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("折叠时显示")
            VStack(spacing: 0) {
                ToggleRow(
                    title: "处理器",
                    detail: "占用曲线与百分比",
                    icon: "cpu",
                    color: PulseTheme.azure,
                    isOn: $settings.showCPU,
                    canDisable: !isLastEnabled(.cpu)
                )
                ToggleRow(
                    title: "内存",
                    detail: "内存压力与使用量",
                    icon: "memorychip",
                    color: PulseTheme.violet,
                    isOn: $settings.showMemory,
                    canDisable: !isLastEnabled(.memory)
                )
                ToggleRow(
                    title: "网络",
                    detail: "实时下载与上传速率",
                    icon: "network",
                    color: PulseTheme.cyan,
                    isOn: $settings.showNetwork,
                    canDisable: !isLastEnabled(.network)
                )
                ToggleRow(
                    title: "传感器",
                    detail: "无需权限的最高温度",
                    icon: "thermometer.medium",
                    color: PulseTheme.cyan,
                    isOn: $settings.showSensors,
                    canDisable: !isLastEnabled(.sensors)
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.035))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
    }

    private var refresh: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("刷新间隔")
            HStack(spacing: 8) {
                ForEach([1.0, 2.0, 5.0], id: \.self) { interval in
                    Button {
                        settings.interval = interval
                    } label: {
                        Text(L("%d 秒", Int(interval)))
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(settings.interval == interval ? Color.white : PulseTheme.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .contentShape(Rectangle())
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(
                                        settings.interval == interval
                                            ? AnyShapeStyle(
                                                LinearGradient(
                                                    colors: [PulseTheme.cyan.opacity(0.28), PulseTheme.azure.opacity(0.18)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            : AnyShapeStyle(Color.white.opacity(0.035))
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .stroke(
                                        settings.interval == interval
                                            ? PulseTheme.cyan.opacity(0.45)
                                            : Color.white.opacity(0.06),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 9, weight: .semibold))
                Text(L("流衡（Lumeth）只在本机读取系统计数器、IOKit 统计与无需权限的 HID 温度事件。无分析上报，也不发起网络请求。"))
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(PulseTheme.tertiary)

            HStack {
                Spacer()
                Button("完成") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(PulseTheme.azure)
                .controlSize(.large)
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(LocalizedStringKey(title))
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(PulseTheme.tertiary)
            .textCase(.uppercase)
            .tracking(0.9)
    }

    private enum Item {
        case cpu, memory, network, sensors
    }

    private func isLastEnabled(_ item: Item) -> Bool {
        let enabled = [settings.showCPU, settings.showMemory, settings.showNetwork, settings.showSensors]
        guard enabled.filter({ $0 }).count == 1 else { return false }
        switch item {
        case .cpu: return settings.showCPU
        case .memory: return settings.showMemory
        case .network: return settings.showNetwork
        case .sensors: return settings.showSensors
        }
    }
}

private struct SettingsBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.051, green: 0.067, blue: 0.090)
            LinearGradient(
                colors: [Color(red: 0.086, green: 0.106, blue: 0.133), Color(red: 0.051, green: 0.067, blue: 0.090)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [PulseTheme.azure.opacity(0.10), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 280
            )
            RadialGradient(
                colors: [PulseTheme.azure.opacity(0.04), .clear],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 260
            )
        }
        .ignoresSafeArea()
    }
}

private struct ToggleRow: View {
    let title: String
    let detail: String
    let icon: String
    let color: Color
    @Binding var isOn: Bool
    let canDisable: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(LocalizedStringKey(title))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.text)
                Text(LocalizedStringKey(detail))
                    .font(.system(size: 9, weight: .regular, design: .rounded))
                    .foregroundStyle(PulseTheme.tertiary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(color)
                .disabled(!canDisable)
                .opacity(canDisable ? 1 : 0.45)
                .padding(6)
                .contentShape(Rectangle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.045))
                .frame(height: 1)
                .padding(.leading, 42)
        }
    }
}

@MainActor
final class SettingsWindowController: NSWindowController {
    init(settings: AppSettings) {
        let hosting = NSHostingController(rootView: SettingsView(settings: settings))
        let window = NSWindow(contentViewController: hosting)
        window.title = L("流衡设置")
        window.styleMask = [.titled, .closable]
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
