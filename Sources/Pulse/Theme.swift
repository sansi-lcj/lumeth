import SwiftUI

extension DashboardTab {
    var accentColor: Color {
        PulseTheme.azure
    }
}

enum PulseTheme {
    static let island = Color(red: 0.016, green: 0.020, blue: 0.027)
    static let background = Color(red: 0.051, green: 0.067, blue: 0.090)
    static let backgroundLift = Color(red: 0.086, green: 0.106, blue: 0.133)
    static let card = Color(red: 0.086, green: 0.106, blue: 0.133)
    static let cardStrong = Color(red: 0.110, green: 0.129, blue: 0.157)
    static let stroke = Color(red: 0.188, green: 0.212, blue: 0.239)
    static let text = Color(red: 0.902, green: 0.929, blue: 0.953)
    static let secondary = Color(red: 0.545, green: 0.580, blue: 0.620)
    static let tertiary = Color(red: 0.431, green: 0.494, blue: 0.506)

    static let coral = Color(red: 0.973, green: 0.318, blue: 0.286)
    static let orange = Color(red: 0.941, green: 0.533, blue: 0.243)
    static let amber = Color(red: 0.824, green: 0.600, blue: 0.133)
    static let lime = Color(red: 0.494, green: 0.906, blue: 0.529)
    static let mint = Color(red: 0.247, green: 0.725, blue: 0.314)
    static let cyan = Color(red: 0.475, green: 0.753, blue: 1.000)
    static let azure = Color(red: 0.345, green: 0.651, blue: 1.000)
    static let violet = Color(red: 0.647, green: 0.839, blue: 1.000)
    static let magenta = Color(red: 0.545, green: 0.580, blue: 0.620)

    static let rainbow: [Color] = [azure, cyan, violet, secondary]
    static let ringRainbow: [Color] = [azure, cyan, azure]

    static func rainbowColor(_ index: Int) -> Color {
        rainbow[((index % rainbow.count) + rainbow.count) % rainbow.count]
    }

    static func seriesColor(_ index: Int) -> Color {
        let series = [azure, cyan, violet, secondary]
        return series[((index % series.count) + series.count) % series.count]
    }

    static let cpu = azure
    static let cpuDeep = violet
    static let memory = violet
    static let memoryDeep = magenta
    static let networkDown = azure
    static let networkUp = Color(red: 0.455, green: 0.560, blue: 0.690)
    static let sensors = orange
    static let disk = azure
    static let battery = mint
    static let gpu = amber

    static func temperature(_ value: Double) -> Color {
        switch value {
        case ..<65: return azure
        case ..<80: return amber
        default: return coral
        }
    }
}

struct Card<Content: View>: View {
    let title: String?
    let subtitle: String?
    let content: Content

    init(title: String? = nil, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            if title != nil {
                HStack(alignment: .firstTextBaseline) {
                    Text(title ?? "")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(PulseTheme.secondary)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Spacer()
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(PulseTheme.tertiary)
                    }
                }
            }
            content
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(PulseTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(PulseTheme.stroke, lineWidth: 1)
                )
        )
    }
}

struct RingGauge: View {
    var value: Double
    var color: Color
    var rainbow: Bool = false
    var lineWidth: CGFloat = 9
    var title: String
    var subtitle: String?

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: lineWidth)
            if rainbow {
                Circle()
                    .trim(from: 0, to: min(1, max(0, value)))
                    .stroke(
                        AngularGradient(
                            colors: [color.opacity(0.45), color, color.opacity(0.82)],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: PulseTheme.azure.opacity(0.20), radius: 4)
            } else {
                Circle()
                    .trim(from: 0, to: min(1, max(0, value)))
                    .stroke(
                        AngularGradient(
                            colors: [color.opacity(0.6), color, color.opacity(0.85)],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.35), radius: 4)
            }
            VStack(spacing: 1) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(PulseTheme.text)
                if let subtitle {
                    Text(LocalizedStringKey(subtitle))
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.tertiary)
                }
            }
        }
    }
}

enum ChartPath {
    static func smooth(_ points: [CGPoint], in bounds: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 1 else { return path }

        for index in 0..<(points.count - 1) {
            let p0 = points[max(0, index - 1)]
            let p1 = points[index]
            let p2 = points[index + 1]
            let p3 = points[min(points.count - 1, index + 2)]
            let c1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6,
                y: min(bounds.maxY, max(bounds.minY, p1.y + (p2.y - p0.y) / 6))
            )
            let c2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6,
                y: min(bounds.maxY, max(bounds.minY, p2.y - (p3.y - p1.y) / 6))
            )
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        return path
    }
}

struct AreaChart: View {
    var values: [Double]
    var color: Color
    var maxValue: Double?
    var showGrid: Bool = true
    var lineWidth: CGFloat = 1.6
    var fillOpacity: Double = 0.32

    var body: some View {
        Canvas { context, size in
            guard size.width > 2, size.height > 2 else { return }
            let top = max(maxValue ?? values.max() ?? 1, 0.0001)
            let count = max(values.count, 2)
            let step = size.width / CGFloat(count - 1)

            if showGrid {
                for fraction in [0.25, 0.5, 0.75] {
                    var grid = Path()
                    let y = size.height * fraction
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(grid, with: .color(Color.white.opacity(0.045)), lineWidth: 0.8)
                }
            }

            let plot = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            var points: [CGPoint] = []
            for (index, value) in values.enumerated() {
                let x = CGFloat(index) * step
                let normalized = min(1, max(0, value / top))
                let y = size.height - CGFloat(normalized) * (size.height - 2) - 1
                points.append(CGPoint(x: x, y: y))
            }

            let line = ChartPath.smooth(points, in: plot)
            var area = line
            area.addLine(to: CGPoint(x: size.width, y: size.height))
            area.addLine(to: CGPoint(x: 0, y: size.height))
            area.closeSubpath()
            context.fill(
                area,
                with: .linearGradient(
                    Gradient(colors: [color.opacity(fillOpacity), color.opacity(0.015)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
            context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }
}

struct DualAreaChart: View {
    var down: [Double]
    var up: [Double]

    var body: some View {
        ZStack {
            AreaChart(values: down, color: PulseTheme.networkDown, maxValue: max(down.max() ?? 0, up.max() ?? 0, 1))
            AreaChart(
                values: up,
                color: PulseTheme.networkUp,
                maxValue: max(down.max() ?? 0, up.max() ?? 0, 1),
                showGrid: false
            )
        }
    }
}

struct TinyBar: View {
    var value: Double
    var color: Color
    var height: CGFloat = 30

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(Color.white.opacity(0.055))
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(color)
                .frame(height: max(2, height * CGFloat(min(100, max(0, value)) / 100)))
        }
        .frame(height: height)
    }
}

struct LegendItem: View {
    var color: Color
    var name: String
    var value: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(LocalizedStringKey(name))
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.secondary)
            Spacer(minLength: 4)
            Text(value)
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(PulseTheme.text)
        }
    }
}

struct StatColumn: View {
    var label: String
    var value: String
    var tint: Color = PulseTheme.text

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(LocalizedStringKey(label))
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.tertiary)
                .textCase(.uppercase)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}
