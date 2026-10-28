/// The private (or deprecated) C symbols Oriel resolves. Each one has a public fallback or a disabled-feature
/// path (PLAN §7.1.2), and its provenance is recorded in docs/provenance.md.
public enum PrivateSymbol: String, CaseIterable, Codable, Sendable {
    case axUIElementGetWindow = "_AXUIElementGetWindow"
    case axUIElementCreateWithRemoteToken = "_AXUIElementCreateWithRemoteToken"
    case slsMainConnectionID = "SLSMainConnectionID"
    case slsGetActiveSpace = "SLSGetActiveSpace"
    case slsCopyManagedDisplaySpaces = "SLSCopyManagedDisplaySpaces"
    case slsCopySpacesForWindows = "SLSCopySpacesForWindows"
    case slpsSetFrontProcessWithOptions = "_SLPSSetFrontProcessWithOptions"
    case slpsPostEventRecordTo = "SLPSPostEventRecordTo"
    case getProcessForPID = "GetProcessForPID"
    case cgsGetSymbolicHotKeyValue = "CGSGetSymbolicHotKeyValue"
    case cgsSetSymbolicHotKeyEnabled = "CGSSetSymbolicHotKeyEnabled"
    case cgsIsSymbolicHotKeyEnabled = "CGSIsSymbolicHotKeyEnabled"
}
