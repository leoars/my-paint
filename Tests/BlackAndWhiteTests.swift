import AppKit

/// A 1-bit BMP (black and white palette) written by hand, as ImageIO does not write one.
func monochromeBMP(width: Int, height: Int, black: (Int, Int) -> Bool) -> Data {
    let rowBytes = ((width + 31) / 32) * 4
    let pixelBytes = rowBytes * height
    var data = Data()
    func le32(_ v: Int) { var x = UInt32(truncatingIfNeeded: v).littleEndian; data.append(Data(bytes: &x, count: 4)) }
    func le16(_ v: Int) { var x = UInt16(truncatingIfNeeded: v).littleEndian; data.append(Data(bytes: &x, count: 2)) }
    data.append(contentsOf: Array("BM".utf8))
    le32(14 + 40 + 8 + pixelBytes); le32(0); le32(14 + 40 + 8)
    le32(40); le32(width); le32(height); le16(1); le16(1); le32(0); le32(pixelBytes); le32(3780); le32(3780); le32(2); le32(2)
    data.append(contentsOf: [0, 0, 0, 0, 255, 255, 255, 0])  // index 0 black, 1 white
    for row in (0..<height).reversed() {
        var bytes = [UInt8](repeating: 0, count: rowBytes)
        for x in 0..<width where !black(x, row) { bytes[x / 8] |= 0x80 >> UInt8(x % 8) }
        data.append(contentsOf: bytes)
    }
    return data
}

