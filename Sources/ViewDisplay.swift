import AppKit

/// A ruler along the top or the left of the workspace, in image pixels. It follows the zoom and
/// the scrolling and marks the pointer, as Paint's View > Rulers does.
final class RulerView: FlippedView {
    enum Orientation { case horizontal, vertical }

    let orientation: Orientation
    /// Where image pixel 0 starts along the ruler, in the ruler's own units.
    private(set) var origin: CGFloat = 0
    /// Length of one image pixel along the ruler, in the ruler's own units.
    private(set) var pixelLength: CGFloat = 1
    private(set) var imageLength = 0
    /// Image pixel under the pointer, marked by a line.
    private(set) var pointer: Int?

    init(_ orientation: Orientation) {
        self.orientation = orientation
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.ruler)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func update(origin: CGFloat, pixelLength: CGFloat, imageLength: Int, pointer: Int?) {
        guard origin != self.origin || pixelLength != self.pixelLength || imageLength != self.imageLength
                || pointer != self.pointer else { return }
        self.origin = origin
        self.pixelLength = pixelLength
        self.imageLength = imageLength
        self.pointer = pointer
        needsDisplay = true
    }

    /// Pixels between labelled ticks and between the small ones, so labels stay at least
    /// `RibbonTheme.rulerLabelSpacing` apart.
    static func steps(pixelLength: CGFloat) -> (major: Int, minor: Int) {
        let candidates = [1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000, 2000, 5000, 10000, 20000, 50000]
        let major = candidates.first { CGFloat($0) * pixelLength >= RibbonTheme.rulerLabelSpacing } ?? candidates.last!
        let minor: Int
        switch major {
        case _ where major % 10 == 0: minor = major / 10
        case 25: minor = 5
        case 5: minor = 1
        default: minor = major
        }
        return (major, minor)
    }

    /// Position along the ruler of the start of image pixel `value`.
    func position(of value: Int) -> CGFloat { origin + CGFloat(value) * pixelLength }

    var along: CGFloat { orientation == .horizontal ? bounds.width : bounds.height }
    var across: CGFloat { orientation == .horizontal ? bounds.height : bounds.width }

    /// A rectangle given along and across the ruler, in view coordinates.
    private func rect(along start: CGFloat, _ length: CGFloat, across from: CGFloat, _ depth: CGFloat) -> NSRect {
        orientation == .horizontal ? NSRect(x: start, y: from, width: length, height: depth)
                                   : NSRect(x: from, y: start, width: depth, height: length)
    }

    override func draw(_ dirtyRect: NSRect) {
        RibbonTheme.rulerBackground.setFill()
        bounds.fill()
        let start = max(0, position(of: 0)), end = min(along, position(of: imageLength))
        if end > start {
            RibbonTheme.rulerImage.setFill()
            rect(along: start, end - start, across: 2, across - 3).fill()
        }
        RibbonTheme.rulerBorder.setFill()
        rect(along: 0, along, across: across - 1, 1).fill()
        let steps = RulerView.steps(pixelLength: pixelLength)
        let drawsMinor = CGFloat(steps.minor) * pixelLength >= 4
        let step = drawsMinor ? steps.minor : steps.major
        var value = max(0, Int(floor(-origin / pixelLength / CGFloat(step))) * step)
        let attributes: [NSAttributedString.Key: Any] = [.font: RibbonTheme.rulerFont, .foregroundColor: RibbonTheme.rulerText]
        RibbonTheme.rulerTick.setFill()
        while position(of: value) <= along, value <= 1_000_000 {
            let at = floor(position(of: value))
            let depth: CGFloat
            if value % steps.major == 0 {
                depth = across - 3
                let label = String(value) as NSString
                if orientation == .horizontal {
                    label.draw(at: NSPoint(x: at + 2, y: 1), withAttributes: attributes)
                } else if let context = NSGraphicsContext.current?.cgContext {
                    // Read from the bottom up, like the vertical ruler of the original.
                    context.saveGState()
                    context.translateBy(x: 1, y: at - 2)
                    context.rotate(by: -.pi / 2)
                    label.draw(at: .zero, withAttributes: attributes)
                    context.restoreGState()
                }
                RibbonTheme.rulerTick.setFill()
            } else if steps.major % 2 == 0, value % (steps.major / 2) == 0 {
                depth = 6
            } else {
                depth = 3
            }
            rect(along: at, 1, across: across - 1 - depth, depth).fill()
            value += step
        }
        if let pointer = pointer {
            RibbonTheme.rulerPointer.setFill()
            rect(along: floor(position(of: pointer) + pixelLength / 2), 1, across: 0, across - 1).fill()
        }
    }
}

