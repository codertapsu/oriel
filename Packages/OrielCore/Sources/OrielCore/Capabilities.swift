/// What this Mac can do, computed once at launch by the app and shown in Settings → Diagnostics and by
/// `oriel debug capabilities --json` (PLAN §3.2).
public struct Capabilities: Codable, Sendable, Equatable {
    public var arch: String
    public var isRosetta: Bool
    public var isAppleSiliconHardware: Bool
    /// `available`, or `unavailable: <reason>`.
    public var appleIntelligence: String
    /// Apple Translation's state for the configured language pair, e.g. `installed en→ja`.
    public var translationPacks: String
    /// One flag per private symbol PrivateAPIs looked up.
    public var privateSymbols: [String: Bool]
    /// Permission name → `granted` / `denied` / `notDetermined`.
    public var permissions: [String: String]

    public init(
        arch: String = HardwareInfo.architecture,
        isRosetta: Bool = HardwareInfo.isTranslated,
        isAppleSiliconHardware: Bool = HardwareInfo.isAppleSiliconHardware,
        appleIntelligence: String = "unknown",
        translationPacks: String = "unknown",
        privateSymbols: [String: Bool] = [:],
        permissions: [String: String] = [:]
    ) {
        self.arch = arch
        self.isRosetta = isRosetta
        self.isAppleSiliconHardware = isAppleSiliconHardware
        self.appleIntelligence = appleIntelligence
        self.translationPacks = translationPacks
        self.privateSymbols = privateSymbols
        self.permissions = permissions
    }
}
