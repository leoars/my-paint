import AppKit
import UniformTypeIdentifiers

/// Window that also answers the Windows shortcuts (Ctrl+S, Ctrl+Z, F12…).
final class PaintWindow: NSWindow {
    /// Sees every event first; true when it was used (the key tips).
    var eventFilter: ((NSEvent) -> Bool)?

    override func sendEvent(_ event: NSEvent) {
        if eventFilter?(event) == true { return }
        super.sendEvent(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if super.performKeyEquivalent(with: event) { return true }
        return performWindowsShortcut(event)
    }

    /// Control keys that reach the window without being taken as key equivalents.
    override func keyDown(with event: NSEvent) {
        if !performWindowsShortcut(event) { super.keyDown(with: event) }
    }

    /// Sends a Windows shortcut along this window's responder chain, from the canvas (or
    /// whatever has the focus) up to the controller, whether or not the window is key.
    func performWindowsShortcut(_ event: NSEvent) -> Bool {
        guard let action = PaintWindow.windowsShortcut(for: event) else { return false }
        if let responder = firstResponder, responder !== self, responder.tryToPerform(action, with: self) { return true }
        return tryToPerform(action, with: self)
    }

    /// The action of a Windows shortcut, or nil when the event is not one.
    static func windowsShortcut(for event: NSEvent) -> Selector? {
        guard event.type == .keyDown else { return nil }
        let flags = event.modifierFlags.intersection([.control, .command, .option, .shift])
        if flags.isEmpty, event.keyCode == 111 {  // F12
            return #selector(MainWindowController.saveDocumentAs(_:))
        }
        // Ctrl with + or -, on the main keyboard (with or without Shift) or the keypad.
        if flags == .control || flags == [.control, .shift] {
            switch event.keyCode {
            case 24, 69: return #selector(MainWindowController.growToolSize(_:))  // = +, keypad +
            case 27, 78: return #selector(MainWindowController.shrinkToolSize(_:))  // -, keypad -
            default: break
            }
        }
        // The same shortcuts answer to Cmd: a key remapper may turn Ctrl into Cmd before the key gets
        // here, and the menu bar cannot be relied on for Cmd, since the system's App Shortcuts can
        // rebind its items (to Ctrl, for one) and then nothing would match the Cmd key.
        if flags == [.control, .shift] || flags == [.command, .shift] {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "x": return #selector(MainWindowController.cropImage(_:))
            case "i": return #selector(MainWindowController.invertColors(_:))
            // Cmd+Shift+Z is the Mac's Redo.
            case "z" where flags.contains(.command): return #selector(MainWindowController.redoEdit(_:))
            default: return nil
            }
        }
        if flags.isEmpty, event.keyCode == 103 {  // F11
            return #selector(MainWindowController.viewFullScreen(_:))
        }
        // Shift+F10, or the menu key of PC keyboards: the context menu from the keyboard.
        if (flags == .shift && event.keyCode == 109) || (flags.isEmpty && event.keyCode == 110) {
            return #selector(MainWindowController.showContextMenuFromKeyboard(_:))
        }
        // F10 alone shows the key tips, as Alt does (Option alone, see KeyTipController).
        if flags.isEmpty && event.keyCode == 109 {
            return #selector(MainWindowController.toggleKeyTips(_:))
        }
        // Ctrl+F1, and Cmd+F1, minimize or restore the ribbon.
        if (flags == .control || flags == .command) && event.keyCode == 122 {
            return #selector(MainWindowController.toggleRibbonMinimized(_:))
        }
        guard flags == .control || flags == .command else { return nil }
        // Ctrl+B, Ctrl+I and Ctrl+U format a text box.
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "b": return #selector(MainWindowController.toggleTextBold(_:))
        case "i": return #selector(MainWindowController.toggleTextItalic(_:))
        case "u": return #selector(MainWindowController.toggleTextUnderline(_:))
        default: break
        }
        switch event.keyCode {
        case 116: return #selector(MainWindowController.zoomIn(_:))  // Page Up
        case 121: return #selector(MainWindowController.zoomOut(_:))  // Page Down
        default: break
        }
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "n": return #selector(MainWindowController.newDocument(_:))
        case "o": return #selector(MainWindowController.openDocument(_:))
        case "s": return #selector(MainWindowController.saveDocument(_:))
        case "z": return #selector(MainWindowController.undoEdit(_:))
        case "y": return #selector(MainWindowController.redoEdit(_:))
        case "a": return #selector(MainWindowController.selectAll(_:))
        case "c": return #selector(MainWindowController.copy(_:))
        case "x": return #selector(MainWindowController.cut(_:))
        case "v": return #selector(MainWindowController.paste(_:))
        // Ctrl+W resizes, as in Paint; Cmd+W stays with the system.
        case "w": return flags == .control ? #selector(MainWindowController.showResizeDialog(_:)) : nil
        case "r": return #selector(MainWindowController.toggleRulers(_:))
        case "g": return #selector(MainWindowController.toggleGridlines(_:))
        case "e": return #selector(MainWindowController.showImageProperties(_:))
        case "p": return #selector(MainWindowController.printImage(_:))
        default: return nil
        }
    }
}

