import AppKit

/// Paint's page options beyond paper, orientation, margins and scale, which the Mac page setup
/// holds: fitting to a number of pages and centering on the page.
struct PrintOptions: Equatable {
    /// Fit to `columns` by `rows` pages instead of the scale of the page setup.
    var fitsToPages = false
    var columns = 1
    var rows = 1
    var centersHorizontally = false
    var centersVertically = false
}

/// Where the picture goes on each printed page. Pure, so the preview, the printout and the
/// tests share it.
struct PrintLayout {
    /// Paint prints at 96 pixels per inch at 100%.
    static let pointsPerPixel: CGFloat = 72.0 / 96.0

    let paper: CGSize
    /// The printable area of a page, in page coordinates with y going down.
    let printable: CGRect
    let imageSize: CGSize
    /// The printed size of the picture, in points.
    let printedSize: CGSize
    let columns: Int
    let rows: Int
    let options: PrintOptions

    init(paper: CGSize, margins: NSEdgeInsets, imageWidth: Int, imageHeight: Int, scale: CGFloat, options: PrintOptions) {
        self.paper = paper
        self.options = options
        let area = CGRect(x: margins.left, y: margins.top, width: max(1, paper.width - margins.left - margins.right),
                          height: max(1, paper.height - margins.top - margins.bottom))
        printable = area
        imageSize = CGSize(width: max(1, imageWidth), height: max(1, imageHeight))
        let natural = CGSize(width: imageSize.width * PrintLayout.pointsPerPixel, height: imageSize.height * PrintLayout.pointsPerPixel)
        var factor = max(0.01, scale)
        if options.fitsToPages {
            let across = CGFloat(max(1, options.columns)) * area.width / natural.width
            let down = CGFloat(max(1, options.rows)) * area.height / natural.height
            factor = min(across, down)
        }
        printedSize = CGSize(width: natural.width * factor, height: natural.height * factor)
        // A tiny tolerance keeps rounding from adding an empty page.
        columns = max(1, Int(ceil(printedSize.width / area.width - 0.0001)))
        rows = max(1, Int(ceil(printedSize.height / area.height - 0.0001)))
    }

    init(printInfo: NSPrintInfo, imageWidth: Int, imageHeight: Int, options: PrintOptions) {
        self.init(paper: printInfo.paperSize,
                  margins: NSEdgeInsets(top: printInfo.topMargin, left: printInfo.leftMargin,
                                        bottom: printInfo.bottomMargin, right: printInfo.rightMargin),
                  imageWidth: imageWidth, imageHeight: imageHeight, scale: printInfo.scalingFactor, options: options)
    }

    var pageCount: Int { columns * rows }

    /// The whole picture as placed for page `index` (row by row), in that page's coordinates.
    /// Only the part inside `printable` is printed.
    func imageRect(onPage index: Int) -> CGRect {
        let column = CGFloat(index % columns), row = CGFloat(index / columns)
        var x = printable.minX - column * printable.width
        var y = printable.minY - row * printable.height
        if columns == 1, options.centersHorizontally { x += (printable.width - printedSize.width) / 2 }
        if rows == 1, options.centersVertically { y += (printable.height - printedSize.height) / 2 }
        return CGRect(origin: CGPoint(x: x, y: y), size: printedSize)
    }

    /// Draws page `index` with its top-left corner at `origin`, `factor` points per page point,
    /// into a flipped graphics context.
    func draw(page index: Int, image: CGImage, at origin: CGPoint, factor: CGFloat = 1, in context: CGContext) {
        let place = imageRect(onPage: index)
        let clip = CGRect(x: origin.x + printable.minX * factor, y: origin.y + printable.minY * factor,
                          width: printable.width * factor, height: printable.height * factor)
        let rect = CGRect(x: origin.x + place.minX * factor, y: origin.y + place.minY * factor,
                          width: place.width * factor, height: place.height * factor)
        context.saveGState()
        context.clip(to: clip)
        context.interpolationQuality = .none
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }
}

/// The view handed to `NSPrintOperation`: one rectangle per page, stacked. The Mac puts each
/// page inside the printer's own margins (`inset`), so the view leaves them out and draws the
/// paper shifted by them: the picture lands where `PrintLayout` places it on the sheet.
final class PrintPageView: NSView {
    let layout: PrintLayout
    let image: CGImage?
    /// The printer's margins: left and top, and the size of the page inside them.
    let inset: CGPoint
    let pageSize: CGSize

