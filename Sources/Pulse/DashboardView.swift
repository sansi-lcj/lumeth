import SwiftUI

struct DashboardView: View {
    @ObservedObject var model: AppModel
    var width: CGFloat
    var height: CGFloat
    let onSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            NavigationRail(
                selection: $model.selectedTab,
                onSettings: onSettings,
                onQuit: onQuit
            )

            VStack(spacing: 0) {
                PageHeader(model: model)
                ScrollView(showsIndicators: false) {
                    page
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)
                }
                ConsoleFooter(model: model)
            }
        }
        .frame(width: width, height: height)
        .background(AuroraBackground())
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var page: some View {
        switch model.selectedTab {
        case .overview: OverviewPage(model: model)
        case .cpu: CPUPage(model: model)
        case .memory: MemoryPage(model: model)
        case .network: NetworkPage(model: model)
        case .sensors: SensorsPage(model: model)
        case .system: SystemPage(model: model)
        }
    }
}

// MARK: - Shell

private struct AuroraBackground: View {
    var body: some View {
        ZStack {
            VisualEffectBackground()
            Color.black.opacity(0.46)
            LinearGradient(
                colors: [
                    Color(red: 0.051, green: 0.067, blue: 0.090),
                    Color(red: 0.035, green: 0.043, blue: 0.055),
                    Color(red: 0.020, green: 0.024, blue: 0.031)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [PulseTheme.azure.opacity(0.07), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 330
            )
            RadialGradient(
                colors: [PulseTheme.violet.opacity(0.05), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 300
            )
        }
        .ignoresSafeArea()
    }
}

private struct NavigationRail: View {
    @Binding var selection: DashboardTab
    let onSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 5) {
            ForEach(DashboardTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(height: 16)
                        Text(LocalizedStringKey(tab.railTitle))
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(selection == tab ? Color.white : PulseTheme.tertiary)
                    .frame(width: 56, height: 48)
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selection == tab ? tab.accentColor.opacity(0.16) : .clear)
                    )
                    .overlay(alignment: .leading) {
                        if selection == tab {
                            Capsule()
                                .fill(tab.accentColor)
                                .frame(width: 2, height: 18)
                                .offset(x: 1)
                                .shadow(color: tab.accentColor.opacity(0.8), radius: 4)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 8)

            VStack(spacing: 4) {
                Circle()
                    .fill(PulseTheme.azure)
                    .frame(width: 4, height: 4)
                Text("v1.1")
                    .font(.system(size: 6.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PulseTheme.tertiary)
            }
            .padding(.bottom, 10)

            RailIcon(icon: "slider.horizontal.3", help: L("面板与刷新"), action: onSettings)
            RailIcon(icon: "power", help: L("退出流衡"), action: onQuit)
        }
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(width: 64)
        .background(Color(red: 0.012, green: 0.016, blue: 0.024))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(PulseTheme.stroke)
                .frame(width: 1)
        }
    }
}

private struct RailIcon: View {
    var icon: String
    var help: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PulseTheme.secondary)
                .frame(width: 48, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct PageHeader: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(model.selectedTab.title))
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.text)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 8)
            IntervalPicker(settings: model.settings)
        }
        .padding(.horizontal, 18)
        .padding(.top, 15)
        .padding(.bottom, 11)
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, model.selectedTab.accentColor.opacity(0.45), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)
        }
    }

    private var subtitle: String {
        let base = L(model.selectedTab.subtitle)
        guard !model.snapshot.modelName.isEmpty else { return base }
        return "\(base) · \(model.snapshot.modelName)"
    }
}