final class MainWindowController: NSObject, NSWindowDelegate, NSMenuItemValidation {
    /// Zoom steps of the Paint zoom slider, 12.5% to 800%.
    static let zoomLevels: [CGFloat] = [0.125, 0.25, 0.5, 1, 2, 3, 4, 5, 6, 7, 8]
    /// Size of a new image. To be checked against the original in the fidelity pass.
    static let defaultSize = (width: 800, height: 600)
    static let showsStatusBarKey = "ShowStatusBar"

    let window: PaintWindow
    let scrollView = NSScrollView()
    let canvas: CanvasView
    private(set) var ribbon: RibbonView!
    let statusBar = StatusBarView(frame: NSRect(x: 0, y: 0, width: 800, height: RibbonTheme.statusBarHeight))
    private(set) var document: PaintDocument
    /// Which of Color 1 and Color 2 a palette click sets, like Paint's two color buttons.
    var activeColorSlot = ColorSlot.color1 { didSet { syncInterface() } }
    /// View > Status bar. Remembered between launches, as in Paint.
    var showsStatusBar = true {
        didSet {
            AppSettings.defaults.set(showsStatusBar, forKey: MainWindowController.showsStatusBarKey)
            layoutContent()
            syncInterface()
        }
    }
    /// Image pixel under the pointer, for the status bar.
    private(set) var pointer: PixelPoint?
    /// Size of the open file on disk, or nil for a new image.
    private(set) var fileSize: Int?
    /// Where Cut, Copy and Paste go; the tests use a private pasteboard. Launching with
    /// `-PasteboardName <name>` does the same for manual checks without touching the user's clipboard.
    var pasteboard = UserDefaults.standard.string(forKey: "PasteboardName").map { NSPasteboard(name: .init($0)) } ?? .general
    /// Shows a drawn menu with its top-left corner at a point of a view, in a `RibbonPopup`.
    /// The menu is not modal, so the tests can open it for real; they may also replace this.
    lazy var presentMenu: (RibbonMenuView, NSPoint, NSView) -> Void = { menu, point, view in
        RibbonPopup.show(menu, from: view, at: point)
    }
    /// Asks whether to enlarge the canvas for a larger pasted image; the tests answer it themselves.
    lazy var confirmEnlarge: () -> NSApplication.ModalResponse = { [unowned self] in self.askToEnlarge() }
    /// Shows why a picture could not be opened; the tests record it instead.
    lazy var reportOpenError: (Error) -> Void = { [unowned self] error in _ = self.runAlert(NSAlert(error: error)) }
    /// Picks the file for Paste from; the tests choose it themselves.
    lazy var choosePasteFile: () -> URL? = { [unowned self] in self.askForPasteFile() }

