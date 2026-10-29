import AppKit

/// The Mac as a whole, under the list: the tab's numbers on either side of a live history graph, as in macOS's
/// Activity Monitor. The CPU tab adds a bar per core and, when the GPU reports it, its utilization.
final class SummaryView: NSView {
    static let height: CGFloat = 132

    private let left = StatGridView()
    private let right = StatGridView()
    private let graph = HistoryGraphView()
    private let graphTitle = NSTextField(labelWithString: "")
    private let cores = CoreStripView()
    private let coresTitle = NSTextField(labelWithString: "CORES")
    private let gpuGraph = HistoryGraphView()
    private let gpuTitle = NSTextField(labelWithString: "GPU")
    private lazy var coreColumn = column(coresTitle, cores)
    private lazy var gpuColumn = column(gpuTitle, gpuGraph)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        for title in [graphTitle, coresTitle, gpuTitle] {
            title.font = .systemFont(ofSize: 10, weight: .semibold)
            title.textColor = .secondaryLabelColor
            title.lineBreakMode = .byTruncatingTail
        }
        gpuGraph.maximum = 100
        gpuGraph.setContentHuggingPriority(.required, for: .horizontal)
        let graphColumn = column(graphTitle, graph)
        let stack = NSStackView(views: [left, graphColumn, coreColumn, gpuColumn, right])
        stack.orientation = .horizontal
        stack.alignment = .top
        stack.spacing = 20
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        stack.setHuggingPriority(.defaultHigh, for: .horizontal)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            graph.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            graph.heightAnchor.constraint(equalToConstant: 88),
            cores.heightAnchor.constraint(equalToConstant: 88),
            gpuGraph.widthAnchor.constraint(equalToConstant: 90),
            gpuGraph.heightAnchor.constraint(equalToConstant: 88),
            left.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
            right.widthAnchor.constraint(greaterThanOrEqualToConstant: 170),
        ])
        graph.setContentHuggingPriority(.defaultLow, for: .horizontal)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Summary")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(tab: ActivityTab, snapshot: ActivitySnapshot?) {
        let system = snapshot?.system ?? SystemMetrics()
        let history = snapshot?.history ?? .empty
        graph.capacity = history.capacity
        gpuGraph.capacity = history.capacity
        coreColumn.isHidden = tab != .cpu || system.cores.isEmpty
        gpuColumn.isHidden = tab != .cpu || system.gpus.isEmpty
        switch tab {
        case .cpu: showCPU(system, history)
        case .memory: showMemory(system, history)
        case .energy: showEnergy(system, history, processes: snapshot?.processes ?? [])
        case .disk: showDisk(system, history)
        case .network: showNetwork(system, history)
        }
        graph.setAccessibilityLabel(graphTitle.stringValue.capitalized + " history")
    }

    // MARK: Tabs

    private func showCPU(_ system: SystemMetrics, _ history: HistorySnapshot) {
        let cpu = system.cpu
        left.show([
            .init("System", ActivityFormat.percentWithSign(cpu.map { $0.system * 100 }), swatch: ActivityColors.system),
            .init("User", ActivityFormat.percentWithSign(cpu.map { $0.user * 100 }), swatch: ActivityColors.user),
            .init("Idle", ActivityFormat.percentWithSign(cpu.map { $0.idle * 100 })),
        ])
        graph.maximum = 100
        graph.isStacked = true
        graph.series = [
            .init(history.values(.cpuSystem), color: ActivityColors.system),
            .init(history.values(.cpuUser), color: ActivityColors.user),
        ]
        setTitle("CPU LOAD", scale: nil)
        cores.cores = system.cores
        let gpu = system.gpus.map(\.utilization).max()
        gpuTitle.stringValue = "GPU " + ActivityFormat.percentWithSign(gpu)
        gpuGraph.series = [.init(history.values(.gpu), color: ActivityColors.gpu)]
        gpuGraph.toolTip = system.gpus.map(\.name).joined(separator: ", ")
        right.show([
            .init("Processes", system.processCount.formatted()),
            .init("Your threads", system.ownThreadCount.formatted(), toolTip: "macOS counts other users' threads only for them."),
            .init("Load average", ActivityFormat.decimal(system.loadAverage)),
        ])
    }

    private func showMemory(_ system: SystemMetrics, _ history: HistorySnapshot) {
        let memory = system.memory
        left.show([
            .init("Physical Memory", ActivityFormat.memory(memory?.physical)),
            .init("Memory Used", ActivityFormat.memory(memory?.used)),
            .init("Cached Files", ActivityFormat.memory(memory?.cached)),
            .init("Swap Used", ActivityFormat.memory(memory?.swapUsed)),
        ])
        graph.maximum = 100
        graph.isStacked = false
        let levels = history.pressureLevels.map(ActivityColors.pressure)
        let pressure = history.values(.memoryPressure)
        graph.series = [.init(pressure, color: .systemGreen, colors: levels.count == pressure.count ? levels : nil)]
        setTitle("MEMORY PRESSURE", scale: system.pressure?.level.title)
        right.show([
            .init("App Memory", ActivityFormat.memory(memory?.app)),
            .init("Wired Memory", ActivityFormat.memory(memory?.wired)),
            .init("Compressed", ActivityFormat.memory(memory?.compressed)),
        ])
    }

    private func showEnergy(_ system: SystemMetrics, _ history: HistorySnapshot, processes: [ProcessMetrics]) {
        let awake = processes.filter(\.preventsSleep).count
        left.show([
            .init(
                "Your processes",
                ActivityFormat.power(system.ownPower),
                swatch: ActivityColors.power,
                toolTip: "macOS measures power only for your own processes."
            ),
            .init("Keeping the Mac awake", awake.formatted()),
            .init("Temperature", system.thermal.title),
        ])
        graph.maximum = nil
        graph.isStacked = false
        graph.series = [.init(history.values(.power), color: ActivityColors.power)]
        setTitle("POWER, YOUR PROCESSES", scale: ActivityFormat.power(graph.scaleTop()))
        guard let battery = system.battery else {
            right.show([.init("Battery", "None"), .init("Power", "Power adapter")])
            return
        }
        let estimating = battery.onBattery || battery.isCharging ? "Estimating…" : ActivityFormat.dash
        right.show([
            .init("Battery", "\(battery.percent) %"),
            .init("State", battery.state),
            .init(battery.isCharging ? "Until full" : "Time left", battery.minutesRemaining.map(ActivityFormat.minutes) ?? estimating),
        ])
    }

    private func showDisk(_ system: SystemMetrics, _ history: HistorySnapshot) {
        let disk = system.disk
        left.show([
            .init("Reads in", ActivityFormat.count(disk?.totals.reads)),
            .init("Writes out", ActivityFormat.count(disk?.totals.writes)),
            .init("Reads in/sec", ActivityFormat.perSecond(disk?.readsPerSecond)),
            .init("Writes out/sec", ActivityFormat.perSecond(disk?.writesPerSecond)),
        ])
        graph.maximum = nil
        graph.isStacked = false
        graph.series = [
            .init(history.values(.diskRead), color: ActivityColors.read),
            .init(history.values(.diskWritten), color: ActivityColors.written),
        ]
        setTitle("DISK", scale: ActivityFormat.rate(graph.scaleTop()))
        right.show([
            .init("Data read", ActivityFormat.bytes(disk?.totals.bytesRead)),
            .init("Data written", ActivityFormat.bytes(disk?.totals.bytesWritten)),
            .init("Data read/sec", ActivityFormat.rate(disk?.readBytesPerSecond), swatch: ActivityColors.read),
            .init("Data written/sec", ActivityFormat.rate(disk?.writtenBytesPerSecond), swatch: ActivityColors.written),
        ])
    }

    private func showNetwork(_ system: SystemMetrics, _ history: HistorySnapshot) {
        let network = system.network
        left.show([
            .init("Packets in", ActivityFormat.count(network?.packets.received)),
            .init("Packets out", ActivityFormat.count(network?.packets.sent)),
            .init("Packets in/sec", ActivityFormat.perSecond(network?.packetsPerSecond.received)),
            .init("Packets out/sec", ActivityFormat.perSecond(network?.packetsPerSecond.sent)),
        ])
        graph.maximum = nil
        graph.isStacked = false
        graph.series = [
            .init(history.values(.networkReceived), color: ActivityColors.received),
            .init(history.values(.networkSent), color: ActivityColors.sent),
        ]
        setTitle("NETWORK", scale: ActivityFormat.rate(graph.scaleTop()))
        right.show([
            .init("Data received", ActivityFormat.bytes(network?.bytes.received)),
            .init("Data sent", ActivityFormat.bytes(network?.bytes.sent)),
            .init("Data received/sec", ActivityFormat.rate(network?.bytesPerSecond.received), swatch: ActivityColors.received),
            .init("Data sent/sec", ActivityFormat.rate(network?.bytesPerSecond.sent), swatch: ActivityColors.sent),
        ])
    }

    /// "DISK  up to 20 MB/s": the measure in small capitals, the scale or state in plain words after it.
    private func setTitle(_ title: String, scale: String?) {
        let text = NSMutableAttributedString(
            string: title,
            attributes: [.font: NSFont.systemFont(ofSize: 10, weight: .semibold), .foregroundColor: NSColor.secondaryLabelColor]
        )
        if let scale {
            let detail = title == "MEMORY PRESSURE" ? "  \(scale)" : "  up to \(scale)"
            text.append(NSAttributedString(
                string: detail,
                attributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.tertiaryLabelColor]
            ))
        }
        graphTitle.attributedStringValue = text
    }

    private func column(_ title: NSTextField, _ content: NSView) -> NSStackView {
        let stack = NSStackView(views: [title, content])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        return stack
    }
}