private struct IntervalPicker: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        HStack(spacing: 2) {
            ForEach([1.0, 2.0, 5.0], id: \.self) { interval in
                Button {
                    settings.interval = interval
                } label: {
                    Text("\(Int(interval))s")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(
                            settings.interval == interval ? PulseTheme.text : PulseTheme.tertiary
                        )
                        .frame(width: 38, height: 28)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(
                                    settings.interval == interval
                                        ? PulseTheme.azure.opacity(0.18)
                                        : Color.clear
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(PulseTheme.stroke, lineWidth: 1)
        )
    }
}

struct LivePill: View {
    var text: String

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 10)) { timeline in
            let pulse = 0.55 + 0.45 * sin(timeline.date.timeIntervalSinceReferenceDate * 2.2)
            HStack(spacing: 5) {
                Circle()
                    .fill(PulseTheme.azure)
                    .frame(width: 5, height: 5)
                    .shadow(color: PulseTheme.azure.opacity(pulse), radius: 3)
                Text(text)
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.azure)
                    .tracking(0.5)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(PulseTheme.azure.opacity(0.08)))
        }
    }
}

private struct ConsoleFooter: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(PulseTheme.azure)
                .frame(width: 4, height: 4)
            Text(L("采样 %.0f ms", model.sampleTime * 1000))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(PulseTheme.tertiary)
            Spacer()
            Text(L("本机读取"))
                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.tertiary)
        }
        .padding(.horizontal, 18)
        .frame(height: 36)
        .background(Color.black.opacity(0.18))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [PulseTheme.azure.opacity(0.45), PulseTheme.cyan.opacity(0.45)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .opacity(0.35)
                )
                .frame(height: 1)
        }
    }
}

// MARK: - Overview

private struct OverviewPage: View {
    @ObservedObject var model: AppModel
    private var snapshot: SystemSnapshot { model.snapshot }

    var body: some View {
        VStack(spacing: 12) {
            PulseCPUCard(model: model, onOpen: { model.selectedTab = .cpu })

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                SignalCard(
                    title: "内存",
                    icon: "memorychip",
                    value: Format.percent(snapshot.memory.usedFraction * 100),
                    details: [
                        ("应用", Format.bytes(snapshot.memory.app)),
                        ("联动", Format.bytes(snapshot.memory.wired)),
                        ("压缩", Format.bytes(snapshot.memory.compressed))
                    ],
                    history: model.memoryHistory,
                    maxHistory: 100,
                    onOpen: { model.selectedTab = .memory }
                )
                SignalCard(
                    title: "网络",
                    icon: "network",
                    value: Format.rate(snapshot.network.downRate),
                    details: [
                        ("上传", Format.rate(snapshot.network.upRate)),
                        ("接收", Format.bytes(snapshot.network.totalDown)),
                        ("发送", Format.bytes(snapshot.network.totalUp))
                    ],
                    history: model.downloadHistory,
                    maxHistory: max(1, model.downloadHistory.max() ?? 1),
                    onOpen: { model.selectedTab = .network }
                )
                SignalCard(
                    title: "温度",
                    icon: "thermometer.medium",
                    value: snapshot.primaryTemperature.map { String(format: "%.0f°", $0) } ?? "—",
                    details: [
                        ("最高", snapshot.primaryTemperature.map { String(format: "%.0f°", $0) } ?? "—"),
                        ("传感器", "\(snapshot.sensors.count)")
                    ],
                    history: model.temperatureHistory,
                    maxHistory: 100,
                    accent: PulseTheme.temperature(snapshot.primaryTemperature ?? 0),
                    onOpen: { model.selectedTab = .sensors }
                )
                SignalCard(
                    title: "图形处理器",
                    icon: "square.stack.3d.up",
                    value: snapshot.gpu.available ? Format.percent(snapshot.gpu.utilization) : "—",
                    details: [
                        ("占用", Format.bytes(snapshot.gpu.memoryInUse)),
                        ("已分配", Format.bytes(snapshot.gpu.memoryAllocated))
                    ],
                    history: model.gpuHistory,
                    maxHistory: 100,
                    onOpen: { model.selectedTab = .system }
                )
            }

            SystemStrip(snapshot: snapshot)

            ConsoleCard(title: "进程排行", trailing: "处理器") {
                ProcessRows(items: snapshot.processes, limit: 3)
            }
        }
    }
}