    // View tab state, remembered between launches as Paint does.
    var showsRulers = false {
        didSet {
            AppSettings.defaults.set(showsRulers, forKey: AppSettings.rulersKey)
            layoutContent()
            syncInterface()
        }
    }
    var showsGridlines = false {
        didSet {
            AppSettings.defaults.set(showsGridlines, forKey: AppSettings.gridlinesKey)
            canvas.showsGrid = showsGridlines
            syncInterface()
        }
    }
    var showsThumbnail = false {
        didSet {
            AppSettings.defaults.set(showsThumbnail, forKey: AppSettings.thumbnailKey)
            syncThumbnailPanel()
            syncInterface()
        }
    }
    /// Only the tabs of the ribbon show (Ctrl+F1). Remembered between launches.
    var isRibbonMinimized = false {
        didSet {
            guard oldValue != isRibbonMinimized else { return }
            AppSettings.defaults.set(isRibbonMinimized, forKey: AppSettings.ribbonMinimizedKey)
            keyTips.stop()
            ribbon.setMinimized(isRibbonMinimized)
            layoutContent()
            syncInterface()
        }
    }
    /// Option alone or F10 and the letters over the ribbon.
    private(set) lazy var keyTips = KeyTipController(controller: self)
    /// View > Interface text size.
    var interfaceSize = InterfaceSize.normal {
        didSet {
            AppSettings.defaults.set(interfaceSize.rawValue, forKey: AppSettings.interfaceSizeKey)
            applyInterfaceSize()
        }
    }
    let horizontalRuler = RulerView(.horizontal)
    let verticalRuler = RulerView(.vertical)
    let rulerCorner = RulerCornerView()
    var fullScreenWindow: FullScreenWindow?
    var savedPresentation: NSApplication.PresentationOptions?
    var thumbnailPanel: NSPanel?
    var settingsWindow: SettingsWindow?
    /// The 10 custom places of the palette, filled in order by Edit colors.
    var customColors = AppSettings.colors(AppSettings.customColorsKey, count: 10) {
        didSet { AppSettings.setColors(customColors, forKey: AppSettings.customColorsKey) }
    }
    /// Recent pictures of the application menu and File > Open Recent.
    let recentPictures = RecentPictures()
    /// Page setup shared by Print, Page setup and Print preview.
    lazy var printInfo: NSPrintInfo = MainWindowController.makePrintInfo()
    var printOptions = PrintOptions()
    /// The page setup sheet in progress and what follows it.
    var pageSetupContext: PageSetupContext?
    /// The pages of Print preview while it shows, in `previewScroll` instead of the canvas.
    var printPreview: PrintPreviewView?
    let previewScroll = NSScrollView()
    /// Print from the preview; the tests replace it so that nothing prints.
    lazy var startPrinting: () -> Void = { [unowned self] in self.printImage(nil) }
    /// Page setup from the preview, then what follows it; the tests replace it too.
    lazy var startPageSetup: (@escaping () -> Void) -> Void = { [unowned self] next in self.runPageSetup(then: next) }
    /// Sets the desktop picture; the tests use a fake one.
    var desktopPicture: DesktopPictureSetting = SystemDesktopPicture()
    /// Where the desktop picture files go.
    var wallpaperFolder = MainWindowController.defaultWallpaperFolder