    init(layout: PrintLayout, bitmap: Bitmap, imageable: CGRect) {
        self.layout = layout
        image = bitmap.makeImage()
        let paper = layout.paper
        let area = imageable.isEmpty ? CGRect(origin: .zero, size: paper) : imageable
        inset = CGPoint(x: area.minX, y: paper.height - area.maxY)
        pageSize = area.size
        super.init(frame: NSRect(x: 0, y: 0, width: area.width, height: area.height * CGFloat(layout.pageCount)))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isFlipped: Bool { true }

    override func knowsPageRange(_ range: NSRangePointer) -> Bool {
        range.pointee = NSRange(location: 1, length: layout.pageCount)
        return true
    }

    override func rectForPage(_ page: Int) -> NSRect {
        NSRect(x: 0, y: CGFloat(page - 1) * pageSize.height, width: pageSize.width, height: pageSize.height)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext, let image = image else { return }
        for page in 0..<layout.pageCount {
            let top = CGFloat(page) * pageSize.height
            guard rectForPage(page + 1).intersects(dirtyRect) else { continue }
            context.saveGState()
            context.clip(to: rectForPage(page + 1))
            layout.draw(page: page, image: image, at: CGPoint(x: -inset.x, y: top - inset.y), in: context)
            context.restoreGState()
        }
    }
}

extension MainWindowController {
    /// Paint's default margins are 0.75 inch (a conferir com o original).
    static let defaultMargin: CGFloat = 54