private struct PulseCPUCard: View {
    @ObservedObject var model: AppModel
    var onOpen: () -> Void = {}
    private var cpu: CPUStats { model.snapshot.cpu }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardHeading(title: "处理器", icon: "cpu", accent: PulseTheme.azure)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: "\(Int(cpu.total.rounded()))%")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(PulseTheme.azure)
                Text("总占用")
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.secondary)
                Spacer(minLength: 8)
                MiniStat(label: "用户", value: String(format: "%.0f%%", cpu.user))
                MiniStat(label: "系统", value: String(format: "%.0f%%", cpu.system))
                MiniStat(
                    label: "温度",
                    value: model.snapshot.primaryTemperature.map { String(format: "%.0f°", $0) } ?? "—"
                )
            }

            DotMatrix(
                values: model.cpuHistory,
                maxValue: 100,
                color: PulseTheme.azure,
                columns: 62,
                rows: 6
            )
            .frame(height: 46)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(PulseTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PulseTheme.stroke, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onOpen() }
    }
}

private struct SignalCard: View {
    var title: String
    var icon: String
    var value: String
    var details: [(String, String)]
    var history: [Double]
    var maxHistory: Double
    var accent: Color
    var onOpen: () -> Void

    init(
        title: String,
        icon: String,
        value: String,
        details: [(String, String)],
        history: [Double],
        maxHistory: Double,
        accent: Color = PulseTheme.azure,
        onOpen: @escaping () -> Void = {}
    ) {
        self.title = title
        self.icon = icon
        self.value = value
        self.details = details
        self.history = history
        self.maxHistory = maxHistory
        self.accent = accent
        self.onOpen = onOpen
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            CardHeading(title: title, icon: icon, accent: accent)

            Text(value)
                .font(.system(size: 27, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(PulseTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            HStack(alignment: .top, spacing: 10) {
                ForEach(Array(details.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey(item.0))
                            .font(.system(size: 7.5, weight: .medium, design: .rounded))
                            .foregroundStyle(PulseTheme.tertiary)
                        Text(item.1)
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(PulseTheme.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
            }

            DotMatrix(
                values: history,
                maxValue: maxHistory,
                color: accent,
                columns: 34,
                rows: 5
            )
            .frame(height: 26)
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PulseTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PulseTheme.stroke, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onOpen() }
    }
}

private struct CardHeading: View {
    var title: String
    var icon: String
    var accent: Color

    var body: some View {
        HStack(spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(accent.opacity(0.13))
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .frame(width: 22, height: 22)
            Text(LocalizedStringKey(title))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 7.5, weight: .semibold))
                .foregroundStyle(PulseTheme.tertiary)
        }
    }
}

private struct MiniStat: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStringKey(label))
                .font(.system(size: 7.5, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.tertiary)
            Text(value)
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(PulseTheme.text)
                .lineLimit(1)
        }
    }
}

private struct SystemStrip: View {
    var snapshot: SystemSnapshot