/// The square where the two rulers meet.
final class RulerCornerView: FlippedView {
    override func draw(_ dirtyRect: NSRect) {
        RibbonTheme.rulerBackground.setFill()
        bounds.fill()
        RibbonTheme.rulerBorder.setFill()
        NSRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1).fill()
        NSRect(x: bounds.width - 1, y: 0, width: 1, height: bounds.height).fill()
    }
}

/// The picture reduced to fit, with the part shown in the workspace outlined: View > Thumbnail.
final class ThumbnailView: FlippedView {
    /// The image to show, asked for each time the view draws.
    var imageProvider: () -> CGImage? = { nil }
    var imageSize = (width: 1, height: 1) { didSet { needsDisplay = true } }
    /// The part of the image shown in the workspace, in image pixels; nil when all of it shows.
    var visibleArea: CGRect? { didSet { if oldValue != visibleArea { needsDisplay = true } } }

    /// Where the image is drawn: reduced to fit (never enlarged) and centred.
    var imageRect: CGRect {
        let w = CGFloat(max(1, imageSize.width)), h = CGFloat(max(1, imageSize.height))
        let factor = min(1, min(bounds.width / w, bounds.height / h))
        let size = CGSize(width: max(1, floor(w * factor)), height: max(1, floor(h * factor)))
        return CGRect(x: floor((bounds.width - size.width) / 2), y: floor((bounds.height - size.height) / 2),
                      width: size.width, height: size.height)
    }

    override func draw(_ dirtyRect: NSRect) {
        RibbonTheme.thumbnailBackground.setFill()
        bounds.fill()
        guard let context = NSGraphicsContext.current?.cgContext, let image = imageProvider() else { return }
        let rect = imageRect
        context.saveGState()
        context.interpolationQuality = .medium
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
        guard let area = visibleArea else { return }
        let factor = rect.width / CGFloat(max(1, imageSize.width))
        let outline = CGRect(x: rect.minX + area.minX * factor, y: rect.minY + area.minY * factor,
                             width: area.width * factor, height: area.height * factor).intersection(rect)
        RibbonTheme.thumbnailVisibleArea.setStroke()
        NSBezierPath(rect: outline.insetBy(dx: 0.5, dy: 0.5)).stroke()
    }
}

/// View > Full screen: a borderless window over the whole screen with only the picture.
/// Any click or key goes back.
final class FullScreenWindow: NSWindow {
    var onClose: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) { onClose?() }
    override func mouseDown(with event: NSEvent) { onClose?() }
    override func rightMouseDown(with event: NSEvent) { onClose?() }
    override func otherMouseDown(with event: NSEvent) { onClose?() }
    // Shortcuts (Cmd or Ctrl keys) also leave instead of reaching the menus.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        onClose?()
        return true
    }
}

/// The picture at 100%, centred over the background; reduced to fit when larger than the screen.
final class FullScreenView: FlippedView {
    let image: CGImage?
    let imageSize: CGSize

