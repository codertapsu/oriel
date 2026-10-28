import OrielCore

/// Routes CLI verbs to whoever answers them: the app itself, the feature hub, or a module.
@MainActor
final class IPCRouter {
    private let handlers: () -> [IPCCommandHandler]

    init(handlers: @escaping () -> [IPCCommandHandler]) {
        self.handlers = handlers
    }

    func handle(_ request: IPCRequest) async -> IPCResponse {
        #if !DEBUG
            // The plan's test hooks are compiled out of Release builds (PLAN §14.3).
            if request.verb.hasPrefix("debug."), request.verb != "debug.capabilities" {
                return .failure(request, "\(request.verb) exists only in Debug builds.", status: 64)
            }
        #endif
        guard let handler = handlers().first(where: { $0.verb == request.verb }) else {
            return .failure(request, "This version of Oriel does not know '\(request.verb)'. Is the CLI newer than the app?", status: 64)
        }
        return await handler.handle(request)
    }
}