    var body: some View {
        HStack(spacing: 12) {
            item(icon: "clock", text: L("运行 %@", Format.duration(snapshot.uptime)))
            divider
            item(icon: "battery.100", text: snapshot.battery.present ? Format.percent(snapshot.battery.percent) : "—")
            divider
            item(icon: "internaldrive", text: L("%@ 可用", Format.bytes(snapshot.disk.free)))
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(PulseTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(PulseTheme.stroke, lineWidth: 1)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(PulseTheme.stroke)
            .frame(width: 1, height: 12)
    }

    private func item(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(PulseTheme.azure)
            Text(text)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(PulseTheme.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PulseHero: View {
    @ObservedObject var model: AppModel
    private var cpu: CPUStats { model.snapshot.cpu }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.086, green: 0.106, blue: 0.133),
                            Color(red: 0.051, green: 0.067, blue: 0.090)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            PulseWave(values: model.cpuHistory, accent: PulseTheme.azure)
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .opacity(0.72)

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.55)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 190)
            .frame(maxWidth: .infinity, alignment: .trailing)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 9, weight: .bold))
                        Text("实时态势")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(0.9)
                    }
                    .foregroundStyle(PulseTheme.azure)
                    Spacer()
                }

                Spacer(minLength: 4)

                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text(verbatim: "\(Int(cpu.total.rounded()))%")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.22), value: cpu.total)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .environment(\.layoutDirection, .leftToRight)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [PulseTheme.azure, PulseTheme.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("处理器总占用")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(PulseTheme.secondary)
                        .frame(width: 120, alignment: .leading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(L("用户 %.1f%%", cpu.user) + "\u{200E}")
                            .environment(\.layoutDirection, .leftToRight)
                        Text(L("系统 %.1f%%", cpu.system) + "\u{200E}")
                            .environment(\.layoutDirection, .leftToRight)
                    }
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(PulseTheme.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: 96, alignment: .trailing)
                }

                HStack(spacing: 12) {
                    Text(L("负载 %.2f · %.2f · %.2f", cpu.load1, cpu.load5, cpu.load15))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Text(L("%d 性能 + %d 能效", cpu.performanceCores, cpu.efficiencyCores))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(PulseTheme.tertiary)
                .padding(.top, 7)
            }
            .padding(16)
        }
        .frame(height: 172)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct PulseWave: View {
    var values: [Double]
    var accent: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 18)) { timeline in
            Canvas { context, size in
                var samples = Array(values.suffix(90))
                if samples.count < 2 {
                    samples = stride(from: 0, through: 20, by: 1).map { index in
                        26 + 10 * sin(Double(index) * 0.8)
                    }
                }
                let top = max(60, samples.max() ?? 60)
                let step = size.width / CGFloat(max(1, samples.count - 1))
                var line = Path()
                for (index, value) in samples.enumerated() {
                    let x = CGFloat(index) * step
                    let y = size.height - CGFloat(min(top, max(0, value)) / top) * (size.height - 4) - 2
                    if index == 0 {
                        line.move(to: CGPoint(x: x, y: y))
                    } else {
                        line.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                var area = line
                area.addLine(to: CGPoint(x: size.width, y: size.height))
                area.addLine(to: CGPoint(x: 0, y: size.height))
                area.closeSubpath()
                context.fill(
                    area,
                    with: .linearGradient(
                        Gradient(colors: [accent.opacity(0.20), accent.opacity(0.015)]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )
                context.stroke(
                    line,
                    with: .linearGradient(
                        Gradient(colors: [PulseTheme.azure, PulseTheme.cyan]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width, y: 0)
                    ),
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
                )

                let phase = 0.5 + 0.5 * sin(timeline.date.timeIntervalSinceReferenceDate * 2.8)
                let lastY = size.height - CGFloat(min(top, max(0, samples.last ?? 0)) / top) * (size.height - 4) - 2
                let pulseRect = CGRect(
                    x: size.width - 5 - phase * 2,
                    y: lastY - 2.5 - phase * 1.5,
                    width: 5 + phase * 3,
                    height: 5 + phase * 3
                )
                context.fill(Path(ellipseIn: pulseRect), with: .color(accent.opacity(0.28)))
                context.fill(
                    Path(ellipseIn: pulseRect.insetBy(dx: 2, dy: 2)),
                    with: .color(accent)
                )
            }
        }
    }
}

private struct MetricTile: View {
    var label: String
    var value: String
    var detail: String
    var icon: String
    var accent: Color
    var progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(accent)
                Text(LocalizedStringKey(label))
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.secondary)
                Spacer()
            }
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.2), value: value)
                .foregroundStyle(PulseTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(PulseTheme.tertiary)
                .lineLimit(1)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.45), accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * min(1, max(0, progress)))
                }
            }
            .frame(height: 3)
        }
        .padding(12)
        .frame(height: 92)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.07), PulseTheme.card],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PulseTheme.stroke, lineWidth: 1)
        )
    }
}

private struct FactChip: View {
    var icon: String
    var text: String
    var tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .semibold))
            Text(text)
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .frame(height: 26)
        .background(
            Capsule()
                .fill(tint.opacity(0.07))
                .overlay(Capsule().stroke(tint.opacity(0.14), lineWidth: 1))
        )
    }
}

// MARK: - CPU

private struct CPUPage: View {
    @ObservedObject var model: AppModel
    private var cpu: CPUStats { model.snapshot.cpu }

