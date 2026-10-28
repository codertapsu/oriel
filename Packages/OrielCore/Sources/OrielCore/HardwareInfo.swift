import Darwin

/// What the running slice and the hardware are (PLAN §3.2).
public enum HardwareInfo {
    /// The slice this code was compiled for.
    public static var architecture: String {
        #if arch(arm64)
            "arm64"
        #else
            "x86_64"
        #endif
    }

    /// True when the x86_64 slice runs under Rosetta (`sysctl.proc_translated`).
    public static var isTranslated: Bool {
        sysctlFlag("sysctl.proc_translated")
    }

    /// True on Apple silicon, even when this process runs under Rosetta (`hw.optional.arm64`).
    public static var isAppleSiliconHardware: Bool {
        sysctlFlag("hw.optional.arm64")
    }

    private static func sysctlFlag(_ name: String) -> Bool {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname(name, &value, &size, nil, 0) == 0 && value == 1
    }
}
