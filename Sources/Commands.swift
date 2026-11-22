import AppKit

/// The tag of a menu item or ribbon control that sent an action.
func senderTag(_ sender: Any?) -> Int {
    if let item = sender as? NSMenuItem { return item.tag }
    if let view = sender as? NSView { return view.tag }
    return 0
}

/// Commands shared by the ribbon and the menu bar. Both read their enabled and checked
/// state from `commandState`, so the logic lives here once.
// Names avoid selectors AppKit already answers (changeColor:, undo:, toggleToolbarShown:…).
extension MainWindowController: NSMenuDelegate {
    @objc func chooseTool(_ sender: Any?) {
        guard let kind = ToolKind(rawValue: senderTag(sender)) else { return }
        canvas.toolbox.select(kind)
    }

    @objc func chooseToolSize(_ sender: Any?) { canvas.toolbox.setSize(senderTag(sender)) }
    @objc func growToolSize(_ sender: Any?) { canvas.toolbox.stepSize(1) }
    @objc func shrinkToolSize(_ sender: Any?) { canvas.toolbox.stepSize(-1) }

    /// The Size drop-down of the ribbon: the sizes of the current tool under the button.
    @objc func showSizeMenu(_ sender: Any?) {
        showRibbonMenu(sizeMenuItems(), style: .sizes, name: "menu.size", under: sender)
    }

    @objc func chooseColorSlot(_ sender: Any?) {
        activeColorSlot = ColorSlot(rawValue: senderTag(sender)) ?? .color1
    }

    /// A palette click sets Color 1 or Color 2, whichever button is selected.
    @objc func choosePaletteColor(_ sender: Any?) {
        guard let color = paletteColor(at: senderTag(sender)) else { return }
        switch activeColorSlot {
        case .color1: document.color1 = color
        case .color2: document.color2 = color
        }
        canvas.redrawShape()
        syncInterface()
    }

    @objc func swapColors(_ sender: Any?) {
        (document.color1, document.color2) = (document.color2, document.color1)
        canvas.redrawShape()
        syncInterface()
    }

    @objc func toggleStatusBar(_ sender: Any?) {
        showsStatusBar.toggle()
    }

    /// Save As with a format chosen in the application menu.
    @objc func saveDocumentAsFormat(_ sender: Any?) {
        let formats = ImageFormat.allCases
        let index = senderTag(sender)
        saveAs(preferring: formats.indices.contains(index) ? formats[index] : nil)
    }