    var body: some View {
        VStack(spacing: 10) {
            ConsoleCard(title: "处理器") {
                HStack(spacing: 16) {
                    RingGauge(
                        value: cpu.total / 100,
                        color: PulseTheme.azure,
                        rainbow: true,
                        title: "\(Int(cpu.total.rounded()))%",
                        subtitle: "总占用"
                    )
                    .frame(width: 106, height: 106)

                    VStack(spacing: 10) {
                        HStack {
                            StatColumn(label: "用户", value: String(format: "%.1f%%", cpu.user), tint: PulseTheme.azure)
                            Spacer()
                            StatColumn(label: "系统", value: String(format: "%.1f%%", cpu.system), tint: PulseTheme.violet)
                            Spacer()
                            StatColumn(label: "空闲", value: String(format: "%.1f%%", cpu.idle), tint: PulseTheme.secondary)
                        }
                        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                        HStack {
                            StatColumn(label: "负载 1m", value: String(format: "%.2f", cpu.load1))
                            Spacer()
                            StatColumn(label: "5m", value: String(format: "%.2f", cpu.load5))
                            Spacer()
                            StatColumn(label: "15m", value: String(format: "%.2f", cpu.load15))
                        }
                    }
                }
            }

            ConsoleCard(title: "核心矩阵", trailing: L("%d 性能 + %d 能效", cpu.performanceCores, cpu.efficiencyCores)) {
                if cpu.cores.isEmpty {
                    Text("等待首个处理器采样…")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 62)
                } else {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 8),
                        spacing: 7
                    ) {
                        ForEach(cpu.cores) { core in
                            CoreCell(core: core)
                        }
                    }
                }
            }

            ConsoleCard(title: "处理器历史", trailing: "LIVE") {
                AreaChart(values: model.cpuHistory, color: PulseTheme.azure, maxValue: 100)
                    .frame(height: 74)
            }

            ConsoleCard(title: "进程排行", trailing: "处理器") {
                ProcessRows(items: model.snapshot.processes, limit: 5)
            }
        }
    }
}

private struct CoreCell: View {
    var core: CPUCoreSample

    private var color: Color {
        core.kind == .performance ? PulseTheme.azure : PulseTheme.violet
    }

    var body: some View {
        VStack(spacing: 3) {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(Color.white.opacity(0.055))
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.45), color],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: max(3, geometry.size.height * core.usage / 100))
                }
            }
            .frame(height: 34)
            Text("\(core.id + 1)")
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundStyle(PulseTheme.tertiary)
        }
        .frame(height: 46)
    }
}

// MARK: - Memory

private struct MemoryPage: View {
    @ObservedObject var model: AppModel
    private var memory: MemoryStats { model.snapshot.memory }

    var body: some View {
        VStack(spacing: 10) {
            ConsoleCard(title: "内存") {
                HStack(spacing: 16) {
                    RingGauge(
                        value: memory.usedFraction,
                        color: PulseTheme.azure,
                        rainbow: true,
                        title: Format.percent(memory.usedFraction * 100),
                        subtitle: "已用"
                    )
                    .frame(width: 106, height: 106)

                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(Format.bytes(memory.used))
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundStyle(PulseTheme.text)
                            Text(L("共 %@", Format.bytes(memory.total)))
                                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                .foregroundStyle(PulseTheme.tertiary)
                        }
                        PressurePill(pressure: memory.pressure)
                        Text(L("交换 %@ / %@", Format.bytes(memory.swapUsed), Format.bytes(memory.swapTotal)))
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(PulseTheme.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }

            ConsoleCard(title: "内存构成") {
                MemoryRail(memory: memory)
                    .frame(height: 12)
                VStack(spacing: 7) {
                    HStack(spacing: 18) {
                        LegendItem(color: PulseTheme.azure, name: "应用", value: Format.bytes(memory.app))
                        LegendItem(color: PulseTheme.violet, name: "联动", value: Format.bytes(memory.wired))
                    }
                    HStack(spacing: 18) {
                        LegendItem(color: PulseTheme.secondary, name: "压缩", value: Format.bytes(memory.compressed))
                        LegendItem(color: PulseTheme.cyan, name: "缓存", value: Format.bytes(memory.cached))
                    }
                }
            }

            ConsoleCard(title: "内存历史", trailing: "LIVE") {
                AreaChart(values: model.memoryHistory, color: PulseTheme.azure, maxValue: 100)
                    .frame(height: 72)
            }

            ConsoleCard(title: "详情") {
                HStack {
                    StatColumn(label: "可用", value: Format.bytes(memory.free))
                    Spacer()
                    StatColumn(label: "压缩", value: Format.bytes(memory.compressed), tint: PulseTheme.secondary)
                    Spacer()
                    StatColumn(label: "交换已用", value: Format.bytes(memory.swapUsed), tint: PulseTheme.cyan)
                }
            }
        }
    }
}

private struct PressurePill: View {
    var pressure: MemoryPressure

