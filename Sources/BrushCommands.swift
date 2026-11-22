import AppKit

/// Commands of the Brushes group: the split button and its drop-down of nine brushes,
/// mirrored in Tools > Brushes of the menu bar.
extension MainWindowController {
    /// A brush from the drop-down: picks the Brushes tool with it.
    @objc func chooseBrush(_ sender: Any?) {
        guard let kind = BrushKind(rawValue: senderTag(sender)) else { return }
        let toolbox = canvas.toolbox
        toolbox.brushTool.kind = kind
        if toolbox.kind == .brush { toolbox.toolDidChange() } else { toolbox.select(.brush) }
        syncInterface()
    }

    @objc func showBrushMenu(_ sender: Any?) {
        showRibbonMenu(brushMenuItems(), style: .gallery(columns: RibbonTheme.brushGalleryColumns), name: "menu.brushes", under: sender)
    }

    /// The nine brushes with their icons; the current one is checked.
    func brushMenuItems() -> [NSMenuItem] {
        BrushKind.allCases.map { kind in
            let item = NSMenuItem(title: L(kind.nameKey), action: #selector(chooseBrush(_:)), keyEquivalent: "")
            item.tag = kind.rawValue
            item.target = self
            item.image = kind.icon.menuImage
            item.state = canvas.toolbox.brushTool.kind == kind ? .on : .off
            return item
        }
    }
}

extension BrushKind {
    var icon: RibbonIcon {
        switch self {
        case .brush: return .brushPlain
        case .calligraphy1: return .brushCalligraphy1
        case .calligraphy2: return .brushCalligraphy2
        case .airbrush: return .brushAirbrush
        case .oil: return .brushOil
        case .crayon: return .brushCrayon
        case .marker: return .brushMarker
        case .naturalPencil: return .brushNaturalPencil
        case .watercolor: return .brushWatercolor
        }
    }
}

/// Original drawings of the nine brush icons on the 32 unit grid: a stroke sample at the
/// bottom left and the tool at the top right.
extension IconPainter {
    /// The sample stroke of every icon: an S from the bottom left towards the middle.
    private func sample(_ build: (CGMutablePath) -> Void = { _ in }) -> CGMutablePath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 3, y: 27))
        path.addCurve(to: CGPoint(x: 17, y: 22), control1: CGPoint(x: 7, y: 19), control2: CGPoint(x: 12, y: 30))
        build(path)
        return path
    }

    private func stroke(_ path: CGPath, _ color: UInt32, _ width: CGFloat, dash: [CGFloat] = []) {
        context.saveGState()
        if !dash.isEmpty { context.setLineDash(phase: 0, lengths: dash) }
        context.addPath(path)
        context.setStrokeColor(cg(color))
        context.setLineWidth(width)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.strokePath()
        context.restoreGState()
    }

    /// A round brush: handle, ferrule and tip, pointing to the bottom left.
    private func roundBrush(tip: UInt32) {
        path(fill: 0x9C6B3A, stroke: 0x5E3D1E, 1) { $0.move(to: CGPoint(x: 26, y: 2)); $0.addLine(to: CGPoint(x: 30, y: 6))
            $0.addLine(to: CGPoint(x: 21, y: 15)); $0.addLine(to: CGPoint(x: 17, y: 11)); $0.closeSubpath() }
        path(fill: 0xB8BEC8, stroke: 0x5F6670, 1) { $0.move(to: CGPoint(x: 17, y: 11)); $0.addLine(to: CGPoint(x: 21, y: 15))
            $0.addLine(to: CGPoint(x: 18.5, y: 17.5)); $0.addLine(to: CGPoint(x: 14.5, y: 13.5)); $0.closeSubpath() }
        path(fill: tip, stroke: 0x3A3A3A, 1) { $0.move(to: CGPoint(x: 14.5, y: 13.5)); $0.addLine(to: CGPoint(x: 18.5, y: 17.5))
            $0.addCurve(to: CGPoint(x: 11, y: 21), control1: CGPoint(x: 16, y: 20), control2: CGPoint(x: 13, y: 21))
            $0.addCurve(to: CGPoint(x: 14.5, y: 13.5), control1: CGPoint(x: 11, y: 18), control2: CGPoint(x: 12, y: 15)) }
    }

    func brushIcon(_ kind: BrushKind) {
        switch kind {
        case .brush:
            stroke(sample(), 0x1F4E9A, 3)
            roundBrush(tip: 0x2E6BC6)
        case .calligraphy1, .calligraphy2:
            // A flat nib dragged along the sample: thick and thin parts at 45°.
            let rising = kind == .calligraphy1
            for step in 0..<6 {
                let d = CGFloat(step) * 0.55
                var shift = CGAffineTransform(translationX: d, y: rising ? -d : d)
                if let moved = sample().copy(using: &shift) { stroke(moved, 0x1E1E1E, 1) }
            }
            path(fill: 0x2B2B2B, stroke: 0x111111, 1) { $0.move(to: CGPoint(x: 27, y: 3)); $0.addLine(to: CGPoint(x: 30, y: 6))
                $0.addLine(to: CGPoint(x: 21, y: 15)); $0.addLine(to: CGPoint(x: 18, y: 12)); $0.closeSubpath() }
            path(fill: 0xD9B44A, stroke: 0x7D6420, 1) {
                $0.move(to: CGPoint(x: 18, y: 12)); $0.addLine(to: CGPoint(x: 21, y: 15))
                if rising {
                    $0.addLine(to: CGPoint(x: 18, y: 21)); $0.addLine(to: CGPoint(x: 12, y: 15))
                } else {
                    $0.addLine(to: CGPoint(x: 15, y: 20)); $0.addLine(to: CGPoint(x: 13, y: 18))
                }
                $0.closeSubpath()
            }
        case .airbrush:
            // A spray can and its cloud of dots.
            let dots: [(CGFloat, CGFloat)] = [(4, 24), (6, 20), (8, 26), (9, 22), (11, 18), (12, 24), (13, 28), (14, 21),
                                              (7, 16), (16, 25), (10, 29), (5, 28), (15, 17), (3, 21), (17, 21)]
            for (x, y) in dots { rect(x, y, 1.6, 1.6, fill: 0x1F4E9A, stroke: nil) }
            path(fill: 0xC9D3DF, stroke: 0x4F5B6B, 1) { $0.addRoundedRect(in: CGRect(x: 20.5, y: 8.5, width: 9, height: 20), cornerWidth: 2, cornerHeight: 2) }
            rect(20.5, 13, 9, 7, fill: 0x2E6BC6, stroke: nil)
            rect(23, 4.5, 4, 4, fill: 0x6E7886, stroke: 0x3E4652)
            rect(19, 5.5, 3, 2, fill: 0x3E4652, stroke: nil)
        case .oil:
            // A flat brush and a streaky stroke.
            for (offset, color) in [(-1.5, 0x8A3A12), (0.0, 0xC0581F), (1.5, 0x9E4416)] as [(CGFloat, UInt32)] {
                var shift = CGAffineTransform(translationX: 0, y: offset)
                if let moved = sample().copy(using: &shift) { stroke(moved, color, 1.6) }
            }
            path(fill: 0x9C6B3A, stroke: 0x5E3D1E, 1) { $0.move(to: CGPoint(x: 27, y: 2)); $0.addLine(to: CGPoint(x: 30, y: 5))
                $0.addLine(to: CGPoint(x: 22, y: 13)); $0.addLine(to: CGPoint(x: 19, y: 10)); $0.closeSubpath() }
            path(fill: 0xB8BEC8, stroke: 0x5F6670, 1) { $0.move(to: CGPoint(x: 19, y: 10)); $0.addLine(to: CGPoint(x: 22, y: 13))
                $0.addLine(to: CGPoint(x: 18, y: 19)); $0.addLine(to: CGPoint(x: 13, y: 14)); $0.closeSubpath() }
            path(fill: 0xC0581F, stroke: 0x6A2C0C, 1) { $0.move(to: CGPoint(x: 13, y: 14)); $0.addLine(to: CGPoint(x: 18, y: 19))
                $0.addLine(to: CGPoint(x: 14, y: 22)); $0.addLine(to: CGPoint(x: 10, y: 18)); $0.closeSubpath() }
        case .crayon:
            // A wax stick and a broken, grainy stroke.
            stroke(sample(), 0xD8402E, 3.5, dash: [1.2, 0.8])
            path(fill: 0xD8402E, stroke: 0x7A1E12, 1) { $0.move(to: CGPoint(x: 27, y: 3)); $0.addLine(to: CGPoint(x: 30, y: 6))
                $0.addLine(to: CGPoint(x: 19, y: 17)); $0.addLine(to: CGPoint(x: 16, y: 14)); $0.closeSubpath() }
            path(fill: 0xF2E3C2, stroke: 0x7A1E12, 1) { $0.move(to: CGPoint(x: 23, y: 7)); $0.addLine(to: CGPoint(x: 26, y: 10))
                $0.addLine(to: CGPoint(x: 23, y: 13)); $0.addLine(to: CGPoint(x: 20, y: 10)); $0.closeSubpath() }
            path(fill: 0xE86A55, stroke: 0x7A1E12, 1) { $0.move(to: CGPoint(x: 16, y: 14)); $0.addLine(to: CGPoint(x: 19, y: 17))
                $0.addLine(to: CGPoint(x: 13, y: 19)); $0.closeSubpath() }
        case .marker:
            // A marker and a wide, see-through stroke.
            stroke(sample(), 0xF6E46A, 6)
            stroke(sample(), 0xEED43A, 2)
            path(fill: 0x3D3D3D, stroke: 0x1E1E1E, 1) { $0.move(to: CGPoint(x: 26, y: 2)); $0.addLine(to: CGPoint(x: 30, y: 6))
                $0.addLine(to: CGPoint(x: 21, y: 15)); $0.addLine(to: CGPoint(x: 17, y: 11)); $0.closeSubpath() }
            path(fill: 0xE0C21A, stroke: 0x6B5A08, 1) { $0.move(to: CGPoint(x: 17, y: 11)); $0.addLine(to: CGPoint(x: 21, y: 15))
                $0.addLine(to: CGPoint(x: 16, y: 19)); $0.addLine(to: CGPoint(x: 13, y: 15)); $0.closeSubpath() }
        case .naturalPencil:
            // A wooden pencil and a soft gray line.
            stroke(sample(), 0x7A7A7A, 1.6, dash: [2, 0.7])
            path(fill: 0xF0C23A, stroke: 0x7D5F12, 1) { $0.move(to: CGPoint(x: 27, y: 2)); $0.addLine(to: CGPoint(x: 30, y: 5))
                $0.addLine(to: CGPoint(x: 19, y: 16)); $0.addLine(to: CGPoint(x: 16, y: 13)); $0.closeSubpath() }
            path(fill: 0xE9D3A8, stroke: 0x7D5F12, 1) { $0.move(to: CGPoint(x: 16, y: 13)); $0.addLine(to: CGPoint(x: 19, y: 16))
                $0.addLine(to: CGPoint(x: 13, y: 19)); $0.closeSubpath() }
            path(fill: 0x4A4A4A, stroke: nil, 0) { $0.move(to: CGPoint(x: 14.2, y: 16.6)); $0.addLine(to: CGPoint(x: 15.6, y: 18))
                $0.addLine(to: CGPoint(x: 13, y: 19)); $0.closeSubpath() }
        case .watercolor:
            // Soft washes of color under a round brush.
            ellipse(2, 19, 12, 10, fill: 0xCFE3F6, stroke: nil)
            ellipse(9, 20, 10, 8, fill: 0xB7D4F0, stroke: nil)
            ellipse(4, 21, 8, 6, fill: 0x9CC3EA, stroke: nil)
            roundBrush(tip: 0x5D9BDB)
        }
    }
}