    static func makePrintInfo() -> NSPrintInfo {
        let info = (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo()
        info.topMargin = defaultMargin
        info.bottomMargin = defaultMargin
        info.leftMargin = defaultMargin
        info.rightMargin = defaultMargin
        info.scalingFactor = 1
        return info
    }

    var printLayout: PrintLayout {
        PrintLayout(printInfo: printInfo, imageWidth: document.bitmap.width, imageHeight: document.bitmap.height, options: printOptions)
    }

    /// The print job for the picture as it is. The page view does its own margins, scale and
    /// pages, so the job itself prints at 100% within the printer's margins only. `saveTo` writes a PDF instead
    /// of printing, which is what the tests use.
    func makePrintOperation(saveTo url: URL? = nil) -> NSPrintOperation {
        canvas.finishEditing()
        let job = (printInfo.copy() as? NSPrintInfo) ?? NSPrintInfo()
        job.scalingFactor = 1
        let paper = job.paperSize, imageable = job.imageablePageBounds
        job.topMargin = paper.height - imageable.maxY
        job.bottomMargin = imageable.minY
        job.leftMargin = imageable.minX
        job.rightMargin = paper.width - imageable.maxX
        job.horizontalPagination = .clip
        job.verticalPagination = .clip
        job.isHorizontallyCentered = false
        job.isVerticallyCentered = false
        if let url = url {
            job.jobDisposition = .save
            job.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url
        }
        let view = PrintPageView(layout: printLayout, bitmap: document.bitmap, imageable: imageable)
        let operation = NSPrintOperation(view: view, printInfo: job)
        operation.jobTitle = document.url?.lastPathComponent ?? L("untitled")
        if url != nil {
            operation.showsPrintPanel = false
            operation.showsProgressPanel = false
        }
        return operation
    }

    /// Print (Ctrl+P): the Mac print panel as a sheet on the window.
    @objc func printImage(_ sender: Any?) {
        let operation = makePrintOperation()
        operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }

    /// Page setup: the Mac page setup as a sheet, with Paint's fitting and centering below it.
    @objc func showPageSetup(_ sender: Any?) { runPageSetup(then: nil) }

    func runPageSetup(then next: (() -> Void)?) {
        let layout = NSPageLayout()
        let accessory = PageSetupAccessory(options: printOptions)
        layout.addAccessoryController(accessory)
        pageSetupContext = PageSetupContext(accessory: accessory, next: next)
        layout.beginSheet(with: printInfo, modalFor: window, delegate: self,
                          didEnd: #selector(pageLayoutDidEnd(_:returnCode:contextInfo:)), contextInfo: nil)
    }

    @objc func pageLayoutDidEnd(_ pageLayout: NSPageLayout, returnCode: Int, contextInfo: UnsafeMutableRawPointer?) {
        guard let context = pageSetupContext else { return }
        pageSetupContext = nil
        finishPageSetup(accepted: returnCode == NSApplication.ModalResponse.OK.rawValue, accessory: context.accessory)
        if let next = context.next { DispatchQueue.main.async(execute: next) }
    }

    /// Takes Paint's options from the page setup accessory when the page setup was accepted.
    func finishPageSetup(accepted: Bool, accessory: PageSetupAccessory) {
        guard accepted else { return }
        printOptions = accessory.options
    }

}

/// What to do when the page setup sheet ends.
struct PageSetupContext {
    let accessory: PageSetupAccessory
    let next: (() -> Void)?
}

/// Paint's Scaling and Centering options under the Mac page setup (a conferir com o original).
final class PageSetupAccessory: NSViewController {
    let fit = NSButton(checkboxWithTitle: L("pageSetup.fit"), target: nil, action: nil)
    let columnsField = NSTextField(string: "1")
    let rowsField = NSTextField(string: "1")
    let centerHorizontally = NSButton(checkboxWithTitle: L("pageSetup.centerHorizontally"), target: nil, action: nil)
    let centerVertically = NSButton(checkboxWithTitle: L("pageSetup.centerVertically"), target: nil, action: nil)

    init(options: PrintOptions) {
        super.init(nibName: nil, bundle: nil)
        title = L("pageSetup.title")
        fit.state = options.fitsToPages ? .on : .off
        columnsField.stringValue = String(options.columns)
        rowsField.stringValue = String(options.rows)
        centerHorizontally.state = options.centersHorizontally ? .on : .off
        centerVertically.state = options.centersVertically ? .on : .off
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func loadView() {
        let view = FlippedView(frame: NSRect(x: 0, y: 0, width: 360, height: 104))
        fit.frame = NSRect(x: 10, y: 8, width: 150, height: 20)
        fit.sizeToFit()
        let by = NSTextField(labelWithString: L("pageSetup.by"))
        let pages = NSTextField(labelWithString: L("pageSetup.pages"))
        columnsField.frame = NSRect(x: fit.frame.maxX + 6, y: 6, width: 40, height: 22)
        by.sizeToFit()
        by.frame.origin = NSPoint(x: columnsField.frame.maxX + 6, y: 9)
        rowsField.frame = NSRect(x: by.frame.maxX + 6, y: 6, width: 40, height: 22)
        pages.sizeToFit()
        pages.frame.origin = NSPoint(x: rowsField.frame.maxX + 6, y: 9)
        let centering = NSTextField(labelWithString: L("pageSetup.centering"))
        centering.sizeToFit()
        centering.frame.origin = NSPoint(x: 10, y: 42)
        centerHorizontally.sizeToFit()
        centerHorizontally.frame.origin = NSPoint(x: 24, y: 62)
        centerVertically.sizeToFit()
        centerVertically.frame.origin = NSPoint(x: 24, y: 82)
        [fit, columnsField, by, rowsField, pages, centering, centerHorizontally, centerVertically].forEach(view.addSubview)
        view.frame.size.width = max(360, pages.frame.maxX + 10)
        self.view = view
    }

    /// The options as the controls show them; page counts out of 1–99 fall back to 1.
    var options: PrintOptions {
        let count = { (field: NSTextField) in min(99, max(1, Int(field.stringValue.trimmingCharacters(in: .whitespaces)) ?? 1)) }
        return PrintOptions(fitsToPages: fit.state == .on, columns: count(columnsField), rows: count(rowsField),
                            centersHorizontally: centerHorizontally.state == .on, centersVertically: centerVertically.state == .on)
    }
}

/// The pages drawn as they will print, in the workspace while Print preview shows: paper,
/// margins, the picture and the page number. At zoom 1 the page fits the room it is given;
/// larger zooms make the view larger than that room, and its scroll view scrolls.
final class PrintPreviewView: FlippedView {
    var layout: PrintLayout { didSet { page = min(page, layout.pageCount - 1); resize() } }
    var image: CGImage { didSet { needsDisplay = true } }
    var page = 0 { didSet { if oldValue != page { needsDisplay = true } } }
    var zoom: CGFloat = 1 { didSet { if oldValue != zoom { resize() } } }
    /// Room the page fits at zoom 1 (the visible part of the workspace).
    var fitSize = NSSize(width: 400, height: 400) { didSet { if oldValue != fitSize { resize() } } }
    /// Keys while the preview has the focus (Esc, Page Up, Page Down…); true when used.
    var onKey: ((NSEvent) -> Bool)?

    init(frame: NSRect, layout: PrintLayout, image: CGImage) {
        self.layout = layout
        self.image = image
        super.init(frame: frame)
        fitSize = frame.size
        resize()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if onKey?(event) == true { return }
        super.keyDown(with: event)
    }

    /// Points of the view per page point.
    var factor: CGFloat {
        let room = NSSize(width: max(1, fitSize.width - 2 * RibbonTheme.previewRoom),
                          height: max(1, fitSize.height - 2 * RibbonTheme.previewRoom - RibbonTheme.previewLabelHeight))
        return min(room.width / layout.paper.width, room.height / layout.paper.height) * zoom
    }

    private func resize() {
        let paper = CGSize(width: floor(layout.paper.width * factor), height: floor(layout.paper.height * factor))
        let size = NSSize(width: max(fitSize.width, paper.width + 2 * RibbonTheme.previewRoom),
                          height: max(fitSize.height, paper.height + 2 * RibbonTheme.previewRoom + RibbonTheme.previewLabelHeight))
        if frame.size != size { setFrameSize(size) }
        needsDisplay = true
    }

    /// The paper, in the middle of the view, above the page number.
    var paperRect: CGRect {
        let size = CGSize(width: floor(layout.paper.width * factor), height: floor(layout.paper.height * factor))
        let height = bounds.height - RibbonTheme.previewLabelHeight
        return CGRect(x: floor(bounds.midX - size.width / 2), y: max(RibbonTheme.previewRoom, floor(height / 2 - size.height / 2)),
                      width: size.width, height: size.height)
    }

    var pageLabel: String { String(format: L("preview.page"), page + 1, layout.pageCount) }

    override func draw(_ dirtyRect: NSRect) {
        RibbonTheme.previewBackground.setFill()
        bounds.fill()
        let paper = paperRect
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowOffset = NSSize(width: 2, height: -2)
        shadow.shadowBlurRadius = 3
        shadow.shadowColor = NSColor(white: 0, alpha: 0.35)
        shadow.set()
        NSColor.white.setFill()
        paper.fill()
        NSGraphicsContext.restoreGraphicsState()
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let factor = paper.width / layout.paper.width
        layout.draw(page: page, image: image, at: paper.origin, factor: factor, in: context)
        // The margins, as dotted lines.
        let printable = layout.printable
        let margins = CGRect(x: paper.minX + printable.minX * factor, y: paper.minY + printable.minY * factor,
                             width: printable.width * factor, height: printable.height * factor)
        context.saveGState()
        context.setLineDash(phase: 0, lengths: [2, 2])
        context.setStrokeColor(RibbonTheme.previewMargin.cgColor)
        context.setLineWidth(1)
        context.stroke(margins.insetBy(dx: -0.5, dy: -0.5))
        context.restoreGState()
        // The page number under the paper.
        let attributes = RibbonTheme.attributes(color: RibbonTheme.previewLabel)
        let label = pageLabel as NSString
        let size = label.size(withAttributes: attributes)
        label.draw(at: NSPoint(x: floor(bounds.midX - size.width / 2), y: paper.maxY + floor((RibbonTheme.previewLabelHeight - size.height) / 2) + 2),
                   withAttributes: attributes)
    }
}

/// Print preview: a mode, not a dialog. The ribbon shows only its own tab (Print, Page setup,
/// Zoom in and out, Next and Previous page, Close print preview) and the workspace shows the
/// pages instead of the canvas, until Close or Esc.
extension MainWindowController {
    /// Zoom steps of the preview, times the size that fits the whole page (a conferir com o original).
    static let previewZoomLevels: [CGFloat] = [1, 1.5, 2, 3, 4]

    var isShowingPrintPreview: Bool { printPreview != nil }

    @objc func showPrintPreview(_ sender: Any?) {
        canvas.finishEditing()
        guard printPreview == nil, let image = document.bitmap.makeImage() else { return }
        RibbonPopup.current?.close()
        keyTips.stop()
        let preview = PrintPreviewView(frame: previewScroll.bounds, layout: printLayout, image: image)
        preview.onKey = { [weak self] event in self?.previewKey(event) ?? false }
        preview.setAccessibilityIdentifier("printPreview.pages")
        previewScroll.documentView = preview
        printPreview = preview
        // The preview tab needs the body; a minimized ribbon comes back as it was afterwards.
        if isRibbonMinimized { ribbon.setMinimized(false) }
        ribbon.setPrintPreview(true)
        layoutContent()
        window.makeFirstResponder(preview)
        syncInterface()
    }

    @objc func closePrintPreview(_ sender: Any?) {
        guard printPreview != nil else { return }
        RibbonPopup.current?.close()
        keyTips.stop()
        printPreview = nil
        previewScroll.documentView = nil
        ribbon.setPrintPreview(false)
        if isRibbonMinimized { ribbon.setMinimized(true) }
        layoutContent()
        window.makeFirstResponder(canvas)
        syncInterface()
    }

    /// Print in the preview: the same print panel as Ctrl+P; the preview stays.
    @objc func printFromPreview(_ sender: Any?) { startPrinting() }

    /// Page setup in the preview; the pages follow what was chosen.
    @objc func pageSetupFromPreview(_ sender: Any?) {
        startPageSetup { [weak self] in self?.syncInterface() }
    }

    @objc func zoomPreviewIn(_ sender: Any?) { stepPreviewZoom(1) }
    @objc func zoomPreviewOut(_ sender: Any?) { stepPreviewZoom(-1) }

    @objc func showNextPreviewPage(_ sender: Any?) {
        guard let preview = printPreview else { return }
        preview.page = min(preview.layout.pageCount - 1, preview.page + 1)
        syncInterface()
    }

    @objc func showPreviousPreviewPage(_ sender: Any?) {
        guard let preview = printPreview else { return }
        preview.page = max(0, preview.page - 1)
        syncInterface()
    }

    private func stepPreviewZoom(_ direction: Int) {
        guard let preview = printPreview else { return }
        let levels = MainWindowController.previewZoomLevels
        let index = levels.firstIndex(of: preview.zoom) ?? 0
        preview.zoom = levels[max(0, min(levels.count - 1, index + direction))]
        syncInterface()
    }

    /// Keys of the preview: Esc closes it, Page Down and → go to the next page, Page Up and ← to the previous one.
    private func previewKey(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return false }
        switch event.keyCode {
        case 53: closePrintPreview(nil)
        case 121, 124: showNextPreviewPage(nil)
        case 116, 123: showPreviousPreviewPage(nil)
        default: return false
        }
        return true
    }

    /// The pages follow the picture and the page setup while the preview shows.
    func syncPrintPreview() {
        guard let preview = printPreview else { return }
        preview.layout = printLayout
        if let image = document.bitmap.makeImage() { preview.image = image }
        preview.fitSize = previewScroll.contentSize
    }

    /// Enabled state of the preview's commands, or nil for the others.
    func previewCommandState(_ action: Selector) -> (enabled: Bool, checked: Bool?)? {
        let levels = MainWindowController.previewZoomLevels
        switch action {
        case #selector(printFromPreview(_:)), #selector(pageSetupFromPreview(_:)), #selector(closePrintPreview(_:)):
            return (isShowingPrintPreview, nil)
        case #selector(zoomPreviewIn(_:)): return ((printPreview?.zoom ?? levels.last!) < levels.last!, nil)
        case #selector(zoomPreviewOut(_:)): return ((printPreview?.zoom ?? levels[0]) > levels[0], nil)
        case #selector(showNextPreviewPage(_:)):
            return (printPreview.map { $0.page < $0.layout.pageCount - 1 } ?? false, nil)
        case #selector(showPreviousPreviewPage(_:)): return ((printPreview?.page ?? 0) > 0, nil)
        default: return nil
        }
    }
}
