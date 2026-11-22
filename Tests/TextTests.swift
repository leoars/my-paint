import AppKit

/// The Text tool: layout and drawing on their own, then the box, the Text tab and the shortcuts
/// through the window with synthetic events.
func runTextTests() {
    let white = RGB.white.packed
    let red = RGB(r: 255, g: 0, b: 0), blue = RGB(r: 0, g: 0, b: 255)
    func dark(_ bitmap: Bitmap, in rect: PixelRect) -> Int {
        var count = 0
        for y in rect.y..<rect.maxY { for x in rect.x..<rect.maxX where RGB(packed: bitmap[x, y]).r < 128 { count += 1 } }
        return count
    }
    /// Whether every pixel outside `rect` is the same in both bitmaps.
    func sameOutside(_ a: Bitmap, _ b: Bitmap, _ rect: PixelRect) -> Bool {
        for y in 0..<a.height {
            for x in 0..<a.width where !(x >= rect.x && x < rect.maxX && y >= rect.y && y < rect.maxY) {
                if a[x, y] != b[x, y] { return false }
            }
        }
        return true
    }

    // Format and layout
    let standard = TextFormat.standard
    check(standard.size == 11 && standard.family == (TextFormat.families.contains("Calibri") ? "Calibri" : "Helvetica Neue"),
          "the default font is Calibri 11, or Helvetica Neue 11 without it")
    check(TextFormat.sizes.first == 8 && TextFormat.sizes.last == 72 && TextFormat.sizes.contains(11), "the Size list goes from 8 to 72")
    check(abs(standard.pixelSize - 11 * 96 / 72) < 0.01, "points are 96 dpi pixels")
    check(TextFormat.family(named: "helvetica neue") == "Helvetica Neue" && TextFormat.family(named: "No Such Font") == nil,
          "families are found ignoring case")
    let line = TextLayout.lineHeight(standard)
    check(line > 10 && line < 30, "one line of 11 pt is between 10 and 30 px")
    check(TextLayout.height(of: "a\nb", format: standard, width: 200) >= 2 * line - 1, "a new line adds a line")
    check(TextLayout.height(of: "a\n", format: standard, width: 200) >= 2 * line - 1, "an empty last line counts")
    let long = "the quick brown fox jumps over the lazy dog"
    check(TextLayout.height(of: long, format: standard, width: 60) >= 3 * line - 1, "text wraps within the width")

    // Drawing
    let box = PixelRect(x: 10, y: 10, width: 80, height: 30)
    var plain = Bitmap(width: 120, height: 60)
    let blank = plain
    let edit = TextEdit(rect: box, string: "Hello", format: standard, opaque: false)
    let changed = TextLayout.draw(edit, color: .black, background: blue, on: &plain)
    check(changed == box && dark(plain, in: box) > 20, "the text is drawn in Color 1 inside the box")
    check(sameOutside(plain, blank, box), "nothing is drawn outside the box")
    check(plain[box.maxX - 1, box.maxY - 1] == white, "transparent leaves the image under the box")
    var opaque = Bitmap(width: 120, height: 60)
    TextLayout.draw(TextEdit(rect: box, string: "Hello", format: standard, opaque: true), color: .black, background: blue, on: &opaque)
    check(opaque[box.x, box.y] == blue.packed && opaque[box.maxX - 1, box.maxY - 1] == blue.packed && sameOutside(opaque, blank, box),
          "opaque paints the box with Color 2")
    let grays = (box.y..<box.maxY).flatMap { y in (box.x..<box.maxX).map { x in RGB(packed: plain[x, y]).r } }
    check(grays.contains { $0 > 20 && $0 < 235 }, "the text is antialiased")
    var bold = Bitmap(width: 120, height: 60)
    var boldFormat = standard
    boldFormat.bold = true
    TextLayout.draw(TextEdit(rect: box, string: "Hello", format: boldFormat, opaque: false), color: .black, background: blue, on: &bold)
    check(dark(bold, in: box) > dark(plain, in: box), "bold paints more")
    for change in [{ (f: inout TextFormat) in f.italic = true }, { $0.underline = true }, { $0.strikethrough = true }, { $0.size = 20 }] {
        var format = standard
        change(&format)
        var other = Bitmap(width: 120, height: 60)
        TextLayout.draw(TextEdit(rect: box, string: "Hello", format: format, opaque: false), color: .black, background: blue, on: &other)
        check(other != plain && sameOutside(other, blank, box), "italic, underline, strikethrough and size change the text")
    }
    var empty = Bitmap(width: 120, height: 60)
    check(TextLayout.draw(TextEdit(rect: box, string: "", format: standard, opaque: true), color: .black, background: blue, on: &empty).isEmpty
          && empty == blank, "an empty box draws nothing")
    var clipped = Bitmap(width: 40, height: 20)
    TextLayout.draw(TextEdit(rect: PixelRect(x: 20, y: 5, width: 60, height: 40), string: "Hello world", format: standard, opaque: true),
                    color: .black, background: blue, on: &clipped)
    check(clipped[39, 19] == blue.packed && clipped[19, 5] == white, "drawing stays inside the image")

    // The document
    let document = PaintDocument(bitmap: Bitmap(width: 200, height: 100))
    document.beginText(PixelRect(x: 10, y: 10, width: 60, height: 5), format: standard, opaque: false)
    check(document.text?.rect.height == line, "a box is at least one line tall")
    document.updateText { $0.string = long }
    check((document.text?.rect.height ?? 0) >= 3 * line - 1 && document.text?.rect.width == 60, "the box grows down when the text does not fit")
    document.updateText { $0.string = String(repeating: "line\n", count: 40) }
    check(document.text?.rect.maxY == 100, "growing stops at the bottom of the image")
    document.updateText { $0.rect.x = 180; $0.rect.width = 60 }
    check(document.text.map { $0.rect.x + $0.rect.width } == 200, "the box stays inside the image")
    check(document.canUndo && !document.canRedo, "a box being edited can be undone")
    document.undo()
    check(document.text == nil && !document.canUndo && document.bitmap == Bitmap(width: 200, height: 100), "undo drops the box")
    document.beginText(PixelRect(x: 10, y: 10, width: 60, height: 20), format: standard, opaque: true)
    document.fixText()
    check(!document.canUndo && document.bitmap == Bitmap(width: 200, height: 100), "an empty box leaves no undo step, even opaque")
    document.beginText(PixelRect(x: 10, y: 10, width: 60, height: 20), format: standard, opaque: false)
    document.updateText { $0.string = "Hi" }
    document.fixText()
    check(document.canUndo && document.bitmap != Bitmap(width: 200, height: 100), "fixing text is an undo step")
    document.undo()
    check(!document.canUndo && document.bitmap == Bitmap(width: 200, height: 100), "one undo removes the text")

    // Through the window
    _ = NSApplication.shared
    let controller = MainWindowController()
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("local.mypaint.tests.\(UUID().uuidString)"))
    defer { pasteboard.releaseGlobally() }
    controller.pasteboard = pasteboard
    let canvas = controller.canvas, window = controller.window, ribbon = controller.ribbon!
    let toolbox = canvas.toolbox
    var doc: PaintDocument { controller.document }
    func control(_ name: String) -> RibbonControl { ribbon.control(name)! }
    func reset() {
        doc.replaceImage(Bitmap(width: 300, height: 200))
        doc.color1 = .black
        doc.color2 = blue
        canvas.zoom = 1
        canvas.reload()
        controller.syncInterface()
    }
    func mouse(_ type: NSEvent.EventType, _ point: NSPoint) {
        let event = NSEvent.mouseEvent(with: type, location: canvas.convert(point, to: nil), modifierFlags: [], timestamp: 0,
                                       windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        switch type {
        case .leftMouseDown: canvas.mouseDown(with: event)
        case .leftMouseDragged: canvas.mouseDragged(with: event)
        case .leftMouseUp: canvas.mouseUp(with: event)
        case .rightMouseDown: canvas.rightMouseDown(with: event)
        case .rightMouseUp: canvas.rightMouseUp(with: event)
        default: break
        }
    }
    func at(_ x: Int, _ y: Int) -> NSPoint {
        NSPoint(x: CanvasView.inset + (CGFloat(x) + 0.5) * canvas.zoom, y: CanvasView.inset + (CGFloat(y) + 0.5) * canvas.zoom)
    }
    func click(_ x: Int, _ y: Int, right: Bool = false) {
        mouse(right ? .rightMouseDown : .leftMouseDown, at(x, y))
        mouse(right ? .rightMouseUp : .leftMouseUp, at(x, y))
    }
    func drag(_ a: NSPoint, _ b: NSPoint) {
        mouse(.leftMouseDown, a)
        mouse(.leftMouseDragged, NSPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2))
        mouse(.leftMouseDragged, b)
        mouse(.leftMouseUp, b)
    }
    func key(_ code: UInt16, _ characters: String, _ flags: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: window.windowNumber,
                         context: nil, characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code)!
    }
    func ctrl(_ code: UInt16, _ letter: String) -> Bool { window.performKeyEquivalent(with: key(code, letter, .control)) }
    func type(_ text: String) { canvas.textView?.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0)) }
    func menuItem(_ action: Selector, tag: Int = 0) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: action, keyEquivalent: "")
        item.tag = tag
        return item
    }

    reset()
    control("tool.text").perform()
    check(toolbox.kind == .text && control("tool.text").isChecked && !control("tool.pencil").isChecked,
          "the A button picks the Text tool")
    check(ToolKind.text.rawValue == 8 && ToolKind.brush.rawValue == 7, "Text is the last tool kind; earlier tags stay")
    check(!ribbon.showsContextual && ribbon.tabs[2].isHidden && ribbon.selectedPage == 0, "the Text tab is hidden without a box")
    check(!control("home.size").isEnabled, "Size is disabled for the Text tool")

    // A click opens a box at the pointer.
    click(20, 30)
    check(doc.text?.rect == PixelRect(x: 20, y: 30, width: TextLayout.clickWidth, height: line), "a click opens a box of the standard width")
    check(canvas.textView != nil && canvas.textView?.superview === canvas && window.firstResponder === canvas.textView,
          "a text view is laid over the box and takes the keyboard")
    check(canvas.textView?.frame == canvas.viewRect(doc.text!.rect), "the text view covers the box")
    check(ribbon.showsContextual && !ribbon.tabs[2].isHidden && ribbon.selectedPage == 2 && ribbon.tabs[2].isChecked,
          "the Text tab appears and is selected")
    check(ribbon.contextualTitle == "Text Tools" && ribbon.contextualHeaderRect.map { $0.minX == ribbon.tabs[2].frame.minX } == true
          && ribbon.tabs[2].frame.minX > ribbon.tabs[1].frame.maxX, "the tab has its Text Tools header above it, after the others")
    check(ribbon.pages[2].groups.map(\.title) == ["Clipboard", "Font", "Background", "Colors"], "the Text tab has its four groups")
    check(controller.statusBar.selectionText == "\(TextLayout.clickWidth) × \(line)px", "the status bar shows the box size")
    let family = control("text.fontFamily") as! RibbonComboBox, size = control("text.fontSize") as! RibbonComboBox
    check(family.stringValue == standard.family && size.stringValue == "11" && family.combo.numberOfItems == TextFormat.families.count,
          "the Font boxes show the family and the size")
    check(control("text.opaque").isEnabled && !control("text.opaque").isChecked && control("text.transparent").isChecked,
          "the background starts transparent")

    // Typing, deleting, new lines, wrapping.
    type("Hello")
    check(doc.text?.string == "Hello" && canvas.textView?.string == "Hello", "typing goes into the box")
    canvas.textView?.keyDown(with: key(0, "a"))
    check(doc.text?.string == "Helloa", "key presses type into the box")
    canvas.textView?.keyDown(with: key(51, "\u{7F}"))
    check(doc.text?.string == "Hello", "Backspace deletes")
    canvas.textView?.moveLeft(nil)
    canvas.textView?.moveLeft(nil)
    canvas.textView?.deleteForward(nil)
    check(doc.text?.string == "Helo" && canvas.textView?.selectedRange().location == 3, "arrows move the caret and Delete deletes forward")
    canvas.textView?.moveRightAndModifySelection(nil)
    check(canvas.textView?.selectedRange() == NSRange(location: 3, length: 1), "Shift+arrow selects")
    canvas.textView?.moveToEndOfDocument(nil)
    canvas.textView?.keyDown(with: key(36, "\r"))
    check(doc.text?.string == "Helo\n" && (doc.text?.rect.height ?? 0) >= 2 * line - 1, "Return starts a new line and the box grows")
    type(long)
    let grown = doc.text?.rect.height ?? 0
    check(grown >= 4 * line - 2 && doc.text?.rect.width == TextLayout.clickWidth, "long text wraps and grows the box down")
    check(canvas.textView?.frame == canvas.viewRect(doc.text!.rect), "the text view follows the box")

    // Moving by the border and stretching by the handles.
    let start = doc.text!.rect
    drag(at(start.x + 30, start.y - 1), at(start.x + 40, start.y + 9))
    check(doc.text?.rect == PixelRect(x: start.x + 10, y: start.y + 10, width: start.width, height: start.height),
          "dragging the border moves the box")
    check(window.firstResponder === canvas.textView, "the text view takes the keyboard back after the drag")
    let moved = doc.text!.rect
    // The handles sit on the edge: the pixel just past the right and bottom edges grabs them.
    drag(at(moved.maxX, moved.y + moved.height / 2), at(moved.maxX + 60, moved.y + moved.height / 2))
    check(doc.text?.rect.width == moved.width + 60 && doc.text?.rect.x == moved.x, "the right handle widens the box")
    let wide = doc.text!.rect
    drag(at(wide.maxX, wide.maxY), at(wide.maxX - 100, wide.maxY + 20))
    check(doc.text?.rect.width == wide.width - 100 && doc.text!.rect.height >= wide.height + 20, "the corner handle stretches the box")
    let narrow = doc.text!.rect
    check(narrow.height >= TextLayout.height(of: doc.text!.string, format: doc.text!.format, width: narrow.width),
          "a narrower box stays as tall as its text")
    let inside = canvas.viewRect(narrow)
    check(canvas.hitTest(canvas.convert(NSPoint(x: inside.midX, y: inside.midY), to: canvas.superview)) === canvas.textView
          && canvas.hitTest(canvas.convert(NSPoint(x: inside.midX, y: inside.minY), to: canvas.superview)) === canvas,
          "the inside of the box belongs to the text view, its border to the canvas")

    // Format: Ctrl+B, Ctrl+I, Ctrl+U go to the text while editing.
    let lineBefore = TextLayout.lineHeight(doc.text!.format)
    check(ctrl(11, "b") && doc.text?.format.bold == true && control("text.bold").isChecked, "Ctrl+B makes the text bold")
    check((canvas.textView?.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
            .map { NSFontManager.shared.traits(of: $0).contains(.boldFontMask) } == true, "the text view shows it bold at once")
    check(ctrl(34, "i") && doc.text?.format.italic == true && control("text.italic").isChecked, "Ctrl+I makes it italic")
    check(ctrl(32, "u") && doc.text?.format.underline == true && control("text.underline").isChecked, "Ctrl+U underlines it")
    check(canvas.textView?.textStorage?.attribute(.underlineStyle, at: 2, effectiveRange: nil) as? Int == NSUnderlineStyle.single.rawValue,
          "the format covers the whole box")
    check(ctrl(32, "u") && doc.text?.format.underline == false, "Ctrl+U again removes the underline")
    control("text.strikethrough").perform()
    check(doc.text?.format.strikethrough == true && control("text.strikethrough").isChecked, "the Strikethrough button works")
    control("text.strikethrough").perform()
    control("text.italic").perform()
    check(doc.text?.format.italic == false, "the Italic button toggles back")
    let cmdB = controller.makeTextMenu().items[0]
    check(cmdB.keyEquivalent == "b" && cmdB.keyEquivalentModifierMask == .command && cmdB.action == #selector(MainWindowController.toggleTextBold(_:)),
          "Cmd+B is in the Text menu")
    controller.toggleTextBold(cmdB)
    check(doc.text?.format.bold == false, "the Text menu turns bold off")
    size.stringValue = "24"
    controller.chooseTextFontSize(size)
    check(doc.text?.format.size == 24 && TextLayout.lineHeight(doc.text!.format) > lineBefore
          && doc.text!.rect.height == min(200 - doc.text!.rect.y,
                                          TextLayout.height(of: doc.text!.string, format: doc.text!.format, width: doc.text!.rect.width)),
          "a typed size applies and the box grows to fit, down to the bottom of the image")
    size.stringValue = "abc"
    controller.chooseTextFontSize(size)
    check(doc.text?.format.size == 24 && size.stringValue == "24", "an invalid size is ignored")
    controller.chooseTextFontSize(menuItem(#selector(MainWindowController.chooseTextFontSize(_:)), tag: 11))
    check(doc.text?.format.size == 11, "the Font size menu sets the size")
    let other = TextFormat.families.first { $0 != standard.family && $0 != "Apple Color Emoji" } ?? standard.family
    family.stringValue = other.lowercased()
    controller.chooseTextFontFamily(family)
    check(doc.text?.format.family == other && family.stringValue == other, "a family typed in the Font box applies")
    family.stringValue = "No Such Font"
    controller.chooseTextFontFamily(family)
    check(doc.text?.format.family == other && family.stringValue == other, "an unknown family is ignored")
    let familyItem = NSMenuItem(title: standard.family, action: #selector(MainWindowController.chooseTextFontFamily(_:)), keyEquivalent: "")
    familyItem.representedObject = standard.family
    controller.chooseTextFontFamily(familyItem)
    _ = controller.validateMenuItem(familyItem)
    check(doc.text?.format.family == standard.family && familyItem.state == .on, "the Font menu sets and marks the family")

    // Clipboard inside the box: Ctrl+A, Ctrl+C, Ctrl+X, Ctrl+V on the text, on the app's pasteboard.
    let typed = doc.text!.string
    pasteboard.clearContents()
    check(ctrl(0, "a") && canvas.textView?.selectedRange() == NSRange(location: 0, length: (typed as NSString).length),
          "Ctrl+A selects all the text")
    check(doc.selection == nil, "Ctrl+A does not select the image while typing")
    check(ctrl(8, "c") && pasteboard.string(forType: .string) == typed, "Ctrl+C copies the text to the app's pasteboard")
    check(controller.commandState(#selector(MainWindowController.paste(_:)), tag: 0).enabled, "Paste is enabled with text on the pasteboard")
    canvas.textView?.setSelectedRange(NSRange(location: 0, length: 4))
    check(ctrl(7, "x") && doc.text?.string == String(typed.dropFirst(4)) && pasteboard.string(forType: .string) == "Helo",
          "Ctrl+X cuts the selected text")
    canvas.textView?.setSelectedRange(NSRange(location: 0, length: 0))
    check(ctrl(9, "v") && doc.text?.string == typed, "Ctrl+V pastes it back")
    pasteboard.clearContents()
    pasteboard.setString("A\r\nB", forType: .string)
    controller.syncInterface()
    canvas.textView?.moveToEndOfDocument(nil)
    control("text.paste").perform()
    check(doc.text?.string == typed + "A\nB", "the Paste button of the Text tab pastes text")
    canvas.textView?.setSelectedRange(NSRange(location: 0, length: 4))
    control("text.copy").perform()
    check(pasteboard.string(forType: .string) == "Helo", "the Copy button copies the selected text")
    check(controller.commandState(#selector(MainWindowController.cut(_:)), tag: 0).enabled
          && control("text.cut").isEnabled, "Cut is enabled with text selected")

    // Colors change the text at once; fixing draws it.
    controller.choosePaletteColor(menuItem(#selector(MainWindowController.choosePaletteColor(_:)), tag: 4))
    let color1 = Palette.colors[4].color
    check((canvas.textView?.textStorage?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor)?.usingColorSpace(.sRGB)
            .map { abs($0.redComponent - CGFloat(color1.r) / 255) < 0.01 } == true, "a new Color 1 recolors the text at once")
    check((control("text.color1") as! ColorWellButton).color == color1, "the Text tab shows Color 1")
    controller.chooseTextBackground(menuItem(#selector(MainWindowController.chooseTextBackground(_:)), tag: TextBackground.opaque.rawValue))
    check(doc.text?.opaque == true && control("text.opaque").isChecked && !control("text.transparent").isChecked, "Opaque applies to the box")
    let before = doc.bitmap
    let final = doc.text!.rect
    check(!controller.commandState(#selector(MainWindowController.redoEdit(_:)), tag: 0).enabled, "Redo is disabled while typing")
    click(290, 190)
    check(doc.text == nil && canvas.textView == nil && toolbox.kind == .text, "a click outside fixes the box without opening another")
    check(!ribbon.showsContextual && ribbon.tabs[2].isHidden && ribbon.selectedPage == 0, "the Text tab goes away and Home comes back")
    check(sameOutside(doc.bitmap, before, final) && doc.bitmap[final.maxX - 1, final.maxY - 1] == blue.packed,
          "the text is drawn inside the box only, on Color 2")
    let pixels = (final.y..<final.maxY).flatMap { y in (final.x..<final.maxX).map { x in RGB(packed: doc.bitmap[x, y]) } }
    check(pixels.contains(color1), "the text is in Color 1")
    controller.undoEdit(nil)
    check(doc.bitmap == before && !doc.canUndo, "one undo removes the fixed text")
    controller.redoEdit(nil)
    check(doc.bitmap != before, "redo brings it back")

    // A drag opens a box of the dragged size; another tool fixes it.
    reset()
    controller.chooseTextBackground(menuItem(#selector(MainWindowController.chooseTextBackground(_:)), tag: TextBackground.transparent.rawValue))
    doc.draw { $0.fill(PixelRect(x: 0, y: 0, width: 300, height: 200), with: red.packed) }
    let redImage = doc.bitmap
    drag(at(40, 50), at(139, 99))
    check(doc.text?.rect == PixelRect(x: 40, y: 50, width: 100, height: 50), "a drag opens a box of the dragged size")
    type("Text")
    controller.chooseTool(menuItem(#selector(MainWindowController.chooseTool(_:)), tag: ToolKind.pencil.rawValue))
    check(doc.text == nil && canvas.textView == nil && doc.bitmap != redImage, "picking another tool fixes the text")
    check(doc.bitmap[139, 99] == red.packed && sameOutside(doc.bitmap, redImage, PixelRect(x: 40, y: 50, width: 100, height: 50)),
          "transparent text keeps the image around the letters")
    check(!ribbon.showsContextual, "the Text tab hides with another tool")

    // Ctrl+B with another tool and no box does nothing; Ctrl+A and Ctrl+C go to the image again.
    let wasBold = toolbox.textTool.format.bold
    _ = ctrl(11, "b")
    check(toolbox.textTool.format.bold == wasBold, "Ctrl+B does nothing outside the Text tool")
    pasteboard.clearContents()
    check(ctrl(0, "a") && doc.selection?.rect == doc.bitmap.bounds && toolbox.kind == .select, "outside a box Ctrl+A selects the image")
    check(ctrl(8, "c") && MainWindowController.readImage(from: pasteboard) != nil, "outside a box Ctrl+C copies the image")

    // Esc fixes, the right button opens a box with the text still in Color 1, an empty box leaves no step.
    reset()
    controller.chooseTool(menuItem(#selector(MainWindowController.chooseTool(_:)), tag: ToolKind.text.rawValue))
    let blankImage = doc.bitmap
    click(20, 20, right: true)
    check(doc.text != nil, "the right button opens a box too")
    type("Esc")
    canvas.textView?.keyDown(with: key(53, "\u{1B}"))
    check(doc.text == nil && doc.canUndo && dark(doc.bitmap, in: doc.bitmap.bounds) > 0, "Esc fixes the box, in Color 1 for the right button too")
    reset()
    click(20, 20)
    click(250, 150)
    check(doc.text == nil && !doc.canUndo && doc.bitmap == blankImage, "an empty box fixed leaves no undo step")
    click(20, 20)
    type("Gone")
    controller.undoEdit(nil)
    check(doc.text == nil && canvas.textView == nil && doc.bitmap == blankImage && !doc.canUndo, "undo while typing drops the box")
    check(!ribbon.showsContextual, "dropping the box hides the Text tab")

    // A box at 200% and the save path.
    controller.zoomIn(nil)
    click(10, 10)
    type("Zoom")
    check(canvas.textView?.frame.width == CGFloat(doc.text!.rect.width) * 2 && canvas.textView?.bounds.width == CGFloat(doc.text!.rect.width),
          "at 200% the text view is twice the box, laid out in image pixels")
    canvas.finishEditing()
    check(doc.text == nil && doc.canUndo, "fixing before saving draws the text")
    controller.zoomActual(nil)

    // Commands, menus and selectors.
    reset()
    controller.chooseTool(menuItem(#selector(MainWindowController.chooseTool(_:)), tag: ToolKind.pencil.rawValue))
    check(!controller.commandState(#selector(MainWindowController.toggleTextBold(_:)), tag: 0).enabled,
          "Text formatting is disabled with another tool")
    let tools = controller.makeToolsMenu().items.filter { $0.action == #selector(MainWindowController.chooseTool(_:)) }.map(\.title)
    check(tools.count == 7 && tools[2] == "Text", "the Tools menu lists Text after Fill")
    let textMenu = controller.makeTextMenu()
    check(textMenu.title == "Text" && textMenu.items.map(\.title) == ["Bold", "Italic", "Underline", "Strikethrough", "", "Font",
                                                                      "Font size", "", "Opaque", "Transparent"],
          "the Text menu mirrors the Font and Background groups")
    check(textMenu.items[5].submenu?.items.count == TextFormat.families.count
          && textMenu.items[6].submenu?.items.map(\.tag) == TextFormat.sizes, "the Font and Font size submenus list families and sizes")
    check(PaintWindow.windowsShortcut(for: key(11, "b", .control)) == #selector(MainWindowController.toggleTextBold(_:))
          && PaintWindow.windowsShortcut(for: key(34, "i", .control)) == #selector(MainWindowController.toggleTextItalic(_:))
          && PaintWindow.windowsShortcut(for: key(32, "u", .control)) == #selector(MainWindowController.toggleTextUnderline(_:))
          && PaintWindow.windowsShortcut(for: key(34, "I", [.control, .shift])) == #selector(MainWindowController.invertColors(_:)),
          "Ctrl+B, Ctrl+I and Ctrl+U format text; Ctrl+Shift+I still inverts colors")
    let actions = ["toggleTextBold:", "toggleTextItalic:", "toggleTextUnderline:", "toggleTextStrikethrough:",
                   "chooseTextBackground:", "chooseTextFontFamily:", "chooseTextFontSize:"].map(NSSelectorFromString)
    let textView = NSTextView()
    check(actions.allSatisfy { controller.responds(to: $0) && !window.responds(to: $0) && !canvas.responds(to: $0)
                               && !NSApp.responds(to: $0) && !ribbon.responds(to: $0) && !textView.responds(to: $0) },
          "the Text actions reach the controller, not the window, the view or a text view")
}