    init(frame: NSRect, bitmap: Bitmap) {
        image = bitmap.makeImage()
        imageSize = CGSize(width: bitmap.width, height: bitmap.height)
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    var imageRect: CGRect {
        let factor = min(1, min(bounds.width / imageSize.width, bounds.height / imageSize.height))
        let size = CGSize(width: floor(imageSize.width * factor), height: floor(imageSize.height * factor))
        return CGRect(x: floor((bounds.width - size.width) / 2), y: floor((bounds.height - size.height) / 2),
                      width: size.width, height: size.height)
    }

    override func draw(_ dirtyRect: NSRect) {
        RibbonTheme.fullScreenBackground.setFill()
        bounds.fill()
        guard let context = NSGraphicsContext.current?.cgContext, let image = image else { return }
        let rect = imageRect
        context.saveGState()
        context.interpolationQuality = .none
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }
}

/// View tab commands: rulers, gridlines, full screen, thumbnail and the interface size.
extension MainWindowController {
    @objc func toggleRulers(_ sender: Any?) { showsRulers.toggle() }
    @objc func toggleGridlines(_ sender: Any?) { showsGridlines.toggle() }
    @objc func toggleThumbnail(_ sender: Any?) { showsThumbnail.toggle() }

    /// Brings the rulers in line with the zoom, the scrolling and the pointer.
    func syncRulers() {
        guard showsRulers else { return }
        let bitmap = document.bitmap
        let start = canvas.convert(NSPoint(x: CanvasView.inset, y: CanvasView.inset), to: nil)
        let far = canvas.convert(NSPoint(x: CanvasView.inset + 100 * canvas.zoom, y: CanvasView.inset + 100 * canvas.zoom), to: nil)
        let h0 = horizontalRuler.convert(start, from: nil), h1 = horizontalRuler.convert(far, from: nil)
        let v0 = verticalRuler.convert(start, from: nil), v1 = verticalRuler.convert(far, from: nil)
        horizontalRuler.update(origin: h0.x, pixelLength: (h1.x - h0.x) / 100, imageLength: bitmap.width, pointer: pointer?.x)
        verticalRuler.update(origin: v0.y, pixelLength: (v1.y - v0.y) / 100, imageLength: bitmap.height, pointer: pointer?.y)
    }

    // MARK: Full screen

    /// View > Full screen (F11). The main window is left as it is underneath.
    @objc func viewFullScreen(_ sender: Any?) {
        guard fullScreenWindow == nil else { return closeFullScreen() }
        canvas.finishEditing()
        let screen = window.screen ?? NSScreen.main
        let frame = screen?.frame ?? window.frame
        let full = FullScreenWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        full.isReleasedWhenClosed = false
        full.contentView = FullScreenView(frame: NSRect(origin: .zero, size: frame.size), bitmap: document.bitmap)
        full.onClose = { [weak self] in self?.closeFullScreen() }
        fullScreenWindow = full
        guard window.isVisible else { return }
        if NSApp.isActive {
            savedPresentation = NSApp.presentationOptions
            NSApp.presentationOptions = [.hideDock, .hideMenuBar]
        }
        full.makeKeyAndOrderFront(nil)
    }

    func closeFullScreen() {
        guard let full = fullScreenWindow else { return }
        fullScreenWindow = nil
        full.onClose = nil
        full.orderOut(nil)
        if let options = savedPresentation {
            NSApp.presentationOptions = options
            savedPresentation = nil
        }
        if window.isVisible { window.makeKeyAndOrderFront(nil) }
    }

    // MARK: Thumbnail

    /// Shows or hides the thumbnail panel, at the top right of the workspace.
    func syncThumbnailPanel() {
        guard showsThumbnail else {
            if let panel = thumbnailPanel {
                thumbnailPanel = nil
                panel.delegate = nil
                panel.parent?.removeChildWindow(panel)
                panel.orderOut(nil)
            }
            return
        }
        if thumbnailPanel == nil {
            let size = RibbonTheme.thumbnailSize
            let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                                styleMask: [.titled, .closable, .utilityWindow], backing: .buffered, defer: false)
            panel.title = L("thumbnail.title")
            panel.isReleasedWhenClosed = false
            panel.hidesOnDeactivate = true
            panel.becomesKeyOnlyIfNeeded = true
            panel.appearance = NSAppearance(named: .aqua)
            let view = ThumbnailView(frame: NSRect(origin: .zero, size: size))
            view.imageProvider = { [weak self] in self?.document.bitmap.makeImage() }
            panel.contentView = view
            panel.delegate = self
            let area = window.convertToScreen(scrollView.convert(scrollView.bounds, to: nil))
            panel.setFrameTopLeftPoint(NSPoint(x: area.maxX - panel.frame.width - 20, y: area.maxY - 12))
            thumbnailPanel = panel
        }
        // Shown once the window is: at launch the panel is made before the window appears.
        if let panel = thumbnailPanel, panel.parent == nil, window.isVisible {
            window.addChildWindow(panel, ordered: .above)
            panel.orderFront(nil)
        }
        syncThumbnail()
    }

