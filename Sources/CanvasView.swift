import AppKit

/// Shows the image at the current zoom and hands mouse input to the selected tool.
/// It also draws the selection outline and runs the canvas resize handles.
final class CanvasView: NSView, ToolHost, NSTextViewDelegate {
    /// Gap between the workspace edge and the image, as in Paint.
    static let inset: CGFloat = 5
    /// Room kept around the image for the resize handles.
    static let trailing: CGFloat = 12

    var document: PaintDocument { didSet { cancelStroke(); canvasDrag = nil; reload() } }
    var zoom: CGFloat = 1 { didSet { reload(); onZoomChange?() } }
    let toolbox = ToolBox()
    /// Called after the image or its undo history changes.
    var onChange: (() -> Void)?
    /// Called after the selected tool or its size changes.
    var onToolChange: (() -> Void)?
    /// Called after the zoom changes, from a menu, the ribbon or the magnifier.
    var onZoomChange: (() -> Void)?
    /// Called with the image pixel under the pointer, or nil when it leaves the image.
    var onPointerMove: ((PixelPoint?) -> Void)?
    /// Called while a selection or a canvas handle is dragged, for the status bar.
    var onSelectionChange: (() -> Void)?
    /// Right click with the selection tool: the controller shows the shortcut menu.
    var onContextMenu: ((NSEvent) -> Void)?

    private var cachedImage: CGImage?

    /// View > Gridlines: lines between image pixels, shown from `RibbonTheme.gridMinimumZoom` up.
    var showsGrid = false { didSet { if oldValue != showsGrid { needsDisplay = true } } }
    /// Whether the gridlines are drawn at the current zoom.
    var drawsGrid: Bool { showsGrid && zoom >= RibbonTheme.gridMinimumZoom }
    /// The pixel under the pointer while the magnifier is chosen, for its preview rectangle.
    private(set) var magnifierPoint: PixelPoint? {
        didSet { if oldValue != magnifierPoint { needsDisplay = true } }
    }
    /// Called after the image is redrawn, for the thumbnail.
    var onRefresh: (() -> Void)?

    /// The text view over the text box being edited, while there is one.
    private(set) var textView: TextBoxView?
    /// Format and color last given to the text view, so typing is not disturbed by restyling.
    private var textStyle: (format: TextFormat, color: RGB)?
    /// Called when the text selected in the text box changes, which enables or disables Cut and Copy.
    var onTextSelectionChange: (() -> Void)?
    /// The app's pasteboard, for Cut, Copy and Paste inside a text box.
    var pasteboardProvider: () -> NSPasteboard = { .general }

    /// The tool and button of the gesture in progress; the tool is kept even if the selection changes.
    private struct Gesture {
        let tool: Tool
        let button: MouseButton
    }
    private var gesture: Gesture?

    /// A canvas handle being dragged: which one, and the size it would give.
    private struct CanvasDrag {
        let handle: Int
        let button: MouseButton
        var size: (width: Int, height: Int)
    }
    private var canvasDrag: CanvasDrag?

