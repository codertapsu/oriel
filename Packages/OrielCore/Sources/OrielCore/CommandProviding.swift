/// A feature that offers commands (PLAN §6.5): a coordinator's capture or translation modes, or a tool's windows.
/// `commands` is read again whenever the app needs it, so a title may follow the feature's state.
@MainActor
public protocol CommandProviding: AnyObject {
    var commands: [ToolCommand] { get }
}
