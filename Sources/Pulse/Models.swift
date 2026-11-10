import Foundation

enum AppVersion {
    static var short: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "—"
    }
}

enum CoreKind: String {
    case performance = "P"
    case efficiency = "E"
}

struct CPUCoreSample: Identifiable {
    let id: Int
    let usage: Double
    let kind: CoreKind
}

struct CPUStats {
    var total: Double = 0
    var user: Double = 0
    var system: Double = 0
    var idle: Double = 100
    var cores: [CPUCoreSample] = []
    var load1: Double = 0
    var load5: Double = 0
    var load15: Double = 0
    var brand: String = ""
    var performanceCores: Int = 0
    var efficiencyCores: Int = 0
}

enum MemoryPressure: String {
    case normal = "正常"
    case warning = "偏高"
    case critical = "严重"
    case unknown = "未知"

    var level: Int {
        switch self {
        case .normal: return 0
        case .warning: return 1
        case .critical: return 2
        case .unknown: return 0
        }
    }

    var title: String { L(rawValue) }
}

struct MemoryStats {
    var total: Double = 0
    var used: Double = 0
    var app: Double = 0
    var wired: Double = 0
    var compressed: Double = 0
    var cached: Double = 0
    var free: Double = 0
    var swapUsed: Double = 0
    var swapTotal: Double = 0
    var pressure: MemoryPressure = .unknown

    var usedFraction: Double {
        total > 0 ? min(1, used / total) : 0
    }
}

struct NetworkStats {
    var downRate: Double = 0
    var upRate: Double = 0
    var totalDown: Double = 0
    var totalUp: Double = 0
    var interfaceName: String = "—"
    var isConnected: Bool = false
    var addresses: [String] = []
    var interfaces: [NetworkInterfaceStats] = []
}

struct NetworkInterfaceStats: Identifiable {
    var id: String { name }
    let name: String
    let downRate: Double
    let upRate: Double
    let totalDown: Double
    let totalUp: Double
    let addresses: [String]
    let isPrimary: Bool
    let isConnected: Bool
}

struct DiskStats {
    var readRate: Double = 0
    var writeRate: Double = 0
    var totalRead: Double = 0
    var totalWritten: Double = 0
    var capacity: Double = 0
    var free: Double = 0
    var used: Double { max(0, capacity - free) }
}

struct GPUStats {
    var name: String = "GPU"
    var utilization: Double = 0
    var memoryInUse: Double = 0
    var memoryAllocated: Double = 0
    var available: Bool = false
}

struct BatteryStats {
    var present: Bool = false
    var percent: Double = 0
    var charging: Bool = false
    var onAC: Bool = false
    var minutesRemaining: Int = 0
    var cycleCount: Int = 0
    var temperature: Double = 0
    var health: Double = 0
}

enum SensorCategory: String, CaseIterable {
    case cpu = "处理器"
    case gpu = "图形处理器"
    case memory = "内存"
    case storage = "存储"
    case battery = "电池"
    case board = "主板"
    case ambient = "环境"
    case other = "其他"
}

struct SensorReading: Identifiable {
    let id: String
    let name: String
    let value: Double
    let unit: String
    let category: SensorCategory

    var isTemperature: Bool {
        unit.contains("°")
    }
}

struct ProcessItem: Identifiable {
    let id: Int32
    let name: String
    let cpu: Double
    let memory: Double
}

struct SystemSnapshot {
    var date = Date()
    var cpu = CPUStats()
    var memory = MemoryStats()
    var network = NetworkStats()
    var disk = DiskStats()
    var gpu = GPUStats()
    var battery = BatteryStats()
    var sensors: [SensorReading] = []
    var processes: [ProcessItem] = []
    var uptime: TimeInterval = 0
    var hostName: String = ""
    var modelName: String = ""
    var modelIdentifier: String = ""
    var osVersion: String = ""

    var primaryTemperature: Double? {
        sensors.filter { $0.category == .cpu }.map(\.value).max()
    }
}

enum Format {
    static func bytes(_ value: Double, decimals: Int = 1) -> String {
        let units = ["B", "KB", "MB", "GB", "TB", "PB"]
        var amount = max(0, value)
        var unit = 0
        while amount >= 1024, unit < units.count - 1 {
            amount /= 1024
            unit += 1
        }
        if unit == 0 {
            return String(format: "%.0f %@", amount, units[unit])
        }
        return String(format: "%.\(decimals)f %@", amount, units[unit])
    }

    static func compactBytes(_ value: Double) -> String {
        let units = ["B", "K", "M", "G", "T"]
        var amount = max(0, value)
        var unit = 0
        while amount >= 1024, unit < units.count - 1 {
            amount /= 1024
            unit += 1
        }
        if unit == 0 { return String(format: "%.0f%@", amount, units[unit]) }
        if amount >= 100 { return String(format: "%.0f%@", amount, units[unit]) }
        if amount >= 10 { return String(format: "%.1f%@", amount, units[unit]) }
        return String(format: "%.2f%@", amount, units[unit])
    }

    static func rate(_ value: Double) -> String {
        compactBytes(value) + "/s"
    }

    static func percent(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        if days > 0 {
            return L("%d天 %02d:%02d", days, hours, minutes)
        }
        return String(format: "%02d:%02d", hours, minutes)
    }

    static func batteryTime(_ minutes: Int) -> String {
        guard minutes > 0, minutes < 1_000 else { return L("计算中…") }
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
}
