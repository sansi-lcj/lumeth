import Foundation

enum HistoryRange: String, CaseIterable, Identifiable {
    case minute
    case fiveMinutes
    case fifteenMinutes
    case hour
    case day

    var id: String { rawValue }

    var seconds: TimeInterval {
        switch self {
        case .minute: return 60
        case .fiveMinutes: return 300
        case .fifteenMinutes: return 900
        case .hour: return 3_600
        case .day: return 86_400
        }
    }

    var label: String {
        switch self {
        case .minute: return "1m"
        case .fiveMinutes: return "5m"
        case .fifteenMinutes: return "15m"
        case .hour: return "1h"
        case .day: return "24h"
        }
    }

    var usesLongTermStorage: Bool {
        self == .day
    }
}

struct MetricSample: Codable, Identifiable {
    let timestamp: Date
    let cpu: Double
    let memory: Double
    let download: Double
    let upload: Double
    let gpu: Double
    let temperature: Double
    let battery: Double
    let diskRead: Double
    let diskWrite: Double
    let swapUsed: Double

    var id: Date { timestamp }
}

struct HistorySummary {
    let average: Double
    let maximum: Double
    let count: Int
}

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var revision = 0

    private var recent: [MetricSample] = []
    private var archive: [MetricSample] = []
    private let recentRetention: TimeInterval = 3_600
    private let archiveRetention: TimeInterval = 86_400
    private let archiveInterval: TimeInterval = 60
    private var lastSave = Date.distantPast
    private let fileURL: URL

    init() {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        let directory = support.appendingPathComponent("Lumeth", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        fileURL = directory.appendingPathComponent("history-v1.json")
        load()
    }

    func append(_ snapshot: SystemSnapshot, now: Date = Date()) {
        let sample = MetricSample(
            timestamp: now,
            cpu: snapshot.cpu.total,
            memory: snapshot.memory.usedFraction * 100,
            download: snapshot.network.downRate,
            upload: snapshot.network.upRate,
            gpu: snapshot.gpu.utilization,
            temperature: snapshot.primaryTemperature ?? 0,
            battery: snapshot.battery.present ? snapshot.battery.percent : 0,
            diskRead: snapshot.disk.readRate,
            diskWrite: snapshot.disk.writeRate,
            swapUsed: snapshot.memory.swapUsed
        )

        recent.append(sample)
        let recentCutoff = now.addingTimeInterval(-recentRetention)
        recent.removeAll { $0.timestamp < recentCutoff }

        if archive.last.map({ now.timeIntervalSince($0.timestamp) >= archiveInterval }) ?? true {
            archive.append(sample)
        }
        let archiveCutoff = now.addingTimeInterval(-archiveRetention)
        archive.removeAll { $0.timestamp < archiveCutoff }

        revision &+= 1
        if now.timeIntervalSince(lastSave) >= 60 {
            save()
        }
    }

    func samples(
        in range: HistoryRange,
        now: Date = Date()
    ) -> [MetricSample] {
        let cutoff = now.addingTimeInterval(-range.seconds)
        if range.usesLongTermStorage {
            var seen: Set<Date> = []
            return (archive + recent)
                .filter { $0.timestamp >= cutoff }
                .sorted { $0.timestamp < $1.timestamp }
                .filter { seen.insert($0.timestamp).inserted }
        }
        return recent.filter { $0.timestamp >= cutoff }
    }

    func values(
        _ keyPath: KeyPath<MetricSample, Double>,
        in range: HistoryRange,
        now: Date = Date()
    ) -> [Double] {
        samples(in: range, now: now).map { $0[keyPath: keyPath] }
    }

    func summary(
        _ keyPath: KeyPath<MetricSample, Double>,
        in range: HistoryRange,
        now: Date = Date()
    ) -> HistorySummary? {
        let values = values(keyPath, in: range, now: now)
        guard !values.isEmpty else { return nil }
        return HistorySummary(
            average: values.reduce(0, +) / Double(values.count),
            maximum: values.max() ?? 0,
            count: values.count
        )
    }

    func save(force: Bool = false) {
        guard force || Date().timeIntervalSince(lastSave) >= 60 else { return }
        lastSave = Date()
        let payload = PersistedHistory(recent: recent, archive: archive)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(payload)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            pulseLog("history save failed: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let payload = try? decoder.decode(PersistedHistory.self, from: data) else {
            return
        }
        let now = Date()
        recent = payload.recent.filter {
            $0.timestamp >= now.addingTimeInterval(-recentRetention)
        }
        archive = payload.archive.filter {
            $0.timestamp >= now.addingTimeInterval(-archiveRetention)
        }
        revision &+= 1
    }
}

private struct PersistedHistory: Codable {
    let recent: [MetricSample]
    let archive: [MetricSample]
}