    override init() {
        document = MainWindowController.blankDocument()
        canvas = CanvasView(document: document)
        window = PaintWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        super.init()
        ribbon = makeRibbon()
        ribbon.onTabDoubleClick = { [weak self] in self?.toggleRibbonMinimized(nil) }
        ribbon.onBodyPopupClose = { [weak self] in self?.keyTips.bodyPopupClosed() }
        window.eventFilter = { [weak self] event in self?.keyTips.filter(event) ?? false }
        showsStatusBar = AppSettings.bool(MainWindowController.showsStatusBarKey, default: true)

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = RibbonTheme.workspace
        scrollView.documentView = canvas
        previewScroll.hasVerticalScroller = true
        previewScroll.hasHorizontalScroller = true
        previewScroll.autohidesScrollers = true
        previewScroll.borderType = .noBorder
        previewScroll.drawsBackground = true
        previewScroll.backgroundColor = RibbonTheme.previewBackground
        previewScroll.isHidden = true
        canvas.onChange = { [weak self] in self?.updateTitle() }
        canvas.pasteboardProvider = { [weak self] in self?.pasteboard ?? .general }
        canvas.onTextSelectionChange = { [weak self] in self?.syncInterface() }
        canvas.onToolChange = { [weak self] in self?.syncInterface() }
        canvas.onZoomChange = { [weak self] in self?.syncInterface() }
        canvas.onSelectionChange = { [weak self] in self?.syncStatusBar() }
        canvas.onContextMenu = { [weak self] event in self?.showContextMenu(for: event) }
        canvas.onPointerMove = { [weak self] point in
            self?.pointer = point
            self?.statusBar.updatePosition(point)
            self?.syncRulers()
        }
        canvas.onRefresh = { [weak self] in self?.syncThumbnail() }
        statusBar.zoomOut.target = self
        statusBar.zoomOut.action = #selector(zoomOut(_:))
        statusBar.zoomIn.target = self
        statusBar.zoomIn.action = #selector(zoomIn(_:))
        statusBar.slider.target = self
        statusBar.slider.action = #selector(chooseZoom(_:))

        let content = WindowContentView()
        content.onLayout = { [weak self] in self?.layoutContent() }
        [menuStrip, ribbon, horizontalRuler, verticalRuler, rulerCorner, scrollView, previewScroll, statusBar].forEach { content.addSubview($0) }
        window.contentView = content
        window.delegate = self
        window.isReleasedWhenClosed = false
        // Observers do not run inside init, so the saved state is applied by hand.
        showsRulers = AppSettings.bool(AppSettings.rulersKey, default: false)
        showsGridlines = AppSettings.bool(AppSettings.gridlinesKey, default: false)
        canvas.showsGrid = showsGridlines
        interfaceSize = InterfaceSize.saved
        applyInterfaceSize()
        isRibbonMinimized = AppSettings.bool(AppSettings.ribbonMinimizedKey, default: false)
        ribbon.setMinimized(isRibbonMinimized)
        // Wide enough for every group of the Home tab, when the screen allows.
        let wide = MainWindowController.ribbonWidth(ribbon) * RibbonTheme.scale
        let screenWidth = (NSScreen.main?.visibleFrame.width ?? wide) - 40
        window.setContentSize(NSSize(width: min(wide, max(960, screenWidth)), height: 760))
        window.center()
        window.setFrameAutosaveName("MainWindow")
        window.makeFirstResponder(canvas)
        layoutContent()
        updateTitle()
        watchPasteboard()
        // The rulers and the thumbnail follow the scrolling.
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scrollView.contentView,
                                               queue: nil) { [weak self] _ in
            self?.syncRulers()
            self?.syncThumbnail()
        }
        showsThumbnail = AppSettings.bool(AppSettings.thumbnailKey, default: false)
        syncThumbnailPanel()
    }

    /// The Mac sends no notice when another app changes the clipboard, so its change count is
    /// checked every second to keep Paste enabled or disabled, as Paint does.
    private func watchPasteboard() {
        var seen = pasteboard.changeCount
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] timer in
            guard let self = self else { return timer.invalidate() }
            let count = self.pasteboard.changeCount
            if count != seen { seen = count; self.syncInterface() }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
    }

    /// Width that shows every group of the Home tab expanded, the Shapes gallery at its widest.
    static func ribbonWidth(_ ribbon: RibbonView) -> CGFloat {
        ceil(ribbon.pages[0].groups.map(\.fullWidth).reduce(0, +) + 2 * RibbonTheme.bodyMargin)
    }

    /// The menus inside the window, as in the other applications of the suite.
    let menuStrip = MenuStripView()

    /// Menu strip and ribbon on top, status bar at the bottom, the workspace in between.
    /// Everything but the picture is drawn at the interface factor (View > Interface text size).
    func layoutContent() {
        guard let content = window.contentView, ribbon != nil else { return }
        let bounds = content.bounds
        let scale = RibbonTheme.scale
        let stripHeight = MenuStripView.height * scale
        menuStrip.setScaledFrame(NSRect(x: 0, y: 0, width: bounds.width, height: stripHeight), scale: scale)
        // Everything below starts under the strip and the ribbon.
        let ribbonHeight = stripHeight + ribbon.preferredHeight * scale
        let statusHeight = RibbonTheme.statusBarHeight * scale
        let shownStatus = showsStatusBar ? statusHeight : 0
        ribbon.setScaledFrame(NSRect(x: 0, y: stripHeight, width: bounds.width, height: ribbonHeight - stripHeight), scale: scale)
        statusBar.isHidden = !showsStatusBar
        statusBar.setScaledFrame(NSRect(x: 0, y: bounds.height - shownStatus, width: bounds.width, height: statusHeight), scale: scale)
        let workHeight = max(0, bounds.height - ribbonHeight - shownStatus)
        // Print preview shows the pages over the whole workspace, without rulers.
        let previewing = printPreview != nil
        scrollView.isHidden = previewing
        previewScroll.isHidden = !previewing
        if previewing {
            [horizontalRuler, verticalRuler, rulerCorner].forEach { $0.isHidden = true }
            previewScroll.frame = NSRect(x: 0, y: ribbonHeight, width: bounds.width, height: workHeight)
            printPreview?.fitSize = previewScroll.contentSize
            return
        }
        let ruler = showsRulers ? RibbonTheme.rulerThickness * scale : 0
        [horizontalRuler, verticalRuler, rulerCorner].forEach { $0.isHidden = !showsRulers }
        if showsRulers {
            rulerCorner.setScaledFrame(NSRect(x: 0, y: ribbonHeight, width: ruler, height: ruler), scale: scale)
            horizontalRuler.setScaledFrame(NSRect(x: ruler, y: ribbonHeight, width: max(0, bounds.width - ruler), height: ruler), scale: scale)
            verticalRuler.setScaledFrame(NSRect(x: 0, y: ribbonHeight + ruler, width: ruler, height: max(0, workHeight - ruler)), scale: scale)
        }
        scrollView.frame = NSRect(x: ruler, y: ribbonHeight + ruler, width: max(0, bounds.width - ruler), height: max(0, workHeight - ruler))
        syncRulers()
    }

    /// Brings the ribbon and the status bar in line with the document, the tool and the zoom.
    func syncInterface() {
        guard ribbon != nil else { return }
        syncPrintPreview()
        syncRibbon()
        syncStatusBar()
        syncRulers()
        syncThumbnail()
    }

    /// Status bar only, cheap enough to run on every drag of a selection or a canvas handle.
    func syncStatusBar() {
        let bitmap = document.bitmap
        let size = canvas.pendingCanvasSize ?? (bitmap.width, bitmap.height)
        statusBar.update(position: pointer, selection: canvas.selectionSizeForStatus, imageWidth: size.width,
                         imageHeight: size.height, diskBytes: fileSize, zoom: canvas.zoom)
    }

    /// The status bar slider picked a zoom level.
    @objc func chooseZoom(_ sender: Any?) {
        guard let slider = sender as? ZoomSlider else { return }
        canvas.zoom = slider.zoom
        updateTitle()
    }

    private static func blankDocument() -> PaintDocument {
        PaintDocument(bitmap: Bitmap(width: defaultSize.width, height: defaultSize.height))
    }

    private func show(_ newDocument: PaintDocument) {
        // Colors belong to the window, not the file, so they survive New and Open (a black-and-white
        // picture keeps the black and white it starts with).
        if !newDocument.blackAndWhite {
            newDocument.color1 = document.color1
            newDocument.color2 = document.color2
        }
        newDocument.transparentSelection = document.transparentSelection
        document = newDocument
        canvas.document = newDocument
        canvas.scroll(.zero)
        fileSize = MainWindowController.fileSize(of: newDocument.url)
        updateTitle()
    }

    static func fileSize(of url: URL?) -> Int? {
        guard let url = url else { return nil }
        return (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
    }

    private var displayName: String { document.url?.lastPathComponent ?? L("untitled") }

    func updateTitle() {
        window.title = String(format: L("window.title"), displayName)
        window.representedURL = document.url
        window.isDocumentEdited = document.isDirty
        // Keeps Undo/Redo state current for accessibility clients, which read it without opening the menu.
        NSApp.mainMenu?.items.forEach { $0.submenu?.update() }
        syncInterface()
    }

    // MARK: File

    /// Asks about unsaved changes. Returns false when the user cancels.
    func confirmDiscardingChanges() -> Bool {
        // A shape or a text box still being edited counts as a change.
        canvas.finishEditing()
        guard document.isDirty else { return true }
        let alert = NSAlert()
        alert.messageText = String(format: L("save.prompt"), displayName)
        alert.addButton(withTitle: L("save.yes"))
        alert.addButton(withTitle: L("save.no"))
        alert.addButton(withTitle: L("cancel"))
        switch runAlert(alert) {
        case .alertFirstButtonReturn: return save()
        case .alertSecondButtonReturn: return true
        default: return false
        }
    }

    @objc func newDocument(_ sender: Any?) {
        guard confirmDiscardingChanges() else { return }
        show(MainWindowController.blankDocument())
    }

    @objc func openDocument(_ sender: Any?) {
        guard confirmDiscardingChanges() else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = ImageFormat.allCases.map(\.type)
        panel.allowsMultipleSelection = false
        guard runPanel(panel) == .OK, let url = panel.url else { return }
        load(url)
    }

    /// Opens a file chosen in Finder, after asking about unsaved changes.
    func open(_ url: URL) {
        guard confirmDiscardingChanges() else { return }
        load(url)
    }

    func load(_ url: URL) {
        do {
            let bitmap = try ImageFile.read(url)
            let opened = PaintDocument(bitmap: bitmap, url: url, format: ImageFormat(url: url) ?? .png)
            // A 1-bit BMP opens in black-and-white mode.
            opened.blackAndWhite = opened.format == .bmp && ImageFile.isOneBit(url) && opened.isBlackAndWhite
            show(opened)
            noteRecent(url)
        } catch {
            // A recent picture that can no longer be read leaves the list; the pins of the others stay.
            recentPictures.remove(url)
            reportOpenError(error)
        }
    }

    @objc func saveDocument(_ sender: Any?) { save() }
    @objc func saveDocumentAs(_ sender: Any?) { saveAs() }

    @discardableResult
    private func save() -> Bool {
        guard let url = document.url else { return saveAs() }
        return write(to: url, format: document.format)
    }

    /// Save As; `preferred` is the format picked in the application menu, if any.
    @discardableResult
    func saveAs(preferring preferred: ImageFormat? = nil) -> Bool {
        let panel = NSSavePanel()
        let formats = ImageFormat.allCases
        let initial = preferred ?? document.format
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.addItems(withTitles: formats.map { L($0.nameKey) })
        popup.selectItem(at: formats.firstIndex(of: initial) ?? 0)
        let chooser = FormatChooser(panel: panel, formats: formats)
        popup.target = chooser
        popup.action = #selector(FormatChooser.changed(_:))
        let label = NSTextField(labelWithString: L("save.type"))
        let row = NSStackView(views: [label, popup])
        row.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        panel.accessoryView = row
        panel.allowedContentTypes = [initial.type]
        panel.nameFieldStringValue = document.url?.deletingPathExtension().lastPathComponent ?? L("untitled")
        let response = runPanel(panel)
        let format = formats[max(0, popup.indexOfSelectedItem)]
        guard response == .OK, let url = panel.url else { return false }
        return write(to: url, format: format)
    }

    private func write(to url: URL, format: ImageFormat) -> Bool {
        canvas.finishEditing()
        do {
            try ImageFile.write(document.bitmap, to: url, format: format)
            document.url = url
            document.format = format
            document.isDirty = false
            fileSize = MainWindowController.fileSize(of: url)
            noteRecent(url)
            updateTitle()
            return true
        } catch {
            _ = runAlert(NSAlert(error: error))
            return false
        }
    }

    // MARK: Edit

    // Not named undo(_:): NSWindow answers that itself and would shadow this in the responder chain.
    @objc func undoEdit(_ sender: Any?) {
        if document.undo() { canvas.reload(); updateTitle() }
    }

    @objc func redoEdit(_ sender: Any?) {
        // Redo first fixes a shape or a text box being edited, which also changes the image.
        let editing = document.shape != nil || document.text != nil
        if document.redo() || editing { canvas.reload(); updateTitle() }
    }

    // MARK: View

    private func stepZoom(_ direction: Int) {
        canvas.zoom = CanvasView.steppedZoom(from: canvas.zoom, direction)
    }

    @objc func zoomIn(_ sender: Any?) { stepZoom(1); updateTitle() }
    @objc func zoomOut(_ sender: Any?) { stepZoom(-1); updateTitle() }
    @objc func zoomActual(_ sender: Any?) { canvas.zoom = 1; updateTitle() }

    // MARK: Window

    func windowShouldClose(_ sender: NSWindow) -> Bool { confirmDiscardingChanges() }

    /// Another app may have changed the clipboard, which enables or disables Paste.
    func windowDidBecomeKey(_ notification: Notification) { syncInterface() }
}

/// Window content that hands its layout to the controller.
private final class WindowContentView: FlippedView {
    var onLayout: (() -> Void)?

    override func resizeSubviews(withOldSize oldSize: NSSize) { onLayout?() }
}

/// Keeps the save panel's file extension in step with the chosen format.
private final class FormatChooser: NSObject {
    private let panel: NSSavePanel
    private let formats: [ImageFormat]

    init(panel: NSSavePanel, formats: [ImageFormat]) {
        self.panel = panel
        self.formats = formats
        super.init()
        // The popup holds its target weakly; the panel keeps this object alive.
        objc_setAssociatedObject(panel, "FormatChooser", self, .OBJC_ASSOCIATION_RETAIN)
    }

    @objc func changed(_ sender: NSPopUpButton) {
        panel.allowedContentTypes = [formats[max(0, sender.indexOfSelectedItem)].type]
    }
}
