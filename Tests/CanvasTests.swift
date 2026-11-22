import AppKit

/// Canvas details of Phase 9: the diagonal cursors of the corner handles and pasting into a scrolled window.
func runCanvasTests() {
    _ = NSApplication.shared
    runDiagonalCursorTests()
    runScrolledPasteTests()
}

/// Renders `cursor` at its own point size, one pixel per point, and reads the alpha and darkness of a pixel
/// counted from the top-left corner.
private struct CursorPixels {
    let rep: NSBitmapImageRep

    init(_ cursor: NSCursor) {
        let size = cursor.image.size
        rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        cursor.image.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
    }

    func alpha(_ x: Int, _ y: Int) -> CGFloat { rep.colorAt(x: x, y: y)?.alphaComponent ?? 0 }
    /// Black, opaque: the arrow itself rather than its white halo.
    func isInk(_ x: Int, _ y: Int) -> Bool {
        guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { return false }
        return color.alphaComponent > 0.8 && color.redComponent < 0.3
    }
    var opaqueCount: Int {
        var count = 0
        for y in 0..<rep.pixelsHigh { for x in 0..<rep.pixelsWide where alpha(x, y) > 0.5 { count += 1 } }
        return count
    }
}

private func runDiagonalCursorTests() {
    let down = ToolCursor.resizeDiagonalDown, up = ToolCursor.resizeDiagonalUp
    let side = Int(RibbonTheme.diagonalCursorSize)

    // The drawings.
    check(down.image.size == NSSize(width: side, height: side) && up.image.size == down.image.size, "the diagonal cursors are square")
    check(down.hotSpot == NSPoint(x: CGFloat(side) / 2, y: CGFloat(side) / 2) && up.hotSpot == down.hotSpot,
          "the diagonal cursors point at their centre")
    let a = CursorPixels(down), b = CursorPixels(up)
    let total = side * side
    check(a.opaqueCount > total / 8 && a.opaqueCount < total / 2 && b.opaqueCount > total / 8 && b.opaqueCount < total / 2,
          "the diagonal cursors are drawn, not empty and not a filled square")
    let mid = side / 2, near = mid - 5, far = mid + 4
    check(a.isInk(mid, mid) && b.isInk(mid, mid), "the shaft crosses the hot spot in black")
    check(a.isInk(near, near) && a.isInk(far, far) && a.alpha(far, near) == 0 && a.alpha(near, far) == 0,
          "↖↘ has its heads at the top-left and bottom-right, nothing at the other corners")
    check(b.isInk(far, near) && b.isInk(near, far) && b.alpha(near, near) == 0 && b.alpha(far, far) == 0,
          "↗↙ has its heads at the top-right and bottom-left, nothing at the other corners")
    var halo = false, mirrored = true
    for y in 0..<side {
        for x in 0..<side {
            if a.alpha(x, y) > 0.8 && !a.isInk(x, y) { halo = true }
            if (a.alpha(x, y) > 0.5) != (b.alpha(side - 1 - x, y) > 0.5) { mirrored = false }
        }
    }
    check(halo, "the arrows have a white outline, so they show on dark colors")
    check(mirrored, "↗↙ is ↖↘ mirrored")
    check(ToolCursor.resizeDiagonalDown === down, "the cursors are made once")

    // Which cursor goes on which handle.
    let expected: [SelectionHandle: NSCursor] = [
        .topLeft: down, .top: .resizeUpDown, .topRight: up, .right: .resizeLeftRight,
        .bottomRight: down, .bottom: .resizeUpDown, .bottomLeft: up, .left: .resizeLeftRight,
    ]
    check(SelectionHandle.allCases.allSatisfy { ToolCursor.cursor(for: $0) === expected[$0]! }, "each box handle has its cursor")
    check(ToolCursor.canvasHandles.count == 3 && ToolCursor.canvasHandles[0] === NSCursor.resizeLeftRight
          && ToolCursor.canvasHandles[1] === NSCursor.resizeUpDown && ToolCursor.canvasHandles[2] === down,
          "the canvas handles: right ↔, bottom ↕, bottom-right corner ↖↘")

    // The cursors the canvas really sets up, for the image, a selection, a shape and a text box.
    let controller = MainWindowController()
    let canvas = controller.canvas, window = controller.window, toolbox = canvas.toolbox
    var document: PaintDocument { controller.document }
    document.replaceImage(Bitmap(width: 120, height: 90))
    canvas.zoom = 1
    canvas.reload()
    controller.syncInterface()
    func cursor(at point: NSPoint) -> NSCursor? { canvas.cursorAreas().last { $0.rect.contains(point) }?.cursor }
    func center(_ rect: CGRect) -> NSPoint { NSPoint(x: rect.midX, y: rect.midY) }
    let canvasHandles = CanvasView.handleRects(around: canvas.imageRect)
    check(cursor(at: center(canvasHandles[0])) === NSCursor.resizeLeftRight && cursor(at: center(canvasHandles[1])) === NSCursor.resizeUpDown
          && cursor(at: center(canvasHandles[2])) === down, "the canvas handles show ↔, ↕ and ↖↘")
    func boxCursorsRight(_ rect: PixelRect) -> Bool {
        CanvasView.selectionHandleRects(canvas.viewRect(rect)).enumerated().allSatisfy { index, handle in
            cursor(at: center(handle)) === expected[SelectionHandle(rawValue: index)!]!
        }
    }
    func mouse(_ type: NSEvent.EventType, _ point: NSPoint) {
        let event = NSEvent.mouseEvent(with: type, location: canvas.convert(point, to: nil), modifierFlags: [], timestamp: 0,
                                       windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        switch type {
        case .leftMouseDown: canvas.mouseDown(with: event)
        case .leftMouseDragged: canvas.mouseDragged(with: event)
        default: canvas.mouseUp(with: event)
        }
    }
    func view(_ x: Int, _ y: Int) -> NSPoint { NSPoint(x: CanvasView.inset + CGFloat(x) + 0.5, y: CanvasView.inset + CGFloat(y) + 0.5) }

    toolbox.select(.select)
    let selected = PixelRect(x: 20, y: 15, width: 40, height: 30)
    document.select(selected)
    check(boxCursorsRight(selected), "the selection's corner handles show the diagonal cursors, the sides ↔ and ↕")
    check(cursor(at: center(canvas.viewRect(selected))) === ToolCursor.move, "inside the selection the cursor still moves it")
    document.fixSelection()

    toolbox.select(.shape)
    mouse(.leftMouseDown, view(30, 20))
    mouse(.leftMouseDragged, view(69, 49))
    mouse(.leftMouseUp, view(69, 49))
    if let bounds = document.shape?.shape.bounds {
        check(boxCursorsRight(bounds), "the handles of the shape being edited show the same cursors")
    } else {
        check(false, "a shape is being edited")
    }
    canvas.finishShape()

    toolbox.select(.text)
    let box = PixelRect(x: 10, y: 10, width: 80, height: 40)
    document.beginText(box, format: toolbox.textTool.format, opaque: false)
    check(boxCursorsRight(box), "the text box handles show the same cursors")
    canvas.finishText()
}

private func runScrolledPasteTests() {
    let controller = MainWindowController()
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("local.mypaint.tests.\(UUID().uuidString)"))
    defer { pasteboard.releaseGlobally() }
    controller.pasteboard = pasteboard
    let canvas = controller.canvas, window = controller.window
    window.setContentSize(NSSize(width: 1000, height: 700))
    var document: PaintDocument { controller.document }
    let green = RGB(r: 0, g: 200, b: 0).packed
    var asked = 0
    controller.confirmEnlarge = { asked += 1; return .alertFirstButtonReturn }
    func reset(zoom: CGFloat, scroll: NSPoint) {
        document.replaceImage(Bitmap(width: 2000, height: 1500))
        canvas.zoom = zoom
        canvas.reload()
        canvas.scroll(scroll)
        controller.syncInterface()
        asked = 0
    }
    func visible() -> CGRect { canvas.visibleRect }
    /// The pasted image's top-left corner is the first image pixel shown whole in the view.
    func atVisibleCorner(_ expected: PixelPoint) -> Bool {
        guard let rect = document.selection?.rect, document.selection?.isFloating == true else { return false }
        let shown = canvas.viewRect(rect), area = visible()
        return rect.x == expected.x && rect.y == expected.y && shown.minX >= area.minX && shown.minX < area.minX + canvas.zoom
            && shown.minY >= area.minY && shown.minY < area.minY + canvas.zoom
    }

    // 100%: scrolled 600 × 400 points, so the first pixel shown is (595, 395) after the 5-point margin.
    reset(zoom: 1, scroll: NSPoint(x: 600, y: 400))
    check(visible().minX == 600 && visible().minY == 400, "the window really scrolls at 100%")
    MainWindowController.write(Bitmap(width: 40, height: 30, value: green), to: pasteboard)
    controller.paste(nil)
    check(atVisibleCorner(PixelPoint(x: 595, y: 395)) && document.bitmap[595, 395] == green && document.bitmap[594, 395] != green,
          "at 100% Paste puts the image at the top-left of the visible area")
    check(visible().minX == 600 && visible().minY == 400 && asked == 0, "pasting leaves the scrolling alone and asks nothing")
    controller.undoEdit(nil)

    // 200%: 602 points is pixel 298.5, so the first whole pixel is 299; 401 points is pixel 198.
    reset(zoom: 2, scroll: NSPoint(x: 602, y: 401))
    check(visible().minX == 602 && visible().minY == 401, "the window really scrolls at 200%")
    controller.paste(nil)
    check(atVisibleCorner(PixelPoint(x: 299, y: 198)), "at 200% Paste puts the image at the first whole pixel of the visible area")
    controller.undoEdit(nil)

    // Paste from: the same place.
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("mypaint-canvas-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("piece.png")
    try? ImageFile.write(Bitmap(width: 25, height: 20, value: green), to: file, format: .png)
    controller.choosePasteFile = { file }
    reset(zoom: 1, scroll: NSPoint(x: 600, y: 400))
    controller.pasteFromFile(nil)
    check(atVisibleCorner(PixelPoint(x: 595, y: 395)) && document.selection?.rect.width == 25, "at 100% Paste from puts the file at the top-left of the visible area")
    controller.undoEdit(nil)
    reset(zoom: 2, scroll: NSPoint(x: 602, y: 401))
    controller.pasteFromFile(nil)
    check(atVisibleCorner(PixelPoint(x: 299, y: 198)), "at 200% Paste from does the same")
    controller.undoEdit(nil)
    controller.choosePasteFile = { nil }
    controller.pasteFromFile(nil)
    check(document.selection == nil && !document.canUndo, "cancelling the file panel pastes nothing")

    // Larger than the canvas: the question compares the image with the canvas size, not with what is left past the corner.
    reset(zoom: 1, scroll: NSPoint(x: 600, y: 400))
    MainWindowController.write(Bitmap(width: 1800, height: 1400, value: green), to: pasteboard)
    controller.paste(nil)
    check(asked == 0 && document.bitmap.width == 2000 && document.bitmap.height == 1500 && atVisibleCorner(PixelPoint(x: 595, y: 395)),
          "an image smaller than the canvas pastes at the visible corner without asking, even if it runs past the edges")
    controller.undoEdit(nil)
    MainWindowController.write(Bitmap(width: 2500, height: 1000, value: green), to: pasteboard)
    controller.confirmEnlarge = { asked += 1; return .alertSecondButtonReturn }
    controller.paste(nil)
    check(asked == 1 && document.bitmap.width == 2000 && atVisibleCorner(PixelPoint(x: 595, y: 395)),
          "No pastes the larger image at the visible corner, on the same canvas")
    controller.undoEdit(nil)
    reset(zoom: 2, scroll: NSPoint(x: 602, y: 401))
    controller.confirmEnlarge = { asked += 1; return .alertFirstButtonReturn }
    controller.paste(nil)
    check(asked == 1 && document.bitmap.width == 2500 && document.bitmap.height == 1500
          && document.selection?.rect == PixelRect(x: 0, y: 0, width: 2500, height: 1000),
          "Yes enlarges the canvas and pastes at its top-left corner")
    check(visible().minX == 0 && visible().minY == 0, "after enlarging, the view scrolls to the pasted image")
    controller.undoEdit(nil)
    check(document.bitmap.width == 2000 && document.selection == nil, "one undo takes back the paste and the larger canvas")
}
