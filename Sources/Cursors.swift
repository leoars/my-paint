import AppKit

/// Pointer shown over the image for each tool. The drawings are original line art.
enum ToolCursor {
    private static var cache: [ToolKind: NSCursor] = [:]

    static func cursor(for kind: ToolKind, size: Int, zoom: CGFloat, brush: BrushKind = .brush) -> NSCursor {
        if kind == .eraser { return eraser(size: size, zoom: zoom) }
        if kind == .brush { return self.brush(brush, size: size, zoom: zoom) }
        // The Text tool shows the text beam, as in Paint.
        if kind == .text { return .iBeam }
        if let cursor = cache[kind] { return cursor }
        let cursor = make(kind)
        cache[kind] = cursor
        return cursor
    }

    /// The eraser shows its real footprint at the current zoom.
    private static func eraser(size: Int, zoom: CGFloat) -> NSCursor {
        let side = min(128, max(3, (CGFloat(size) * zoom).rounded()))
        let image = NSImage(size: NSSize(width: side, height: side), flipped: true) { rect in
            NSColor.white.setFill()
            rect.fill()
            NSColor.black.setStroke()
            let border = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
            border.lineWidth = 1
            border.stroke()
            return true
        }
        // The pointer pixel sits where Bitmap.square puts it inside the square.
        let offset = min(side - 1, (CGFloat(size / 2) + 0.5) * zoom)
        return NSCursor(image: image, hotSpot: NSPoint(x: offset, y: offset))
    }