    private var color: Color {
        switch pressure {
        case .normal: return PulseTheme.azure
        case .warning: return PulseTheme.amber
        case .critical: return PulseTheme.coral
        case .unknown: return PulseTheme.secondary
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(L("内存压力：%@", pressure.title))
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.09)))
        .fixedSize()
    }
}

private struct MemoryRail: View {
    var memory: MemoryStats

    var body: some View {
        Canvas { context, size in
            let total = max(memory.total, 1)
            let segments: [(Color, Double)] = [
                (PulseTheme.azure, memory.app),
                (PulseTheme.violet, memory.wired),
                (PulseTheme.secondary, memory.compressed),
                (PulseTheme.cyan, memory.cached)
            ]
            var x: CGFloat = 0
            for (color, value) in segments {
                let width = size.width * CGFloat(min(1, max(0, value / total)))
                guard width > 0 else { continue }
                let rect = CGRect(x: x, y: 0, width: max(0, width - 1), height: size.height)
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 3),
                    with: .color(color)
                )
                x += width
            }
        }
    }
}

// MARK: - Network

private struct NetworkPage: View {
    @ObservedObject var model: AppModel
    private var network: NetworkStats { model.snapshot.network }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                RateTile(
                    title: "下载",
                    value: Format.rate(network.downRate),
                    total: L("累计 %@", Format.bytes(network.totalDown)),
                    icon: "arrow.down",
                    color: PulseTheme.azure
                )
                RateTile(
                    title: "上传",
                    value: Format.rate(network.upRate),
                    total: L("累计 %@", Format.bytes(network.totalUp)),
                    icon: "arrow.up",
                    color: PulseTheme.secondary
                )
            }

            ConsoleCard(title: "带宽波形", trailing: "LIVE") {
                DualAreaChart(down: model.downloadHistory, up: model.uploadHistory)
                    .frame(height: 88)
                HStack(spacing: 18) {
                    LegendItem(color: PulseTheme.azure, name: "下载", value: Format.rate(network.downRate))
                    LegendItem(color: PulseTheme.secondary, name: "上传", value: Format.rate(network.upRate))
                }
            }

            ConsoleCard(title: "连接") {
                HStack {
                    StatColumn(label: "网卡", value: network.interfaceName)
                    Spacer()
                    StatColumn(label: "链路", value: network.isConnected ? L("已连接") : L("未连接"))
                    Spacer()
                    HStack(spacing: 5) {
                        Circle()
                            .fill(network.isConnected ? PulseTheme.azure : PulseTheme.coral)
                            .frame(width: 6, height: 6)
                        Text(network.isConnected ? L("在线") : L("离线"))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(network.isConnected ? PulseTheme.azure : PulseTheme.coral)
                    }
                }
            }

            ConsoleCard(title: "采样与吞吐") {
                HStack {
                    StatColumn(label: "接收", value: Format.bytes(network.totalDown), tint: PulseTheme.azure)
                    Spacer()
                    StatColumn(label: "发送", value: Format.bytes(network.totalUp), tint: PulseTheme.secondary)
                    Spacer()
                    StatColumn(label: "采样", value: String(format: "%.1f ms", model.sampleTime * 1000))
                }
            }
        }
    }
}

private struct RateTile: View {
    var title: String
    var value: String
    var total: String
    var icon: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
            Text(LocalizedStringKey(title))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.7)
                Spacer()
            }
            .foregroundStyle(color)
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(PulseTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(total)
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .foregroundStyle(PulseTheme.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.07), PulseTheme.card],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PulseTheme.stroke, lineWidth: 1)
        )
    }
}

