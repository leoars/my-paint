import AppKit

/// The items of the Rotate menu, in the original order; the raw value is the menu tag.
enum RotateCommand: Int, CaseIterable {
    case right90, left90, rotate180, flipVertical, flipHorizontal

    var nameKey: String {
        switch self {
        case .right90: return "rotate.right"
        case .left90: return "rotate.left"
        case .rotate180: return "rotate.180"
        case .flipVertical: return "rotate.flipVertical"
        case .flipHorizontal: return "rotate.flipHorizontal"
        }
    }

    var icon: RibbonIcon {
        switch self {
        case .right90: return .rotateRight
        case .left90: return .rotateLeft
        case .rotate180: return .rotate180
        case .flipVertical: return .flipVertical
        case .flipHorizontal: return .flipHorizontal
        }
    }

    func apply(_ bitmap: Bitmap) -> Bitmap {
        switch self {
        case .right90: return bitmap.rotatedRight()
        case .left90: return bitmap.rotatedLeft()
        case .rotate180: return bitmap.rotated180()
        case .flipVertical: return bitmap.flippedVertically()
        case .flipHorizontal: return bitmap.flippedHorizontally()
        }
    }
}

/// Clipboard and Image commands: the Clipboard and Image groups, the Edit and Image menus
/// of the menu bar and the selection's shortcut menu all send these.
///
/// Cut, Copy, Paste, Delete and Select All use the standard Edit selectors on purpose:
/// NSWindow, NSView and NSApplication do not answer them, so from the canvas they reach this
/// controller (the window delegate), while text fields in dialogs and panels keep their own.
extension MainWindowController {
    // MARK: Clipboard

    // While a text box is open these work on its text (from the ribbon, which targets this controller).

    @objc func cut(_ sender: Any?) {
        if let view = canvas.textView { view.cut(sender); return syncInterface() }
        guard document.selection != nil else { return }
        copy(sender)
        document.deleteSelection()
        documentChanged()
    }

    @objc func copy(_ sender: Any?) {
        if let view = canvas.textView { view.copy(sender); return syncInterface() }
        guard let image = document.selectionImage() else { return }
        MainWindowController.write(image, to: pasteboard)
        syncInterface()
    }

    @objc func paste(_ sender: Any?) {
        if let view = canvas.textView { view.paste(sender); return syncInterface() }
        guard let image = MainWindowController.readImage(from: pasteboard) else { return }
        place(image)
    }

    /// Paste from: an image file pasted as a selection.
    @objc func pasteFromFile(_ sender: Any?) {
        guard let url = choosePasteFile() else { return }
        do {
            place(try ImageFile.read(url))
        } catch {
            _ = runAlert(NSAlert(error: error))
        }
    }

