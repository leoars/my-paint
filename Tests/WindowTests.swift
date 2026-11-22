import AppKit

/// Drives the real window and canvas with synthetic mouse events.
func runWindowTests() {
    _ = NSApplication.shared
    let controller = MainWindowController()
    let canvas = controller.canvas
    let black = RGB.black.packed, white = RGB.white.packed
    let red = RGB(r: 255, g: 0, b: 0)
    controller.document.color2 = red

    func send(_ type: NSEvent.EventType, _ x: Int, _ y: Int, _ flags: NSEvent.ModifierFlags = []) {
        let inView = NSPoint(x: CanvasView.inset + (CGFloat(x) + 0.5) * canvas.zoom,
                             y: CanvasView.inset + (CGFloat(y) + 0.5) * canvas.zoom)
        let event = NSEvent.mouseEvent(
            with: type, location: canvas.convert(inView, to: nil), modifierFlags: flags, timestamp: 0,
            windowNumber: controller.window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        switch type {
        case .leftMouseDown: canvas.mouseDown(with: event)
        case .leftMouseDragged: canvas.mouseDragged(with: event)
        case .leftMouseUp: canvas.mouseUp(with: event)
        case .rightMouseDown: canvas.rightMouseDown(with: event)
        case .rightMouseDragged: canvas.rightMouseDragged(with: event)
        case .rightMouseUp: canvas.rightMouseUp(with: event)
        default: break
        }
    }
    func item(_ action: Selector) -> NSMenuItem { NSMenuItem(title: "", action: action, keyEquivalent: "") }
    let undoItem = item(#selector(MainWindowController.undoEdit(_:)))
    let redoItem = item(#selector(MainWindowController.redoEdit(_:)))

    check(!controller.validateMenuItem(undoItem), "Undo starts disabled")
    let actions = ["newDocument:", "openDocument:", "saveDocument:", "saveDocumentAs:", "undoEdit:", "redoEdit:",
                   "zoomIn:", "zoomOut:", "zoomActual:", "chooseTool:", "chooseToolSize:", "growToolSize:",
                   "shrinkToolSize:", "chooseColorSlot:", "choosePaletteColor:", "swapColors:", "showSizeMenu:",
                   "toggleStatusBar:", "saveDocumentAsFormat:", "showAboutPanel:", "chooseZoom:",
                   "cut:", "copy:", "paste:", "pasteFromFile:", "delete:", "selectAll:", "invertSelection:",
                   "chooseSelectionShape:", "toggleTransparentSelection:", "cropImage:", "rotateImage:", "invertColors:",
                   "showResizeDialog:", "showPasteMenu:", "showSelectMenu:", "showRotateMenu:",
                   "chooseShape:", "chooseOutline:", "chooseShapeFill:", "showOutlineMenu:", "showShapeFillMenu:",
                   "chooseBrush:", "showBrushMenu:", "toggleTextBold:", "toggleTextItalic:", "toggleTextUnderline:",
                   "toggleTextStrikethrough:", "chooseTextBackground:", "chooseTextFontFamily:", "chooseTextFontSize:",
                   "toggleRulers:", "toggleGridlines:", "toggleThumbnail:", "viewFullScreen:", "showInterfaceSizeMenu:",
                   "chooseInterfaceSize:", "openAppSettings:", "printImage:", "showPageSetup:", "showPrintPreview:",
                   "setDesktopBackground:", "showImageProperties:", "showEditColors:", "openRecentPicture:",
                   "clearRecentPictures:", "showContextMenuFromKeyboard:", "toggleKeyTips:", "toggleRibbonMinimized:",
                   "closePrintPreview:", "printFromPreview:", "pageSetupFromPreview:", "zoomPreviewIn:", "zoomPreviewOut:",
                   "showNextPreviewPage:", "showPreviousPreviewPage:"].map(NSSelectorFromString)
    check(actions.allSatisfy { controller.responds(to: $0) && !controller.window.responds(to: $0) && !canvas.responds(to: $0)
                               && !NSApp.responds(to: $0) && !controller.ribbon.responds(to: $0) },
          "menu actions reach the controller, not the window or the view")

    send(.leftMouseDown, 10, 10)
    send(.leftMouseDragged, 30, 20)
    send(.leftMouseUp, 30, 20)
    let bitmap = controller.document.bitmap
    check(bitmap[10, 10] == black && bitmap[30, 20] == black && bitmap[20, 15] == black, "left drag draws with Color 1")
    check(controller.validateMenuItem(undoItem) && controller.window.isDocumentEdited, "a stroke enables Undo and marks the window edited")

    send(.rightMouseDown, 40, 40)
    send(.rightMouseDragged, 50, 40)
    send(.rightMouseUp, 50, 40)
    check(controller.document.bitmap[45, 40] == red.packed, "right drag draws with Color 2")

    controller.undoEdit(nil)
    check(controller.document.bitmap[45, 40] == white && controller.document.bitmap[10, 10] == black, "Undo removes only the last stroke")
    check(controller.validateMenuItem(redoItem), "Undo enables Redo")
    controller.redoEdit(nil)
    check(controller.document.bitmap[45, 40] == red.packed, "Redo restores the stroke")

    let before = controller.document.bitmap
    send(.leftMouseDown, 60, 60)
    send(.leftMouseDragged, 80, 80)
    send(.rightMouseDown, 80, 80)
    send(.leftMouseDragged, 90, 90)
    send(.leftMouseUp, 90, 90)
    check(controller.document.bitmap == before, "pressing the other button cancels the stroke")

    controller.zoomIn(nil)
    check(canvas.zoom == 2, "Zoom In goes from 100% to 200%")
    send(.leftMouseDown, 100, 100)
    send(.leftMouseUp, 100, 100)
    check(controller.document.bitmap[100, 100] == black && controller.document.bitmap[101, 100] == white, "a click at 200% paints one image pixel")
    for _ in 0..<20 { controller.zoomIn(nil) }
    check(canvas.zoom == 8, "zoom stops at 800%")
    for _ in 0..<20 { controller.zoomOut(nil) }
    check(canvas.zoom == 0.125, "zoom stops at 12.5%")

    controller.zoomActual(nil)
    let toolbox = canvas.toolbox
    func click(_ x: Int, _ y: Int, right: Bool = false, _ flags: NSEvent.ModifierFlags = []) {
        send(right ? .rightMouseDown : .leftMouseDown, x, y, flags)
        send(right ? .rightMouseUp : .leftMouseUp, x, y, flags)
    }
    func menuItem(_ action: Selector, tag: Int) -> NSMenuItem {
        let menuItem = item(action)
        menuItem.tag = tag
        return menuItem
    }

    // Shortcuts for the tool size: Ctrl with + or -, main keyboard and keypad.
    func key(_ code: UInt16, _ characters: String, _ flags: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                         windowNumber: controller.window.windowNumber, context: nil, characters: characters,
                         charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code)!
    }
    let grow = #selector(MainWindowController.growToolSize(_:)), shrink = #selector(MainWindowController.shrinkToolSize(_:))
    check(PaintWindow.windowsShortcut(for: key(24, "=", .control)) == grow
          && PaintWindow.windowsShortcut(for: key(24, "+", [.control, .shift])) == grow
          && PaintWindow.windowsShortcut(for: key(69, "+", [.control, .numericPad])) == grow,
          "Ctrl++ on the main keyboard and the keypad grows the tool")
    check(PaintWindow.windowsShortcut(for: key(27, "-", .control)) == shrink
          && PaintWindow.windowsShortcut(for: key(78, "-", [.control, .numericPad])) == shrink,
          "Ctrl+- on the main keyboard and the keypad shrinks the tool")
    check(PaintWindow.windowsShortcut(for: key(24, "=", .command)) == nil, "Cmd+= is left to the View menu")
    check(PaintWindow.windowsShortcut(for: key(6, "z", .control)) == #selector(MainWindowController.undoEdit(_:)),
          "Ctrl+Z still undoes")

    // Pencil sizes through the controller.
    controller.chooseTool(menuItem(#selector(MainWindowController.chooseTool(_:)), tag: ToolKind.pencil.rawValue))
    check(toolbox.kind == .pencil, "the Tools menu selects the pencil")
    check(!controller.validateMenuItem(item(shrink)), "Decrease Size is disabled at 1 px")
    controller.growToolSize(nil)
    controller.growToolSize(nil)
    check(toolbox.current.size == 3 && controller.validateMenuItem(item(shrink)), "Ctrl++ grows the pencil to 3 px")
    click(200, 200)
    check(pixels(of: controller.document.bitmap, equalTo: black).isSuperset(of: square(199, 199, 3, 3))
          && controller.document.bitmap[202, 200] == white, "a 3 px pencil click paints 3×3 pixels")
    controller.shrinkToolSize(nil)
    controller.shrinkToolSize(nil)
    check(toolbox.current.size == 1, "Ctrl+- brings the pencil back to 1 px")
    controller.chooseToolSize(menuItem(#selector(MainWindowController.chooseToolSize(_:)), tag: 4))
    let sizeItem = menuItem(#selector(MainWindowController.chooseToolSize(_:)), tag: 4)
    _ = controller.validateMenuItem(sizeItem)
    check(toolbox.current.size == 4 && sizeItem.state == .on, "the Size menu sets and shows 4 px")
    controller.chooseToolSize(menuItem(#selector(MainWindowController.chooseToolSize(_:)), tag: 1))

    // Palette and the two colors.
    controller.chooseColorSlot(menuItem(#selector(MainWindowController.chooseColorSlot(_:)), tag: 2))
    controller.choosePaletteColor(menuItem(#selector(MainWindowController.choosePaletteColor(_:)), tag: 8))
    check(controller.document.color2 == Palette.colors[8].color && controller.document.color1 == .black,
          "with Color 2 active a palette pick sets Color 2")
    let indigoItem = menuItem(#selector(MainWindowController.choosePaletteColor(_:)), tag: 8)
    _ = controller.validateMenuItem(indigoItem)
    check(indigoItem.state == .on, "the palette marks the active color")
    controller.chooseColorSlot(menuItem(#selector(MainWindowController.chooseColorSlot(_:)), tag: 1))
    controller.choosePaletteColor(menuItem(#selector(MainWindowController.choosePaletteColor(_:)), tag: 3))
    check(controller.document.color1 == Palette.colors[3].color, "with Color 1 active a palette pick sets Color 1")
    controller.swapColors(nil)
    check(controller.document.color1 == Palette.colors[8].color && controller.document.color2 == Palette.colors[3].color,
          "Swap exchanges Color 1 and Color 2")
    check(Palette.colors.count == 20 && Palette.colors[0].color == .black && Palette.colors[10].color == .white,
          "the palette has 20 colors, black first and white below it")
    controller.document.color1 = .black
    controller.document.color2 = red

    // Eraser with Control-click: only Color 1 pixels turn into Color 2.
    controller.chooseTool(menuItem(#selector(MainWindowController.chooseTool(_:)), tag: ToolKind.eraser.rawValue))
    check(toolbox.current.size == 8, "the eraser starts at 8 px")
    let beforeErase = controller.document.bitmap
    send(.leftMouseDown, 20, 15, .control)
    send(.leftMouseDragged, 30, 15, .control)
    send(.leftMouseUp, 30, 15, .control)
    check(controller.document.bitmap[20, 15] == red.packed && controller.document.bitmap[30, 12] == white,
          "Control-drag with the eraser replaces only Color 1")
    controller.undoEdit(nil)
    check(controller.document.bitmap == beforeErase, "undo reverts the eraser stroke")
    send(.leftMouseDown, 300, 300)
    send(.leftMouseDragged, 320, 300)
    send(.leftMouseUp, 320, 300)
    check(controller.document.bitmap[296, 296] == red.packed && controller.document.bitmap[323, 303] == red.packed
          && controller.document.bitmap[324, 300] == white, "left eraser drag paints an 8 px band of Color 2")

    // Bucket on the blank area, then undo.
    controller.chooseTool(menuItem(#selector(MainWindowController.chooseTool(_:)), tag: ToolKind.fill.rawValue))
    let beforeFill = controller.document.bitmap
    click(700, 500)
    check(controller.document.bitmap[799, 599] == black && controller.document.bitmap[0, 599] == black,
          "the bucket fills the white background with Color 1")
    check(controller.document.bitmap[300, 300] == red.packed, "the bucket does not cross other colors")
    controller.undoEdit(nil)
    check(controller.document.bitmap == beforeFill, "undo reverts the fill")

    // Color picker: picks and goes back to the bucket.
    controller.chooseTool(menuItem(#selector(MainWindowController.chooseTool(_:)), tag: ToolKind.colorPicker.rawValue))
    click(300, 300)
    check(controller.document.color1 == red && toolbox.kind == .fill, "the color picker sets Color 1 and returns to the bucket")
    controller.chooseTool(menuItem(#selector(MainWindowController.chooseTool(_:)), tag: ToolKind.colorPicker.rawValue))
    click(10, 10, right: true)
    check(controller.document.color2 == .black && toolbox.kind == .fill, "right click with the picker sets Color 2")
    let toolItem = menuItem(#selector(MainWindowController.chooseTool(_:)), tag: ToolKind.fill.rawValue)
    _ = controller.validateMenuItem(toolItem)
    check(toolItem.state == .on, "the Tools menu marks the selected tool")

    // Magnifier: zooms around the clicked pixel.
    controller.chooseTool(menuItem(#selector(MainWindowController.chooseTool(_:)), tag: ToolKind.magnifier.rawValue))
    click(400, 300)
    let visible = canvas.visibleRect
    let centre = (x: (visible.midX - CanvasView.inset) / canvas.zoom, y: (visible.midY - CanvasView.inset) / canvas.zoom)
    check(canvas.zoom == 2, "a magnifier click zooms in one level")
    check(abs(centre.x - 400.5) < 2 && abs(centre.y - 300.5) < 2, "the clicked pixel ends up in the middle of the view")
    click(400, 300, right: true)
    check(canvas.zoom == 1, "a right magnifier click zooms out one level")
    check(toolbox.kind == .magnifier, "the magnifier stays selected")
}

