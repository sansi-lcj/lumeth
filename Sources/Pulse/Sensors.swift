import Foundation
import IOKit

/// Reads the same unprivileged temperature events iStat Menus uses through
/// IOHIDEventSystemClient. AppleSMC is only needed for fan control, which
/// requires a privileged helper.
final class HIDSensorReader {
    private typealias ClientCreate = @convention(c) (CFAllocator?) -> OpaquePointer?
    private typealias SetMatching = @convention(c) (OpaquePointer?, CFDictionary?) -> Void
    private typealias CopyServices = @convention(c) (OpaquePointer?) -> OpaquePointer?
    private typealias CopyProperty = @convention(c) (OpaquePointer?, CFString) -> OpaquePointer?
    private typealias CopyEvent = @convention(c) (OpaquePointer?, Int64, Int32, Int64) -> OpaquePointer?
    private typealias GetFloat = @convention(c) (OpaquePointer?, Int32) -> Double

    private var client: OpaquePointer?
    private var services: CFArray?
    private var entries: [(service: OpaquePointer, name: String)] = []
    private var copyEvent: CopyEvent?
    private var getFloat: GetFloat?
    private var available = false

    private static let temperatureEventType: Int64 = 15
    private static let temperatureField = Int32(15 << 16)

    init() {
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW) else {
            return
        }
        func symbol<T>(_ name: String, as type: T.Type) -> T? {
            guard let pointer = dlsym(handle, name) else { return nil }
            return unsafeBitCast(pointer, to: T.self)
        }
        guard
            let create = symbol("IOHIDEventSystemClientCreate", as: ClientCreate.self),
            let setMatching = symbol("IOHIDEventSystemClientSetMatching", as: SetMatching.self),
            let copyServices = symbol("IOHIDEventSystemClientCopyServices", as: CopyServices.self),
            let copyProperty = symbol("IOHIDServiceClientCopyProperty", as: CopyProperty.self),
            let copyEvent = symbol("IOHIDServiceClientCopyEvent", as: CopyEvent.self),
            let getFloat = symbol("IOHIDEventGetFloatValue", as: GetFloat.self)
        else {
            return
        }

        self.copyEvent = copyEvent
        self.getFloat = getFloat
        guard let client = create(kCFAllocatorDefault) else { return }
        self.client = client
        setMatching(client, nil)
        guard let rawServices = copyServices(client) else { return }
        let array = Unmanaged<CFArray>.fromOpaque(UnsafeRawPointer(rawServices)).takeRetainedValue()
        services = array

