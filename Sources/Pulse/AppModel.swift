import Combine
import Foundation

enum DashboardTab: String, CaseIterable, Identifiable {
    case overview
    case cpu
    case memory
    case network
    case sensors
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "总览"
        case .cpu: return "处理器"
        case .memory: return "内存"
        case .network: return "网络"
        case .sensors: return "传感器"
        case .system: return "系统"
        }
    }

    var icon: String {
        switch self {
        case .overview: return "waveform.path.ecg"
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .network: return "network"
        case .sensors: return "thermometer.medium"
        case .system: return "square.grid.2x2"
        }
    }

    var railTitle: String {
        switch self {
        case .overview: return "总览"
        case .cpu: return "处理器"
        case .memory: return "内存简"
        case .network: return "网络"
        case .sensors: return "传感"
        case .system: return "系统"
        }
    }

    var subtitle: String {
        switch self {
        case .overview: return "实时状态与关键指标"
        case .cpu: return "逐核占用、负载与进程"
        case .memory: return "内存构成、压力与交换"
        case .network: return "实时吞吐与链路状态"
        case .sensors: return "温度传感器与散热状态"
        case .system: return "磁盘、图形、电池与本机"
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    private let defaults = UserDefaults.standard
    var onChange: (() -> Void)?

    @Published var showCPU: Bool {
        didSet { defaults.set(showCPU, forKey: "showCPU"); onChange?() }
    }
    @Published var showMemory: Bool {
        didSet { defaults.set(showMemory, forKey: "showMemory"); onChange?() }
    }
    @Published var showNetwork: Bool {
        didSet { defaults.set(showNetwork, forKey: "showNetwork"); onChange?() }
    }
    @Published var showSensors: Bool {
        didSet { defaults.set(showSensors, forKey: "showSensors"); onChange?() }
    }
    @Published var interval: Double {
        didSet { defaults.set(interval, forKey: "interval"); onChange?() }
    }
    init() {
        defaults.register(defaults: [
            "showCPU": true,
            "showMemory": true,
            "showNetwork": true,
            "showSensors": true,
            "interval": 1.0
        ])
        showCPU = defaults.bool(forKey: "showCPU")
        showMemory = defaults.bool(forKey: "showMemory")
        showNetwork = defaults.bool(forKey: "showNetwork")
        showSensors = defaults.bool(forKey: "showSensors")
        interval = defaults.double(forKey: "interval")
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot = SystemSnapshot()
    @Published private(set) var cpuHistory: [Double] = []
    @Published private(set) var memoryHistory: [Double] = []
    @Published private(set) var downloadHistory: [Double] = []
    @Published private(set) var uploadHistory: [Double] = []
    @Published private(set) var gpuHistory: [Double] = []
    @Published private(set) var temperatureHistory: [Double] = []
    @Published var selectedTab: DashboardTab = .overview
    @Published private(set) var tick = 0
    @Published private(set) var sampleTime = 0.0

    let settings = AppSettings()

    private let sampler = SystemSampler()
    private var timer: Timer?
    private var sampling = false
    private var dashboardVisible = false
    private var cancellables: Set<AnyCancellable> = []
    private let historyLimit = 120

    init() {
        settings.$interval
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in self?.restartTimer() }
            }
            .store(in: &cancellables)
    }

    func start() {
        sampleNow()
        restartTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func setDashboardVisible(_ visible: Bool) {
        dashboardVisible = visible
        if visible { sampleNow() }
    }

    func sampleNow() {
        guard !sampling else { return }
        sampling = true
        pulseLog("sample start")
        let start = CFAbsoluteTimeGetCurrent()
        let includeProcesses = dashboardVisible && (selectedTab == .overview || selectedTab == .cpu)
        DispatchQueue.global(qos: .utility).async { [sampler] in
            let snapshot = sampler.sample(includeProcesses: includeProcesses)
            let duration = CFAbsoluteTimeGetCurrent() - start
            DispatchQueue.main.async {
                pulseLog(
                    String(
                        format: "sample done cpu=%.1f mem=%.1f sensors=%d in %.1fms",
                        snapshot.cpu.total,
                        snapshot.memory.usedFraction * 100,
                        snapshot.sensors.count,
                        duration * 1000
                    )
                )
                self.apply(snapshot, duration: duration)
                self.sampling = false
            }
        }
    }

    private func restartTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: max(0.5, settings.interval), repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.sampleNow()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func apply(_ newSnapshot: SystemSnapshot, duration: Double) {
        snapshot = newSnapshot
        sampleTime = duration
        append(newSnapshot.cpu.total, to: &cpuHistory)
        append(newSnapshot.memory.usedFraction * 100, to: &memoryHistory)
        append(newSnapshot.network.downRate, to: &downloadHistory)
        append(newSnapshot.network.upRate, to: &uploadHistory)
        append(newSnapshot.gpu.utilization, to: &gpuHistory)
        append(newSnapshot.primaryTemperature ?? 0, to: &temperatureHistory)
        tick &+= 1
        if tick == 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.sampleNow()
            }
        }
    }

    private func append(_ value: Double, to history: inout [Double]) {
        history.append(value.isFinite ? value : 0)
        if history.count > historyLimit {
            history.removeFirst(history.count - historyLimit)
        }
    }
}

func pulseLog(_ message: String) {
    guard ProcessInfo.processInfo.environment["PULSE_DEBUG"] == "1" else { return }
    FileHandle.standardError.write(Data(("PULSE " + message + "\n").utf8))
}
