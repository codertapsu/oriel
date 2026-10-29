import AppKit

/// Drawing the timeline: system colors throughout, so it follows light and dark appearance and the accent color.
extension TimelineView {
    private static let laneFill = NSColor.quaternarySystemFill
    private static let hintAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 11),
        .foregroundColor: NSColor.tertiaryLabelColor,
    ]

    /// Draws everything but the playhead.
    func drawTimeline() {
        drawGutterIcons()
        drawRuler()
        drawStrip()
        drawTrim()
        drawZoomLane()
        drawChapterLane()
    }

    // MARK: Gutter

    private func drawGutterIcons() {
        let icons = [
            ("film", stripRect, "Frames"),
            ("plus.magnifyingglass", zoomLaneRect, "Zoom"),
            ("bookmark", chapterLaneRect, "Chapters"),
        ]
        let configuration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.secondaryLabelColor]))
        for (symbol, lane, label) in icons {
            guard let image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)?.withSymbolConfiguration(configuration)
            else {
                continue
            }
            let size = image.size
            let target = CGRect(x: (Self.gutter - size.width) / 2, y: lane.midY - size.height / 2, width: size.width, height: size.height)
            image.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
    }

    // MARK: Ruler

    private func drawRuler() {
        let interval = mapping.tickInterval()
        let minor = interval / 5
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let first = (mapping.visibleStart / minor).rounded(.down)
        let last = (mapping.visibleEnd / minor).rounded(.up)
        guard last - first < 2000 else { return }
        NSColor.tertiaryLabelColor.setFill()
        var step = first
        while step <= last {
            let time = step * minor
            defer { step += 1 }
            guard time >= 0, time <= session.duration else { continue }
            let x = x(for: time).rounded() + 0.5
            let isMajor = abs((time / interval).rounded() * interval - time) < minor / 10
            CGRect(x: x - 0.5, y: isMajor ? 12 : 17, width: 1, height: isMajor ? 9 : 4).fill()
            if isMajor {
                let label = NSAttributedString(string: Self.label(for: time, interval: interval), attributes: attributes)
                // A label that would run off the right edge is left out rather than cut.
                if x + 3 + label.size().width <= bounds.width - 2 {
                    label.draw(at: CGPoint(x: x + 3, y: 2))
                }
            }
        }
    }

    private static func label(for time: Double, interval: Double) -> String {
        guard interval < 1 else { return Timecode.short(time) }
        let tenths = Int((time * 10).rounded()) % 10
        return "\(Timecode.short(time)).\(tenths)"
    }

    // MARK: Filmstrip

    private func drawStrip() {
        let strip = stripRect
        let movie = CGRect(x: x(for: 0), y: strip.minY, width: x(for: session.duration) - x(for: 0), height: strip.height)
        let visible = movie.intersection(strip)
        guard !visible.isEmpty, let context = NSGraphicsContext.current?.cgContext else { return }
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: visible, xRadius: 6, yRadius: 6).addClip()
        Self.laneFill.setFill()
        visible.fill()
        let aspect = thumbnails.pixelSize.height > 0 ? thumbnails.pixelSize.width / thumbnails.pixelSize.height : 16.0 / 9.0
        let tileWidth = strip.height * aspect
        let tileDuration = Double(tileWidth) / max(mapping.pointsPerSecond, 0.0001)
        let first = Int((mapping.visibleStart / tileDuration).rounded(.down))
        let last = Int((mapping.visibleEnd / tileDuration).rounded(.up))
        var wanted: [Double] = []
        if last - first < 400 {
            for index in first ..< max(last, first + 1) {
                let start = Double(index) * tileDuration
                guard start < session.duration else { break }
                let time = min(start + tileDuration / 2, max(session.duration - 0.05, 0))
                let tile = CGRect(x: x(for: start), y: strip.minY, width: tileWidth, height: strip.height)
                let image = thumbnails.image(near: time, tolerance: tileDuration)
                    ?? thumbnails.image(before: time, reach: tileDuration * 8)
                if thumbnails.image(near: time, tolerance: tileDuration) == nil {
                    wanted.append(time)
                }
                if let image {
                    context.saveGState()
                    // The context is flipped; images draw upright the other way up.
                    context.translateBy(x: tile.minX, y: tile.maxY)
                    context.scaleBy(x: 1, y: -1)
                    context.interpolationQuality = .high
                    context.draw(image, in: CGRect(origin: .zero, size: tile.size))
                    context.restoreGState()
                }
                NSColor.black.withAlphaComponent(0.25).setFill()
                CGRect(x: tile.maxX - 0.5, y: tile.minY, width: 1, height: tile.height).fill()
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        if !wanted.isEmpty {
            thumbnails.request(wanted, tolerance: tileDuration / 2)
        }
    }

    // MARK: Trim

    private func drawTrim() {
        let strip = stripRect
        let range = session.range
        let start = x(for: range.lowerBound)
        let end = x(for: range.upperBound)
        let movieStart = x(for: 0)
        let movieEnd = x(for: session.duration)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: strip.insetBy(dx: -Self.handleWidth - 2, dy: -3)).addClip()
        // What the export leaves out is dimmed.
        NSColor.black.withAlphaComponent(0.55).setFill()
        if start > movieStart {
            CGRect(x: movieStart, y: strip.minY, width: start - movieStart, height: strip.height).fill()
        }
        if end < movieEnd {
            CGRect(x: end, y: strip.minY, width: movieEnd - end, height: strip.height).fill()
        }
        let isTrimmed = session.edit.trimStart != nil || session.edit.trimEnd != nil
        let color = isTrimmed ? NSColor.systemYellow : NSColor.tertiaryLabelColor
        let outer = CGRect(
            x: start - Self.handleWidth,
            y: strip.minY - 2,
            width: end - start + 2 * Self.handleWidth,
            height: strip.height + 4
        )
        let inner = CGRect(x: start, y: strip.minY + 1, width: max(end - start, 0), height: strip.height - 2)
        let frame = NSBezierPath(roundedRect: outer, xRadius: 6, yRadius: 6)
        frame.append(NSBezierPath(rect: inner).reversed)
        color.setFill()
        frame.fill()
        // Chevrons on the handles.
        let chevron = isTrimmed ? NSColor.black.withAlphaComponent(0.7) : NSColor.windowBackgroundColor
        chevron.setStroke()
        for (x, direction) in [(start - Self.handleWidth / 2, CGFloat(-1)), (end + Self.handleWidth / 2, CGFloat(1))] {
            let path = NSBezierPath()
            path.lineWidth = 1.6
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: CGPoint(x: x - direction * 1.5, y: strip.midY - 5))
            path.line(to: CGPoint(x: x + direction * 1.5, y: strip.midY))
            path.line(to: CGPoint(x: x - direction * 1.5, y: strip.midY + 5))
            path.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    // MARK: Zoom lane

    private func drawZoomLane() {
        let lane = zoomLaneRect
        Self.laneFill.setFill()
        NSBezierPath(roundedRect: lane, xRadius: 5, yRadius: 5).fill()
        let segments = session.edit.zoomSegments
        guard !segments.isEmpty else {
            drawHint(
                session.clicks == nil ? "Double-click here, or press Z, to zoom in" : "Use Auto Zoom, or press Z, to zoom in",
                in: lane
            )
            return
        }
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: lane.insetBy(dx: -2, dy: 0)).addClip()
        let accent = NSColor.controlAccentColor
        for segment in segments {
            let frame = rect(for: segment)
            guard frame.maxX >= lane.minX - 4, frame.minX <= lane.maxX + 4 else { continue }
            let selected = session.selection == .zoom(segment.id)
            let shape = NSBezierPath(roundedRect: frame, xRadius: 4, yRadius: 4)
            accent.withAlphaComponent(selected ? 0.55 : 0.28).setFill()
            shape.fill()
            // The ramps, lighter, so the hold stands out.
            let ramp = CGFloat(segment.rampDuration * mapping.pointsPerSecond)
            if ramp > 3 {
                accent.withAlphaComponent(selected ? 0.35 : 0.18).setFill()
                CGRect(x: frame.minX, y: frame.minY, width: min(ramp, frame.width / 2), height: frame.height).fill()
                CGRect(x: frame.maxX - min(ramp, frame.width / 2), y: frame.minY, width: min(ramp, frame.width / 2), height: frame.height)
                    .fill()
            }
            accent.setStroke()
            shape.lineWidth = selected ? 2 : 1
            shape.stroke()
            if frame.width > 34 {
                let label = NSAttributedString(string: Self.scaleLabel(segment.scale), attributes: [
                    .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
                    .foregroundColor: selected ? NSColor.labelColor : NSColor.secondaryLabelColor,
                ])
                let size = label.size()
                label.draw(at: CGPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2))
            }
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    /// `2×`, `1.5×`.
    static func scaleLabel(_ scale: Double) -> String {
        let rounded = (scale * 10).rounded() / 10
        return rounded == rounded.rounded() ? "\(Int(rounded))×" : String(format: "%.1f×", rounded)
    }

    // MARK: Chapter lane

    private func drawChapterLane() {
        let lane = chapterLaneRect
        Self.laneFill.setFill()
        NSBezierPath(roundedRect: lane, xRadius: 5, yRadius: 5).fill()
        let chapters = session.edit.chapters
        guard !chapters.isEmpty else {
            drawHint("Press M to add a chapter at the playhead", in: lane)
            return
        }
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: lane.insetBy(dx: -6, dy: 0)).addClip()
        for (index, marker) in chapters.enumerated() {
            let x = x(for: marker.time).rounded()
            guard x >= lane.minX - 8, x <= lane.maxX + 8 else { continue }
            let selected = session.selection == .chapter(marker.id)
            let color = NSColor.systemOrange
            color.setFill()
            CGRect(x: x - 0.75, y: lane.minY + 2, width: 1.5, height: lane.height - 4).fill()
            let flag = NSBezierPath()
            flag.move(to: CGPoint(x: x, y: lane.minY + 2))
            flag.line(to: CGPoint(x: x + 8, y: lane.minY + 6))
            flag.line(to: CGPoint(x: x, y: lane.minY + 10))
            flag.close()
            flag.fill()
            let next = index + 1 < chapters.count ? self.x(for: chapters[index + 1].time) : lane.maxX
            let room = min(next, lane.maxX) - x - 16
            guard room > 24 else { continue }
            let title = ChapterList.title(marker.title, number: index + 1)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: selected ? .semibold : .regular),
                .foregroundColor: selected ? NSColor.labelColor : NSColor.secondaryLabelColor,
            ]
            let label = NSAttributedString(string: title, attributes: attributes)
            label.draw(
                with: CGRect(x: x + 11, y: lane.minY + 5, width: room, height: lane.height - 6),
                options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
            )
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawHint(_ text: String, in lane: CGRect) {
        let label = NSAttributedString(string: text, attributes: Self.hintAttributes)
        let size = label.size()
        label.draw(at: CGPoint(x: lane.minX + 10, y: lane.midY - size.height / 2))
    }
}
