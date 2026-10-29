import Foundation
import IOKit

/// The disks, graphics processors and processor cores in the I/O Registry. Each reads one property per entry rather
/// than every property, which keeps a sample's registry work near a quarter of a millisecond.
nonisolated enum IORegistryReader {
    /// Each block storage driver's counters, by registry entry ID. Disk images are left out: their reads and writes
    /// reach the physical disk too, and would be counted twice.
    static func disks() -> [UInt64: DiskCounters] {
        var disks: [UInt64: DiskCounters] = [:]
        forEach("IOBlockStorageDriver") { entry in
            guard !isDiskImage(entry),
                  let statistics = property("Statistics", of: entry) as? [String: Any],
                  let counters = DiskCounters(statistics: statistics)
            else { return }
            var id: UInt64 = 0
            IORegistryEntryGetRegistryEntryID(entry, &id)
            disks[id] = counters
        }
        return disks
    }

    /// Each graphics processor that reports its utilization.
    static func gpus() -> [GPUReading] {
        var gpus: [GPUReading] = []
        forEach("IOAccelerator") { entry in
            guard let statistics = property("PerformanceStatistics", of: entry) as? [String: Any] else { return }
            let name = property("model", of: entry).flatMap(text) ?? "GPU"
            if let gpu = GPUReading(name: name, performanceStatistics: statistics) {
                gpus.append(gpu)
            }
        }
        return gpus
    }

    /// The core type of each logical CPU, from the device tree's `cluster-type` (Apple silicon); nil elsewhere.
    static func coreTypes() -> [CoreType]? {
        let root = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/cpus")
        guard root != 0 else { return nil }
        defer { IOObjectRelease(root) }
        var iterator: io_iterator_t = 0
        guard IORegistryEntryGetChildIterator(root, kIODeviceTreePlane, &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var types: [Int: CoreType] = [:]
        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            guard let cluster = property("cluster-type", of: entry).flatMap(text),
                  let id = (property("logical-cpu-id", of: entry) as? NSNumber)?.intValue
            else { continue }
            types[id] = CoreType(clusterType: cluster)
        }
        guard !types.isEmpty else { return nil }
        return (0 ..< types.count).map { types[$0] ?? .standard }
    }

    private static func forEach(_ className: String, _ body: (io_registry_entry_t) -> Void) {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(className), &iterator) == KERN_SUCCESS else { return }
        defer { IOObjectRelease(iterator) }
        while case let entry = IOIteratorNext(iterator), entry != 0 {
            body(entry)
            IOObjectRelease(entry)
        }
    }

    private static func property(_ key: String, of entry: io_registry_entry_t) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }

    /// Device-tree strings are NUL-terminated data; others are strings.
    private static func text(_ value: Any) -> String? {
        if let string = value as? String {
            return string
        }
        guard let data = value as? Data else { return nil }
        return ByteText.cString(data)
    }

    private static func isDiskImage(_ driver: io_registry_entry_t) -> Bool {
        var parent: io_registry_entry_t = 0
        guard IORegistryEntryGetParentEntry(driver, kIOServicePlane, &parent) == KERN_SUCCESS else { return false }
        defer { IOObjectRelease(parent) }
        var name = [CChar](repeating: 0, count: 128)
        IOObjectGetClass(parent, &name)
        return ByteText.cString(name).contains("DiskImage")
    }
}