// MARK: - Sensors

private struct SensorsPage: View {
    @ObservedObject var model: AppModel
    private var sensors: [SensorReading] { model.snapshot.sensors }
    private var featured: SensorReading? {
        sensors.filter { $0.category == .cpu }.max(by: { $0.value < $1.value })
            ?? sensors.max(by: { $0.value < $1.value })
    }

    var body: some View {
        VStack(spacing: 10) {
            ConsoleCard(title: "热度") {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        PulseTheme.temperature(featured?.value ?? 0).opacity(0.28),
                                        .clear
                                    ],
                                    center: .center,
                                    startRadius: 2,
                                    endRadius: 46
                                )
                            )
                        Image(systemName: "thermometer.medium")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(PulseTheme.temperature(featured?.value ?? 0))
                    }
                    .frame(width: 72, height: 72)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(featured.map { String(format: "%.1f°C", $0.value) } ?? "—")
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(PulseTheme.text)
                        Text(featured?.name ?? L("暂无温度传感器"))
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundStyle(PulseTheme.secondary)
                        Text(L("%d 个传感器 · 无需 root", sensors.count))
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(PulseTheme.tertiary)
                    }
                    Spacer(minLength: 0)
                }
                ThermalScale(value: featured?.value ?? 0)
            }

            ForEach(SensorCategory.allCases, id: \.self) { category in
                let readings = sensors.filter { $0.category == category }
                if !readings.isEmpty {
                    ConsoleCard(title: category.rawValue, trailing: "\(readings.count)") {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8)
                            ],
                            spacing: 8
                        ) {
                            ForEach(readings) { reading in
                                SensorChip(reading: reading)
                            }
                        }
                    }
                }
            }

            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 9, weight: .semibold))
                Text("风扇转速与控制需要特权 SMC 助手。流衡通过无需 root 的 HID 路径读取温度，不安装后台守护进程。")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(PulseTheme.tertiary)
            .padding(.horizontal, 3)
        }
    }
}

private struct ThermalScale: View {
    var value: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(PulseTheme.temperature(value))
                    .frame(width: 3)
                    .offset(x: geometry.size.width * min(1, max(0, (value - 25) / 70)))
            }
        }
        .frame(height: 7)
    }
}

private struct SensorChip: View {
    var reading: SensorReading

    var body: some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 2)
                .fill(PulseTheme.temperature(reading.value))
                .frame(width: 3, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(reading.name)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.secondary)
                    .lineLimit(1)
                Text(String(format: "%.1f%@", reading.value, reading.unit))
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PulseTheme.text)
            }
            Spacer(minLength: 0)
        }
        .padding(7)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.035))
        )
    }
}

// MARK: - System

private struct SystemPage: View {
    @ObservedObject var model: AppModel
    private var snapshot: SystemSnapshot { model.snapshot }

