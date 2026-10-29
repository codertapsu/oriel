import OrielCore

/// `oriel top [--sort cpu|memory|disk|network] [--limit <n>] [--json]`: a snapshot of the busiest processes from two
/// samples a second apart, taken by a sampler of its own, so it works whether or not the window is open. It reads
/// other users' processes with `ps`, and per-process traffic with nettop only when sorting by network.
enum TopCommand {
    static let verb = "top"
    static let usage = "top [--sort cpu|memory|disk|network] [--limit <n>] [--json]"

    static func handler() -> IPCCommandHandler {
        IPCCommandHandler(verb: verb, usage: usage) { request in
            await run(request)
        }
    }

    static func run(_ request: IPCRequest) async -> IPCResponse {
        let sort: TopSort
        if let name = request.options["sort"] {
            guard let chosen = TopSort(rawValue: name.lowercased()) else {
                return .failure(request, "--sort must be cpu, memory, disk or network.", status: 64)
            }
            sort = chosen
        } else {
            sort = .cpu
        }
        var limit = TopReport.defaultLimit
        if let text = request.options["limit"] {
            guard let value = Int(text), TopReport.limits.contains(value) else {
                return .failure(request, "--limit must be a whole number from 1 to \(TopReport.limits.upperBound).", status: 64)
            }
            limit = value
        }
        var sources: SampleSources = [.otherUsers, .devices]
        if sort == .network {
            sources.insert(.network)
        }
        let sampler = ActivitySampler(historyCapacity: 2)
        let sampleRequest = SampleRequest(sources: sources, apps: RunningApps.catalog())
        _ = await sampler.sample(sampleRequest)
        // A single one-second wait between the two samples, not a loop.
        try? await Task.sleep(for: .seconds(1))
        guard !Task.isCancelled else { return .failure(request, "Cancelled.") }
        let snapshot = await sampler.sample(sampleRequest)
        let report = TopReport(
            processes: snapshot.processes,
            system: snapshot.system,
            sort: sort,
            limit: limit,
            seconds: snapshot.interval ?? 1
        )
        guard request.flag("json") else {
            return .ok(request, report.text)
        }
        do {
            return try .ok(request, report.json())
        } catch {
            return .failure(request, error.localizedDescription)
        }
    }
}