    /// The open panel of Paste from; the tests replace it through `choosePasteFile`.
    func askForPasteFile() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = ImageFormat.allCases.map(\.type)
        panel.allowsMultipleSelection = false
        guard runPanel(panel) == .OK else { return nil }
        return panel.url
    }

    /// Pastes `image` as a floating selection at the top-left of the visible area, after
    /// asking whether to enlarge a canvas that is too small for it. As in Paint, the question
    /// compares the image with the canvas size, wherever the window is scrolled. An enlarged
    /// canvas takes the image at its top-left corner, so the view scrolls back there.
    func place(_ image: Bitmap) {
        var enlarge = false
        if image.width > document.bitmap.width || image.height > document.bitmap.height {
            switch confirmEnlarge() {
            case .alertFirstButtonReturn: enlarge = true
            case .alertSecondButtonReturn: enlarge = false
            default: return
            }
        }
        canvas.toolbox.select(.select)
        document.paste(image, at: canvas.visibleOrigin, enlarge: enlarge)
        documentChanged()
        if enlarge { canvas.scroll(.zero) }
    }

    /// "The image is larger than the canvas": Yes enlarges, No pastes it clipped, Cancel stops.
    func askToEnlarge() -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = L("paste.enlarge.title")
        alert.informativeText = L("paste.enlarge.detail")
        alert.addButton(withTitle: L("yes"))
        alert.addButton(withTitle: L("no"))
        alert.addButton(withTitle: L("cancel"))
        return runAlert(alert)
    }

    static func write(_ bitmap: Bitmap, to pasteboard: NSPasteboard) {
        guard let image = bitmap.makeImage() else { return }
        let rep = NSBitmapImageRep(cgImage: image)
        pasteboard.clearContents()
        pasteboard.declareTypes([.png, .tiff], owner: nil)
        if let png = rep.representation(using: .png, properties: [:]) { pasteboard.setData(png, forType: .png) }
        if let tiff = rep.tiffRepresentation { pasteboard.setData(tiff, forType: .tiff) }
    }

    /// The image on `pasteboard`, at its pixel size; PNG and TIFF first, then anything NSImage reads.
    static func readImage(from pasteboard: NSPasteboard) -> Bitmap? {
        for type in [NSPasteboard.PasteboardType.png, .tiff] {
            if let data = pasteboard.data(forType: type),
               let source = CGImageSourceCreateWithData(data as CFData, nil),
               let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                return Bitmap(image: image)
            }
        }
        guard let image = NSImage(pasteboard: pasteboard) else { return nil }
        let rep = image.representations.compactMap { $0 as? NSBitmapImageRep }.first
        var rect = NSRect(x: 0, y: 0, width: rep?.pixelsWide ?? Int(image.size.width), height: rep?.pixelsHigh ?? Int(image.size.height))
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil).flatMap(Bitmap.init(image:))
    }

    static func hasImage(_ pasteboard: NSPasteboard) -> Bool {
        pasteboard.availableType(from: [.png, .tiff]) != nil || NSImage.canInit(with: pasteboard)
    }

    // MARK: Selection

    @objc func delete(_ sender: Any?) {
        if let view = canvas.textView { return view.deleteForward(sender) }
        // A shape still being edited goes away, as nothing was fixed yet.
        if document.shape != nil { return canvas.deleteShape() }
        guard document.selection != nil else { return }
        document.deleteSelection()
        documentChanged()
    }

    @objc func selectAll(_ sender: Any?) {
        if let view = canvas.textView { return view.selectAll(sender) }
        canvas.toolbox.select(.select)
        document.selectAll()
        selectionChanged()
    }

    @objc func invertSelection(_ sender: Any?) {
        document.invertSelection()
        selectionChanged()
    }

    /// Rectangular or free-form selection, from the Select menu; also picks the selection tool.
    @objc func chooseSelectionShape(_ sender: Any?) {
        guard let shape = SelectionShape(rawValue: senderTag(sender)) else { return }
        canvas.toolbox.selectionTool.shape = shape
        canvas.toolbox.select(.select)
        syncInterface()
    }

    @objc func toggleTransparentSelection(_ sender: Any?) {
        document.setTransparentSelection(!document.transparentSelection)
        documentChanged()
    }

    // MARK: Image

    @objc func cropImage(_ sender: Any?) {
        guard document.selection != nil else { return }
        document.cropToSelection()
        documentChanged()
    }

    @objc func rotateImage(_ sender: Any?) {
        guard let command = RotateCommand(rawValue: senderTag(sender)) else { return }
        document.transform { bitmap, _ in command.apply(bitmap) }
        documentChanged()
    }

    @objc func invertColors(_ sender: Any?) {
        document.invertColors()
        documentChanged()
    }

    @objc func showResizeDialog(_ sender: Any?) {
        let size = document.selection.map { ($0.rect.width, $0.rect.height) } ?? (document.bitmap.width, document.bitmap.height)
        let dialog = ResizeSkewDialog(width: size.0, height: size.1)
        dialog.onInvalid = { [weak self] message in
            let alert = NSAlert()
            alert.messageText = message
            _ = self?.runAlert(alert)
        }
        guard runDialog(dialog.window) == .OK, let result = dialog.result else { return }
        applyResize(result)
    }

    /// Resize and Skew, on the selection or the whole image.
    func applyResize(_ change: ResizeSkew) {
        let size = document.selection.map { ($0.rect.width, $0.rect.height) } ?? (document.bitmap.width, document.bitmap.height)
        guard change.width != size.0 || change.height != size.1 || change.skewHorizontal != 0 || change.skewVertical != 0 else { return }
        document.transform { bitmap, fill in
            bitmap.scaled(toWidth: change.width, height: change.height)
                .skewed(horizontal: change.skewHorizontal, vertical: change.skewVertical, fill: fill)
        }
        documentChanged()
    }

    /// The image or its history changed: redraw, retitle and resync.
    func documentChanged() {
        canvas.reload()
        updateTitle()
    }

    /// Only the selection changed (no undo step).
    func selectionChanged() {
        canvas.refresh()
        syncInterface()
    }

    // MARK: Menus

    private func item(_ key: String, _ action: Selector, tag: Int = 0, icon: RibbonIcon? = nil, key equivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: L(key), action: action, keyEquivalent: equivalent)
        item.tag = tag
        item.target = self
        item.image = icon?.menuImage
        return item
    }

    private func header(_ key: String) -> NSMenuItem {
        let item = NSMenuItem(title: L(key), action: nil, keyEquivalent: "")
        item.isEnabled = false
        // The drawn Select drop-down shows it as a section header.
        item.identifier = RibbonMenuEntry.headerIdentifier
        return item
    }

    func pasteMenuItems() -> [NSMenuItem] {
        [item("paste.paste", #selector(paste(_:)), icon: .paste),
         item("paste.from", #selector(pasteFromFile(_:)), icon: .pasteFrom)]
    }

    func selectMenuItems() -> [NSMenuItem] {
        [header("select.shapes"),
         item("select.rectangle", #selector(chooseSelectionShape(_:)), tag: SelectionShape.rectangle.rawValue, icon: .selectRectangle),
         item("select.freeForm", #selector(chooseSelectionShape(_:)), tag: SelectionShape.freeForm.rawValue, icon: .selectFreeForm),
         .separator(),
         header("select.options"),
         item("select.all", #selector(selectAll(_:)), icon: .selectAll),
         item("select.invert", #selector(invertSelection(_:)), icon: .invertSelection),
         item("select.delete", #selector(delete(_:)), icon: .deleteSelection),
         item("select.transparent", #selector(toggleTransparentSelection(_:)), icon: .transparentSelection)]
    }

    func rotateMenuItems() -> [NSMenuItem] {
        RotateCommand.allCases.map { item($0.nameKey, #selector(rotateImage(_:)), tag: $0.rawValue, icon: $0.icon) }
    }

    /// The shortcut menu of the selection tool, in the original order.
    func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        let rotate = NSMenuItem(title: L("context.rotate"), action: nil, keyEquivalent: "")
        rotate.image = RibbonIcon.rotate.menuImage
        rotate.submenu = NSMenu()
        rotateMenuItems().forEach(rotate.submenu!.addItem)
        [item("context.cut", #selector(cut(_:)), icon: .cut),
         item("context.copy", #selector(copy(_:)), icon: .copy),
         item("context.paste", #selector(paste(_:)), icon: .pasteFrom),
         .separator(),
         item("context.selectAll", #selector(selectAll(_:)), icon: .selectAll),
         item("context.invertSelection", #selector(invertSelection(_:)), icon: .invertSelection),
         item("context.delete", #selector(delete(_:)), icon: .deleteSelection),
         .separator(),
         rotate,
         item("context.resize", #selector(showResizeDialog(_:)), icon: .resize),
         item("context.invertColor", #selector(invertColors(_:)), icon: .invertColor)].forEach(menu.addItem)
        return menu
    }

    /// The drawn context menu, from the same items as `makeContextMenu`.
    func makeCanvasContextMenu() -> RibbonMenuView {
        makeRibbonMenu(makeContextMenu().items, name: "menu.context")
    }

    /// A right click with the selection tool: the context menu at the pointer.
    func showContextMenu(for event: NSEvent) {
        presentMenu(makeCanvasContextMenu(), canvas.convert(event.locationInWindow, from: nil), canvas)
    }

    /// Shift+F10: the same context menu, in the middle of the selection, or of the visible
    /// part of the image when nothing is selected. A text box keeps the keys to itself.
    @objc func showContextMenuFromKeyboard(_ sender: Any?) {
        guard document.text == nil else { return }
        let visible = canvas.visibleRect.intersection(canvas.imageRect)
        var area = visible.isNull ? canvas.imageRect : visible
        if let selection = document.selection {
            let selected = canvas.viewRect(selection.rect).intersection(area)
            if !selected.isNull { area = selected }
        }
        presentMenu(makeCanvasContextMenu(), NSPoint(x: area.midX, y: area.midY), canvas)
    }

    @objc func showPasteMenu(_ sender: Any?) { showRibbonMenu(pasteMenuItems(), name: "menu.paste", under: sender) }
    @objc func showSelectMenu(_ sender: Any?) { showRibbonMenu(selectMenuItems(), name: "menu.select", under: sender) }
    @objc func showRotateMenu(_ sender: Any?) { showRibbonMenu(rotateMenuItems(), name: "menu.rotate", under: sender) }

    /// The Image menu of the menu bar, mirroring the Image group.
    func makeImageMenu() -> NSMenu {
        let menu = NSMenu(title: L("menu.image"))
        let select = NSMenuItem(title: L("menu.select"), action: nil, keyEquivalent: "")
        select.submenu = NSMenu()
        selectMenuItems().forEach(select.submenu!.addItem)
        menu.addItem(select)
        let crop = item("menu.crop", #selector(cropImage(_:)), key: "X")
        menu.addItem(crop)
        let resize = item("menu.resize", #selector(showResizeDialog(_:)), key: "w")
        // Ctrl+W, as in Windows: Cmd+W stays the Mac's Close Window.
        resize.keyEquivalentModifierMask = .control
        menu.addItem(resize)
        let rotate = NSMenuItem(title: L("menu.rotate"), action: nil, keyEquivalent: "")
        rotate.submenu = NSMenu()
        rotateMenuItems().forEach(rotate.submenu!.addItem)
        menu.addItem(rotate)
        menu.addItem(.separator())
        menu.addItem(item("menu.invertColor", #selector(invertColors(_:)), key: "I"))
        return menu
    }
}

extension RibbonIcon {
    /// The icon as a 16-point image for menus.
    var menuImage: NSImage {
        NSImage(size: NSSize(width: 16, height: 16), flipped: true) { rect in
            self.draw(in: rect)
            return true
        }
    }
}
