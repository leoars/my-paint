import AppKit

/// Phase 8: pending behaviors finished in the fidelity pass.
func runFidelityTests() {
    let controller = MainWindowController()
    let window = controller.window
    let canvas = controller.canvas
    window.setFrame(NSRect(x: 0, y: 0, width: 1240, height: 860), display: false)
    func key(_ code: UInt16, _ characters: String, _ flags: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: window.windowNumber,
                         context: nil, characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code)!
    }

    // MARK: Shift+F10
    let f10 = String(UnicodeScalar(NSF10FunctionKey)!)
    check(PaintWindow.windowsShortcut(for: key(109, f10, .shift)) == #selector(MainWindowController.showContextMenuFromKeyboard(_:)),
          "Shift+F10 is the keyboard's context menu")
    check(PaintWindow.windowsShortcut(for: key(110, "", [])) == #selector(MainWindowController.showContextMenuFromKeyboard(_:)),
          "so is the menu key of PC keyboards")
    check(PaintWindow.windowsShortcut(for: key(109, f10, [])) == #selector(MainWindowController.toggleKeyTips(_:))
          && PaintWindow.windowsShortcut(for: key(109, f10, .command)) == nil,
          "F10 alone shows the key tips, as in Windows, and Cmd+F10 is left to the system")
    // MARK: Cmd answers like Ctrl
    check(PaintWindow.windowsShortcut(for: key(6, "z", .control)) == #selector(MainWindowController.undoEdit(_:))
          && PaintWindow.windowsShortcut(for: key(6, "z", .command)) == #selector(MainWindowController.undoEdit(_:)),
          "Ctrl+Z and Cmd+Z both undo, whatever the menu bar is bound to")
    check(PaintWindow.windowsShortcut(for: key(16, "y", .command)) == #selector(MainWindowController.redoEdit(_:))
          && PaintWindow.windowsShortcut(for: key(6, "Z", [.command, .shift])) == #selector(MainWindowController.redoEdit(_:))
          && PaintWindow.windowsShortcut(for: key(6, "Z", [.control, .shift])) == nil,
          "Cmd+Y and Cmd+Shift+Z redo; Ctrl+Shift+Z stays unbound")
    check(PaintWindow.windowsShortcut(for: key(0, "a", .command)) == #selector(MainWindowController.selectAll(_:))
          && PaintWindow.windowsShortcut(for: key(8, "c", .command)) == #selector(MainWindowController.copy(_:))
          && PaintWindow.windowsShortcut(for: key(7, "x", .command)) == #selector(MainWindowController.cut(_:))
          && PaintWindow.windowsShortcut(for: key(9, "v", .command)) == #selector(MainWindowController.paste(_:)),
          "Cmd+A, C, X and V edit like their Ctrl forms")
    check(PaintWindow.windowsShortcut(for: key(13, "w", .control)) == #selector(MainWindowController.showResizeDialog(_:))
          && PaintWindow.windowsShortcut(for: key(13, "w", .command)) == nil
          && PaintWindow.windowsShortcut(for: key(12, "q", .command)) == nil
          && PaintWindow.windowsShortcut(for: key(4, "h", .command)) == nil,
          "Ctrl+W resizes, while Cmd+W, Cmd+Q and Cmd+H are left to the system")
    canvas.document.invertColors()
    let afterDraw = canvas.document.bitmap
    check(canvas.document.canUndo && window.performKeyEquivalent(with: key(6, "z", .command))
          && canvas.document.bitmap != afterDraw && !canvas.document.canUndo,
          "Cmd+Z reaching the window undoes the last change")
    var shown: (menu: RibbonMenuView, point: NSPoint, view: NSView)?
    controller.presentMenu = { menu, point, view in shown = (menu, point, view) }
    window.makeFirstResponder(canvas)
    check(window.performKeyEquivalent(with: key(109, f10, .shift)) && shown != nil, "Shift+F10 opens a menu")
    if let shown = shown {
        let actions = shown.menu.entries.compactMap(\.action)
        check(shown.view === canvas && actions.contains(#selector(MainWindowController.cut(_:)))
              && actions.contains(#selector(MainWindowController.invertColors(_:))) && shown.menu.name == "menu.context",
              "it is the canvas's drawn context menu")
        let visible = canvas.visibleRect.intersection(canvas.imageRect)
        check(abs(shown.point.x - visible.midX) < 1 && abs(shown.point.y - visible.midY) < 1,
              "with nothing selected it opens in the middle of the visible image")
    }
    controller.document.select(PixelRect(x: 10, y: 20, width: 40, height: 30))
    shown = nil
    controller.showContextMenuFromKeyboard(nil)
    if let point = shown?.point {
        let selected = canvas.viewRect(PixelRect(x: 10, y: 20, width: 40, height: 30))
        check(abs(point.x - selected.midX) < 1 && abs(point.y - selected.midY) < 1, "with a selection it opens in its middle")
    } else {
        check(false, "Shift+F10 with a selection opens the menu")
    }

    // MARK: Split buttons light one part at a time
    guard let select = controller.ribbon.control("home.select") as? RibbonButton else {
        check(false, "the Select split button exists")
        return
    }
    controller.ribbon.selectPage(0)
    controller.ribbon.layoutSubtreeIfNeeded()
    func enter(_ point: NSPoint) {
        let event = NSEvent.mouseEvent(with: .mouseMoved, location: select.convert(point, to: nil), modifierFlags: [], timestamp: 0,
                                       windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 0, pressure: 0)!
        select.mouseEntered(with: event)
        select.mouseMoved(with: event)
    }
    func alpha(at point: NSPoint) -> CGFloat {
        guard let rep = select.bitmapImageRepForCachingDisplay(in: select.bounds) else { return -1 }
        select.cacheDisplay(in: select.bounds, to: rep)
        let scale = CGFloat(rep.pixelsWide) / select.bounds.width
        return rep.colorAt(x: Int(point.x * scale), y: Int(point.y * scale))?.alphaComponent ?? -1
    }
    let upper = NSPoint(x: 4, y: 10), lower = NSPoint(x: 4, y: select.bounds.height - 5)
    enter(upper)
    check(select.hoveredPart == .main, "the pointer over the icon is over the command part")
    check(alpha(at: upper) > 0.5 && alpha(at: lower) < 0.1, "only the command part lights up")
    enter(lower)
    check(select.hoveredPart == .menu, "the pointer over the label is over the menu part")
    check(alpha(at: lower) > 0.5 && alpha(at: upper) < 0.1, "only the menu part lights up")
    select.mouseExited(with: NSEvent.mouseEvent(with: .mouseMoved, location: .zero, modifierFlags: [], timestamp: 0,
                                                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 0, pressure: 0)!)
    check(select.hoveredPart == nil && alpha(at: upper) < 0.1 && alpha(at: lower) < 0.1, "leaving the button clears both parts")
    if let paste = controller.ribbon.control("home.paste") as? RibbonButton {
        paste.isMainEnabled = false
        let event = NSEvent.mouseEvent(with: .mouseMoved, location: paste.convert(upper, to: nil), modifierFlags: [], timestamp: 0,
                                       windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 0, pressure: 0)!
        paste.mouseEntered(with: event)
        let rep = paste.bitmapImageRepForCachingDisplay(in: paste.bounds)!
        paste.cacheDisplay(in: paste.bounds, to: rep)
        let scale = CGFloat(rep.pixelsWide) / paste.bounds.width
        check((rep.colorAt(x: Int(upper.x * scale), y: Int(upper.y * scale))?.alphaComponent ?? 1) < 0.1,
              "an unavailable command part does not light up")
        paste.mouseExited(with: event)
    }
    let plain = RibbonButton(.large, title: "x", icon: nil)
    plain.hover(at: NSPoint(x: 2, y: 2))
    check(plain.hoveredPart == nil, "plain buttons have no parts")
    window.orderOut(nil)
}