        for index in 0..<CFArrayGetCount(array) {
            guard let raw = CFArrayGetValueAtIndex(array, index) else { continue }
            let service = OpaquePointer(raw)
            var name = ""
            if let property = copyProperty(service, "Product" as CFString) {
                let value = Unmanaged<CFTypeRef>.fromOpaque(UnsafeRawPointer(property)).takeRetainedValue()
                if CFGetTypeID(value) == CFStringGetTypeID() {
                    name = (value as? String) ?? ""
                }
            }
            if Self.isRelevant(name) {
                entries.append((service, name))
            }
        }
        available = true
    }

    func read() -> [SensorReading] {
        guard available, let copyEvent, let getFloat else { return [] }
        var byName: [String: Double] = [:]

        for entry in entries {
            guard let event = copyEvent(entry.service, Self.temperatureEventType, 0, 0) else {
                continue
            }
            let value = getFloat(event, Self.temperatureField)
            Unmanaged<CFTypeRef>.fromOpaque(UnsafeRawPointer(event)).release()
            guard value.isFinite, value > 0, value < 130 else { continue }
            if let existing = byName[entry.name] {
                byName[entry.name] = max(existing, value)
            } else {
                byName[entry.name] = value
            }
        }

        return byName.map { name, value in
            SensorReading(
                id: name,
                name: Self.displayName(for: name),
                value: value,
                unit: "°C",
                category: Self.category(for: name)
            )
        }
        .sorted {
            let lhs = SensorCategory.allCases.firstIndex(of: $0.category) ?? 99
            let rhs = SensorCategory.allCases.firstIndex(of: $1.category) ?? 99
            if lhs == rhs { return $0.name < $1.name }
            return lhs < rhs
        }
    }

    private static func category(for raw: String) -> SensorCategory {
        let name = raw.lowercased()
        if name.contains("tdie") || name.contains("cpu") || name.contains("soc") {
            return .cpu
        }
        if name.contains("gpu") {
            return .gpu
        }
        if name.contains("nand") || name.contains("ssd") || name.contains("storage") {
            return .storage
        }
        if name.contains("battery") || name.contains("gas gauge") {
            return .battery
        }
        if name.contains("ambient") || name.contains("als-temp") {
            return .ambient
        }
        if name.contains("mem") {
            return .memory
        }
        if name.contains("tdev") || name.contains("pmu") || name.contains("board") {
            return .board
        }
        return .other
    }

    private static func isRelevant(_ raw: String) -> Bool {
        let name = raw.lowercased()
        return name.contains("temp") || name.contains("tdie") || name.contains("tdev")
            || name.contains("gas gauge") || name.contains("nand")
            || name.contains("ambient") || name.contains("als-temp")
            || name == "pmu tcal"
    }

    private static func displayName(for raw: String) -> String {
        if raw.hasPrefix("PMU tdie") {
            return L("处理器核心") + " " + raw.replacingOccurrences(of: "PMU tdie", with: "")
        }
        if raw.hasPrefix("PMU tdev") {
            return L("主板传感器") + " " + raw.replacingOccurrences(of: "PMU tdev", with: "")
        }
        if raw == "gas gauge battery" { return L("电池") }
        if raw == "NAND CH0 temp" { return L("SSD 闪存") }
        if raw == "als-temp" { return L("环境光") }
        if raw == "PMU tcal" { return L("温标校准") }
        return raw.replacingOccurrences(of: "PMU ", with: "")
    }
}

// MARK: - AppleSMC (optional, works only with elevated privileges)

private struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

private struct SMCParamStruct {
    var key: UInt32 = 0
    var version = SMCVersion()
    var pLimit = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
        (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
         0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}

final class SMCReader {
    private var connection: io_connect_t = 0
    private var opened = false

    init() {
        guard MemoryLayout<SMCParamStruct>.size == 80 else { return }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }
        opened = IOServiceOpen(service, mach_task_self_, 0, &connection) == KERN_SUCCESS
    }

    deinit {
        if opened { IOServiceClose(connection) }
    }

    func fanRPM() -> Double? {
        guard let value = readKey("F0Ac") else { return nil }
        return value
    }

    private func readKey(_ key: String) -> Double? {
        guard opened else { return nil }
        var input = SMCParamStruct()
        var output = SMCParamStruct()
        var outputSize = MemoryLayout<SMCParamStruct>.size
        input.key = Self.fourCC(key)
        input.data8 = 9
        var result = IOConnectCallStructMethod(
            connection, 2, &input, MemoryLayout<SMCParamStruct>.size, &output, &outputSize
        )
        guard result == KERN_SUCCESS, output.result == 0 else { return nil }
        let size = output.keyInfo.dataSize
        guard size == 4 else { return nil }

        input = SMCParamStruct()
        output = SMCParamStruct()
        input.key = Self.fourCC(key)
        input.keyInfo.dataSize = size
        input.data8 = 5
        outputSize = MemoryLayout<SMCParamStruct>.size
        result = IOConnectCallStructMethod(
            connection, 2, &input, MemoryLayout<SMCParamStruct>.size, &output, &outputSize
        )
        guard result == KERN_SUCCESS, output.result == 0 else { return nil }
        let bits = withUnsafeBytes(of: output.bytes) { $0.load(as: UInt32.self) }
        return Double(Float(bitPattern: bits.byteSwapped))
    }

    private static func fourCC(_ key: String) -> UInt32 {
        let chars = Array(key.utf8)
        guard chars.count == 4 else { return 0 }
        return (UInt32(chars[0]) << 24) | (UInt32(chars[1]) << 16)
            | (UInt32(chars[2]) << 8) | UInt32(chars[3])
    }
}
