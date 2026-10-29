import Darwin

/// Every network interface's 64-bit counters, from `sysctl(NET_RT_IFLIST2)`.
nonisolated enum NetworkInterfaces {
    static func counters() -> [InterfaceCounters] {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0
        guard sysctl(&mib, 6, nil, &length, nil, 0) == 0, length > 0 else { return [] }
        // Room for an interface that appears in between.
        length += 2048
        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, 6, &buffer, &length, nil, 0) == 0 else { return [] }
        var interfaces: [InterfaceCounters] = []
        buffer.withUnsafeBytes { raw in
            var offset = 0
            while offset + MemoryLayout<if_msghdr>.size <= length {
                let header = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                guard header.ifm_msglen > 0 else { break }
                if Int32(header.ifm_type) == RTM_IFINFO2, offset + MemoryLayout<if_msghdr2>.size <= length {
                    let message = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    interfaces.append(counters(message))
                }
                offset += Int(header.ifm_msglen)
            }
        }
        return interfaces
    }

    private static func counters(_ message: if_msghdr2) -> InterfaceCounters {
        var name = [CChar](repeating: 0, count: Int(IF_NAMESIZE) + 1)
        let named = if_indextoname(UInt32(message.ifm_index), &name) != nil
        let data = message.ifm_data
        return InterfaceCounters(
            name: named ? ByteText.cString(name) : "if\(message.ifm_index)",
            type: data.ifi_type,
            flags: UInt32(bitPattern: message.ifm_flags),
            bytes: TrafficBytes(received: data.ifi_ibytes, sent: data.ifi_obytes),
            packets: TrafficBytes(received: data.ifi_ipackets, sent: data.ifi_opackets)
        )
    }
}
