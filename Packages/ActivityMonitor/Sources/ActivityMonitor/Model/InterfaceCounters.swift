/// One network interface's 64-bit counters from `sysctl(NET_RT_IFLIST2)`. (`getifaddrs` gives 32-bit counters that
/// wrap every 4 GB.)
nonisolated struct InterfaceCounters: Sendable, Equatable {
    let name: String
    /// The `IFT_*` type.
    let type: UInt8
    let flags: UInt32
    let bytes: TrafficBytes
    let packets: TrafficBytes

    /// Whether its traffic is the Mac's own: Ethernet, Wi-Fi (Ethernet to the kernel) and cellular. Loopback never
    /// leaves the Mac, and tunnels (VPNs), bridges and 6to4 carry traffic that a physical interface counts again.
    var countsTowardTotals: Bool {
        let ether: UInt8 = 0x06
        let wireless: UInt8 = 0x47
        let cellular: UInt8 = 0xFF
        let loopbackFlag: UInt32 = 0x8
        return [ether, wireless, cellular].contains(type) && flags & loopbackFlag == 0
    }

    /// The Mac's totals: the counting interfaces' counters added up.
    static func totals(_ interfaces: [InterfaceCounters]) -> (bytes: TrafficBytes, packets: TrafficBytes) {
        interfaces.filter(\.countsTowardTotals).reduce((TrafficBytes.zero, TrafficBytes.zero)) { sum, interface in
            (sum.0 + interface.bytes, sum.1 + interface.packets)
        }
    }

    /// What the counting interfaces carried since `earlier`, interface by interface, so one that was reset or that came and
    /// went adds nothing instead of a jump.
    static func added(since earlier: [InterfaceCounters], now: [InterfaceCounters]) -> (bytes: TrafficBytes, packets: TrafficBytes) {
        let before = Dictionary(earlier.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        return now.filter(\.countsTowardTotals).reduce((TrafficBytes.zero, TrafficBytes.zero)) { sum, interface in
            guard let previous = before[interface.name] else { return sum }
            return (sum.0 + interface.bytes.added(since: previous.bytes), sum.1 + interface.packets.added(since: previous.packets))
        }
    }
}