    var body: some View {
        VStack(spacing: 10) {
            ConsoleCard(title: "磁盘") {
                HStack {
                    StatColumn(label: "读取", value: Format.rate(snapshot.disk.readRate), tint: PulseTheme.azure)
                    Spacer()
                    StatColumn(label: "写入", value: Format.rate(snapshot.disk.writeRate), tint: PulseTheme.cyan)
                    Spacer()
                    StatColumn(label: "可用", value: Format.bytes(snapshot.disk.free))
                }
                if snapshot.disk.capacity > 0 {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.06))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [PulseTheme.azure, PulseTheme.violet],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * CGFloat(snapshot.disk.used / snapshot.disk.capacity))
                        }
                    }
                    .frame(height: 8)
                    HStack {
                        Text(L("%@ 已用", Format.bytes(snapshot.disk.used)))
                        Spacer()
                        Text(L("%@ 总计", Format.bytes(snapshot.disk.capacity)))
                    }
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(PulseTheme.tertiary)
                }
            }

            ConsoleCard(title: "图形处理器", trailing: snapshot.gpu.name) {
                if snapshot.gpu.available {
                    HStack {
                        StatColumn(label: "利用率", value: Format.percent(snapshot.gpu.utilization), tint: PulseTheme.azure)
                        Spacer()
                        StatColumn(label: "占用", value: Format.bytes(snapshot.gpu.memoryInUse), tint: PulseTheme.cyan)
                        Spacer()
                        StatColumn(label: "已分配", value: Format.bytes(snapshot.gpu.memoryAllocated))
                    }
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.06))
                            Capsule()
                                .fill(
                                    PulseTheme.azure
                                )
                                .frame(width: geometry.size.width * CGFloat(snapshot.gpu.utilization / 100))
                        }
                    }
                    .frame(height: 7)
                } else {
                    Text("此 Mac 暂不提供图形处理器统计。")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.tertiary)
                }
            }

            ConsoleCard(title: "电池") {
                if snapshot.battery.present {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().stroke(Color.white.opacity(0.07), lineWidth: 7)
                            Circle()
                                .trim(from: 0, to: snapshot.battery.percent / 100)
                                .stroke(
                                    AngularGradient(
                                        colors: [PulseTheme.azure, PulseTheme.cyan, PulseTheme.violet, PulseTheme.azure],
                                        center: .center
                                    ),
                                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                            Text(Format.percent(snapshot.battery.percent))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .frame(width: 54, height: 54)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(snapshot.battery.charging ? L("正在充电") : (snapshot.battery.onAC ? L("已接通电源") : L("使用电池")))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(PulseTheme.text)
                            Text(snapshot.battery.minutesRemaining > 0
                                ? (snapshot.battery.charging
                                    ? L("预计充满 %@", Format.batteryTime(snapshot.battery.minutesRemaining))
                                    : L("预计剩余 %@", Format.batteryTime(snapshot.battery.minutesRemaining)))
                                : L("已充满"))
                                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                .foregroundStyle(PulseTheme.secondary)
                        }
                        Spacer()
                        StatColumn(label: "循环", value: "\(snapshot.battery.cycleCount)")
                        StatColumn(label: "健康度", value: snapshot.battery.health > 0 ? String(format: "%.0f%%", snapshot.battery.health) : "—")
                    }
                } else {
                    Text("无内置电池。")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.tertiary)
                }
            }

            ConsoleCard(title: "关于本机") {
                VStack(spacing: 7) {
                    AboutLine(label: "主机", value: snapshot.hostName)
                    AboutLine(label: "型号", value: snapshot.modelIdentifier)
                    AboutLine(label: "芯片", value: snapshot.cpu.brand)
                    AboutLine(label: "系统", value: snapshot.osVersion)
                    AboutLine(label: "运行", value: Format.duration(snapshot.uptime))
                }
            }
        }
    }
}

private struct AboutLine: View {
    var label: String
    var value: String

    var body: some View {
        HStack {
            Text(LocalizedStringKey(label))
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.tertiary)
            Spacer()
            Text(value)
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(PulseTheme.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

// MARK: - Shared

private struct ConsoleCard<Content: View>: View {
    let title: String
    let trailing: String?
    let content: Content

    init(title: String, trailing: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                    Text(LocalizedStringKey(title))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                if let trailing {
                    Text(LocalizedStringKey(trailing))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(PulseTheme.tertiary)
                }
            }
            content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(PulseTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PulseTheme.stroke, lineWidth: 1)
        )
    }
}

private struct ProcessRows: View {
    var items: [ProcessItem]
    var limit: Int

    var body: some View {
        if items.isEmpty {
            Text("正在采集进程…")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 8) {
                ForEach(Array(items.prefix(limit).enumerated()), id: \.element.id) { index, process in
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(PulseTheme.tertiary)
                            .frame(width: 10)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(PulseTheme.seriesColor(index))
                            .frame(width: 3, height: 18)
                        Text(process.name)
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundStyle(PulseTheme.text)
                            .lineLimit(1)
                        Spacer()
                        Text(Format.bytes(process.memory))
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(PulseTheme.tertiary)
                        Text(String(format: "%.0f%%", process.cpu))
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(PulseTheme.seriesColor(index))
                            .frame(width: 42, alignment: .trailing)
                    }
                }
            }
        }
    }
}