extension ToolCursor {
    /// The brushes show their footprint at the current zoom; a small one is a thin cross instead.
    static func brush(_ kind: BrushKind, size: Int, zoom: CGFloat) -> NSCursor {
        let span = CGFloat(size) * zoom
        guard span >= 6 else { return cursor(for: .select, size: 0, zoom: zoom) }
        let side = min(128, ceil(span) + 4)
        let center = side / 2
        let image = NSImage(size: NSSize(width: side, height: side), flipped: true) { _ in
            let path = NSBezierPath()
            switch kind {
            case .calligraphy1, .calligraphy2:
                let half = min(span, side - 4) / 2 * 0.7071
                let rising = kind == .calligraphy1
                path.move(to: NSPoint(x: center - half, y: rising ? center + half : center - half))
                path.line(to: NSPoint(x: center + half, y: rising ? center - half : center + half))
            default:
                let radius = min(span, side - 4) / 2
                path.appendOval(in: NSRect(x: center - radius, y: center - radius, width: 2 * radius, height: 2 * radius))
            }
            path.lineCapStyle = .round
            NSColor.white.setStroke()
            path.lineWidth = 3
            path.stroke()
            NSColor.black.setStroke()
            path.lineWidth = 1
            path.stroke()
            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: center, y: center))
    }
}
