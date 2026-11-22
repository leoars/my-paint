import AppKit

/// Fires the airbrush only when the test says so.
final class ManualBrushClock: BrushClock {
    private var tick: (() -> Void)?
    var isRunning: Bool { tick != nil }
    func start(_ tick: @escaping () -> Void) { self.tick = tick }
    func stop() { tick = nil }
    func fire(_ times: Int) { for _ in 0..<times { tick?() } }
}

/// Brushes: each brush alone on a small image, the textured shapes, then the ribbon, the
/// menus and strokes through the real window with synthetic events.
func runBrushTests() {
    let white = RGB.white.packed
    let red = RGB(r: 255, g: 0, b: 0), blue = RGB(r: 0, g: 0, b: 255)

    func changed(_ bitmap: Bitmap, from base: Bitmap) -> [(Int, Int)] {
        var found: [(Int, Int)] = []
        for y in 0..<bitmap.height { for x in 0..<bitmap.width where bitmap[x, y] != base[x, y] { found.append((x, y)) } }
        return found
    }
    /// Distance from the center of pixel (x, y) to the segment between the centers of a and b.
    func distance(_ x: Int, _ y: Int, _ a: (Int, Int), _ b: (Int, Int)) -> Double {
        let px = Double(x - a.0), py = Double(y - a.1), dx = Double(b.0 - a.0), dy = Double(b.1 - a.1)
        let length = dx * dx + dy * dy
        let t = length == 0 ? 0 : min(1, max(0, (px * dx + py * dy) / length))
        let ex = px - t * dx, ey = py - t * dy
        return (ex * ex + ey * ey).squareRoot()
    }
    func path(_ a: (Int, Int), _ b: (Int, Int), steps: Int = 6) -> [(Int, Int)] {
        (0...steps).map { (a.0 + (b.0 - a.0) * $0 / steps, a.1 + (b.1 - a.1) * $0 / steps) }
    }
    func paint(_ kind: BrushKind, size: Int? = nil, seed: UInt64 = 7, button: MouseButton = .left,
               _ points: [(Int, Int)], width: Int = 80, height: Int = 60) -> (Bitmap, PaintDocument) {
        let host = FakeHost(width: width, height: height)
        host.document.color1 = red
        host.document.color2 = blue
        let tool = BrushTool()
        tool.kind = kind
        if let size = size { tool.size = size }
        tool.seed = seed
        tool.clock = ManualBrushClock()
        stroke(tool, host, points, button: button)
        return (host.document.bitmap, host.document)
    }

    check(BrushKind.allCases.count == 9 && ToolKind.brush.rawValue == 7 && ToolKind.shape.rawValue == 6,
          "nine brushes; the Brushes tool comes last, keeping the earlier tags")
    check(BrushKind.brush.sizes == [1, 3, 5, 8] && BrushKind.airbrush.sizes.first! > BrushKind.brush.sizes.last!
          && BrushKind.calligraphy1.sizes.last! > BrushKind.brush.sizes.last! && BrushKind.marker.sizes.last! > BrushKind.brush.sizes.last!,
          "brush sizes: 1, 3, 5, 8 px for the brush, larger for calligraphy, marker and airbrush")

    let blank = Bitmap(width: 80, height: 60)
    let a = (15, 30), b = (60, 30)
    for kind in BrushKind.allCases {
        let name = "\(kind)"
        let size = kind.sizes[1]
        let (left, document) = paint(kind, path(a, b))
        let marks = changed(left, from: blank)
        let reach = Double(size) / 2 + Double(size) / 10 + 1.5
        check(!marks.isEmpty && marks.allSatisfy { distance($0.0, $0.1, a, b) <= reach }, "\(name): paints near the path and nowhere else")
        if kind != .airbrush {
            check(left[37, 30] != white && left[a.0, a.1] != white && left[b.0, b.1] != white, "\(name): covers the path from end to end")
        }
        check(marks.allSatisfy { let c = RGB(packed: left[$0.0, $0.1]); return c.r == 255 && c.g == c.b },
              "\(name): the left button paints with Color 1")
        let (right, _) = paint(kind, button: .right, path(a, b))
        check(changed(right, from: blank).allSatisfy { let c = RGB(packed: right[$0.0, $0.1]); return c.b == 255 && c.r == c.g },
              "\(name): the right button paints with Color 2")
        let small = changed(paint(kind, size: kind.sizes[0], path(a, b)).0, from: blank).count
        let large = changed(paint(kind, size: kind.sizes[3], path(a, b)).0, from: blank).count
        check(large > small, "\(name): a larger size paints more")
        check(paint(kind, path(a, b)).0 == left, "\(name): the same seed paints the same stroke")
        check(document.canUndo && document.undo() && document.bitmap == blank && !document.canUndo, "\(name): one stroke is one undo step")

        let host = FakeHost(width: 80, height: 60)
        let tool = BrushTool()
        tool.kind = kind
        tool.clock = ManualBrushClock()
        tool.press(at: PixelPoint(x: 20, y: 20), button: .left, host: host)
        tool.drag(to: PixelPoint(x: 50, y: 40), host: host)
        let painted = host.document.bitmap != blank
        tool.cancel(host: host)
        check(painted && host.document.bitmap == blank && !host.document.canUndo, "\(name): cancelling restores the image")
    }
    check(paint(.airbrush, seed: 1, path(a, b)).0 != paint(.airbrush, seed: 2, path(a, b)).0, "another seed sprays other dots")

    // Calligraphy: a flat nib at 45°, mirrored between the two.
    let rising = path((20, 40), (40, 20)), falling = path((20, 20), (40, 40))
    for kind in [BrushKind.calligraphy1, .calligraphy2] {
        let up = changed(paint(kind, size: 12, rising).0, from: blank).count
        let down = changed(paint(kind, size: 12, falling).0, from: blank).count
        let thin = kind == .calligraphy1 ? up : down, thick = kind == .calligraphy1 ? down : up
        check(thick > thin * 2, "\(kind): thin along its nib, wide across it")
    }
    let one = paint(.calligraphy1, size: 12, falling).0
    let two = paint(.calligraphy2, size: 12, path((59, 20), (39, 40))).0
    var mirrored = true
    for y in 0..<60 { for x in 0..<80 where one[x, y] != two[79 - x, y] { mirrored = false } }
    check(mirrored, "calligraphy brush 2 is the mirror image of brush 1")

    // Airbrush: keeps spraying while the pointer rests, always inside the circle.
    do {
        let host = FakeHost(width: 80, height: 60)
        host.document.color1 = red
        let tool = BrushTool(), clock = ManualBrushClock()
        tool.kind = .airbrush
        tool.size = 24
        tool.seed = 3
        tool.clock = clock
        var sprays = 0
        tool.onSpray = { sprays += 1 }
        tool.press(at: PixelPoint(x: 40, y: 30), button: .left, host: host)
        let first = changed(host.document.bitmap, from: blank).count
        check(clock.isRunning && first > 0, "the airbrush starts spraying on press and starts its timer")
        clock.fire(20)
        let later = changed(host.document.bitmap, from: blank)
        check(later.count > first * 3 && sprays == 20, "with the button held still it keeps spraying")
        check(later.allSatisfy { distance($0.0, $0.1, (40, 30), (40, 30)) <= 12.8 }, "every dot falls inside the circle")
        check(later.allSatisfy { host.document.bitmap[$0.0, $0.1] == red.packed }, "airbrush dots are solid Color 1")
        tool.release(at: PixelPoint(x: 40, y: 30), host: host)
        let done = host.document.bitmap
        clock.fire(5)
        check(!clock.isRunning && host.document.bitmap == done && host.document.canUndo, "release stops the timer and keeps one step")
    }

    // Marker and watercolor: see-through, never building up within a stroke.
    do {
        let once = paint(.marker, size: 10, path((10, 30), (60, 30))).0
        let twice = paint(.marker, size: 10, path((10, 30), (60, 30)) + path((60, 30), (10, 30)) + path((10, 30), (60, 30))).0
        let c = RGB(packed: once[35, 30])
        check(c.r == 255 && c.g > 100 && c.g < 155, "the marker is half see-through")
        check(twice[35, 30] == once[35, 30] && twice[20, 32] == once[20, 32], "passing the marker again in one stroke does not darken it")
        let host = FakeHost(width: 80, height: 60)
        host.document.color1 = red
        let tool = BrushTool()
        tool.kind = .marker
        stroke(tool, host, path((10, 30), (60, 30)))
        stroke(tool, host, path((10, 30), (60, 30)))
        check(RGB(packed: host.document.bitmap[35, 30]).g < c.g, "a second stroke over it does darken, as in Paint")
        let wash = paint(.watercolor, size: 16, path((20, 30), (60, 30))).0
        let middle = RGB(packed: wash[40, 30]), edge = RGB(packed: wash[40, 36])
        check(middle.g > 60 && middle.g < 255 && edge.g > middle.g, "watercolor is see-through with soft edges")
    }

    // Textured outlines and fills.
    do {
        let box = DrawnShape.box(.rectangle, PixelRect(x: 4, y: 4, width: 32, height: 24))
        func render(_ outline: ShapeStyle, _ fill: ShapeStyle) -> Bitmap {
            var bitmap = Bitmap(width: 40, height: 32)
            ShapeRenderer.draw(box, options: ShapeOptions(outline: outline, fill: fill, width: 5), outline: red, fill: blue, on: &bitmap)
            return bitmap
        }
        let solid = render(.solid, .solid)
        let solidOutline = render(.solid, .none)
        for style in ShapeStyle.allCases where style.isTexture {
            let outlined = render(style, .none)
            let marks = changed(outlined, from: Bitmap(width: 40, height: 32))
            // Watercolor's soft edge may spill one pixel past the solid outline.
            let spill = style == .watercolor ? 1 : 0
            func nearOutline(_ x: Int, _ y: Int) -> Bool {
                for dy in -spill...spill { for dx in -spill...spill where solidOutline[min(39, max(0, x + dx)), min(31, max(0, y + dy))] != white { return true } }
                return false
            }
            check(outlined != solidOutline && !marks.isEmpty && marks.allSatisfy { nearOutline($0.0, $0.1) }
                  && outlined[20, 16] == white, "\(style) outline: textured, only where the solid outline goes")
            let filled = render(.solid, style)
            check(filled != solid && RGB(packed: filled[20, 16]).b > 0 && filled[20, 16] != blue.packed && filled[4, 4] == red.packed,
                  "\(style) fill: textured inside a solid outline")
        }
        check(render(.watercolor, .none)[20, 16] == white && render(.crayon, .crayon) == render(.crayon, .crayon),
              "textures are deterministic")
    }

    // Through the window.
    _ = NSApplication.shared
    let controller = MainWindowController()
    let canvas = controller.canvas, window = controller.window, toolbox = canvas.toolbox
    var document: PaintDocument { controller.document }
    func control(_ name: String) -> RibbonControl { controller.ribbon.control(name)! }
    let clock = ManualBrushClock()
    toolbox.brushTool.clock = clock
    toolbox.brushTool.seed = 5
    func reset() {
        document.replaceImage(Bitmap(width: 80, height: 60))
        document.color1 = red
        document.color2 = blue
        canvas.reload()
        controller.syncInterface()
    }
    func view(_ p: (Int, Int)) -> NSPoint {
        NSPoint(x: CanvasView.inset + (CGFloat(p.0) + 0.5) * canvas.zoom, y: CanvasView.inset + (CGFloat(p.1) + 0.5) * canvas.zoom)
    }
    func mouse(_ type: NSEvent.EventType, _ p: (Int, Int), _ flags: NSEvent.ModifierFlags = []) {
        mouse(type, view(p), flags)
    }
    func mouse(_ type: NSEvent.EventType, _ point: NSPoint, _ flags: NSEvent.ModifierFlags = []) {
        let event = NSEvent.mouseEvent(with: type, location: canvas.convert(point, to: nil), modifierFlags: flags,
                                       timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0,
                                       clickCount: 1, pressure: 1)!
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
    func drag(_ from: (Int, Int), _ to: (Int, Int), right: Bool = false, _ flags: NSEvent.ModifierFlags = []) {
        mouse(right ? .rightMouseDown : .leftMouseDown, from, flags)
        mouse(right ? .rightMouseDragged : .leftMouseDragged, ((from.0 + to.0) / 2, (from.1 + to.1) / 2), flags)
        mouse(right ? .rightMouseDragged : .leftMouseDragged, to, flags)
        mouse(right ? .rightMouseUp : .leftMouseUp, to, flags)
    }
    func key(_ code: UInt16, _ characters: String, _ flags: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: window.windowNumber,
                         context: nil, characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code)!
    }
    func menuItem(_ action: Selector, tag: Int = 0) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: action, keyEquivalent: "")
        item.tag = tag
        return item
    }
    func choose(_ kind: BrushKind) { controller.chooseBrush(menuItem(#selector(MainWindowController.chooseBrush(_:)), tag: kind.rawValue)) }

    // Ribbon and menus.
    reset()
    let button = control("home.brushes") as! RibbonButton
    check(button.isEnabled && button.isMainEnabled && button.menuAction == #selector(MainWindowController.showBrushMenu(_:))
          && button.action == #selector(MainWindowController.chooseTool(_:)) && !button.isChecked,
          "the Brushes button is a working split button")
    button.perform()
    check(toolbox.kind == .brush && toolbox.brushTool.kind == .brush && button.isChecked && !control("tool.pencil").isChecked
          && button.icon == .brushPlain, "its upper part picks the Brushes tool with the current brush")
    let items = controller.brushMenuItems()
    check(items.map(\.title) == ["Brush", "Calligraphy brush 1", "Calligraphy brush 2", "Airbrush", "Oil brush", "Crayon",
                                 "Marker", "Natural pencil", "Watercolor brush"] && items.allSatisfy { $0.image != nil },
          "the drop-down lists the nine brushes with icons")
    check(items[0].state == .on && items[1...].allSatisfy { $0.state == .off }, "the current brush is checked")
    check(controller.sizeMenuItems().map(\.tag) == [1, 3, 5, 8] && toolbox.brushTool.size == 3, "the brush offers 1, 3, 5 and 8 px")
    control("tool.pencil").perform()
    choose(.oil)
    check(toolbox.kind == .brush && toolbox.brushTool.kind == .oil && button.icon == .brushOil && button.isChecked,
          "picking a brush picks the tool and shows its icon on the button")
    check(controller.brushMenuItems()[BrushKind.oil.rawValue].state == .on
          && controller.validateMenuItem(menuItem(#selector(MainWindowController.chooseBrush(_:)), tag: BrushKind.oil.rawValue))
          && menuItem(#selector(MainWindowController.chooseBrush(_:)), tag: BrushKind.oil.rawValue).state == .off,
          "the menus check the chosen brush")
    let oilCheck = menuItem(#selector(MainWindowController.chooseBrush(_:)), tag: BrushKind.oil.rawValue)
    _ = controller.validateMenuItem(oilCheck)
    check(oilCheck.state == .on, "validating a brush item checks the current brush")
    check(controller.sizeMenuItems().map(\.tag) == BrushKind.oil.sizes, "the Size drop-down follows the brush")
    controller.chooseToolSize(menuItem(#selector(MainWindowController.chooseToolSize(_:)), tag: 30))
    check(window.performKeyEquivalent(with: key(24, "=", .control)) && toolbox.brushTool.size == 40, "Ctrl++ grows the brush")
    check(!controller.validateMenuItem(menuItem(#selector(MainWindowController.growToolSize(_:)))), "the largest size stops Ctrl++")
    choose(.marker)
    check(toolbox.brushTool.size == BrushKind.marker.defaultSize && window.performKeyEquivalent(with: key(27, "-", .control))
          && toolbox.brushTool.size == BrushKind.marker.sizes[0], "each brush keeps its own size; Ctrl+- shrinks it")
    choose(.oil)
    check(toolbox.brushTool.size == 40, "the oil brush remembers its size")
    let toolsMenu = controller.makeToolsMenu()
    let brushesItem = toolsMenu.items.first { $0.title == "Brushes" }
    check(brushesItem?.submenu?.items.count == 9 && brushesItem?.submenu?.items[3].title == "Airbrush"
          && !toolsMenu.items.contains { $0.tag == ToolKind.brush.rawValue && $0.action == #selector(MainWindowController.chooseTool(_:)) },
          "Tools > Brushes in the menu bar lists the nine brushes")
    check(ToolCursor.cursor(for: .brush, size: 16, zoom: 1, brush: .oil).image.size.width >= 16
          && ToolCursor.cursor(for: .brush, size: 1, zoom: 1).image.size.width == 16, "the cursor shows the brush footprint, or a cross when tiny")

    // Strokes through the window.
    choose(.brush)
    controller.chooseToolSize(menuItem(#selector(MainWindowController.chooseToolSize(_:)), tag: 3))
    drag((10, 10), (40, 10))
    check(document.bitmap[25, 10] == red.packed && document.bitmap[25, 20] == white && controller.validateMenuItem(menuItem(#selector(MainWindowController.undoEdit(_:)))),
          "a drag with the brush paints Color 1 and enables Undo")
    drag((10, 30), (40, 30), right: true)
    check(document.bitmap[25, 30] == blue.packed, "the right button paints Color 2")
    controller.undoEdit(nil)
    check(document.bitmap[25, 30] == white && document.bitmap[25, 10] == red.packed, "undo removes one stroke")
    let before = document.bitmap
    mouse(.leftMouseDown, (10, 50))
    mouse(.leftMouseDragged, (40, 50))
    mouse(.rightMouseDown, (40, 50))
    mouse(.leftMouseDragged, (60, 50))
    mouse(.leftMouseUp, (60, 50))
    check(document.bitmap == before, "the other button cancels the stroke")
    mouse(.leftMouseDown, (10, 50))
    mouse(.leftMouseDragged, (40, 50))
    canvas.keyDown(with: key(53, "\u{1B}"))
    mouse(.leftMouseUp, (40, 50))
    check(document.bitmap == before, "Esc cancels the stroke")
    choose(.airbrush)
    mouse(.leftMouseDown, (60, 40))
    let pressed = changed(document.bitmap, from: before).count
    clock.fire(15)
    let held = changed(document.bitmap, from: before).count
    mouse(.leftMouseUp, (60, 40))
    check(pressed > 0 && held > pressed && !clock.isRunning, "the airbrush keeps spraying while the button is held in the window")

    // Shapes: live textures, Delete and Shift on the handles.
    reset()
    controller.chooseShape(menuItem(#selector(MainWindowController.chooseShape(_:)), tag: GalleryShape.rectangle.rawValue))
    controller.chooseToolSize(menuItem(#selector(MainWindowController.chooseToolSize(_:)), tag: 5))
    drag((10, 10), (49, 39))
    let solidShape = document.bitmap
    controller.chooseOutline(menuItem(#selector(MainWindowController.chooseOutline(_:)), tag: ShapeStyle.crayon.rawValue))
    let crayon = document.bitmap
    check(document.shape != nil && crayon != solidShape && crayon[30, 25] == white, "a textured outline redraws the shape being edited")
    controller.chooseShapeFill(menuItem(#selector(MainWindowController.chooseShapeFill(_:)), tag: ShapeStyle.watercolor.rawValue))
    check(document.bitmap[30, 25] != white && document.bitmap[30, 25] != blue.packed, "a textured fill shows at once")
    let corner = CanvasView.selectionHandleRects(canvas.viewRect(document.shape!.shape.bounds))[SelectionHandle.bottomRight.rawValue]
    mouse(.leftMouseDown, NSPoint(x: corner.midX, y: corner.midY), .shift)
    mouse(.leftMouseDragged, (69, 44), .shift)
    mouse(.leftMouseUp, (69, 44), .shift)
    check(document.shape?.shape.bounds == PixelRect(x: 10, y: 10, width: 59, height: 44),
          "Shift on a corner handle keeps the shape's proportions")
    check(document.bitmap[65, 50] != white, "the stretched shape keeps its textures")
    check(ShapeTool.proportional(PixelRect(x: 0, y: 0, width: 30, height: 12), from: PixelRect(x: 0, y: 0, width: 20, height: 10), handle: .right)
          == PixelRect(x: 0, y: 0, width: 30, height: 12)
          && ShapeTool.proportional(PixelRect(x: 5, y: 8, width: 25, height: 12), from: PixelRect(x: 10, y: 10, width: 20, height: 10), handle: .topLeft)
          == PixelRect(x: 5, y: 7, width: 25, height: 13), "side handles stretch freely; corners keep proportions from the opposite corner")
    check(controller.validateMenuItem(menuItem(#selector(MainWindowController.delete(_:)))), "Delete is available for a shape being edited")
    canvas.keyDown(with: key(51, "\u{7F}"))
    check(document.shape == nil && document.bitmap == Bitmap(width: 80, height: 60) && !document.canUndo,
          "Delete throws away the shape being edited")
}
