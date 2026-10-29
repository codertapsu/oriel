import AppKit

/// A live history graph drawn with Core Graphics: one or more series, newest at the right edge, filled areas under
/// lines, stacked or overlaid. Unknown values (NaN) leave a gap. The vertical scale is fixed (percentages) or follows
/// the largest value on screen, rounded to a readable step.
final class HistoryGraphView: NSView {
    struct Series {
        var values: [Double]
        var color: NSColor
        /// One colour per value instead of `color`, drawn as columns: memory pressure.
        var colors: [NSColor]?

        init(_ values: [Double], color: NSColor, colors: [NSColor]? = nil) {
            self.values = values
            self.color = color
            self.colors = colors
        }
    }

    /// Where a sample lands.
    private struct Geometry {
        let plot: CGRect
        let step: CGFloat
        let startX: CGFloat
        let top: Double

        func point(_ index: Int, _ value: Double) -> CGPoint {
            CGPoint(x: startX + CGFloat(index) * step, y: plot.minY + plot.height * CGFloat(min(1, max(0, value / top))))
        }
    }

    var series: [Series] = [] {
        didSet { needsDisplay = true }
    }

    /// How many samples span the width once the history is full.
    var capacity = 150 {
        didSet { needsDisplay = true }
    }

    /// A fixed top value (100 for percentages); nil scales to the data.
    var maximum: Double?
    /// Series drawn on top of one another (CPU system + user) rather than over one another.
    var isStacked = false
    var cornerRadius: CGFloat = 6

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func draw(_: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let frame = bounds.insetBy(dx: 0.5, dy: 0.5)
        let shape = CGPath(roundedRect: frame, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        context.addPath(shape)
        context.setFillColor(NSColor.textBackgroundColor.cgColor)
        context.fillPath()
        context.saveGState()
        context.addPath(shape)
        context.clip()
        drawGrid(in: frame, context: context)
        let count = series.map(\.values.count).max() ?? 0
        let plot = frame.insetBy(dx: 1, dy: 2)
        let step = plot.width / CGFloat(max(1, capacity - 1))
        let geometry = Geometry(plot: plot, step: step, startX: plot.maxX - CGFloat(max(0, count - 1)) * step, top: scaleTop())
        var baseline = [Double](repeating: 0, count: count)
        for item in series {
            let padded = item.values + [Double](repeating: .nan, count: max(0, count - item.values.count))
            let values = isStacked ? zip(padded, baseline).map { $0.isNaN ? .nan : $0 + $1 } : padded
            draw(values, below: isStacked ? baseline : nil, series: item, geometry: geometry, context: context)
            if isStacked {
                baseline = zip(baseline, padded).map { $1.isNaN ? $0 : $0 + $1 }
            }
        }
        context.restoreGState()
        context.addPath(shape)
        context.setStrokeColor(NSColor.separatorColor.cgColor)
        context.setLineWidth(1)
        context.strokePath()
    }

    /// The top of the scale: fixed, or the largest value shown rounded up to 1, 2 or 5 times a power of ten.
    func scaleTop() -> Double {
        if let maximum {
            return maximum
        }
        let count = series.map(\.values.count).max() ?? 0
        let peaks: [Double] = isStacked
            ? (0 ..< count).map { index in
                series.reduce(0) { $0 + (index < $1.values.count && !$1.values[index].isNaN ? $1.values[index] : 0) }
            }
            : series.flatMap(\.values).filter { !$0.isNaN }
        return Self.niceCeiling(peaks.max() ?? 0)
    }

    static func niceCeiling(_ value: Double) -> Double {
        guard value > 0, value.isFinite else { return 1 }
        let power = pow(10, floor(log10(value)))
        for step in [1.0, 2.0, 5.0] where value <= step * power {
            return step * power
        }
        return 10 * power
    }

    private func drawGrid(in frame: CGRect, context: CGContext) {
        context.setStrokeColor(NSColor.separatorColor.withAlphaComponent(0.35).cgColor)
        context.setLineWidth(1)
        for fraction in [0.25, 0.5, 0.75] {
            let y = (frame.minY + frame.height * fraction).rounded() + 0.5
            context.move(to: CGPoint(x: frame.minX, y: y))
            context.addLine(to: CGPoint(x: frame.maxX, y: y))
        }
        context.strokePath()
    }

    private func draw(_ values: [Double], below: [Double]?, series: Series, geometry: Geometry, context: CGContext) {
        guard !values.isEmpty, geometry.top > 0 else { return }
        for run in Self.runs(of: values) {
            if let colors = series.colors, colors.count == values.count {
                for index in run {
                    let top = geometry.point(index, values[index])
                    let column = CGRect(
                        x: top.x - geometry.step / 2,
                        y: geometry.plot.minY,
                        width: max(1, geometry.step),
                        height: top.y - geometry.plot.minY
                    )
                    context.setFillColor(colors[index].withAlphaComponent(0.75).cgColor)
                    context.fill(column)
                }
                continue
            }
            let area = CGMutablePath()
            area.move(to: geometry.point(run[0], below?[run[0]] ?? 0))
            for index in run {
                area.addLine(to: geometry.point(index, values[index]))
            }
            for index in run.reversed() {
                area.addLine(to: geometry.point(index, below?[index] ?? 0))
            }
            area.closeSubpath()
            context.addPath(area)
            context.setFillColor(series.color.withAlphaComponent(0.28).cgColor)
            context.fillPath()
            let line = CGMutablePath()
            line.move(to: geometry.point(run[0], values[run[0]]))
            for index in run.dropFirst() {
                line.addLine(to: geometry.point(index, values[index]))
            }
            context.addPath(line)
            context.setStrokeColor(series.color.cgColor)
            context.setLineWidth(1.5)
            context.setLineJoin(.round)
            context.strokePath()
        }
    }

    /// The stretches of known values, as index lists.
    static func runs(of values: [Double]) -> [[Int]] {
        var runs: [[Int]] = []
        var run: [Int] = []
        for index in values.indices {
            if values[index].isNaN {
                if !run.isEmpty {
                    runs.append(run)
                }
                run = []
            } else {
                run.append(index)
            }
        }
        if !run.isEmpty {
            runs.append(run)
        }
        return runs
    }
}