    init(document: PaintDocument) {
        self.document = document
        super.init(frame: .zero)
        toolbox.onChange = { [weak self] in self?.toolChanged() }
        // The airbrush keeps painting from its timer while the pointer rests.
        toolbox.brushTool.onSpray = { [weak self] in self?.refresh() }
        reload()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    var imageRect: CGRect {
        CGRect(x: CanvasView.inset, y: CanvasView.inset,
               width: CGFloat(document.bitmap.width) * zoom, height: CGFloat(document.bitmap.height) * zoom)
    }

    /// Call after the bitmap changes size or content from outside the view.
    func reload() {
        cachedImage = nil
        let rect = imageRect
        setFrameSize(NSSize(width: rect.maxX + CanvasView.trailing, height: rect.maxY + CanvasView.trailing))
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
        syncTextView()
        onRefresh?()
    }

    /// View rectangle of an area of image pixels.
    func viewRect(_ rect: PixelRect) -> CGRect {
        CGRect(x: CanvasView.inset + CGFloat(rect.x) * zoom, y: CanvasView.inset + CGFloat(rect.y) * zoom,
               width: CGFloat(rect.width) * zoom, height: CGFloat(rect.height) * zoom)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        if cachedImage == nil { cachedImage = document.bitmap.makeImage() }
        guard let image = cachedImage else { return }
        let rect = imageRect
        context.saveGState()
        context.interpolationQuality = .none
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
        // An opaque text box shows Color 2 behind the text view.
        if let edit = document.text, edit.opaque {
            document.color2.nsColor.setFill()
            viewRect(edit.rect).fill()
        }
        if drawsGrid { drawGrid(in: rect.intersection(dirtyRect), image: rect) }
        drawHandles(around: rect)
        drawSelection(context)
        if let preview = magnifierPreviewRect {
            context.saveGState()
            context.setLineWidth(1)
            context.setStrokeColor(RibbonTheme.selectionDashDark.cgColor)
            context.stroke(preview.insetBy(dx: 0.5, dy: 0.5))
            context.restoreGState()
        }
        if let drag = canvasDrag {
            let outline = CGRect(x: rect.minX, y: rect.minY, width: CGFloat(drag.size.width) * zoom,
                                 height: CGFloat(drag.size.height) * zoom).insetBy(dx: -0.5, dy: -0.5)
            dashed(outline, RibbonTheme.canvasResizeDash, dark: RibbonTheme.canvasResizeColor, light: nil, context)
        }
    }

    /// One-point lines on the pixel edges inside `area`, the visible part of the image at `image`.
    private func drawGrid(in area: CGRect, image: CGRect) {
        guard !area.isEmpty else { return }
        RibbonTheme.gridColor.setFill()
        let first = { (start: CGFloat, origin: CGFloat) in max(1, Int(floor((start - origin) / self.zoom))) }
        var column = first(area.minX, image.minX)
        while CGFloat(column) * zoom + image.minX < area.maxX, column < document.bitmap.width {
            NSRect(x: image.minX + CGFloat(column) * zoom, y: area.minY, width: 1, height: area.height).fill(using: .sourceOver)
            column += 1
        }
        var row = first(area.minY, image.minY)
        while CGFloat(row) * zoom + image.minY < area.maxY, row < document.bitmap.height {
            NSRect(x: area.minX, y: image.minY + CGFloat(row) * zoom, width: area.width, height: 1).fill(using: .sourceOver)
            row += 1
        }
    }

    /// The area the magnifier would show after a click, centred on the pointer and kept inside
    /// the image, as Paint outlines it while the magnifier moves over the picture.
    var magnifierPreviewRect: CGRect? {
        guard toolbox.kind == .magnifier, let point = magnifierPoint else { return nil }
        let next = CanvasView.steppedZoom(from: zoom, 1)
        guard next > zoom else { return nil }
        let visible = enclosingScrollView?.contentView.bounds.size ?? visibleRect.size
        let image = imageRect
        let width = min(image.width, visible.width * zoom / next), height = min(image.height, visible.height * zoom / next)
        guard width < image.width || height < image.height else { return nil }
        let center = NSPoint(x: image.minX + (CGFloat(point.x) + 0.5) * zoom, y: image.minY + (CGFloat(point.y) + 0.5) * zoom)
        let x = max(image.minX, min(center.x - width / 2, image.maxX - width))
        let y = max(image.minY, min(center.y - height / 2, image.maxY - height))
        return CGRect(x: floor(x), y: floor(y), width: floor(width), height: floor(height))
    }

    /// The three resize handles of the image: right, bottom and bottom-right corner.
    static func handleRects(around rect: CGRect) -> [CGRect] {
        let side = RibbonTheme.handleSize
        let right = rect.maxX + 1, bottom = rect.maxY + 1
        return [
            CGRect(x: right, y: floor(rect.midY - side / 2), width: side, height: side),
            CGRect(x: floor(rect.midX - side / 2), y: bottom, width: side, height: side),
            CGRect(x: right, y: bottom, width: side, height: side),
        ]
    }

    private func drawHandles(around rect: CGRect) {
        for handle in CanvasView.handleRects(around: rect) {
            RibbonTheme.handleBorder.setFill()
            handle.fill()
            RibbonTheme.handleFill.setFill()
            handle.insetBy(dx: 1, dy: 1).fill()
        }
    }

    // MARK: Selection

    /// The eight handles of a selection shown at `rect`, in `SelectionHandle` order.
    static func selectionHandleRects(_ rect: CGRect) -> [CGRect] {
        let side = RibbonTheme.selectionHandleSize
        let xs = [rect.minX, rect.midX, rect.maxX], ys = [rect.minY, rect.midY, rect.maxY]
        let spots = [(0, 0), (1, 0), (2, 0), (2, 1), (2, 2), (1, 2), (0, 2), (0, 1)]
        return spots.map { CGRect(x: floor(xs[$0.0] - side / 2), y: floor(ys[$0.1] - side / 2), width: side, height: side) }
    }

    private var selectionTool: SelectionTool { toolbox.selectionTool }

    /// What a press at `point` (view coordinates) would grab of the selection.
    func selectionHit(at point: NSPoint) -> SelectionHit {
        guard toolbox.kind == .select, let selection = document.selection else { return .outside }
        return CanvasView.boxHit(viewRect(selection.rect), point)
    }

    /// What a press at `point` (view coordinates) would grab of the shape being edited.
    func shapeHit(at point: NSPoint) -> SelectionHit {
        guard toolbox.kind == .shape, let rect = editedShapeRect else { return .outside }
        return CanvasView.boxHit(viewRect(rect), point)
    }

    /// Bounds of the shape being edited while its handles show.
    private var editedShapeRect: PixelRect? {
        guard let edit = document.shape, edit.stage == .complete, !toolbox.shapeTool.isDrawing else { return nil }
        return edit.shape.bounds
    }

    private static func boxHit(_ rect: CGRect, _ point: NSPoint) -> SelectionHit {
        // Well inside, the box itself wins, so a small one can still be dragged.
        if rect.insetBy(dx: 2, dy: 2).contains(point) { return .inside }
        let slop = RibbonTheme.handleHitSlop
        for (index, handle) in CanvasView.selectionHandleRects(rect).enumerated()
        where handle.insetBy(dx: -slop, dy: -slop).contains(point) {
            return .handle(SelectionHandle(rawValue: index)!)
        }
        return rect.contains(point) ? .inside : .outside
    }

    /// What a press at `point` (view coordinates) would grab of the text box: its handles, or its
    /// border to move it. The inside belongs to the text view.
    func textHit(at point: NSPoint) -> SelectionHit {
        guard let edit = document.text else { return .outside }
        let rect = viewRect(edit.rect)
        let slop = RibbonTheme.handleHitSlop
        for (index, handle) in CanvasView.selectionHandleRects(rect).enumerated()
        where handle.insetBy(dx: -slop, dy: -slop).contains(point) {
            return .handle(SelectionHandle(rawValue: index)!)
        }
        let band = RibbonTheme.textBorderBand
        return rect.insetBy(dx: -band, dy: -band).contains(point) ? .inside : .outside
    }

    /// Presses on the border and the handles of the text box come to the canvas, not the text view.
    override func hitTest(_ point: NSPoint) -> NSView? {
        if let view = textView, !view.isHidden {
            let local = convert(point, from: superview)
            let band = RibbonTheme.textBorderBand
            if textHit(at: local) != .outside, !view.frame.insetBy(dx: band, dy: band).contains(local) { return self }
        }
        return super.hitTest(point)
    }

    /// Size of the selection for the status bar, including one being marked, or of the shape being drawn.
    var selectionSizeForStatus: (width: Int, height: Int)? {
        if toolbox.kind == .text, let rect = document.text?.rect ?? toolbox.textTool.creatingRect { return (rect.width, rect.height) }
        if toolbox.kind == .shape, let edit = document.shape { return (edit.shape.bounds.width, edit.shape.bounds.height) }
        if let rect = selectionTool.markingRect, toolbox.kind == .select { return (rect.width, rect.height) }
        let path = selectionTool.path
        if toolbox.kind == .select, !path.isEmpty {
            let xs = path.map(\.x), ys = path.map(\.y)
            return (xs.max()! - xs.min()! + 1, ys.max()! - ys.min()! + 1)
        }
        return document.selectionSize
    }

    /// The size a canvas handle drag would give, while one is in progress.
    var pendingCanvasSize: (width: Int, height: Int)? { canvasDrag?.size }

    private func drawSelection(_ context: CGContext) {
        if let marking = selectionTool.markingRect, toolbox.kind == .select {
            dashed(viewRect(marking).insetBy(dx: -0.5, dy: -0.5), RibbonTheme.selectionDash,
                   dark: RibbonTheme.selectionDashDark, light: RibbonTheme.selectionDashLight, context)
            return
        }
        let path = selectionTool.path
        if toolbox.kind == .select, path.count > 0 {
            let line = NSBezierPath()
            for (index, point) in path.enumerated() {
                let spot = NSPoint(x: CanvasView.inset + (CGFloat(point.x) + 0.5) * zoom,
                                   y: CanvasView.inset + (CGFloat(point.y) + 0.5) * zoom)
                if index == 0 { line.move(to: spot) } else { line.line(to: spot) }
            }
            line.lineWidth = 1
            RibbonTheme.selectionDashDark.setStroke()
            line.stroke()
            return
        }
        if toolbox.kind == .shape, let rect = editedShapeRect {
            drawBox(viewRect(rect), context)
            return
        }
        if toolbox.kind == .text, let rect = toolbox.textTool.creatingRect {
            dashed(viewRect(rect).insetBy(dx: -0.5, dy: -0.5), RibbonTheme.selectionDash,
                   dark: RibbonTheme.selectionDashDark, light: RibbonTheme.selectionDashLight, context)
            return
        }
        if let edit = document.text {
            drawBox(viewRect(edit.rect), context)
            return
        }
        guard let selection = document.selection else { return }
        drawBox(viewRect(selection.rect), context)
    }

    /// Dashed outline and eight handles, around a selection or a shape being edited.
    private func drawBox(_ rect: CGRect, _ context: CGContext) {
        dashed(rect.insetBy(dx: -0.5, dy: -0.5), RibbonTheme.selectionDash,
               dark: RibbonTheme.selectionDashDark, light: RibbonTheme.selectionDashLight, context)
        for handle in CanvasView.selectionHandleRects(rect) {
            RibbonTheme.selectionHandleBorder.setFill()
            handle.fill()
            RibbonTheme.selectionHandleFill.setFill()
            handle.insetBy(dx: 1, dy: 1).fill()
        }
    }

    private func dashed(_ rect: CGRect, _ pattern: [CGFloat], dark: NSColor, light: NSColor?, _ context: CGContext) {
        context.saveGState()
        context.setLineWidth(1)
        if let light = light {
            context.setStrokeColor(light.cgColor)
            context.stroke(rect)
        }
        context.setLineDash(phase: 0, lengths: pattern)
        context.setStrokeColor(dark.cgColor)
        context.stroke(rect)
        context.restoreGState()
    }

    // MARK: Pointer

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    /// Reports the pixel under the pointer while it is over the image, and always while drawing.
    private func reportPointer(_ event: NSEvent) {
        let point = pixel(for: event)
        let inside = point.x >= 0 && point.y >= 0 && point.x < document.bitmap.width && point.y < document.bitmap.height
        onPointerMove?(inside || gesture != nil ? point : nil)
        magnifierPoint = inside && toolbox.kind == .magnifier && gesture == nil ? point : nil
    }

    override func mouseMoved(with event: NSEvent) { reportPointer(event) }
    override func mouseExited(with event: NSEvent) {
        onPointerMove?(nil)
        magnifierPoint = nil
    }

    private func pixel(for event: NSEvent) -> PixelPoint {
        let point = convert(event.locationInWindow, from: nil)
        return PixelPoint(x: Int(floor((point.x - CanvasView.inset) / zoom)),
                          y: Int(floor((point.y - CanvasView.inset) / zoom)))
    }

    /// Image pixel corner nearest to the pointer, for edges (canvas handles).
    private func corner(for event: NSEvent) -> PixelPoint {
        let point = convert(event.locationInWindow, from: nil)
        return PixelPoint(x: Int(((point.x - CanvasView.inset) / zoom).rounded()),
                          y: Int(((point.y - CanvasView.inset) / zoom).rounded()))
    }

    private func canvasHandle(at point: NSPoint) -> Int? {
        let slop = RibbonTheme.handleHitSlop
        return CanvasView.handleRects(around: imageRect).firstIndex { $0.insetBy(dx: -slop, dy: -slop).contains(point) }
    }

    private func begin(_ event: NSEvent, button: MouseButton) {
        window?.makeFirstResponder(self)
        // Pressing the other button mid-stroke cancels it, as in Paint.
        if gesture != nil || canvasDrag != nil { cancelStroke(); return }
        let location = convert(event.locationInWindow, from: nil)
        let point = pixel(for: event)
        let isSelect = toolbox.kind == .select, isShape = toolbox.kind == .shape, isText = toolbox.kind == .text
        if isSelect && button == .right {
            onContextMenu?(event)
            return
        }
        let hit = isShape ? shapeHit(at: location) : isText ? textHit(at: location) : selectionHit(at: location)
        if hit == .outside, let handle = canvasHandle(at: location) {
            document.fixSelection()
            document.fixShape()
            document.fixText()
            canvasDrag = CanvasDrag(handle: handle, button: button, size: (document.bitmap.width, document.bitmap.height))
            refresh()
            return
        }
        let inside = point.x >= 0 && point.y >= 0 && point.x < document.bitmap.width && point.y < document.bitmap.height
        if isShape, !inside, hit == .outside, document.shape?.stage == .complete {
            // A click on the workspace fixes the shape without starting another.
            finishShape()
            return
        }
        if isText, !inside, hit == .outside, document.text != nil {
            // A click on the workspace fixes the text box.
            finishText()
            return
        }
        // The selection tool also starts outside the image, to fix or grab a selection hanging off it;
        // a shape being edited takes handles, control points and vertices there too.
        guard inside || ((isSelect || (isShape && document.shape != nil) || (isText && hit != .outside))
                         && bounds.contains(location)) else { return }
        let tool = toolbox.current
        gesture = Gesture(tool: tool, button: button)
        if let shape = tool as? ShapeTool {
            shape.constrain = event.modifierFlags.contains(.shift)
            shape.clickCount = event.clickCount
            shape.begin(at: point, hit: hit, button: button, host: self)
            onSelectionChange?()
        } else if let text = tool as? TextTool {
            text.begin(at: point, hit: hit, button: button, host: self)
            onSelectionChange?()
        } else if let selection = tool as? SelectionTool {
            let flags = event.modifierFlags
            // Ctrl copies, as in Windows; Option does too, as on the Mac. Shift leaves a trail.
            selection.begin(at: point, hit: hit, copy: flags.contains(.control) || flags.contains(.option),
                            stamp: flags.contains(.shift), host: self)
        } else {
            tool.press(at: point, button: button, host: self)
        }
        refresh()
    }

    private func extend(_ event: NSEvent, button: MouseButton) {
        if var drag = canvasDrag, drag.button == button {
            let edge = corner(for: event)
            let size = document.bitmap
            drag.size = (drag.handle == 1 ? size.width : max(1, edge.x), drag.handle == 0 ? size.height : max(1, edge.y))
            canvasDrag = drag
            refresh()
            onSelectionChange?()
            return
        }
        guard let current = gesture, current.button == button else { return }
        (current.tool as? ShapeTool)?.constrain = event.modifierFlags.contains(.shift)
        current.tool.drag(to: pixel(for: event), host: self)
        refresh()
        if current.tool is SelectionTool || current.tool is ShapeTool || current.tool is TextTool { onSelectionChange?() }
    }

    private func end(_ event: NSEvent, button: MouseButton) {
        if let drag = canvasDrag, drag.button == button {
            extend(event, button: button)
            let size = canvasDrag?.size ?? drag.size
            canvasDrag = nil
            document.resizeCanvas(width: size.width, height: size.height)
            reload()
            onChange?()
            return
        }
        guard let current = gesture, current.button == button else { return }
        gesture = nil
        (current.tool as? ShapeTool)?.constrain = event.modifierFlags.contains(.shift)
        current.tool.release(at: pixel(for: event), host: self)
        refresh()
        focusText()
        onChange?()
    }

    private func cancelStroke() {
        if canvasDrag != nil {
            canvasDrag = nil
            refresh()
            onSelectionChange?()
        }
        guard let current = gesture else { return }
        gesture = nil
        current.tool.cancel(host: self)
        refresh()
        onSelectionChange?()
    }

    /// Redraws after the image or the selection changed.
    func refresh() {
        cachedImage = nil
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
        syncTextView()
        onRefresh?()
    }

    override func mouseDown(with event: NSEvent) {
        // Control-click is the Mac's secondary click.
        begin(event, button: event.modifierFlags.contains(.control) && toolbox.kind != .select ? .right : .left)
    }
    override func mouseDragged(with event: NSEvent) {
        extend(event, button: canvasDrag?.button ?? gesture?.button ?? .left)
        reportPointer(event)
    }
    override func mouseUp(with event: NSEvent) {
        end(event, button: canvasDrag?.button ?? gesture?.button ?? .left)
    }
    override func rightMouseDown(with event: NSEvent) { begin(event, button: .right) }
    override func rightMouseDragged(with event: NSEvent) { extend(event, button: .right); reportPointer(event) }
    override func rightMouseUp(with event: NSEvent) { end(event, button: .right) }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection([.control, .command, .option])
        if flags.isEmpty, event.keyCode == 53 { return cancelOperation(nil) }  // Esc
        // Enter and Return fix the shape being edited.
        if flags.isEmpty, gesture == nil, document.shape != nil, event.keyCode == 36 || event.keyCode == 76 {
            return finishShape()
        }
        // Delete throws away the shape being edited.
        if flags.isEmpty, gesture == nil, document.shape != nil, event.keyCode == 117 || event.keyCode == 51 {
            _ = tryToPerform(#selector(MainWindowController.delete(_:)), with: self)
            return
        }
        guard flags.isEmpty, document.selection != nil, gesture == nil else { return super.keyDown(with: event) }
        switch event.keyCode {
        case 123: nudge(-1, 0)
        case 124: nudge(1, 0)
        case 125: nudge(0, 1)
        case 126: nudge(0, -1)
        case 117, 51:  // Forward delete and Delete: Paint's Delete key.
            _ = tryToPerform(#selector(MainWindowController.delete(_:)), with: self)
        default: super.keyDown(with: event)
        }
    }

    /// The arrow keys move the selection one pixel, one undo step each.
    private func nudge(_ dx: Int, _ dy: Int) {
        document.nudgeSelection(dx: dx, dy: dy)
        refresh()
        onChange?()
    }

    // MARK: Zoom

    /// Next zoom level in `direction`, staying within Paint's 12.5% to 800%.
    static func steppedZoom(from zoom: CGFloat, _ direction: Int) -> CGFloat {
        let levels = MainWindowController.zoomLevels
        let current = levels.firstIndex(of: zoom) ?? levels.firstIndex(of: 1)!
        return levels[min(levels.count - 1, max(0, current + direction))]
    }

    func stepZoom(_ direction: Int, centeredOn point: PixelPoint) {
        zoom = CanvasView.steppedZoom(from: zoom, direction)
        guard let clip = enclosingScrollView?.contentView else { return }
        let visible = clip.bounds.size
        let target = NSPoint(x: CanvasView.inset + (CGFloat(point.x) + 0.5) * zoom,
                             y: CanvasView.inset + (CGFloat(point.y) + 0.5) * zoom)
        let origin = NSPoint(x: max(0, min(target.x - visible.width / 2, frame.width - visible.width)),
                             y: max(0, min(target.y - visible.height / 2, frame.height - visible.height)))
        scroll(origin)
    }

    /// Top-left image pixel of the visible area, where Paste puts the pasted image: the first pixel
    /// shown whole, so the pasted image's corner and handles are in view at any zoom. It stays
    /// inside the image even when the view shows only the margin past it.
    var visibleOrigin: PixelPoint {
        let visible = visibleRect
        let x = Int(ceil((visible.minX - CanvasView.inset) / zoom - 0.0001))
        let y = Int(ceil((visible.minY - CanvasView.inset) / zoom - 0.0001))
        return PixelPoint(x: max(0, min(x, document.bitmap.width - 1)), y: max(0, min(y, document.bitmap.height - 1)))
    }

    func returnToPreviousTool() { toolbox.returnToPrevious() }

    // MARK: Cursor

    override func resetCursorRects() {
        for (rect, cursor) in cursorAreas() { addCursorRect(rect, cursor: cursor) }
    }

    /// The areas of the view with their cursors, in the order they are added (later ones win).
    func cursorAreas() -> [(rect: CGRect, cursor: NSCursor)] {
        let tool = toolbox.current
        var areas: [(rect: CGRect, cursor: NSCursor)] = [
            (imageRect.intersection(visibleRect),
             ToolCursor.cursor(for: toolbox.kind, size: tool.size, zoom: zoom, brush: toolbox.brushTool.kind)),
        ]
        for (handle, cursor) in zip(CanvasView.handleRects(around: imageRect), ToolCursor.canvasHandles) {
            areas.append((handle, cursor))
        }
        let box: PixelRect?
        switch toolbox.kind {
        case .select: box = document.selection?.rect
        case .shape: box = editedShapeRect
        case .text: box = document.text?.rect
        default: box = nil
        }
        guard let area = box else { return areas }
        let rect = viewRect(area)
        areas.append((rect.intersection(visibleRect), ToolCursor.move))
        for (index, handle) in CanvasView.selectionHandleRects(rect).enumerated() {
            areas.append((handle, ToolCursor.cursor(for: SelectionHandle(rawValue: index)!)))
        }
        return areas
    }

    private func toolChanged() {
        if toolbox.kind != .magnifier { magnifierPoint = nil }
        // Picking another tool fixes the selection where it is, as in Paint.
        if toolbox.kind != .select, document.selection != nil {
            document.fixSelection()
            refresh()
        }
        // Another tool fixes the text box.
        if toolbox.kind != .text, document.text != nil { finishText() }
        // Another tool fixes the shape; a new size redraws it.
        if toolbox.kind == .shape {
            shapeOptionsChanged()
        } else if document.shape != nil {
            finishShape()
        }
        window?.invalidateCursorRects(for: self)
        onToolChange?()
    }

    // MARK: Shapes

    /// Fixes the shape being edited, as one undoable step.
    func finishShape() {
        guard document.shape != nil else { return }
        document.fixShape()
        refresh()
        onChange?()
    }

    /// Outline, fill or width changed: the shape being edited takes them at once.
    func shapeOptionsChanged() {
        let options = toolbox.shapeTool.options
        guard let edit = document.shape, edit.options != options else { return }
        document.updateShape { $0.options = options }
        refresh()
    }

    /// The colors changed: the shape being edited is drawn again with them, and the text box
    /// takes them at once.
    func redrawShape() {
        if document.text != nil { refresh() }
        guard document.shape != nil else { return }
        document.renderShape()
        refresh()
    }

    /// Throws away the shape being edited, as the Delete key does.
    func deleteShape() {
        guard document.discardShape() else { return }
        refresh()
        onChange?()
    }

    /// Esc cancels a gesture in progress, or else fixes the shape or the selection.
    override func cancelOperation(_ sender: Any?) {
        if gesture != nil || canvasDrag != nil {
            cancelStroke()
        } else if document.text != nil {
            finishText()
        } else if document.shape != nil {
            finishShape()
        } else if document.selection != nil {
            document.fixSelection()
            refresh()
            onChange?()
        }
    }
}

// MARK: Text

extension CanvasView {
    /// Fixes whatever is still being edited, a shape or a text box, as before saving.
    func finishEditing() {
        finishShape()
        finishText()
    }

    /// Draws the text box on the image (one undoable step, none when empty) and closes it.
    func finishText() {
        guard document.text != nil else { return }
        // Text still being composed with an input method is kept.
        if let view = textView, view.hasMarkedText() { view.unmarkText() }
        document.fixText()
        refresh()
        onChange?()
    }

    /// The format or the background of the text box changed: it takes them at once.
    func textFormatChanged() {
        let tool = toolbox.textTool
        guard document.text != nil else { return }
        document.updateText { edit in
            edit.format = tool.format
            edit.opaque = tool.opaque
        }
        refresh()
        onSelectionChange?()
    }

    /// Puts the keyboard focus back in the text box, after a drag of its border or a ribbon command.
    func focusText() {
        guard let view = textView, let window = window, window.firstResponder !== view else { return }
        window.makeFirstResponder(view)
    }

    /// Keeps the text view in step with the text box: shown over it at the current zoom, with
    /// its format and Color 1, or removed once the box is fixed or dropped.
    func syncTextView() {
        guard let edit = document.text else {
            if let view = textView {
                if window?.firstResponder === view { window?.makeFirstResponder(self) }
                view.removeFromSuperview()
                textView = nil
                textStyle = nil
            }
            return
        }
        let view: TextBoxView
        if let existing = textView {
            view = existing
        } else {
            view = TextBoxView()
            view.delegate = self
            view.pasteboardProvider = { [weak self] in self?.pasteboardProvider() ?? .general }
            view.onEscape = { [weak self] in self?.finishText() }
            addSubview(view)
            textView = view
            textStyle = nil
            window?.makeFirstResponder(view)
        }
        let frame = viewRect(edit.rect)
        if view.frame != frame || view.bounds.size != NSSize(width: edit.rect.width, height: edit.rect.height) {
            view.frame = frame
            // Bounds in image pixels: the view scales them by the zoom.
            view.bounds = NSRect(x: 0, y: 0, width: edit.rect.width, height: edit.rect.height)
            view.textContainer?.containerSize = NSSize(width: CGFloat(edit.rect.width), height: .greatestFiniteMagnitude)
            view.needsDisplay = true
        }
        let color = document.color1
        if textStyle?.format != edit.format || textStyle?.color != color {
            textStyle = (edit.format, color)
            let attributes = edit.format.attributes(color: color)
            if let storage = view.textStorage {
                storage.beginEditing()
                storage.setAttributes(attributes, range: NSRange(location: 0, length: storage.length))
                storage.endEditing()
            }
            view.typingAttributes = attributes
            view.needsDisplay = true
        }
        if view.string != edit.string, !view.hasMarkedText() { view.string = edit.string }
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard notification.object as? TextBoxView === textView else { return }
        onTextSelectionChange?()
    }

    /// Typing changes the text box, which grows down when the text no longer fits.
    func textDidChange(_ notification: Notification) {
        guard let view = textView, notification.object as? TextBoxView === view else { return }
        let string = view.string
        document.updateText { $0.string = string }
        refresh()
        onSelectionChange?()
    }
}
