import Darwin

/// A process's open files and sockets (`PROC_PIDLISTFDS`, then `proc_pidfdinfo` for each). macOS answers for the
/// user's own processes only; for anyone else's the list is nil.
nonisolated enum OpenFileReader {
    /// At most `limit` descriptors, in descriptor order.
    static func openFiles(of pid: Int32, limit: Int = 400) -> [OpenFile]? {
        let needed = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard needed > 0 else { return nil }
        let stride = MemoryLayout<proc_fdinfo>.stride
        var descriptors = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(needed) / stride + 16)
        let used = descriptors.withUnsafeMutableBytes { proc_pidinfo(pid, PROC_PIDLISTFDS, 0, $0.baseAddress, Int32($0.count)) }
        guard used > 0 else { return nil }
        return descriptors.prefix(Int(used) / stride).prefix(limit).map { describe($0, of: pid) }
    }

    private static func describe(_ descriptor: proc_fdinfo, of pid: Int32) -> OpenFile {
        let fd = descriptor.proc_fd
        switch Int32(descriptor.proc_fdtype) {
        case PROX_FDTYPE_VNODE:
            var info = vnode_fdinfowithpath()
            let size = Int32(MemoryLayout<vnode_fdinfowithpath>.size)
            guard proc_pidfdinfo(pid, fd, PROC_PIDFDVNODEPATHINFO, &info, size) == size else {
                return OpenFile(descriptor: fd, kind: .file, detail: "File", state: nil)
            }
            let path = ByteText.cString(of: info.pvip.vip_path)
            let isDirectory = info.pvip.vip_vi.vi_stat.vst_mode & S_IFMT == S_IFDIR
            return OpenFile(descriptor: fd, kind: isDirectory ? .directory : .file, detail: path.isEmpty ? "File" : path, state: nil)
        case PROX_FDTYPE_SOCKET:
            return socket(fd, of: pid)
        case PROX_FDTYPE_PIPE:
            return OpenFile(descriptor: fd, kind: .pipe, detail: "Pipe", state: nil)
        case PROX_FDTYPE_KQUEUE:
            return OpenFile(descriptor: fd, kind: .other, detail: "Event queue", state: nil)
        default:
            return OpenFile(descriptor: fd, kind: .other, detail: "Other", state: nil)
        }
    }

    private static func socket(_ fd: Int32, of pid: Int32) -> OpenFile {
        var info = socket_fdinfo()
        let size = Int32(MemoryLayout<socket_fdinfo>.size)
        guard proc_pidfdinfo(pid, fd, PROC_PIDFDSOCKETINFO, &info, size) == size else {
            return OpenFile(descriptor: fd, kind: .other, detail: "Socket", state: nil)
        }
        let socket = info.psi
        switch Int(socket.soi_kind) {
        case SOCKINFO_TCP:
            let tcp = socket.soi_proto.pri_tcp
            let ends = endpoints(tcp.tcpsi_ini)
            return OpenFile(descriptor: fd, kind: .tcp, detail: ends, state: OpenFile.tcpState(tcp.tcpsi_state))
        case SOCKINFO_IN:
            let isUDP = socket.soi_protocol == IPPROTO_UDP
            return OpenFile(descriptor: fd, kind: isUDP ? .udp : .other, detail: endpoints(socket.soi_proto.pri_in), state: nil)
        case SOCKINFO_UN:
            let address = socket.soi_proto.pri_un.unsi_addr.ua_sun
            let path = ByteText.cString(of: address.sun_path)
            return OpenFile(descriptor: fd, kind: .unixSocket, detail: path.isEmpty ? "Unix socket" : path, state: nil)
        default:
            return OpenFile(descriptor: fd, kind: .other, detail: "Socket", state: nil)
        }
    }

    /// "10.0.0.2:52167 → 17.57.145.54:443", or "*:5353" for a socket that is not connected.
    private static func endpoints(_ info: in_sockinfo) -> String {
        let isIPv4 = info.insi_vflag & UInt8(INI_IPV4) != 0
        let local = endpoint(ipv4: info.insi_laddr.ina_46.i46a_addr4, ipv6: info.insi_laddr.ina_6, port: info.insi_lport, isIPv4: isIPv4)
        guard info.insi_fport != 0 else { return local }
        let remote = endpoint(ipv4: info.insi_faddr.ina_46.i46a_addr4, ipv6: info.insi_faddr.ina_6, port: info.insi_fport, isIPv4: isIPv4)
        return local + " → " + remote
    }

    /// The port is in network byte order in the low 16 bits.
    private static func endpoint(ipv4: in_addr, ipv6: in6_addr, port: Int32, isIPv4: Bool) -> String {
        let number = UInt16(bigEndian: UInt16(truncatingIfNeeded: port))
        var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        var text: String
        if isIPv4 {
            var address = ipv4
            text = inet_ntop(AF_INET, &address, &buffer, socklen_t(buffer.count)) != nil ? string(buffer) : "?"
            text = text == "0.0.0.0" ? "*" : text
        } else {
            var address = ipv6
            text = inet_ntop(AF_INET6, &address, &buffer, socklen_t(buffer.count)) != nil ? string(buffer) : "?"
            text = text == "::" ? "*" : "[\(text)]"
        }
        return number == 0 ? text : "\(text):\(number)"
    }

    private static func string(_ buffer: [CChar]) -> String {
        ByteText.cString(buffer)
    }
}