    /// Redraws the thumbnail and its outline of the visible area.
    func syncThumbnail() {
        guard let view = thumbnailPanel?.contentView as? ThumbnailView else { return }
        let bitmap = document.bitmap
        view.imageSize = (bitmap.width, bitmap.height)
        let visible = canvas.visibleRect, zoom = canvas.zoom
        let area = CGRect(x: (visible.minX - CanvasView.inset) / zoom, y: (visible.minY - CanvasView.inset) / zoom,
                          width: visible.width / zoom, height: visible.height / zoom)
            .intersection(CGRect(x: 0, y: 0, width: bitmap.width, height: bitmap.height))
        let showsAll = area.width >= CGFloat(bitmap.width) - 0.5 && area.height >= CGFloat(bitmap.height) - 0.5
        view.visibleArea = showsAll || area.isNull ? nil : area
        view.needsDisplay = true
    }

    /// The thumbnail's own close button turns it off, as the ribbon button would.
    func windowWillClose(_ notification: Notification) {
        guard let panel = notification.object as? NSPanel, panel === thumbnailPanel else { return }
        thumbnailPanel = nil
        panel.parent?.removeChildWindow(panel)
        if showsThumbnail { showsThumbnail = false }
    }

    // MARK: Interface size

    /// The drop-down of View > Interface text size.
    @objc func showInterfaceSizeMenu(_ sender: Any?) {
        showRibbonMenu(interfaceSizeMenuItems(), name: "menu.interfaceSize", under: sender)
    }

    func interfaceSizeMenuItems() -> [NSMenuItem] {
        InterfaceSize.allCases.map { size in
            let item = NSMenuItem(title: L(size.nameKey), action: #selector(chooseInterfaceSize(_:)), keyEquivalent: "")
            item.tag = size.rawValue
            item.target = self
            item.state = size == interfaceSize ? .on : .off
            return item
        }
    }

    @objc func chooseInterfaceSize(_ sender: Any?) {
        if let sender = sender as? NSPopUpButton {
            interfaceSize = InterfaceSize(rawValue: sender.selectedTag()) ?? .normal
        } else {
            interfaceSize = InterfaceSize(rawValue: senderTag(sender)) ?? .normal
        }
    }

    /// Applies the interface factor to the window: layout, minimum size and open panels.
    func applyInterfaceSize() {
        let factor = interfaceSize.factor
        RibbonTheme.scale = factor
        RibbonPopup.current?.close()
        window.contentMinSize = MainWindowController.minimumContentSize(factor)
        let content = window.contentRect(forFrameRect: window.frame).size
        let minimum = window.contentMinSize
        if content.width < minimum.width || content.height < minimum.height {
            window.setContentSize(NSSize(width: max(content.width, minimum.width), height: max(content.height, minimum.height)))
        }
        layoutContent()
        settingsWindow?.sync()
        syncInterface()
    }

    /// The smallest window: room for the ribbon, the status bar and some of the picture.
    static func minimumContentSize(_ factor: CGFloat) -> NSSize {
        NSSize(width: ceil(320 * factor),
               height: ceil((RibbonTheme.ribbonHeight + RibbonTheme.statusBarHeight + RibbonTheme.rulerThickness) * factor + 80))
    }
}
