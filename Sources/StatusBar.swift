import AppKit

/// Maps zoom levels to positions on the status bar slider: 12.5% to 100% fill the left half
/// (each step doubles), 100% to 800% the right half (linear), so 100% sits in the middle.
enum ZoomScale {
    static func position(of zoom: CGFloat) -> CGFloat {
        if zoom <= 1 { return max(0, 0.5 * (log2(zoom) + 3) / 3) }
        return min(1, 0.5 + 0.5 * (zoom - 1) / 7)
    }

    /// The zoom level closest to `position` (0 to 1).
    static func zoom(at position: CGFloat) -> CGFloat {
        let levels = MainWindowController.zoomLevels
        return levels.min { abs(ZoomScale.position(of: $0) - position) < abs(ZoomScale.position(of: $1) - position) } ?? 1
    }
}

/// Status bar texts, kept apart from the view so they can be tested.
enum StatusText {
    static func position(_ point: PixelPoint?) -> String {
        guard let point = point else { return "" }
        return String(format: L("status.position"), point.x, point.y)
    }

    static func imageSize(width: Int, height: Int) -> String {
        String(format: L("status.size"), width, height)
    }

    static func selection(_ size: (width: Int, height: Int)?) -> String {
        guard let size = size else { return "" }
        return String(format: L("status.size"), size.width, size.height)
    }

    /// "Tamanho: 1,4KB", as Paint shows the file on disk.
    static func diskSize(_ bytes: Int?) -> String {
        guard let bytes = bytes else { return "" }
        return String(format: L("status.disk"), byteCount(bytes))
    }

    /// "1,4KB", "512 bytes": a file size the way Paint writes it.
    static func byteCount(_ bytes: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        let value: String
        if bytes < 1024 {
            value = String(format: L("status.bytes"), bytes)
        } else if bytes < 1024 * 1024 {
            value = (formatter.string(from: NSNumber(value: Double(bytes) / 1024)) ?? "") + L("status.kb")
        } else {
            value = (formatter.string(from: NSNumber(value: Double(bytes) / 1024 / 1024)) ?? "") + L("status.mb")
        }
        return value
    }

    static func zoom(_ zoom: CGFloat) -> String {
        let percent = zoom * 100
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        return (formatter.string(from: NSNumber(value: Double(percent))) ?? "") + "%"
    }
}

/// The zoom slider of the status bar. Dragging snaps to the zoom levels.
final class ZoomSlider: RibbonControl {
    var zoom: CGFloat = 1 { didSet { if oldValue != zoom { needsDisplay = true } } }
    private let inset: CGFloat = 5

    override func accessibilityRole() -> NSAccessibility.Role? { .slider }
    override func accessibilityValue() -> Any? { StatusText.zoom(zoom) }

    private var track: NSRect { NSRect(x: inset, y: floor(bounds.midY) - 1, width: bounds.width - 2 * inset, height: 2) }

    private func zoom(at point: NSPoint) -> CGFloat {
        ZoomScale.zoom(at: max(0, min(1, (point.x - track.minX) / track.width)))
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        isPressed = true
        move(to: convert(event.locationInWindow, from: nil))
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEnabled, isPressed else { return }
        move(to: convert(event.locationInWindow, from: nil))
    }

    override func mouseUp(with event: NSEvent) { isPressed = false }

    private func move(to point: NSPoint) {
        let next = zoom(at: point)
        guard next != zoom else { return }
        zoom = next
        perform()
    }

    override func draw(_ dirtyRect: NSRect) {
        let track = self.track
        RibbonTheme.zoomTrack.setFill()
        track.fill()
        RibbonTheme.separatorLight.setFill()
        NSRect(x: track.minX, y: track.maxY, width: track.width, height: 1).fill()
        // Tick at 100%.
        RibbonTheme.zoomTrack.setFill()
        NSRect(x: floor(track.midX), y: track.minY - 4, width: 1, height: 10).fill()
        let x = floor(track.minX + ZoomScale.position(of: zoom) * track.width)
        let thumb = NSRect(x: x - 3.5, y: floor(bounds.midY) - 7.5, width: 7, height: 14)
        let path = NSBezierPath(roundedRect: thumb, xRadius: 1.5, yRadius: 1.5)
        NSGradient(starting: isHovered || isPressed ? RibbonTheme.hoverTop : RibbonTheme.zoomThumbTop,
                   ending: isHovered || isPressed ? RibbonTheme.pressedBottom : RibbonTheme.zoomThumbBottom)?.draw(in: path, angle: 90)
        RibbonTheme.zoomThumbBorder.setStroke()
        path.stroke()
    }
}

/// The small − and + buttons beside the zoom slider.
final class ZoomStepButton: RibbonControl {
    let plus: Bool

