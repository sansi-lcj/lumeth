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

    var supportsHistory: Bool {
        self != .sensors
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
    @Published var historyRange: HistoryRange {
        didSet { defaults.set(historyRange.rawValue, forKey: "historyRange") }
    }
    @Published var alertCPU: Bool {
        didSet { defaults.set(alertCPU, forKey: "alertCPU") }
    }
    @Published var alertMemory: Bool {
        didSet { defaults.set(alertMemory, forKey: "alertMemory") }
    }
    @Published var alertTemperature: Bool {
        didSet { defaults.set(alertTemperature, forKey: "alertTemperature") }
    }
    @Published var alertBattery: Bool {
        didSet { defaults.set(alertBattery, forKey: "alertBattery") }
    }
    @Published var cpuAlertThreshold: Int {
        didSet { defaults.set(cpuAlertThreshold, forKey: "cpuAlertThreshold") }
    }
    @Published var temperatureAlertThreshold: Int {
        didSet { defaults.set(temperatureAlertThreshold, forKey: "temperatureAlertThreshold") }
    }
    @Published var batteryAlertThreshold: Int {
        didSet { defaults.set(batteryAlertThreshold, forKey: "batteryAlertThreshold") }
    }
    @Published var alertDuration: Double {
        didSet { defaults.set(alertDuration, forKey: "alertDuration") }
    }
    init() {
        defaults.register(defaults: [
            "showCPU": true,
            "showMemory": true,
            "showNetwork": true,
            "showSensors": true,
            "interval": 1.0,
            "historyRange": HistoryRange.fiveMinutes.rawValue,
            "alertCPU": false,
            "alertMemory": false,
            "alertTemperature": false,
            "alertBattery": false,
            "cpuAlertThreshold": 90,
            "temperatureAlertThreshold": 95,
            "batteryAlertThreshold": 20,
            "alertDuration": 10.0
        ])
        showCPU = defaults.bool(forKey: "showCPU")
        showMemory = defaults.bool(forKey: "showMemory")
        showNetwork = defaults.bool(forKey: "showNetwork")
        showSensors = defaults.bool(forKey: "showSensors")
        interval = defaults.double(forKey: "interval")
        historyRange = HistoryRange(
            rawValue: defaults.string(forKey: "historyRange") ?? ""
        ) ?? .fiveMinutes
        alertCPU = defaults.bool(forKey: "alertCPU")
        alertMemory = defaults.bool(forKey: "alertMemory")
        alertTemperature = defaults.bool(forKey: "alertTemperature")
        alertBattery = defaults.bool(forKey: "alertBattery")
        cpuAlertThreshold = defaults.integer(forKey: "cpuAlertThreshold")
        temperatureAlertThreshold = defaults.integer(forKey: "temperatureAlertThreshold")
        batteryAlertThreshold = defaults.integer(forKey: "batteryAlertThreshold")
        alertDuration = defaults.double(forKey: "alertDuration")
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot = SystemSnapshot()
    @Published var selectedTab: DashboardTab = .overview
    @Published private(set) var tick = 0
    @Published private(set) var sampleTime = 0.0

    let settings = AppSettings()
    let history = HistoryStore()
    private let alertEngine = AlertEngine()

    private let sampler = SystemSampler()
    private var timer: Timer?
    private var sampling = false
    private var dashboardVisible = false
    private var cancellables: Set<AnyCancellable> = []

    init() {
        settings.$interval
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in self?.restartTimer() }
            }
            .store(in: &cancellables)

        history.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        settings.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest4(
            settings.$alertCPU,
            settings.$alertMemory,
            settings.$alertTemperature,
            settings.$alertBattery
        )
        .dropFirst()
        .sink { [weak self] cpu, memory, temperature, battery in
            guard cpu || memory || temperature || battery else { return }
            Task { @MainActor in self?.alertEngine.requestAuthorization() }
        }
        .store(in: &cancellables)
    }

    func start() {
        if settings.alertCPU || settings.alertMemory
            || settings.alertTemperature || settings.alertBattery {
            alertEngine.requestAuthorization()
        }
        sampleNow()
        restartTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        history.save(force: true)
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
        history.append(newSnapshot, now: newSnapshot.date)
        alertEngine.evaluate(snapshot: newSnapshot, settings: settings)
        tick &+= 1
        if tick == 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.sampleNow()
            }
        }
    }

    var cpuHistory: [Double] { history.values(\.cpu, in: settings.historyRange) }
    var memoryHistory: [Double] { history.values(\.memory, in: settings.historyRange) }
    var downloadHistory: [Double] { history.values(\.download, in: settings.historyRange) }
    var uploadHistory: [Double] { history.values(\.upload, in: settings.historyRange) }
    var gpuHistory: [Double] { history.values(\.gpu, in: settings.historyRange) }
    var temperatureHistory: [Double] { history.values(\.temperature, in: settings.historyRange) }
    var batteryHistory: [Double] { history.values(\.battery, in: settings.historyRange) }
    var diskReadHistory: [Double] { history.values(\.diskRead, in: settings.historyRange) }
    var diskWriteHistory: [Double] { history.values(\.diskWrite, in: settings.historyRange) }
    var compactCPUHistory: [Double] {
        Array(history.values(\.cpu, in: .minute).suffix(90))
    }

    func historySummary(
        _ keyPath: KeyPath<MetricSample, Double>
    ) -> HistorySummary? {
        history.summary(keyPath, in: settings.historyRange)
    }
}

func pulseLog(_ message: String) {
    guard ProcessInfo.processInfo.environment["PULSE_DEBUG"] == "1" else { return }
    FileHandle.standardError.write(Data(("PULSE " + message + "\n").utf8))
}