    private static func make(_ kind: ToolKind) -> NSCursor {
        let hotSpot: NSPoint
        let drawing: () -> Void
        switch kind {
        case .pencil:
            hotSpot = NSPoint(x: 1, y: 14)
            drawing = {
                outlined(width: 3) { path in path.move(to: NSPoint(x: 4, y: 11)); path.line(to: NSPoint(x: 13, y: 2)) }
                let tip = NSBezierPath()
                tip.move(to: NSPoint(x: 1, y: 14))
                tip.line(to: NSPoint(x: 2.5, y: 9.5))
                tip.line(to: NSPoint(x: 5.5, y: 12.5))
                tip.close()
                NSColor.white.setStroke(); tip.lineWidth = 2; tip.stroke()
                NSColor.black.setFill(); tip.fill()
            }
        case .fill:
            hotSpot = NSPoint(x: 2, y: 14)
            drawing = {
                outlined(width: 1.5) { path in
                    path.move(to: NSPoint(x: 9, y: 2))
                    path.line(to: NSPoint(x: 15, y: 8))
                    path.line(to: NSPoint(x: 9, y: 14))
                    path.line(to: NSPoint(x: 3, y: 8))
                    path.close()
                }
                outlined(width: 2) { path in path.move(to: NSPoint(x: 3, y: 8)); path.line(to: NSPoint(x: 2, y: 13.5)) }
            }
        case .colorPicker:
            hotSpot = NSPoint(x: 1, y: 14)
            drawing = {
                outlined(width: 2) { path in path.move(to: NSPoint(x: 1.5, y: 13.5)); path.line(to: NSPoint(x: 10, y: 5)) }
                let bulb = NSBezierPath(ovalIn: NSRect(x: 9, y: 1, width: 6, height: 6))
                NSColor.white.setStroke(); bulb.lineWidth = 2; bulb.stroke()
                NSColor.black.setFill(); bulb.fill()
            }
        case .select, .shape, .brush:
            // A thin cross, as Paint shows while selecting and drawing shapes.
            hotSpot = NSPoint(x: 8, y: 8)
            drawing = {
                outlined(width: 1) { path in
                    path.move(to: NSPoint(x: 8, y: 1)); path.line(to: NSPoint(x: 8, y: 15))
                    path.move(to: NSPoint(x: 1, y: 8)); path.line(to: NSPoint(x: 15, y: 8))
                }
            }
        case .magnifier, .eraser, .text:
            hotSpot = NSPoint(x: 6, y: 6)
            drawing = {
                outlined(width: 1.5) { path in path.appendOval(in: NSRect(x: 1.5, y: 1.5, width: 9, height: 9)) }
                outlined(width: 2.5) { path in path.move(to: NSPoint(x: 9.5, y: 9.5)); path.line(to: NSPoint(x: 14.5, y: 14.5)) }
            }
        }
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: true) { _ in drawing(); return true }
        return NSCursor(image: image, hotSpot: hotSpot)
    }

    /// Four arrows, shown over a selection that can be dragged.
    static let move: NSCursor = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            outlined(width: 1.5) { path in
                path.move(to: NSPoint(x: 9, y: 2)); path.line(to: NSPoint(x: 9, y: 16))
                path.move(to: NSPoint(x: 2, y: 9)); path.line(to: NSPoint(x: 16, y: 9))
                for (tip, a, b) in [((9.0, 1.5), (6.5, 4.5), (11.5, 4.5)), ((9.0, 16.5), (6.5, 13.5), (11.5, 13.5)),
                                    ((1.5, 9.0), (4.5, 6.5), (4.5, 11.5)), ((16.5, 9.0), (13.5, 6.5), (13.5, 11.5))] {
                    path.move(to: NSPoint(x: a.0, y: a.1)); path.line(to: NSPoint(x: tip.0, y: tip.1)); path.line(to: NSPoint(x: b.0, y: b.1))
                }
            }
            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: 9, y: 9))
    }()

    /// Double arrow from the top-left to the bottom-right corner (↖↘). macOS 12 has no public
    /// diagonal resize cursor, so both diagonals are drawn here in the style of the system's.
    static let resizeDiagonalDown = diagonal(descending: true)
    /// Double arrow from the bottom-left to the top-right corner (↗↙).
    static let resizeDiagonalUp = diagonal(descending: false)

    /// The cursor over one of the eight handles of a selection, a shape or a text box.
    static func cursor(for handle: SelectionHandle) -> NSCursor {
        switch handle {
        case .top, .bottom: return .resizeUpDown
        case .left, .right: return .resizeLeftRight
        case .topLeft, .bottomRight: return resizeDiagonalDown
        case .topRight, .bottomLeft: return resizeDiagonalUp
        }
    }

    /// The cursors over the image's resize handles, in `CanvasView.handleRects` order:
    /// right, bottom and the bottom-right corner (the only corner, as in Paint).
    static let canvasHandles: [NSCursor] = [.resizeLeftRight, .resizeUpDown, resizeDiagonalDown]

    private static func diagonal(descending: Bool) -> NSCursor {
        let side = RibbonTheme.diagonalCursorSize
        let image = NSImage(size: NSSize(width: side, height: side), flipped: true) { _ in
            // A horizontal double arrow around the origin, turned 45° onto the diagonal.
            let tip = side / 2 - 1.5, head = RibbonTheme.diagonalCursorHead, wing: CGFloat = 4.5, shaft: CGFloat = 1.25
            let points: [(CGFloat, CGFloat)] = [(-tip, 0), (-tip + head, -wing), (-tip + head, -shaft), (tip - head, -shaft),
                                                (tip - head, -wing), (tip, 0), (tip - head, wing), (tip - head, shaft),
                                                (-tip + head, shaft), (-tip + head, wing)]
            let arrow = NSBezierPath()
            arrow.move(to: NSPoint(x: points[0].0, y: points[0].1))
            for point in points.dropFirst() { arrow.line(to: NSPoint(x: point.0, y: point.1)) }
            arrow.close()
            var transform = AffineTransform(translationByX: side / 2, byY: side / 2)
            transform.rotate(byDegrees: descending ? 45 : -45)
            arrow.transform(using: transform)
            arrow.lineJoinStyle = .miter
            NSColor.white.setStroke()
            arrow.lineWidth = 2
            arrow.stroke()
            NSColor.black.setFill()
            arrow.fill()
            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: side / 2, y: side / 2))
    }

    /// Strokes a path in black over a white halo, so it shows on any color.
    private static func outlined(width: CGFloat, _ build: (NSBezierPath) -> Void) {
        let path = NSBezierPath()
        build(path)
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        NSColor.white.setStroke()
        path.lineWidth = width + 2
        path.stroke()
        NSColor.black.setStroke()
        path.lineWidth = width
        path.stroke()
    }
}
