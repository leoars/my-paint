import AppKit

/// Selection, clipboard and Image commands, first on the document and the tool alone,
/// then through the real window with synthetic mouse and keyboard events.
func runSelectionTests() {
    let white = RGB.white.packed, black = RGB.black.packed
    let red = RGB(r: 237, g: 28, b: 36).packed, blue = RGB(r: 63, g: 72, b: 204).packed
    let green = RGB(r: 34, g: 177, b: 76).packed

    func host(_ width: Int, _ height: Int, block: PixelRect? = nil) -> FakeHost {
        let host = FakeHost(width: width, height: height)
        host.document.color2 = RGB(packed: blue)
        if let block = block { host.document.draw { $0.fill(block, with: red) } }
        return host
    }
    func all(_ bitmap: Bitmap, _ rect: PixelRect, _ value: UInt32) -> Bool {
        (rect.y..<rect.maxY).allSatisfy { y in (rect.x..<rect.maxX).allSatisfy { x in bitmap[x, y] == value } }
    }
    let block = PixelRect(x: 5, y: 5, width: 10, height: 10)

    // Rectangular selection and moving it
    do {
        let h = host(40, 30, block: block), tool = SelectionTool(), document = h.document
        let original = document.bitmap
        stroke(tool, h, [(5, 5), (10, 9), (15, 15)])
        check(document.selection?.rect == block && !document.selection!.isFloating, "dragging marks a rectangle from corner to corner")
        check(!document.canUndo && document.bitmap == original, "marking an area is not an undo step")
        check(document.selectionSize! == (10, 10), "the selection size is known for the status bar")
        stroke(tool, h, [(8, 8), (18, 8), (28, 8)])
        let moved = document.bitmap
        check(all(moved, block.offsetBy(20, 0), red) && all(moved, block, blue) && moved[24, 5] == white && moved[35, 5] == white,
              "dragging the selection moves it and leaves Color 2 behind")
        check(document.selection?.rect == block.offsetBy(20, 0) && document.selection!.isFloating, "the moved selection keeps floating")
        stroke(tool, h, [(28, 8), (29, 8)])
        check(all(document.bitmap, block.offsetBy(21, 0), red) && document.bitmap[25, 5] == white,
              "moving it again does not leave a copy behind")
        document.undo()
        check(document.bitmap == moved && document.selection == nil, "undo takes back the last move and drops the selection")
        document.undo()
        check(document.bitmap == original && !document.canUndo, "the first move was a single undo step")
        document.redo()
        check(document.bitmap == moved, "redo moves it again")
    }

    // Ctrl+drag duplicates, Shift+drag stamps a trail, the other button cancels
    do {
        let h = host(40, 30, block: block), tool = SelectionTool(), document = h.document
        document.select(block)
        tool.begin(at: PixelPoint(x: 8, y: 8), hit: .inside, copy: true, stamp: false, host: h)
        tool.drag(to: PixelPoint(x: 28, y: 8), host: h)
        tool.release(at: PixelPoint(x: 28, y: 8), host: h)
        check(all(document.bitmap, block, red) && all(document.bitmap, block.offsetBy(20, 0), red), "Ctrl+drag leaves the original in place")
        document.undo()
        check(all(document.bitmap, block, red) && document.bitmap[30, 8] == white, "undo removes the duplicate")

        document.select(block)
        tool.begin(at: PixelPoint(x: 8, y: 8), hit: .inside, copy: false, stamp: true, host: h)
        for x in 9...18 { tool.drag(to: PixelPoint(x: x, y: 8), host: h) }
        tool.release(at: PixelPoint(x: 18, y: 8), host: h)
        check(all(document.bitmap, PixelRect(x: 5, y: 5, width: 20, height: 10), red) && document.bitmap[25, 8] == white,
              "Shift+drag stamps the selection all along the way")
        document.undo()
        check(all(document.bitmap, block, red) && document.bitmap[20, 8] == white, "the trail is one undo step")

        let before = document.bitmap
        document.select(block)
        tool.begin(at: PixelPoint(x: 8, y: 8), hit: .inside, copy: false, stamp: false, host: h)
        tool.drag(to: PixelPoint(x: 20, y: 8), host: h)
        tool.cancel(host: h)
        check(document.bitmap == before && document.selection?.rect == block, "cancelling a move puts everything back")
    }

    // Transparent selection
    do {
        let h = host(30, 10), document = h.document
        document.color2 = .white
        document.draw { $0.fill($0.bounds, with: green); $0.fill(PixelRect(x: 2, y: 2, width: 2, height: 4), with: red)
            $0.fill(PixelRect(x: 4, y: 2, width: 2, height: 4), with: white) }
        document.setTransparentSelection(true)
        document.select(PixelRect(x: 2, y: 2, width: 4, height: 4))
        document.nudgeSelection(dx: 10, dy: 0)
        let b = document.bitmap
        check(b[12, 3] == red && b[14, 3] == green && b[11, 3] == green, "with Transparent selection, Color 2 pixels let the image show")
        check(b[3, 3] == white && b[4, 3] == white, "the place it left takes Color 2")
        document.setTransparentSelection(false)
        check(document.bitmap[14, 3] == white, "turning transparency off redraws the floating selection opaque")
        document.undo()
        check(document.bitmap == b, "the switch is one undo step")
    }

    // Delete
    do {
        let h = host(40, 30, block: block), document = h.document
        document.select(PixelRect(x: 8, y: 8, width: 4, height: 4))
        document.deleteSelection()
        check(all(document.bitmap, PixelRect(x: 8, y: 8, width: 4, height: 4), blue) && document.bitmap[7, 8] == red
              && document.selection == nil, "Delete fills the selection with Color 2")
        document.undo()
        check(all(document.bitmap, block, red), "undo brings the deleted pixels back")
        document.select(block)
        document.nudgeSelection(dx: 20, dy: 0)
        document.deleteSelection()
        check(all(document.bitmap, block, blue) && document.bitmap[30, 8] == white, "deleting a moved selection drops its pixels")
    }

    // Free-form selection
    do {
        let triangle = [PixelPoint(x: 10, y: 2), PixelPoint(x: 18, y: 12), PixelPoint(x: 2, y: 12)]
        let area = Selection.freeFormMask(triangle)!
        let shape = Selection(rect: area.rect, mask: area.mask)
        check(area.rect == PixelRect(x: 2, y: 2, width: 17, height: 11), "the free-form outline bounds the selection")
        check(shape.contains(10, 8) && shape.contains(18, 12) && shape.contains(10, 2) && !shape.contains(3, 3) && !shape.contains(17, 3),
              "the free-form mask follows the outline")

        let h = host(40, 20, block: PixelRect(x: 0, y: 0, width: 20, height: 14)), tool = SelectionTool(), document = h.document
        tool.shape = .freeForm
        stroke(tool, h, [(10, 2), (14, 7), (18, 12), (10, 12), (2, 12), (6, 7), (10, 2)])
        check(document.selection?.rect == area.rect && document.selection?.mask != nil, "the tool marks a free-form area")
        let image = document.selectionImage()!
        check(image.width == 17 && image[8, 6] == red && image[1, 1] == blue, "copying a free-form area puts Color 2 outside the outline")
        stroke(tool, h, [(10, 9), (30, 9)])
        let b = document.bitmap
        check(b[30, 8] == red && b[23, 3] == white && b[10, 8] == blue && b[3, 3] == red,
              "moving a free-form selection moves only what is inside the outline")
    }

    // Invert selection and Select all
    do {
        let h = host(20, 20), document = h.document
        document.select(PixelRect(x: 5, y: 5, width: 5, height: 5))
        document.invertSelection()
        check(document.selection?.rect == document.bitmap.bounds, "the inverted selection spans the image")
        document.deleteSelection()
        check(document.bitmap[0, 0] == blue && document.bitmap[19, 19] == blue && all(document.bitmap, PixelRect(x: 5, y: 5, width: 5, height: 5), white),
              "deleting an inverted selection keeps only what was selected")
        document.selectAll()
        check(document.selection?.rect == document.bitmap.bounds && document.selection?.mask == nil, "Select all marks the whole image")
    }

    // Invert color
    do {
        let h = host(20, 20), document = h.document
        document.select(PixelRect(x: 0, y: 0, width: 5, height: 5))
        document.invertColors()
        check(document.bitmap[2, 2] == black && document.bitmap[6, 6] == white, "Invert color changes only the selection")
        document.fixSelection()
        document.invertColors()
        check(document.bitmap[2, 2] == white && document.bitmap[6, 6] == black, "without a selection it inverts the whole image")
        document.undo()
        document.undo()
        check(all(document.bitmap, document.bitmap.bounds, white), "each inversion is one undo step")
    }

    // Rotate and flip
    do {
        let values: [UInt32] = [1, 2, 3, 4, 5, 6]  // a b c / d e f
        let image = Bitmap(width: 3, height: 2, pixels: values)
        check(image.rotatedRight().pixels == [4, 1, 5, 2, 6, 3] && image.rotatedRight().width == 2, "rotate right 90° turns clockwise")
        check(image.rotatedLeft().pixels == [3, 6, 2, 5, 1, 4], "rotate left 90° turns counterclockwise")
        check(image.rotated180().pixels == [6, 5, 4, 3, 2, 1], "rotate 180° turns it upside down")
        check(image.flippedVertically().pixels == [4, 5, 6, 1, 2, 3], "flip vertical swaps top and bottom")
        check(image.flippedHorizontally().pixels == [3, 2, 1, 6, 5, 4], "flip horizontal swaps left and right")

        let h = host(30, 20, block: PixelRect(x: 2, y: 2, width: 4, height: 2)), document = h.document
        document.select(PixelRect(x: 2, y: 2, width: 4, height: 2))
        document.transform { bitmap, _ in bitmap.rotatedRight() }
        check(document.selection?.rect == PixelRect(x: 2, y: 2, width: 2, height: 4) && all(document.bitmap, PixelRect(x: 2, y: 2, width: 2, height: 4), red)
              && document.bitmap[4, 2] == blue, "rotating a selection turns it in place and leaves Color 2")
        document.undo()
        check(all(document.bitmap, PixelRect(x: 2, y: 2, width: 4, height: 2), red) && document.bitmap[2, 4] == white, "undo turns it back")
        document.transform { bitmap, _ in bitmap.rotatedLeft() }
        check(document.bitmap.width == 20 && document.bitmap.height == 30 && document.bitmap[2, 27] == red,
              "rotating with nothing selected turns the whole image")
        document.undo()
        check(document.bitmap.width == 30 && document.bitmap.height == 20, "undo restores the image size")
    }

    // Resize and skew
    do {
        let image = Bitmap(width: 2, height: 2, pixels: [1, 2, 3, 4])
        check(image.scaled(toWidth: 4, height: 2).pixels == [1, 1, 2, 2, 3, 3, 4, 4], "resizing stretches without smoothing")
        let square = Bitmap(width: 10, height: 10, value: 7)
        let right = square.skewed(horizontal: 45, vertical: 0, fill: 9)
        check(right.width == 19 && right.height == 10 && right[0, 0] == 7 && right[10, 0] == 9 && right[0, 9] == 9 && right[9, 9] == 7,
              "a 45° horizontal skew slides each row one pixel further")
        let left = square.skewed(horizontal: -45, vertical: 0, fill: 9)
        check(left.width == 19 && left[9, 0] == 7 && left[8, 0] == 9 && left[0, 9] == 7, "a negative skew slants the other way")
        let down = square.skewed(horizontal: 0, vertical: 45, fill: 9)
        check(down.width == 10 && down.height == 19 && down[9, 0] == 9 && down[9, 9] == 7, "a vertical skew slides each column")

        var form = ResizeSkewForm(width: 200, height: 100)
        form.editHorizontal("50")
        check(form.vertical == "50", "with the aspect ratio kept, the vertical percentage follows")
        form.setUnit(.pixels)
        check(form.horizontal == "100" && form.vertical == "50", "switching to pixels converts the values")
        form.editHorizontal("300")
        check(form.vertical == "150", "in pixels the other side keeps the proportion")
        form.keepsAspectRatio = false
        form.editVertical("10")
        check(form.horizontal == "300" && form.validate().change == ResizeSkew(width: 300, height: 10), "without the ratio each side is free")
        form.editHorizontal("0")
        check(form.validate().change == nil && form.validate().invalid == 1...1000, "a size out of range is refused")

        let dialog = ResizeSkewDialog(width: 200, height: 100)
        dialog.type("150", into: dialog.horizontalField)
        dialog.type("30", into: dialog.skewHorizontalField)
        check(dialog.verticalField.stringValue == "150" && dialog.keepRatio.state == .on && dialog.percentage.state == .on,
              "the dialog opens in percentage with the ratio kept")
        dialog.confirmDialog(nil)
        check(dialog.result == ResizeSkew(width: 300, height: 150, skewHorizontal: 30, skewVertical: 0), "OK gives the new size and skew")
        let wrong = ResizeSkewDialog(width: 200, height: 100)
        var message: String?
        wrong.onInvalid = { message = $0 }
        wrong.type("90", into: wrong.skewVerticalField)
        wrong.confirmDialog(nil)
        check(wrong.result == nil && message == "Enter a whole number between -89 and 89.", "an angle out of range shows a message")
        wrong.pixels.performClick(nil)
        check(wrong.horizontalField.stringValue == "200" && wrong.verticalField.stringValue == "100", "the Pixels button shows the size in pixels")
    }

    // Through the window: mouse, keyboard, clipboard, ribbon and menus.
    _ = NSApplication.shared
    let controller = MainWindowController()
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("local.mypaint.tests.\(UUID().uuidString)"))
    defer { pasteboard.releaseGlobally() }
    controller.pasteboard = pasteboard
    let canvas = controller.canvas, window = controller.window
    var document: PaintDocument { controller.document }
    func reset(_ width: Int = 60, _ height: Int = 40) {
        var bitmap = Bitmap(width: width, height: height)
        bitmap.fill(PixelRect(x: 10, y: 10, width: 10, height: 10), with: red)
        document.replaceImage(bitmap)
        document.color2 = RGB(packed: blue)
        canvas.reload()
        controller.syncInterface()
    }
    func mouse(_ type: NSEvent.EventType, _ x: CGFloat, _ y: CGFloat, _ flags: NSEvent.ModifierFlags = []) {
        let event = NSEvent.mouseEvent(with: type, location: canvas.convert(NSPoint(x: x, y: y), to: nil), modifierFlags: flags,
                                       timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0,
                                       clickCount: 1, pressure: 1)!
        switch type {
        case .leftMouseDown: canvas.mouseDown(with: event)
        case .leftMouseDragged: canvas.mouseDragged(with: event)
        case .leftMouseUp: canvas.mouseUp(with: event)
        default: break
        }
    }
    func pixelDrag(_ from: (Int, Int), _ to: (Int, Int), _ flags: NSEvent.ModifierFlags = []) {
        let at = { (p: (Int, Int)) in (CanvasView.inset + (CGFloat(p.0) + 0.5) * canvas.zoom, CanvasView.inset + (CGFloat(p.1) + 0.5) * canvas.zoom) }
        let a = at(from), b = at(to)
        mouse(.leftMouseDown, a.0, a.1, flags)
        mouse(.leftMouseDragged, (a.0 + b.0) / 2, (a.1 + b.1) / 2, flags)
        mouse(.leftMouseDragged, b.0, b.1, flags)
        mouse(.leftMouseUp, b.0, b.1, flags)
    }
    func key(_ code: UInt16, _ characters: String, _ flags: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: window.windowNumber,
                         context: nil, characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code)!
    }
    func ctrl(_ code: UInt16, _ letter: String, shift: Bool = false) -> Bool {
        window.performKeyEquivalent(with: key(code, shift ? letter.uppercased() : letter, shift ? [.control, .shift] : .control))
    }
    func menuItem(_ action: Selector, tag: Int = 0) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: action, keyEquivalent: "")
        item.tag = tag
        return item
    }
    let redBlock = PixelRect(x: 10, y: 10, width: 10, height: 10)
    func control(_ name: String) -> RibbonControl { controller.ribbon.control(name)! }

    // Mouse: mark, move, duplicate, status bar, tool change, Esc
    reset()
    control("home.select").perform()
    check(canvas.toolbox.kind == .select && control("home.select").isChecked, "the Select button picks the selection tool")
    let a = (CanvasView.inset + 10, CanvasView.inset + 10), b = (CanvasView.inset + 20, CanvasView.inset + 17)
    mouse(.leftMouseDown, a.0, a.1)
    mouse(.leftMouseDragged, b.0, b.1)
    check(controller.statusBar.selectionText == "10 × 7px", "the status bar shows the size while marking")
    mouse(.leftMouseUp, b.0, b.1)
    check(document.selection?.rect == PixelRect(x: 10, y: 10, width: 10, height: 7) && controller.statusBar.selectionText == "10 × 7px",
          "dragging on the canvas marks a selection and the status bar keeps its size")
    check(control("home.cut").isEnabled && control("home.copy").isEnabled && control("home.crop").isEnabled,
          "Cut, Copy and Crop are enabled with a selection")
    document.fixSelection()
    document.select(redBlock)
    pixelDrag((12, 12), (32, 12))
    check(all(document.bitmap, redBlock.offsetBy(20, 0), red) && all(document.bitmap, redBlock, blue), "dragging the selection moves it")
    check(ctrl(6, "z") && all(document.bitmap, redBlock, red) && document.selection == nil, "Ctrl+Z undoes the move")
    check(ctrl(16, "y") && all(document.bitmap, redBlock, blue), "Ctrl+Y redoes it")
    reset()
    document.select(redBlock)
    pixelDrag((12, 12), (32, 12), .control)
    check(all(document.bitmap, redBlock, red) && all(document.bitmap, redBlock.offsetBy(20, 0), red), "Ctrl+drag on the canvas duplicates")
    reset()
    document.select(redBlock)
    pixelDrag((12, 12), (22, 12), .shift)
    check(all(document.bitmap, PixelRect(x: 10, y: 10, width: 20, height: 10), red), "Shift+drag on the canvas leaves a trail")
    controller.chooseTool(menuItem(#selector(MainWindowController.chooseTool(_:)), tag: ToolKind.pencil.rawValue))
    check(document.selection == nil && all(document.bitmap, PixelRect(x: 10, y: 10, width: 20, height: 10), red),
          "picking another tool fixes the selection")
    controller.chooseSelectionShape(menuItem(#selector(MainWindowController.chooseSelectionShape(_:)), tag: SelectionShape.rectangle.rawValue))
    check(canvas.toolbox.kind == .select, "a selection shape picks the selection tool")
    document.select(redBlock)
    canvas.cancelOperation(nil)
    check(document.selection == nil, "Esc fixes the selection")

    // Selection handles stretch it.
    reset()
    document.select(redBlock)
    let handle = CanvasView.selectionHandleRects(canvas.viewRect(redBlock))[SelectionHandle.right.rawValue]
    check(canvas.selectionHit(at: NSPoint(x: handle.midX, y: handle.midY)) == .handle(.right), "the right handle is found under the pointer")
    mouse(.leftMouseDown, handle.midX, handle.midY)
    mouse(.leftMouseDragged, CanvasView.inset + 30, handle.midY)
    check(controller.statusBar.selectionText == "20 × 10px", "the status bar follows the stretched size")
    mouse(.leftMouseUp, CanvasView.inset + 30, handle.midY)
    check(document.selection?.rect == PixelRect(x: 10, y: 10, width: 20, height: 10)
          && all(document.bitmap, PixelRect(x: 10, y: 10, width: 20, height: 10), red), "dragging a handle stretches the selection")
    controller.undoEdit(nil)
    check(all(document.bitmap, redBlock, red) && document.bitmap[25, 15] == white, "undo takes back the stretch")

    // Keyboard: arrows and Delete
    reset()
    document.select(redBlock)
    canvas.keyDown(with: key(124, "\u{F703}", []))
    canvas.keyDown(with: key(125, "\u{F701}", []))
    check(document.selection?.rect == redBlock.offsetBy(1, 1) && document.bitmap[20, 20] == red && document.bitmap[10, 10] == blue,
          "the arrow keys move the selection one pixel")
    controller.undoEdit(nil)
    check(document.bitmap[20, 20] == white && document.bitmap[11, 10] == red && document.bitmap[10, 10] == blue, "each arrow is one undo step")
    controller.undoEdit(nil)
    document.select(redBlock)
    canvas.keyDown(with: key(117, "\u{F728}", []))
    check(all(document.bitmap, redBlock, blue) && document.selection == nil, "the Delete key erases the selection to Color 2")

    // Clipboard with Ctrl shortcuts, from the canvas and from the window
    reset()
    window.makeFirstResponder(canvas)
    check(!controller.validateMenuItem(menuItem(#selector(MainWindowController.copy(_:)))) && !control("home.copy").isEnabled,
          "Copy is disabled with nothing selected")
    check((control("home.paste") as! RibbonButton).isEnabled && !(control("home.paste") as! RibbonButton).isMainEnabled,
          "with an empty clipboard Paste is off but its menu part stays usable")
    check(ctrl(0, "a") && document.selection?.rect == document.bitmap.bounds && canvas.toolbox.kind == .select, "Ctrl+A selects the whole image")
    document.select(redBlock)
    check(ctrl(8, "c") && MainWindowController.readImage(from: pasteboard) == Bitmap(width: 10, height: 10, value: red),
          "Ctrl+C copies the selection to the pasteboard")
    check(pasteboard.types?.contains(.png) == true && pasteboard.types?.contains(.tiff) == true, "the copy is offered as PNG and TIFF")
    controller.syncInterface()
    check((control("home.paste") as! RibbonButton).isMainEnabled, "Paste is enabled once the clipboard holds an image")
    check(ctrl(7, "x") && all(document.bitmap, redBlock, blue) && document.selection == nil, "Ctrl+X cuts, leaving Color 2")
    canvas.scroll(.zero)
    check(ctrl(9, "v") && all(document.bitmap, PixelRect(x: 0, y: 0, width: 10, height: 10), red)
          && document.selection?.rect == PixelRect(x: 0, y: 0, width: 10, height: 10) && document.selection!.isFloating,
          "Ctrl+V pastes a floating selection at the top-left of the view")
    pixelDrag((2, 2), (32, 22))
    check(all(document.bitmap, PixelRect(x: 30, y: 20, width: 10, height: 10), red) && document.bitmap[0, 0] == white,
          "the pasted image can be dragged before it is fixed")
    check(ctrl(6, "z") && document.bitmap[0, 0] == red && document.bitmap[35, 25] == white, "Ctrl+Z undoes moving the pasted image")
    check(ctrl(6, "z") && document.bitmap[0, 0] == white && all(document.bitmap, redBlock, blue), "Ctrl+Z undoes the paste")
    check(ctrl(6, "z") && all(document.bitmap, redBlock, red), "Ctrl+Z undoes the cut")
    check(ctrl(16, "y") && all(document.bitmap, redBlock, blue), "Ctrl+Y redoes the cut")
    window.makeFirstResponder(nil)
    check(ctrl(0, "a") && document.selection?.rect == document.bitmap.bounds, "Ctrl+A works with the focus on the window itself")
    check(ctrl(9, "v") && document.selection?.isFloating == true, "Ctrl+V works with the focus on the window itself")
    check(ctrl(6, "z") && document.selection == nil, "Ctrl+Z works with the focus on the window itself")
    window.makeFirstResponder(canvas)
    check(PaintWindow.windowsShortcut(for: key(13, "w", .control)) == #selector(MainWindowController.showResizeDialog(_:))
          && PaintWindow.windowsShortcut(for: key(7, "X", [.control, .shift])) == #selector(MainWindowController.cropImage(_:))
          && PaintWindow.windowsShortcut(for: key(34, "I", [.control, .shift])) == #selector(MainWindowController.invertColors(_:)),
          "Ctrl+W, Ctrl+Shift+X and Ctrl+Shift+I are Resize and Skew, Crop and Invert color")
    check(PaintWindow.windowsShortcut(for: key(8, "c", .command)) == nil, "Cmd+C is left to the Edit menu")
    let standard = ["cut:", "copy:", "paste:", "delete:", "selectAll:"].map(NSSelectorFromString)
    check(standard.allSatisfy { !canvas.responds(to: $0) && !window.responds(to: $0) && !NSApp.responds(to: $0) && controller.responds(to: $0) },
          "the standard Edit selectors are answered only by the controller")
    document.select(redBlock)
    pasteboard.clearContents()
    check(canvas.tryToPerform(#selector(MainWindowController.copy(_:)), with: nil) && MainWindowController.readImage(from: pasteboard) != nil,
          "the Edit menu's Copy reaches the controller from the canvas")

    // Paste larger than the canvas
    reset(20, 10)
    MainWindowController.write(Bitmap(width: 30, height: 15, value: green), to: pasteboard)
    var asked = 0
    controller.confirmEnlarge = { asked += 1; return .alertThirdButtonReturn }
    controller.paste(nil)
    check(asked == 1 && document.bitmap.width == 20 && document.selection == nil && !document.canUndo, "Cancel pastes nothing")
    controller.confirmEnlarge = { .alertSecondButtonReturn }
    controller.paste(nil)
    check(document.bitmap.width == 20 && document.bitmap.height == 10 && document.bitmap[19, 9] == green
          && document.selection?.rect.width == 30, "No pastes it without enlarging the canvas")
    controller.undoEdit(nil)
    controller.confirmEnlarge = { .alertFirstButtonReturn }
    controller.paste(nil)
    check(document.bitmap.width == 30 && document.bitmap.height == 15 && document.bitmap[29, 14] == green, "Yes enlarges the canvas to fit")
    controller.undoEdit(nil)
    check(document.bitmap.width == 20 && document.bitmap.height == 10 && document.bitmap[0, 0] == white, "one undo step takes back the larger canvas")
    controller.confirmEnlarge = { .alertFirstButtonReturn }
    asked = 0
    MainWindowController.write(Bitmap(width: 5, height: 5, value: green), to: pasteboard)
    controller.confirmEnlarge = { asked += 1; return .alertFirstButtonReturn }
    controller.paste(nil)
    check(asked == 0 && document.bitmap.width == 20, "a smaller image pastes without asking")

    // Crop, rotate, resize and invert through the controller
    reset()
    document.select(redBlock)
    check(ctrl(7, "X", shift: true) && document.bitmap.width == 10 && document.bitmap.height == 10 && all(document.bitmap, document.bitmap.bounds, red),
          "Crop (Ctrl+Shift+X) keeps only the selection")
    controller.undoEdit(nil)
    check(document.bitmap.width == 60 && document.bitmap.height == 40 && document.bitmap[0, 0] == white, "undo takes back the crop")
    controller.rotateImage(menuItem(#selector(MainWindowController.rotateImage(_:)), tag: RotateCommand.right90.rawValue))
    check(document.bitmap.width == 40 && document.bitmap.height == 60 && document.bitmap[39 - 10, 10] == red, "Rotate right turns the image")
    controller.undoEdit(nil)
    document.select(PixelRect(x: 10, y: 10, width: 10, height: 5))
    controller.rotateImage(menuItem(#selector(MainWindowController.rotateImage(_:)), tag: RotateCommand.flipVertical.rawValue))
    controller.rotateImage(menuItem(#selector(MainWindowController.rotateImage(_:)), tag: RotateCommand.left90.rawValue))
    check(document.selection?.rect == PixelRect(x: 10, y: 10, width: 5, height: 10) && document.bitmap.width == 60,
          "rotating a selection keeps the image size")
    controller.undoEdit(nil)
    controller.undoEdit(nil)
    check(all(document.bitmap, redBlock, red) && document.bitmap[20, 10] == white, "undo takes back the selection's flip and rotation")
    controller.applyResize(ResizeSkew(width: 120, height: 80))
    check(document.bitmap.width == 120 && document.bitmap.height == 80 && all(document.bitmap, PixelRect(x: 20, y: 20, width: 20, height: 20), red),
          "Resize at 200% doubles the image")
    controller.undoEdit(nil)
    document.select(redBlock)
    controller.applyResize(ResizeSkew(width: 5, height: 5, skewHorizontal: 45))
    check(document.selection?.rect == PixelRect(x: 10, y: 10, width: 9, height: 5) && document.bitmap[10, 10] == red
          && document.bitmap[18, 10] == blue && document.bitmap[18, 14] == red && document.bitmap[10, 14] == blue
          && document.bitmap[15, 15] == blue && document.bitmap.width == 60, "Resize and Skew changes only the selection")
    controller.undoEdit(nil)
    check(all(document.bitmap, redBlock, red), "undo takes back the selection's resize")
    check(ctrl(34, "I", shift: true) && document.bitmap[0, 0] == black && document.bitmap[10, 10] == RGB(r: 18, g: 227, b: 219).packed,
          "Invert color (Ctrl+Shift+I) inverts the image")
    controller.undoEdit(nil)

    // Canvas handles
    reset()
    let image = canvas.imageRect
    let corner = CanvasView.handleRects(around: image)[2]
    mouse(.leftMouseDown, corner.midX, corner.midY)
    mouse(.leftMouseDragged, image.minX + 80, image.minY + 50)
    check(controller.statusBar.imageSizeText == "80 × 50px" && document.bitmap.width == 60, "dragging the corner handle shows the new size")
    mouse(.leftMouseUp, image.minX + 80, image.minY + 50)
    check(document.bitmap.width == 80 && document.bitmap.height == 50 && document.bitmap[70, 45] == blue && document.bitmap[10, 10] == red,
          "releasing it resizes the canvas, the new area in Color 2")
    let rightHandle = CanvasView.handleRects(around: canvas.imageRect)[0]
    mouse(.leftMouseDown, rightHandle.midX, rightHandle.midY)
    mouse(.leftMouseDragged, image.minX + 30, rightHandle.midY + 40)
    mouse(.leftMouseUp, image.minX + 30, rightHandle.midY + 40)
    check(document.bitmap.width == 30 && document.bitmap.height == 50, "the right handle changes only the width")
    controller.undoEdit(nil)
    check(document.bitmap.width == 80 && document.bitmap.height == 50, "undo restores the width")
    controller.undoEdit(nil)
    check(document.bitmap.width == 60 && document.bitmap.height == 40 && controller.statusBar.imageSizeText == "60 × 40px",
          "undo restores the original canvas")

    // Ribbon and menus
    let items = controller.makeContextMenu().items
    check(items.map(\.title) == ["Cut", "Copy", "Paste", "", "Select all", "Invert selection", "Delete", "", "Rotate", "Resize", "Invert color"],
          "the shortcut menu has the commands of the original")
    check(items[8].submenu?.items.map(\.title) == ["Rotate right 90°", "Rotate left 90°", "Rotate 180°", "Flip vertical", "Flip horizontal"],
          "its Rotate submenu lists the five turns")
    document.fixSelection()
    check(!controller.validateMenuItem(items[0]) && controller.validateMenuItem(items[4]), "Cut is disabled there without a selection")
    let selectItems = controller.selectMenuItems()
    check(selectItems.map(\.title) == ["Selection shapes", "Rectangular selection", "Free-form selection", "", "Selection options",
                                       "Select all", "Invert selection", "Delete", "Transparent selection"], "the Select menu lists its items")
    _ = controller.validateMenuItem(selectItems[1])
    _ = controller.validateMenuItem(selectItems[8])
    check(selectItems[1].state == .on && selectItems[8].state == .off, "the Select menu marks the shape and transparency")
    controller.toggleTransparentSelection(selectItems[8])
    _ = controller.validateMenuItem(selectItems[8])
    check(document.transparentSelection && selectItems[8].state == .on, "Transparent selection is a check item")
    controller.toggleTransparentSelection(selectItems[8])
    check(controller.pasteMenuItems().map(\.title) == ["Paste", "Paste from"], "the Paste menu offers Paste and Paste from")
    check((control("home.paste") as! RibbonButton).menuAction == #selector(MainWindowController.showPasteMenu(_:))
          && (control("home.select") as! RibbonButton).menuAction == #selector(MainWindowController.showSelectMenu(_:))
          && control("home.rotate").action == #selector(MainWindowController.showRotateMenu(_:)),
          "Paste and Select are split buttons and Rotate opens its menu")
    check(["home.paste", "home.select", "home.resize", "home.rotate"].allSatisfy { control($0).isEnabled }
          && !control("home.crop").isEnabled && !control("home.cut").isEnabled,
          "the Clipboard and Image groups are enabled, Crop and Cut only with a selection")
    let imageMenu = controller.makeImageMenu()
    check(imageMenu.items.map(\.title) == ["Select", "Crop", "Resize and Skew…", "Rotate", "", "Invert Color"]
          && imageMenu.items[2].keyEquivalent == "w" && imageMenu.items[2].keyEquivalentModifierMask == .control
          && imageMenu.items[1].keyEquivalent == "X", "the Image menu mirrors the Image group with its shortcuts")

    // The dialog opens centred on the window.
    let dialog = ResizeSkewDialog(width: 60, height: 40)
    controller.centerDialog(dialog.window)
    check(abs(dialog.window.frame.midX - window.frame.midX) < 1 || window.screen == nil, "the Resize and Skew dialog is centred on the window")
    // A real modal run centres the window on the screen as it shows it; the dialog is centred on
    // the main window again from inside the loop, even with the app in the background.
    if let screen = window.screen?.visibleFrame {
        let saved = window.frame
        window.setFrameOrigin(NSPoint(x: screen.minX, y: screen.minY))
        let modal = ResizeSkewDialog(width: 60, height: 40)
        var seen = NSRect.zero
        // Queued before the dialog's own work, so it looks one turn later.
        RunLoop.main.perform(inModes: [.modalPanel]) {
            RunLoop.main.perform(inModes: [.modalPanel]) {
                seen = modal.window.frame
                NSApp.abortModal()
            }
        }
        _ = controller.runDialog(modal.window)
        check(abs(seen.midX - window.frame.midX) < 1 && abs(seen.midY - window.frame.midY) < 1,
              "a dialog run modally stays centred on the main window, not on the screen")
        window.setFrame(saved, display: false)
    }
}