    /// Enabled and checked state of a command; `checked` is nil for commands without one.
    func commandState(_ action: Selector, tag: Int) -> (enabled: Bool, checked: Bool?) {
        if let state = textCommandState(action, tag: tag) { return state }
        if let state = systemCommandState(action, tag: tag) { return state }
        if let state = previewCommandState(action) { return state }
        let toolbox = canvas.toolbox
        let levels = MainWindowController.zoomLevels
        switch action {
        case #selector(chooseTool(_:)): return (true, toolbox.kind.rawValue == tag)
        case #selector(chooseToolSize(_:)): return (true, toolbox.current.size == tag)
        case #selector(growToolSize(_:)): return (toolbox.canStepSize(1), nil)
        case #selector(shrinkToolSize(_:)): return (toolbox.canStepSize(-1), nil)
        case #selector(showSizeMenu(_:)): return (!toolbox.current.sizes.isEmpty, nil)
        case #selector(chooseColorSlot(_:)): return (true, activeColorSlot.rawValue == tag)
        case #selector(choosePaletteColor(_:)):
            guard let color = paletteColor(at: tag) else { return (false, false) }
            return (true, color == activeColor)
        case #selector(undoEdit(_:)): return (document.canUndo, nil)
        case #selector(redoEdit(_:)): return (document.canRedo, nil)
        case #selector(zoomIn(_:)): return (canvas.zoom < levels.last!, nil)
        case #selector(zoomOut(_:)): return (canvas.zoom > levels.first!, nil)
        case #selector(zoomActual(_:)): return (canvas.zoom != 1, nil)
        case #selector(toggleStatusBar(_:)): return (true, showsStatusBar)
        case #selector(cut(_:)), #selector(copy(_:)), #selector(cropImage(_:)), #selector(invertSelection(_:)):
            return (document.selection != nil, nil)
        case #selector(delete(_:)): return (document.selection != nil || document.shape != nil, nil)
        case #selector(paste(_:)): return (MainWindowController.hasImage(pasteboard), nil)
        case #selector(chooseSelectionShape(_:)): return (true, toolbox.selectionTool.shape.rawValue == tag)
        case #selector(toggleTransparentSelection(_:)): return (true, document.transparentSelection)
        case #selector(chooseBrush(_:)): return (true, toolbox.brushTool.kind.rawValue == tag)
        case #selector(showBrushMenu(_:)): return (true, nil)
        case #selector(chooseShape(_:)): return (true, toolbox.kind == .shape && toolbox.shapeTool.kind.rawValue == tag)
        case #selector(showOutlineMenu(_:)): return (toolbox.kind == .shape, nil)
        case #selector(showShapeFillMenu(_:)): return (toolbox.kind == .shape && toolbox.shapeTool.kind.canFill, nil)
        case #selector(chooseOutline(_:)), #selector(chooseShapeFill(_:)):
            let outline = action == #selector(chooseOutline(_:))
            let tool = toolbox.shapeTool
            guard let style = ShapeStyle(rawValue: tag) else { return (false, nil) }
            // Line and curve always keep an outline and never fill.
            var enabled = toolbox.kind == .shape
            if outline && style == .none && !tool.kind.canFill { enabled = false }
            if !outline && !tool.kind.canFill { enabled = false }
            return (enabled, (outline ? tool.outline : tool.fill) == style)
        default: return (true, nil)
        }
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        guard let action = item.action else { return true }
        let state = commandState(action, tag: item.tag)
        if let checked = state.checked { item.state = checked ? .on : .off }
        if action == #selector(chooseTextFontFamily(_:)), let family = item.representedObject as? String {
            item.state = family == canvas.toolbox.textTool.format.family ? .on : .off
        }
        if action == #selector(chooseColorSlot(_:)) {
            item.image = MainWindowController.swatch(item.tag == ColorSlot.color1.rawValue ? document.color1 : document.color2)
        }
        return state.enabled
    }

    // MARK: Menu bar mirror

    private static let sizeMenuTitle = "size"

    /// Mirror of the Tools and Size groups for the menu bar.
    func makeToolsMenu() -> NSMenu {
        let menu = NSMenu(title: L("menu.tools"))
        // The Shapes tool is chosen through its own menu, one item per shape; Brushes has a submenu.
        for kind in ToolKind.menuOrder {
            let item = menu.addItem(withTitle: L(kind.nameKey), action: #selector(chooseTool(_:)), keyEquivalent: "")
            item.tag = kind.rawValue
            item.target = self
        }
        let brushes = menu.addItem(withTitle: L("menu.brushes"), action: nil, keyEquivalent: "")
        brushes.submenu = NSMenu(title: L("menu.brushes"))
        brushMenuItems().forEach(brushes.submenu!.addItem)
        menu.addItem(.separator())
        let sizes = NSMenu(title: MainWindowController.sizeMenuTitle)
        sizes.delegate = self
        // The action only gives the item its state: disabled for tools without a size.
        let sizeItem = menu.addItem(withTitle: L("menu.size"), action: #selector(showSizeMenu(_:)), keyEquivalent: "")
        sizeItem.target = self
        sizeItem.submenu = sizes
        let grow = menu.addItem(withTitle: L("menu.sizeUp"), action: #selector(growToolSize(_:)), keyEquivalent: "+")
        grow.keyEquivalentModifierMask = .control
        let shrink = menu.addItem(withTitle: L("menu.sizeDown"), action: #selector(shrinkToolSize(_:)), keyEquivalent: "-")
        shrink.keyEquivalentModifierMask = .control
        [grow, shrink].forEach { $0.target = self }
        return menu
    }

    /// Mirror of the Colors group for the menu bar.
    func makeColorsMenu() -> NSMenu {
        let menu = NSMenu(title: L("menu.colors"))
        for slot in [ColorSlot.color1, .color2] {
            let item = menu.addItem(withTitle: L(slot == .color1 ? "color.1" : "color.2"),
                                    action: #selector(chooseColorSlot(_:)), keyEquivalent: "")
            item.tag = slot.rawValue
            item.target = self
        }
        let swap = menu.addItem(withTitle: L("menu.swapColors"), action: #selector(swapColors(_:)), keyEquivalent: "")
        swap.target = self
        let edit = menu.addItem(withTitle: L("menu.editColors"), action: #selector(showEditColors(_:)), keyEquivalent: "")
        edit.target = self
        menu.addItem(.separator())
        for (index, entry) in Palette.colors.enumerated() {
            let item = menu.addItem(withTitle: L(entry.nameKey), action: #selector(choosePaletteColor(_:)), keyEquivalent: "")
            item.tag = index
            item.target = self
            item.image = MainWindowController.swatch(entry.color)
        }
        return menu
    }

    /// One item per size of the current tool, each with a sample of the stroke.
    func sizeMenuItems() -> [NSMenuItem] {
        let sizes = canvas.toolbox.current.sizes
        guard !sizes.isEmpty else {
            let none = NSMenuItem(title: L("size.none"), action: nil, keyEquivalent: "")
            none.isEnabled = false
            return [none]
        }
        return sizes.map { size in
            let item = NSMenuItem(title: String(format: L("size.pixels"), size), action: #selector(chooseToolSize(_:)), keyEquivalent: "")
            item.tag = size
            item.target = self
            item.state = canvas.toolbox.current.size == size ? .on : .off
            item.image = MainWindowController.strokeSample(size)
            return item
        }
    }

    private static func strokeSample(_ size: Int) -> NSImage {
        NSImage(size: NSSize(width: 60, height: 12), flipped: true) { rect in
            NSColor.black.setFill()
            let height = CGFloat(min(size, 10))
            NSRect(x: 2, y: floor((rect.height - height) / 2), width: rect.width - 4, height: height).fill()
            return true
        }
    }

    static func swatch(_ color: RGB) -> NSImage {
        NSImage(size: NSSize(width: 16, height: 12), flipped: false) { rect in
            color.nsColor.setFill()
            rect.fill()
            NSColor.gray.setStroke()
            NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5)).stroke()
            return true
        }
    }

    /// Lists the sizes of the selected tool each time the Size submenu opens.
    func menuNeedsUpdate(_ menu: NSMenu) {
        switch menu.title {
        case MainWindowController.sizeMenuTitle:
            menu.removeAllItems()
            sizeMenuItems().forEach(menu.addItem)
        case MainWindowController.recentMenuTitle:
            menu.removeAllItems()
            recentMenuItems().forEach(menu.addItem)
        default: break
        }
    }

    /// The color at a palette place: the 20 standard colors, then the 10 custom places.
    func paletteColor(at index: Int) -> RGB? {
        // Black-and-white mode keeps only black and white, in their usual places.
        if document.blackAndWhite { return Palette.blackAndWhiteIndices.contains(index) ? Palette.colors[index].color : nil }
        if Palette.colors.indices.contains(index) { return Palette.colors[index].color }
        let custom = index - Palette.colors.count
        return customColors.indices.contains(custom) ? customColors[custom] : nil
    }
}
