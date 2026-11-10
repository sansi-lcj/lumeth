import Darwin
import Foundation
import IOKit
import IOKit.ps

final class SystemSampler: @unchecked Sendable {
    private let sensorReader = HIDSensorReader()
    private let smcReader = SMCReader()

    private var previousCPU: [UInt32]?
    private var previousNetwork: [String: (down: UInt64, up: UInt64, flags: Int32)] = [:]
    private var previousDisk: (read: UInt64, write: UInt64)?
    private var lastProcessSample = Date.distantPast
    private var cachedProcesses: [ProcessItem] = []
    private var lastSensorSample = Date.distantPast
    private var cachedSensors: [SensorReading] = []
    private var lastDiskSample = Date.distantPast
    private var cachedDisk = DiskStats()
    private var lastGPUSample = Date.distantPast
    private var cachedGPU = GPUStats()
    private var lastBatterySample = Date.distantPast
    private var cachedBattery = BatteryStats()
    private var cachedModel = ""
    private var cachedBrand = ""
    private var cachedHost = ""
    private var cachedOS = ""
    private var lastSampleTime = Date()

    func sample(includeProcesses: Bool = true) -> SystemSnapshot {
        let now = Date()
        let elapsed = max(0.05, now.timeIntervalSince(lastSampleTime))
        lastSampleTime = now

        if cachedModel.isEmpty {
            cachedModel = Self.sysctlString("hw.model") ?? "Mac"
            cachedBrand = Self.sysctlString("machdep.cpu.brand_string") ?? "Apple Silicon"
            cachedHost = ProcessInfo.processInfo.hostName
            cachedOS = ProcessInfo.processInfo.operatingSystemVersionString
        }

        var snapshot = SystemSnapshot()
        snapshot.date = now
        let t0 = CFAbsoluteTimeGetCurrent()
        snapshot.cpu = readCPU()
        let t1 = CFAbsoluteTimeGetCurrent()
        snapshot.memory = readMemory()
        let t2 = CFAbsoluteTimeGetCurrent()
        snapshot.network = readNetwork(elapsed: elapsed)
        let t3 = CFAbsoluteTimeGetCurrent()
        if now.timeIntervalSince(lastDiskSample) >= 1.5 {
            cachedDisk = readDisk(elapsed: max(1.5, now.timeIntervalSince(lastDiskSample)))
            lastDiskSample = now
        }
        snapshot.disk = cachedDisk
        let t4 = CFAbsoluteTimeGetCurrent()
        if now.timeIntervalSince(lastGPUSample) >= 2 {
            cachedGPU = readGPU()
            lastGPUSample = now
        }
        snapshot.gpu = cachedGPU
        let t5 = CFAbsoluteTimeGetCurrent()
        if now.timeIntervalSince(lastSensorSample) >= 2 {
            cachedSensors = sensorReader.read()
            lastSensorSample = now
        }
        let sensors = cachedSensors
        snapshot.sensors = sensors
        let t6 = CFAbsoluteTimeGetCurrent()
        if now.timeIntervalSince(lastBatterySample) >= 5 {
            cachedBattery = readBattery(
                temperature: sensors.first(where: { $0.category == .battery })?.value
            )
            lastBatterySample = now
        }
        snapshot.battery = cachedBattery
        let t7 = CFAbsoluteTimeGetCurrent()
        if let fan = smcReader.fanRPM() {
            snapshot.sensors.append(
                SensorReading(id: "fan", name: "Fan", value: fan, unit: " RPM", category: .board)
            )
        }
        snapshot.processes = includeProcesses ? readProcesses() : cachedProcesses
        let t8 = CFAbsoluteTimeGetCurrent()
        snapshot.uptime = ProcessInfo.processInfo.systemUptime
        snapshot.hostName = cachedHost
        snapshot.modelName = cachedBrand
        snapshot.modelIdentifier = cachedModel
        snapshot.osVersion = cachedOS
        pulseLog(
            String(
                format: "timing cpu=%.1f mem=%.1f net=%.1f disk=%.1f gpu=%.1f sensors=%.1f battery=%.1f proc=%.1f ms",
                (t1 - t0) * 1000, (t2 - t1) * 1000, (t3 - t2) * 1000,
                (t4 - t3) * 1000, (t5 - t4) * 1000, (t6 - t5) * 1000,
                (t7 - t6) * 1000, (t8 - t7) * 1000
            )
        )
        return snapshot
    }

    // MARK: - CPU