    init(plus: Bool, title: String) {
        self.plus = plus
        super.init(title: title)
        frame.size = NSSize(width: 18, height: 18)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func draw(_ dirtyRect: NSRect) {
        RibbonTheme.drawButton(bounds, look, radius: 9)
        let color = isEnabled ? RibbonTheme.rgb(0x3E5878) : RibbonTheme.disabledTextColor
        color.setFill()
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        NSRect(x: center.x - 4.5, y: center.y - 1, width: 9, height: 2).fill()
        if plus { NSRect(x: center.x - 1, y: center.y - 4.5, width: 2, height: 9).fill() }
    }
}

/// Pointer position, selection size, image size, file size and the zoom control.
final class StatusBarView: FlippedView {
    private(set) var positionText = ""
    private(set) var selectionText = ""
    private(set) var imageSizeText = ""
    private(set) var diskSizeText = ""
    let zoomOut = ZoomStepButton(plus: false, title: L("ribbon.zoomOut"))
    let zoomIn = ZoomStepButton(plus: true, title: L("ribbon.zoomIn"))
    let slider = ZoomSlider(title: L("status.zoom"))
    private(set) var zoom: CGFloat = 1

    override init(frame: NSRect) {
        super.init(frame: frame)
        [zoomOut, slider, zoomIn].forEach(addSubview)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(L("ribbon.statusBar"))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    var zoomText: String { StatusText.zoom(zoom) }

    func update(position: PixelPoint?, selection: (width: Int, height: Int)?, imageWidth: Int, imageHeight: Int,
                diskBytes: Int?, zoom: CGFloat) {
        positionText = StatusText.position(position)
        selectionText = StatusText.selection(selection)
        imageSizeText = StatusText.imageSize(width: imageWidth, height: imageHeight)
        diskSizeText = StatusText.diskSize(diskBytes)
        self.zoom = zoom
        slider.zoom = zoom
        let levels = MainWindowController.zoomLevels
        zoomOut.isEnabled = zoom > levels.first!
        zoomIn.isEnabled = zoom < levels.last!
        needsDisplay = true
    }

    func updatePosition(_ position: PixelPoint?) {
        let text = StatusText.position(position)
        guard text != positionText else { return }
        positionText = text
        setNeedsDisplay(NSRect(x: 0, y: 0, width: RibbonTheme.statusSectionWidth, height: bounds.height))
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        let y = floor((bounds.height - 18) / 2)
        var x = bounds.width - 10 - zoomIn.frame.width
        zoomIn.frame.origin = NSPoint(x: x, y: y)
        x -= RibbonTheme.zoomSliderWidth
        slider.frame = NSRect(x: x, y: 2, width: RibbonTheme.zoomSliderWidth, height: bounds.height - 4)
        x -= zoomOut.frame.width
        zoomOut.frame.origin = NSPoint(x: x, y: y)
    }

    override func draw(_ dirtyRect: NSRect) {
        RibbonTheme.fillVertical(bounds, top: RibbonTheme.statusTop, bottom: RibbonTheme.statusBottom)
        RibbonTheme.statusBorder.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 1).fill()
        RibbonTheme.separatorLight.setFill()
        NSRect(x: 0, y: 1, width: bounds.width, height: 1).fill()
        let sections: [(RibbonIcon, String)] = [(.statusPointer, positionText), (.statusSelection, selectionText),
                                                (.statusImage, imageSizeText), (.statusDisk, diskSizeText)]
        let attributes = RibbonTheme.attributes()
        let width = RibbonTheme.statusSectionWidth
        let zoomLeft = zoomOut.frame.minX - 4 - RibbonTheme.zoomLabelWidth
        for (index, section) in sections.enumerated() {
            let x = CGFloat(index) * width
            // Sections that would run into the zoom control are left out, as in a narrow Paint window.
            guard x + width <= zoomLeft else { break }
            if !section.1.isEmpty || index < 3 {
                section.0.draw(in: NSRect(x: x + 6, y: floor((bounds.height - 16) / 2) + 1, width: 16, height: 16))
            }
            let height = (section.1 as NSString).size(withAttributes: attributes).height
            (section.1 as NSString).draw(at: NSPoint(x: x + 27, y: floor((bounds.height - height) / 2) + 1), withAttributes: attributes)
            RibbonTheme.statusBorder.setFill()
            NSRect(x: x + width - 1, y: 4, width: 1, height: bounds.height - 7).fill()
            RibbonTheme.separatorLight.setFill()
            NSRect(x: x + width, y: 4, width: 1, height: bounds.height - 7).fill()
        }
        let zoomRight = zoomOut.frame.minX - 4
        let height = (zoomText as NSString).size(withAttributes: attributes).height
        let textWidth = RibbonTheme.textWidth(zoomText)
        (zoomText as NSString).draw(at: NSPoint(x: zoomRight - textWidth, y: floor((bounds.height - height) / 2) + 1), withAttributes: attributes)
    }
}