func runBlackAndWhiteTests() {
    _ = NSApplication.shared
    let controller = MainWindowController()
    let canvas = controller.canvas, window = controller.window, toolbox = canvas.toolbox
    var document: PaintDocument { controller.document }
    let red = RGB(r: 237, g: 28, b: 36), yellow = RGB(r: 255, g: 242, b: 0)
    let black = RGB.black.packed, white = RGB.white.packed
    func onlyBlackAndWhite(_ bitmap: Bitmap) -> Bool { bitmap.pixels.allSatisfy { $0 == black || $0 == white } }
    func palette(_ name: String) -> PaletteView { controller.ribbon.control(name) as! PaletteView }
    func menuItem(_ action: Selector, tag: Int = 0) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: action, keyEquivalent: "")
        item.tag = tag
        return item
    }
    func view(_ p: (Int, Int)) -> NSPoint {
        NSPoint(x: CanvasView.inset + (CGFloat(p.0) + 0.5) * canvas.zoom, y: CanvasView.inset + (CGFloat(p.1) + 0.5) * canvas.zoom)
    }
    func mouse(_ type: NSEvent.EventType, _ p: (Int, Int)) {
        let event = NSEvent.mouseEvent(with: type, location: canvas.convert(view(p), to: nil), modifierFlags: [],
                                       timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0,
                                       clickCount: 1, pressure: 1)!
        switch type {
        case .leftMouseDown: canvas.mouseDown(with: event)
        case .leftMouseDragged: canvas.mouseDragged(with: event)
        case .leftMouseUp: canvas.mouseUp(with: event)
        default: break
        }
    }
    func drag(_ from: (Int, Int), _ to: (Int, Int)) {
        mouse(.leftMouseDown, from)
        mouse(.leftMouseDragged, ((from.0 + to.0) / 2, (from.1 + to.1) / 2))
        mouse(.leftMouseDragged, to)
        mouse(.leftMouseUp, to)
    }

    // A colored picture with colored Color 1 and Color 2.
    document.replaceImage(Bitmap(width: 120, height: 90))
    document.draw { $0.fill(PixelRect(x: 0, y: 0, width: 30, height: 30), with: yellow.packed)
                    $0.fill(PixelRect(x: 30, y: 0, width: 30, height: 30), with: red.packed) }
    document.color1 = red
    document.color2 = yellow
    canvas.reload()
    controller.syncInterface()
    check(palette("home.palette").colors.compactMap { $0 }.count >= 20 && palette("home.palette").showsEmptyPlaces,
          "in color the palette has its 20 colors")

    // Entering the mode.
    controller.applyProperties(ImageProperties(width: 120, height: 90, blackAndWhite: true))
    check(document.blackAndWhite && onlyBlackAndWhite(document.bitmap) && document.bitmap[5, 5] == white && document.bitmap[35, 5] == black,
          "Black and white converts the picture and enters the mode")
    check(document.color1 == .black && document.color2 == .white, "Color 1 becomes black and Color 2 white")
    for name in ["home.palette", "text.palette"] {
        let colors = palette(name).colors
        check(colors.count == 30 && colors[0] == .black && colors[10] == .white && colors.enumerated().allSatisfy { $0.offset == 0 || $0.offset == 10 || $0.element == nil }
              && !palette(name).showsEmptyPlaces, "\(name): only black and white are left, in their places")
    }
    check(palette("home.palette").accessibilityChildren()?.count == 2, "the palette offers two swatches to accessibility")
    let paletteAction = #selector(MainWindowController.choosePaletteColor(_:))
    check(!controller.commandState(paletteAction, tag: 3).enabled && controller.commandState(paletteAction, tag: 10).enabled,
          "red is no longer available, white is")
    let colorsMenu = controller.makeColorsMenu()
    let paletteItems = colorsMenu.items.filter { $0.action == paletteAction }
    check(paletteItems.filter { controller.validateMenuItem($0) }.map(\.tag) == [0, 10], "the Colors menu offers only black and white")
    check(controller.makePropertiesDialog().blackAndWhiteButton.state == .on, "the dialog shows Black and white")

    // Colors.
    controller.chooseColorSlot(menuItem(#selector(MainWindowController.chooseColorSlot(_:)), tag: 1))
    controller.choosePaletteColor(menuItem(paletteAction, tag: 10))
    check(document.color1 == .white, "a palette click gives white")
    controller.choosePaletteColor(menuItem(paletteAction, tag: 3))
    check(document.color1 == .white, "a hidden place gives nothing")
    document.color1 = red
    check(document.color1 == .black, "a dark color becomes black")
    document.color2 = yellow
    check(document.color2 == .white, "a light color becomes white")
    let customs = controller.customColors
    controller.applyEditedColor(RGB(r: 200, g: 200, b: 200))
    check(document.color1 == .white && controller.customColors == customs, "Edit colors gives white for light gray, without a custom place")
    controller.applyEditedColor(RGB(r: 40, g: 60, b: 90))
    check(document.color1 == .black, "and black for a dark blue")
    toolbox.select(.colorPicker)
    document.draw { $0.set(x: 100, y: 80, to: RGB(r: 180, g: 180, b: 180).packed) }
    mouse(.leftMouseDown, (100, 80))
    mouse(.leftMouseUp, (100, 80))
    check(document.color1 == .white, "the color picker gives black or white by threshold")
    document.draw { $0.set(x: 100, y: 80, to: white) }
    document.color1 = .black
    document.color2 = .white

    // Drawing ends up black and white.
    let start = document.bitmap
    toolbox.select(.brush)
    for kind in [BrushKind.brush, .calligraphy1, .airbrush, .oil, .marker, .watercolor] {
        controller.chooseBrush(menuItem(#selector(MainWindowController.chooseBrush(_:)), tag: kind.rawValue))
        drag((10, 40), (60, 70))
        check(onlyBlackAndWhite(document.bitmap) && document.bitmap != start, "the \(kind) stroke is black and white")
    }
    controller.chooseShape(menuItem(#selector(MainWindowController.chooseShape(_:)), tag: GalleryShape.oval.rawValue))
    drag((65, 35), (115, 85))
    document.fixShape()
    canvas.reload()
    check(onlyBlackAndWhite(document.bitmap), "a fixed oval is black and white")
    document.beginText(PixelRect(x: 62, y: 2, width: 56, height: 28), format: toolbox.textTool.format, opaque: false)
    document.updateText { $0.string = "Abc" }
    document.fixText()
    check(onlyBlackAndWhite(document.bitmap), "fixed text is black and white")
    toolbox.select(.fill)
    let filled = document.bitmap
    mouse(.leftMouseDown, (2, 88))
    mouse(.leftMouseUp, (2, 88))
    check(onlyBlackAndWhite(document.bitmap) && document.bitmap != filled, "the bucket fills in black")
    var colored = Bitmap(width: 10, height: 10, fill: red)
    colored.fill(PixelRect(x: 5, y: 0, width: 5, height: 10), with: yellow.packed)
    document.paste(colored, at: PixelPoint(x: 0, y: 0))
    check(onlyBlackAndWhite(document.bitmap) && document.bitmap[1, 1] == black && document.bitmap[7, 1] == white,
          "a pasted color picture becomes black and white")
    document.step { document.placeSelection(PixelRect(x: 20, y: 20, width: 10, height: 10)) }
    document.fixSelection()
    check(onlyBlackAndWhite(document.bitmap), "and stays so once moved")

    // Undo.
    let afterPaste = document.bitmap
    document.undo()
    check(onlyBlackAndWhite(document.bitmap) && document.bitmap != afterPaste && document.blackAndWhite, "undo stays black and white")
    document.redo()
    check(document.bitmap == afterPaste, "redo brings the paste back")
    while document.blackAndWhite && document.undo() {}
    check(!document.blackAndWhite && document.bitmap[35, 5] == red.packed, "undoing the conversion leaves the mode and gives the colors back")
    controller.syncInterface()
    check(palette("home.palette").colors.compactMap { $0 }.count >= 20, "the palette comes back with the undo")
    document.redo()
    controller.syncInterface()
    check(document.blackAndWhite && document.bitmap[35, 5] == black && palette("home.palette").colors[3] == nil
          && document.color1 == .black && document.color2 == .white, "redo enters the mode again")

    // Leaving the mode.
    controller.applyProperties(ImageProperties(width: 120, height: 90, blackAndWhite: false))
    check(!document.blackAndWhite && onlyBlackAndWhite(document.bitmap), "Color leaves the mode and keeps the pixels")
    check(palette("home.palette").colors[3] == red && palette("home.palette").showsEmptyPlaces
          && controller.commandState(paletteAction, tag: 3).enabled, "Color gives the palette back")
    controller.choosePaletteColor(menuItem(paletteAction, tag: 3))
    check(document.color1 == red, "red can be chosen again")
    controller.undoEdit(nil)
    check(document.blackAndWhite, "undo goes back to black and white")
    controller.redoEdit(nil)
    check(!document.blackAndWhite, "and redo to color")
    check(document.color1 == .black, "going back to black and white made Color 1 black")
    controller.choosePaletteColor(menuItem(paletteAction, tag: 3))
    toolbox.select(.pencil)
    drag((5, 50), (5, 60))
    check(document.bitmap[5, 55] == red.packed, "the pencil paints red again")

    // A monochrome BMP opens in the mode, a 24-bit one does not.
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("mypaint-bw-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let mono = folder.appendingPathComponent("mono.bmp")
    try! monochromeBMP(width: 13, height: 7) { x, y in (x + y) % 3 == 0 }.write(to: mono)
    check(ImageFile.isOneBit(mono), "a 1-bit BMP is recognised")
    document.isDirty = false
    controller.load(mono)
    check(document.blackAndWhite && document.bitmap.width == 13 && document.bitmap[0, 0] == black && document.bitmap[1, 0] == white,
          "opening a 1-bit BMP enters black-and-white mode")
    check(document.color1 == .black && document.color2 == .white && palette("home.palette").colors[3] == nil && !document.canUndo,
          "with black and white colors and palette")
    let full = folder.appendingPathComponent("full.bmp")
    try! ImageFile.write(Bitmap(width: 5, height: 5), to: full, format: .bmp)
    check(!ImageFile.isOneBit(full), "a 24-bit BMP is not 1-bit")
    controller.load(full)
    check(!document.blackAndWhite && palette("home.palette").colors[3] == red, "and opens in color")
}