    private func readCPU() -> CPUStats {
        var stats = CPUStats()
        stats.brand = cachedBrand

        var coreCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let result = host_processor_info(
            mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &coreCount, &info, &infoCount
        )
        guard result == KERN_SUCCESS, let info else { return stats }
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: info)),
                vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)
            )
        }

        let stride = Int(CPU_STATE_MAX)
        let cores = Int(coreCount)
        var current = [UInt32]()
        current.reserveCapacity(cores * stride)
        for index in 0..<(cores * stride) {
            current.append(UInt32(bitPattern: info[index]))
        }

        let performance = Self.sysctlInt("hw.perflevel0.logicalcpu") ?? 0
        let efficiency = Self.sysctlInt("hw.perflevel1.logicalcpu") ?? 0
        stats.performanceCores = performance
        stats.efficiencyCores = efficiency

        guard let previous = previousCPU, previous.count == current.count else {
            previousCPU = current
            stats.cores = (0..<cores).map { index in
                CPUCoreSample(
                    id: index,
                    usage: 0,
                    kind: index < performance ? .performance : .efficiency
                )
            }
            return stats
        }

        var totalUser = 0.0
        var totalSystem = 0.0
        var totalIdle = 0.0
        var coreSamples: [CPUCoreSample] = []
        coreSamples.reserveCapacity(cores)

        for core in 0..<cores {
            let base = core * stride
            let user = Double(current[base + Int(CPU_STATE_USER)] &- previous[base + Int(CPU_STATE_USER)])
            let system = Double(current[base + Int(CPU_STATE_SYSTEM)] &- previous[base + Int(CPU_STATE_SYSTEM)])
            let nice = Double(current[base + Int(CPU_STATE_NICE)] &- previous[base + Int(CPU_STATE_NICE)])
            let idle = Double(current[base + Int(CPU_STATE_IDLE)] &- previous[base + Int(CPU_STATE_IDLE)])
            let total = user + system + nice + idle
            let busy = total > 0 ? (user + system + nice) / total * 100 : 0
            coreSamples.append(
                CPUCoreSample(
                    id: core,
                    usage: min(100, max(0, busy)),
                    kind: core < performance ? .performance : .efficiency
                )
            )
            totalUser += user + nice
            totalSystem += system
            totalIdle += idle
        }

        let total = totalUser + totalSystem + totalIdle
        if total > 0 {
            stats.user = totalUser / total * 100
            stats.system = totalSystem / total * 100
            stats.idle = totalIdle / total * 100
            stats.total = min(100, max(0, stats.user + stats.system))
        }
        stats.cores = coreSamples
        previousCPU = current

        var loads = [Double](repeating: 0, count: 3)
        loads.withUnsafeMutableBufferPointer { buffer in
            _ = getloadavg(buffer.baseAddress, 3)
        }
        stats.load1 = loads[0]
        stats.load5 = loads[1]
        stats.load15 = loads[2]
        return stats
    }

    // MARK: - Memory

    private func readMemory() -> MemoryStats {
        var stats = MemoryStats()
        stats.total = Double(Self.sysctlUInt64("hw.memsize") ?? 0)
        guard stats.total > 0 else { return stats }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let page = Double(pageSize)

        var vm = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &vm) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return stats }

        let appPages = max(0, Int64(vm.internal_page_count) - Int64(vm.purgeable_count))
        stats.app = Double(appPages) * page
        stats.wired = Double(vm.wire_count) * page
        stats.compressed = Double(vm.compressor_page_count) * page
        stats.cached = Double(vm.external_page_count + vm.purgeable_count) * page
        stats.used = min(stats.total, stats.app + stats.wired + stats.compressed)
        stats.free = max(0, stats.total - stats.used - stats.cached)

        var swap = XSWUsage()
        var swapSize = MemoryLayout<XSWUsage>.size
        if sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0 {
            stats.swapTotal = Double(swap.total)
            stats.swapUsed = Double(swap.used)
        }

        var level: Int32 = 0
        var levelSize = MemoryLayout<Int32>.size
        if sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &levelSize, nil, 0) == 0 {
            switch level {
            case 2: stats.pressure = .warning
            case 4: stats.pressure = .critical
            default: stats.pressure = .normal
            }
        }
        return stats
    }

    // MARK: - Network

    private func readNetwork(elapsed: TimeInterval) -> NetworkStats {
        var stats = NetworkStats()
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0
        guard sysctl(&mib, 6, nil, &length, nil, 0) == 0, length > 0 else { return stats }

        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, 6, &buffer, &length, nil, 0) == 0 else { return stats }

        var current: [String: (down: UInt64, up: UInt64, flags: Int32)] = [:]
        buffer.withUnsafeBytes { raw in
            var offset = 0
            while offset + MemoryLayout<if_msghdr2>.size <= length {
                let header = raw.load(fromByteOffset: offset, as: if_msghdr2.self)
                let messageLength = Int(header.ifm_msglen)
                guard messageLength > 0 else { break }
                if header.ifm_type == 0x12 {
                    var nameBuffer = [CChar](repeating: 0, count: Int(IFNAMSIZ) + 1)
                    if if_indextoname(UInt32(header.ifm_index), &nameBuffer) != nil {
                        let name = String(cString: nameBuffer)
                        current[name] = (
                            UInt64(header.ifm_data.ifi_ibytes),
                            UInt64(header.ifm_data.ifi_obytes),
                            header.ifm_flags
                        )
                    }
                }
                offset += messageLength
            }
        }

        let excluded: Set<String> = ["lo0", "awdl0", "llw0", "utun0", "utun1", "utun2", "utun3", "anpi0", "ap1"]
        let primary = current.keys.contains("en0")
            ? "en0"
            : current.keys.filter { !excluded.contains($0) }.sorted().first
        stats.interfaceName = primary ?? "—"
        if let primary, let counters = current[primary] {
            stats.totalDown = Double(counters.down)
            stats.totalUp = Double(counters.up)
            if let previous = previousNetwork[primary] {
                let down = counters.down >= previous.down ? counters.down - previous.down : counters.down
                let up = counters.up >= previous.up ? counters.up - previous.up : counters.up
                stats.downRate = Double(down) / elapsed
                stats.upRate = Double(up) / elapsed
            }
            stats.isConnected = (counters.flags & 0x1) != 0
        }
        previousNetwork = current
        return stats
    }

    // MARK: - Disk

    private func readDisk(elapsed: TimeInterval) -> DiskStats {
        var stats = DiskStats()
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator
        ) == KERN_SUCCESS else { return stats }
        defer { IOObjectRelease(iterator) }

        var bestRead: UInt64 = 0
        var bestWrite: UInt64 = 0
        var bestTotal: UInt64 = 0
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            guard let property = IORegistryEntryCreateCFProperty(
                service, "Statistics" as CFString, kCFAllocatorDefault, 0
            )?.takeRetainedValue() as? [String: Any] else { continue }
            let read = (property["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
            let write = (property["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
            if read + write > bestTotal {
                bestTotal = read + write
                bestRead = read
                bestWrite = write
            }
        }

        stats.totalRead = Double(bestRead)
        stats.totalWritten = Double(bestWrite)
        if let previous = previousDisk {
            let read = bestRead >= previous.read ? bestRead - previous.read : bestRead
            let write = bestWrite >= previous.write ? bestWrite - previous.write : bestWrite
            stats.readRate = Double(read) / elapsed
            stats.writeRate = Double(write) / elapsed
        }
        previousDisk = (bestRead, bestWrite)

        let root = URL(fileURLWithPath: "/")
        if let values = try? root.resourceValues(forKeys: [
            .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey
        ]) {
            stats.capacity = Double(values.volumeTotalCapacity ?? 0)
            stats.free = Double(values.volumeAvailableCapacityForImportantUsage ?? 0)
        }
        return stats
    }

    // MARK: - GPU

    private func readGPU() -> GPUStats {
        var stats = GPUStats()
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator
        ) == KERN_SUCCESS else { return stats }
        defer { IOObjectRelease(iterator) }

        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            if let model = IORegistryEntryCreateCFProperty(
                service, "model" as CFString, kCFAllocatorDefault, 0
            )?.takeRetainedValue() as? String, !model.isEmpty {
                stats.name = model
            }
            guard let performance = IORegistryEntryCreateCFProperty(
                service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0
            )?.takeRetainedValue() as? [String: Any] else { continue }
            guard let utilization = performance["Device Utilization %"] as? NSNumber else {
                continue
            }
            stats.available = true
            stats.utilization = utilization.doubleValue
            stats.memoryInUse = (performance["In use system memory"] as? NSNumber)?.doubleValue ?? 0
            stats.memoryAllocated = (performance["Alloc system memory"] as? NSNumber)?.doubleValue ?? 0
            break
        }
        return stats
    }

    // MARK: - Battery

    private func readBattery(temperature: Double?) -> BatteryStats {
        var stats = BatteryStats()
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue()
        else { return stats }

        for index in 0..<CFArrayGetCount(list) {
            guard let raw = CFArrayGetValueAtIndex(list, index) else { continue }
            let source = unsafeBitCast(raw, to: CFTypeRef.self)
            guard let description = IOPSGetPowerSourceDescription(info, source)?
                .takeUnretainedValue() as? [String: Any] else { continue }
            guard (description["Is Present"] as? Bool) == true else { continue }
            stats.present = true
            let current = (description["Current Capacity"] as? NSNumber)?.doubleValue ?? 0
            let maximum = (description["Max Capacity"] as? NSNumber)?.doubleValue ?? 100
            stats.percent = maximum > 0 ? current / maximum * 100 : current
            stats.charging = (description["Is Charging"] as? Bool) ?? false
            stats.onAC = (description["Power Source State"] as? String) == "AC Power"
            stats.minutesRemaining = (description["Time to Empty"] as? NSNumber)?.intValue ?? 0
            if stats.charging {
                stats.minutesRemaining = (description["Time to Full Charge"] as? NSNumber)?.intValue ?? 0
            }
            if let temperature {
                stats.temperature = temperature
            }
            break
        }

        if stats.present {
            var iterator: io_iterator_t = 0
            if IOServiceGetMatchingServices(
                kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"), &iterator
            ) == KERN_SUCCESS {
                defer { IOObjectRelease(iterator) }
                while case let service = IOIteratorNext(iterator), service != 0 {
                    defer { IOObjectRelease(service) }
                    if let cycle = IORegistryEntryCreateCFProperty(
                        service, "CycleCount" as CFString, kCFAllocatorDefault, 0
                    )?.takeRetainedValue() as? NSNumber {
                        stats.cycleCount = cycle.intValue
                    }
                    let design = (IORegistryEntryCreateCFProperty(
                        service, "DesignCapacity" as CFString, kCFAllocatorDefault, 0
                    )?.takeRetainedValue() as? NSNumber)?.doubleValue ?? 0
                    let maxCapacity = (IORegistryEntryCreateCFProperty(
                        service, "AppleRawMaxCapacity" as CFString, kCFAllocatorDefault, 0
                    )?.takeRetainedValue() as? NSNumber)?.doubleValue ?? 0
                    let batteryData = (IORegistryEntryCreateCFProperty(
                        service, "BatteryData" as CFString, kCFAllocatorDefault, 0
                    )?.takeRetainedValue() as? [String: Any]) ?? [:]
                    let nestedDesign = (batteryData["DesignCapacity"] as? NSNumber)?.doubleValue ?? 0
                    let nestedFull = (batteryData["FullChargeCapacity"] as? NSNumber)?.doubleValue ?? 0
                    if nestedDesign > 0, nestedFull > 0 {
                        stats.health = min(100, nestedFull / nestedDesign * 100)
                    } else if design > 0, maxCapacity > 0 {
                        stats.health = min(100, maxCapacity / design * 100)
                    }
                    break
                }
            }
        }
        return stats
    }

    // MARK: - Processes

    private func readProcesses() -> [ProcessItem] {
        let now = Date()
        guard now.timeIntervalSince(lastProcessSample) >= 4 else { return cachedProcesses }
        lastProcessSample = now

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            "/bin/ps -axo pid=,pcpu=,rss=,comm= -r | /usr/bin/head -n 40"
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return cachedProcesses
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return cachedProcesses }

        let regex = try? NSRegularExpression(
            pattern: #"^\s*(\d+)\s+([\d.]+)\s+(\d+)\s+(.+)$"#, options: [.anchorsMatchLines]
        )
        var items: [ProcessItem] = []
        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        regex?.enumerateMatches(in: output, options: [], range: range) { match, _, _ in
            guard let match, match.numberOfRanges == 5 else { return }
            func group(_ index: Int) -> String {
                guard let range = Range(match.range(at: index), in: output) else { return "" }
                return String(output[range])
            }
            guard let pid = Int32(group(1)) else { return }
            if pid == ProcessInfo.processInfo.processIdentifier { return }
            let cpu = Double(group(2)) ?? 0
            let rss = Double(group(3)) ?? 0
            var name = group(4)
            if let slash = name.lastIndex(of: "/") {
                name = String(name[name.index(after: slash)...])
            }
            if items.count < 5 {
                items.append(ProcessItem(id: pid, name: name, cpu: cpu, memory: rss * 1024))
            }
        }
        if !items.isEmpty {
            cachedProcesses = items
        }
        return cachedProcesses
    }

    // MARK: - System helpers

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    private static func sysctlInt(_ name: String) -> Int? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return Int(value)
    }

    private static func sysctlUInt64(_ name: String) -> UInt64? {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }

}

private struct XSWUsage {
    var total: UInt64 = 0
    var available: UInt64 = 0
    var used: UInt64 = 0
    var pageSize: UInt32 = 0
    var encrypted: Int32 = 0
}
