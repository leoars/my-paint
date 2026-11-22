import AppKit

/// Shapes: geometry and rendering on small bitmaps, then the tool through the real window
/// with synthetic mouse and keyboard events, the ribbon and the menus.
func runShapeTests() {
    let white = RGB.white.packed
    let red = RGB(r: 255, g: 0, b: 0), blue = RGB(r: 0, g: 0, b: 255), green = RGB(r: 0, g: 160, b: 0)

    func render(_ shape: DrawnShape, _ options: ShapeOptions = ShapeOptions(), background: RGB = .white,
                width: Int = 40, height: Int = 40) -> Bitmap {
        var bitmap = Bitmap(width: width, height: height, fill: background)
        ShapeRenderer.draw(shape, options: options, outline: red, fill: blue, on: &bitmap)
        return bitmap
    }
    func pixels(_ bitmap: Bitmap, where test: (Int, Int, RGB) -> Bool) -> Int {
        var count = 0
        for y in 0..<bitmap.height { for x in 0..<bitmap.width where test(x, y, RGB(packed: bitmap[x, y])) { count += 1 } }
        return count
    }
    func close(_ a: UInt32, _ b: UInt32, _ tolerance: Int) -> Bool {
        let p = RGB(packed: a), q = RGB(packed: b)
        return abs(Int(p.r) - Int(q.r)) <= tolerance && abs(Int(p.g) - Int(q.g)) <= tolerance && abs(Int(p.b) - Int(q.b)) <= tolerance
    }
    func mirrored(_ bitmap: Bitmap, horizontally: Bool) -> Bool {
        for y in 0..<bitmap.height {
            for x in 0..<bitmap.width {
                let other = horizontally ? bitmap[bitmap.width - 1 - x, y] : bitmap[x, bitmap.height - 1 - y]
                if !close(bitmap[x, y], other, 40) { return false }
            }
        }
        return true
    }

    // Reference images: every gallery shape in a 32 × 32 box of a 40 × 40 image.
    let box = PixelRect(x: 4, y: 4, width: 32, height: 32)
    let horizontalMirror: Set<GalleryShape> = [.oval, .rectangle, .roundedRectangle, .triangle, .diamond, .pentagon, .hexagon,
                                               .upArrow, .downArrow, .star4, .star5, .star6, .heart]
    let verticalMirror: Set<GalleryShape> = [.oval, .rectangle, .roundedRectangle, .diamond, .hexagon, .leftArrow, .rightArrow,
                                             .star4, .star6]
    for kind in GalleryShape.allCases {
        let shape: DrawnShape
        switch kind {
        case .line: shape = .points(.line, [PixelPoint(x: 4, y: 4), PixelPoint(x: 35, y: 35)])
        case .curve: shape = .points(.curve, [PixelPoint(x: 4, y: 35), PixelPoint(x: 4, y: 4), PixelPoint(x: 35, y: 4), PixelPoint(x: 35, y: 35)])
        case .polygon: shape = .points(.polygon, [PixelPoint(x: 4, y: 4), PixelPoint(x: 35, y: 4), PixelPoint(x: 20, y: 35)])
        default: shape = .box(kind, box)
        }
        let name = "\(kind)"
        let outlined = render(shape)
        let area = ShapeRenderer.area(of: shape, width: 1)
        check(pixels(outlined) { x, y, _ in
            (x < area.x || y < area.y || x >= area.maxX || y >= area.maxY) && outlined[x, y] != white } == 0,
              "\(name): nothing is drawn outside its area")
        check(pixels(outlined) { _, _, c in c.b > c.r } == 0 && pixels(outlined) { _, _, c in c.r == 255 && c.g < 160 } > 10,
              "\(name): the outline uses the outline color")
        if !kind.usesPoints {
            let top = (box.x..<box.maxX).contains { outlined[$0, box.y] != white }
            let bottom = (box.x..<box.maxX).contains { outlined[$0, box.maxY - 1] != white }
            let left = (box.y..<box.maxY).contains { outlined[box.x, $0] != white }
            let right = (box.y..<box.maxY).contains { outlined[box.maxX - 1, $0] != white }
            check(top && bottom && left && right, "\(name): the outline touches all four sides of the box")
            // Curves may bleed a trace (a few levels) past the box where their stroke is approximated.
            check(pixels(outlined) { x, y, c in
                (x < box.x || y < box.y || x >= box.maxX || y >= box.maxY) && min(c.g, c.b) < 240 } == 0,
                  "\(name): the outline stays inside the box")
        }
        if horizontalMirror.contains(kind) { check(mirrored(outlined, horizontally: true), "\(name): left and right are mirror images") }
        if verticalMirror.contains(kind) { check(mirrored(outlined, horizontally: false), "\(name): top and bottom are mirror images") }
        guard kind.canFill else {
            let filledLine = render(shape, ShapeOptions(outline: .solid, fill: .solid, width: 1))
            check(filledLine == outlined, "\(name): Fill does not apply")
            let noOutline = render(shape, ShapeOptions(outline: .none, fill: .none, width: 1))
            check(noOutline == outlined, "\(name): it keeps its outline with No outline")
            continue
        }
        let filled = render(shape, ShapeOptions(outline: .solid, fill: .solid, width: 1))
        let inside = pixels(filled) { _, _, c in c == blue }
        check(inside > 40, "\(name): Fill paints the inside with the fill color")
        let hollow = render(shape, ShapeOptions(outline: .solid, fill: .none, width: 1), background: green)
        check(pixels(filled) { x, y, c in c == blue && hollow[x, y] != green.packed } == 0,
              "\(name): with No fill the inside keeps the image under it")
        let solidOnly = render(shape, ShapeOptions(outline: .none, fill: .solid, width: 1))
        check(pixels(solidOnly) { _, _, c in c.r > c.b } == 0 && pixels(solidOnly) { _, _, c in c == blue } >= inside,
              "\(name): with No outline the edge is not painted")
        let thick = render(shape, ShapeOptions(outline: .solid, fill: .none, width: 8))
        check(pixels(thick) { _, _, c in c == red } > pixels(outlined) { _, _, c in c == red },
              "\(name): a wider outline paints more")
    }

    // Exact pixels where the outline runs along pixel rows.
    let square = render(.box(.rectangle, PixelRect(x: 5, y: 6, width: 10, height: 8)))
    let onBorder = { (x: Int, y: Int) -> Bool in
        (5...14).contains(x) && (6...13).contains(y) && (x == 5 || x == 14 || y == 6 || y == 13)
    }
    check(pixels(square) { x, y, c in onBorder(x, y) != (c == red) } == 0, "a 1 px rectangle is exactly its border pixels")
    let wide = render(.box(.rectangle, PixelRect(x: 5, y: 5, width: 20, height: 20)), ShapeOptions(outline: .solid, fill: .solid, width: 3))
    check(wide[5, 5] == red.packed && wide[7, 15] == red.packed && wide[8, 15] == blue.packed && wide[24, 24] == red.packed
          && wide[4, 15] == white, "a 3 px outline lies inside the box, the fill inside it")
    let flat = render(.points(.line, [PixelPoint(x: 5, y: 10), PixelPoint(x: 30, y: 10)]))
    check((6...29).allSatisfy { flat[$0, 10] == red.packed } && flat[5, 10] != white && flat[30, 10] != white
          && (4...31).allSatisfy { flat[$0, 9] == white && flat[$0, 11] == white } && flat[3, 10] == white && flat[32, 10] == white,
          "a horizontal 1 px line covers exactly its row, with round ends")
    let bent = render(.points(.curve, [PixelPoint(x: 5, y: 30), PixelPoint(x: 20, y: 0), PixelPoint(x: 20, y: 0), PixelPoint(x: 35, y: 30)]))
    check(bent[20, 7] != white && bent[20, 30] == white && bent[5, 30] != white && bent[35, 30] != white,
          "a curve bends towards its control points")
    let straight = render(.points(.curve, [PixelPoint(x: 5, y: 10), PixelPoint(x: 5, y: 10), PixelPoint(x: 30, y: 10), PixelPoint(x: 30, y: 10)]))
    check(straight == flat, "a curve with its controls on the ends is the straight line")
    let open = render(.points(.polygon, [PixelPoint(x: 4, y: 4), PixelPoint(x: 35, y: 4), PixelPoint(x: 20, y: 35)], closed: false),
                      ShapeOptions(outline: .none, fill: .solid, width: 1))
    check(open[20, 4] != white && open[20, 15] == white && open[10, 20] == white, "an open polygon is drawn as lines, without fill")
    check(ShapeGeometry.path(for: .oval, in: CGRect(x: 0, y: 0, width: 10, height: 6)).boundingBoxOfPath
            == CGRect(x: 0, y: 0, width: 10, height: 6)
          && GalleryShape.allCases.filter { !$0.usesPoints }.allSatisfy { kind in
              let bounds = ShapeGeometry.path(for: kind, in: CGRect(x: 2, y: 3, width: 50, height: 30)).boundingBoxOfPath
              return abs(bounds.minX - 2) < 0.01 && abs(bounds.minY - 3) < 0.01 && abs(bounds.maxX - 52) < 0.01 && abs(bounds.maxY - 33) < 0.01
          }, "every box shape's path fills its rectangle exactly")

    // Pure helpers: Shift, moving and stretching.
    let origin = PixelPoint(x: 10, y: 10)
    check(ShapeTool.constrain(PixelPoint(x: 30, y: 20), from: origin, square: true) == PixelPoint(x: 30, y: 30)
          && ShapeTool.constrain(PixelPoint(x: 0, y: 25), from: origin, square: true) == PixelPoint(x: -5, y: 25),
          "Shift makes the box square, following the drag's direction")
    check(ShapeTool.constrain(PixelPoint(x: 30, y: 14), from: origin, square: false) == PixelPoint(x: 30, y: 10)
          && ShapeTool.constrain(PixelPoint(x: 12, y: -20), from: origin, square: false) == PixelPoint(x: 10, y: -20)
          && ShapeTool.constrain(PixelPoint(x: 30, y: 27), from: origin, square: false) == PixelPoint(x: 29, y: 29)
          && ShapeTool.constrain(PixelPoint(x: -8, y: 30), from: origin, square: false) == PixelPoint(x: -9, y: 29),
          "Shift snaps a line to multiples of 45°")
    let line = DrawnShape.points(.line, [PixelPoint(x: 0, y: 0), PixelPoint(x: 10, y: 4)])
    check(line.bounds == PixelRect(x: 0, y: 0, width: 11, height: 5) && line.moved(3, 2).bounds == PixelRect(x: 3, y: 2, width: 11, height: 5),
          "point shapes are bounded by their points and move with them")
    check(line.resized(to: PixelRect(x: 0, y: 0, width: 21, height: 9)).points == [PixelPoint(x: 0, y: 0), PixelPoint(x: 20, y: 8)]
          && DrawnShape.box(.oval, box).resized(to: PixelRect(x: 1, y: 2, width: 3, height: 4)).box == PixelRect(x: 1, y: 2, width: 3, height: 4),
          "stretching scales the points or sets the box")

    // Through the window.
    _ = NSApplication.shared
    let controller = MainWindowController()
    let canvas = controller.canvas, window = controller.window, toolbox = canvas.toolbox
    var document: PaintDocument { controller.document }
    func control(_ name: String) -> RibbonControl { controller.ribbon.control(name)! }
    let gallery = control("home.shapes") as! ShapeGalleryView
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
    func mouse(_ type: NSEvent.EventType, _ point: NSPoint, _ flags: NSEvent.ModifierFlags = [], clicks: Int = 1) {
        let event = NSEvent.mouseEvent(with: type, location: canvas.convert(point, to: nil), modifierFlags: flags,
                                       timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0,
                                       clickCount: clicks, pressure: 1)!
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
    func drag(_ from: (Int, Int), _ to: (Int, Int), _ flags: NSEvent.ModifierFlags = [], right: Bool = false) {
        let a = view(from), b = view(to)
        mouse(right ? .rightMouseDown : .leftMouseDown, a, flags)
        mouse(right ? .rightMouseDragged : .leftMouseDragged, NSPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2), flags)
        mouse(right ? .rightMouseDragged : .leftMouseDragged, b, flags)
        mouse(right ? .rightMouseUp : .leftMouseUp, b, flags)
    }
    func click(_ p: (Int, Int), clicks: Int = 1) {
        mouse(.leftMouseDown, view(p), clicks: clicks)
        mouse(.leftMouseUp, view(p), clicks: clicks)
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
    func pick(_ shape: GalleryShape) { gallery.press(shape.rawValue) }
    func outline(_ style: ShapeStyle) { controller.chooseOutline(menuItem(#selector(MainWindowController.chooseOutline(_:)), tag: style.rawValue)) }
    func fill(_ style: ShapeStyle) { controller.chooseShapeFill(menuItem(#selector(MainWindowController.chooseShapeFill(_:)), tag: style.rawValue)) }
    func enabled(_ action: Selector, _ tag: Int) -> Bool { controller.validateMenuItem(menuItem(action, tag: tag)) }
    let outlineAction = #selector(MainWindowController.chooseOutline(_:)), fillAction = #selector(MainWindowController.chooseShapeFill(_:))

    // Ribbon state
    reset()
    check(!control("home.outline").isEnabled && !control("home.shapeFill").isEnabled && gallery.selected == nil,
          "Outline and Fill are disabled until a shape is chosen")
    check(toolbox.shapeTool.outline == .solid && toolbox.shapeTool.fill == .none && toolbox.shapeTool.sizes == [1, 3, 5, 8]
          && toolbox.shapeTool.size == 1, "shapes start with a solid outline, no fill and 1 px")
    pick(.rectangle)
    check(toolbox.kind == .shape && gallery.selected == .rectangle && control("home.outline").isEnabled && control("home.shapeFill").isEnabled
          && !control("tool.pencil").isChecked, "a gallery shape picks the Shapes tool and shows checked")
    check(ToolKind.shape.rawValue == 6 && ToolKind.select.rawValue == 5, "the Shapes tool comes last, keeping the earlier tags")
    check(controller.sizeMenuItems().map(\.tag) == [1, 3, 5, 8], "the Size drop-down lists 1, 3, 5 and 8 px for shapes")
    check(enabled(outlineAction, ShapeStyle.none.rawValue) && enabled(outlineAction, ShapeStyle.solid.rawValue)
          && enabled(fillAction, ShapeStyle.solid.rawValue)
          && ShapeStyle.allCases.filter(\.isTexture).allSatisfy { enabled(outlineAction, $0.rawValue) && enabled(fillAction, $0.rawValue) },
          "every Outline and Fill choice is available, textures included")
    let outlineItems = controller.outlineMenuItems(), fillItems = controller.fillMenuItems()
    check(outlineItems.map(\.title) == ["No outline", "Solid color", "Crayon", "Marker", "Oil", "Natural pencil", "Watercolor"]
          && fillItems.first?.title == "No fill" && fillItems.count == 7, "the Outline and Fill menus list the original choices")
    _ = controller.validateMenuItem(outlineItems[1])
    _ = controller.validateMenuItem(fillItems[0])
    check(outlineItems[1].state == .on && fillItems[0].state == .on && outlineItems[0].state == .off, "the menus mark the current choices")
    pick(.line)
    check(!control("home.shapeFill").isEnabled && control("home.outline").isEnabled && !enabled(outlineAction, ShapeStyle.none.rawValue)
          && !enabled(fillAction, ShapeStyle.solid.rawValue), "line and curve disable Fill and No outline")
    pick(.heart)
    check(gallery.selected == .heart && gallery.firstRow == 1 && gallery.cellRect(GalleryShape.heart.rawValue) != nil,
          "picking a shape in a hidden row scrolls the gallery to it")
    gallery.scroll(-1)
    check(gallery.firstRow == 0 && gallery.cellRect(GalleryShape.heart.rawValue) == nil, "the gallery scrolls a row at a time")
    gallery.openAll()
    let all = RibbonPopup.current?.panel.contentView?.subviews.first as? ShapeGalleryView
    check(all?.visibleRows == 4 && all?.selected == .heart, "the third gallery button opens every shape")
    all?.press(GalleryShape.lightning.rawValue)
    check(toolbox.shapeTool.kind == .lightning && RibbonPopup.current == nil, "a shape in the open gallery is picked and the panel closes")
    check(gallery.accessibilityChildren()?.count == 26, "each shape and each scroll button is its own accessibility button")
    gallery.pressScrollPart(1)
    check(gallery.firstRow == 1, "the scroll-down button shows the last row")
    gallery.pressScrollPart(0)
    control("tool.pencil").perform()
    check(gallery.selected == nil && !control("home.outline").isEnabled, "another tool unchecks the gallery")
    let shapesMenu = controller.makeShapesMenu()
    check(shapesMenu.items.count == 26 && shapesMenu.items[3].title == "Rectangle" && shapesMenu.items[24].submenu?.items.count == 7,
          "the Shapes menu lists the 23 shapes, Outline and Fill")
    controller.chooseShape(shapesMenu.items[2])
    check(toolbox.kind == .shape && toolbox.shapeTool.kind == .oval && gallery.selected == .oval, "the Shapes menu picks a shape")
    check(!controller.makeToolsMenu().items.contains { $0.tag == ToolKind.shape.rawValue && $0.action == #selector(MainWindowController.chooseTool(_:)) },
          "the Tools menu leaves shapes to their own menu")

    // Drawing, editing handles and fixing.
    reset()
    pick(.rectangle)
    let blank = document.bitmap
    let a = view((10, 10)), b = view((29, 19))
    mouse(.leftMouseDown, a)
    mouse(.leftMouseDragged, b)
    check(controller.statusBar.selectionText == "20 × 10px", "the status bar shows the shape's size while dragging")
    mouse(.leftMouseUp, b)
    check(document.shape?.shape.bounds == PixelRect(x: 10, y: 10, width: 20, height: 10) && document.shape?.stage == .complete,
          "dragging draws a shape that stays editable")
    check(document.bitmap[10, 10] == red.packed && document.bitmap[29, 19] == red.packed && document.bitmap[20, 15] == white,
          "the outline takes Color 1 and No fill keeps the inside")
    check(controller.validateMenuItem(menuItem(#selector(MainWindowController.undoEdit(_:))))
          && !controller.validateMenuItem(menuItem(#selector(MainWindowController.redoEdit(_:)))) && !document.isDirty,
          "an editable shape enables Undo but is not a step yet")
    fill(.solid)
    check(document.bitmap[20, 15] == blue.packed, "choosing Fill redraws the shape at once with Color 2")
    controller.chooseToolSize(menuItem(#selector(MainWindowController.chooseToolSize(_:)), tag: 3))
    check(document.bitmap[12, 14] == red.packed && document.bitmap[13, 14] == blue.packed, "a new size redraws the outline")
    check(window.performKeyEquivalent(with: key(24, "=", .control)) && toolbox.shapeTool.size == 5 && document.bitmap[13, 14] == red.packed,
          "Ctrl++ widens the outline of the shape being edited")
    _ = window.performKeyEquivalent(with: key(27, "-", .control))
    check(toolbox.shapeTool.size == 3 && document.bitmap[13, 14] == blue.packed, "Ctrl+- narrows it")
    outline(.none)
    check(document.bitmap[10, 10] == blue.packed && pixels(document.bitmap) { _, _, c in c == red } == 0,
          "No outline redraws the shape without its edge")
    controller.swapColors(nil)
    check(document.bitmap[20, 15] == red.packed, "changing the colors redraws the shape")
    controller.swapColors(nil)
    outline(.solid)
    fill(.none)
    controller.chooseToolSize(menuItem(#selector(MainWindowController.chooseToolSize(_:)), tag: 1))
    check(document.bitmap[20, 15] == white && document.bitmap[10, 10] == red.packed, "the shape follows every change back")

    drag((20, 15), (30, 25))
    check(document.shape?.shape.bounds == PixelRect(x: 20, y: 20, width: 20, height: 10) && document.bitmap[10, 10] == white
          && document.bitmap[20, 20] == red.packed, "dragging inside the box moves the shape over the image it was drawn on")
    let corner = CanvasView.selectionHandleRects(canvas.viewRect(document.shape!.shape.bounds))[SelectionHandle.bottomRight.rawValue]
    mouse(.leftMouseDown, NSPoint(x: corner.midX, y: corner.midY))
    mouse(.leftMouseDragged, view((50, 40)))
    mouse(.leftMouseUp, view((50, 40)))
    check(document.shape?.shape.bounds == PixelRect(x: 20, y: 20, width: 30, height: 20) && document.bitmap[49, 39] == red.packed
          && document.bitmap[39, 29] == white, "the corner handle stretches the shape before it is fixed")
    check(controller.statusBar.selectionText == "30 × 20px", "the status bar follows the handles")
    click((70, 5))
    check(document.shape == nil && document.bitmap[20, 20] == red.packed && document.isDirty, "a click outside fixes the shape")
    let fixed = document.bitmap
    controller.undoEdit(nil)
    check(document.bitmap == blank, "one undo removes the fixed shape: one step per shape")
    controller.redoEdit(nil)
    check(document.bitmap == fixed, "redo puts it back")

    // Undo while editing, Esc, Enter, tool and shape changes.
    drag((5, 40), (15, 50))
    check(document.shape != nil, "a second shape is being edited")
    controller.undoEdit(nil)
    check(document.shape == nil && document.bitmap == fixed, "undo while editing discards only the shape being edited")
    drag((5, 40), (15, 50))
    canvas.keyDown(with: key(53, "\u{1B}"))
    check(document.shape == nil && document.bitmap[5, 40] == red.packed, "Esc fixes the shape")
    controller.undoEdit(nil)
    check(document.bitmap == fixed, "the shape fixed with Esc is one step")
    drag((5, 40), (15, 50))
    canvas.keyDown(with: key(36, "\r"))
    check(document.shape == nil && document.bitmap[5, 40] == red.packed, "Return fixes the shape")
    controller.undoEdit(nil)
    drag((5, 40), (15, 50))
    controller.chooseTool(menuItem(#selector(MainWindowController.chooseTool(_:)), tag: ToolKind.pencil.rawValue))
    check(document.shape == nil && document.bitmap[5, 40] == red.packed && controller.validateMenuItem(menuItem(#selector(MainWindowController.undoEdit(_:)))),
          "picking another tool fixes the shape")
    controller.undoEdit(nil)
    pick(.rectangle)
    drag((5, 40), (15, 50))
    pick(.oval)
    check(document.shape == nil && document.bitmap[5, 40] == red.packed && toolbox.shapeTool.kind == .oval, "picking another shape fixes the one being edited")
    controller.undoEdit(nil)
    check(document.bitmap == fixed, "each fixed shape is undone on its own")

    // Right button, cancelling, Shift.
    reset()
    pick(.rectangle)
    fill(.solid)
    drag((10, 10), (30, 30), right: true)
    check(document.bitmap[10, 10] == blue.packed && document.bitmap[20, 20] == red.packed, "the right button outlines with Color 2 and fills with Color 1")
    canvas.finishShape()
    let beforeCancel = document.bitmap
    mouse(.leftMouseDown, view((40, 10)))
    mouse(.leftMouseDragged, view((60, 30)))
    mouse(.rightMouseDown, view((60, 30)))
    mouse(.leftMouseUp, view((60, 30)))
    check(document.shape == nil && document.bitmap == beforeCancel, "pressing the other button while dragging cancels the shape")
    fill(.none)
    drag((40, 10), (60, 20), .shift)
    check(document.shape?.shape.bounds == PixelRect(x: 40, y: 10, width: 21, height: 21), "Shift draws a square")
    canvas.finishShape()
    pick(.oval)
    drag((10, 35), (40, 45), .shift)
    let circle = document.shape!.shape.bounds
    check(circle.width == circle.height && circle.width == 31, "Shift draws a circle")
    canvas.finishShape()
    reset()
    pick(.line)
    drag((10, 10), (40, 14), .shift)
    check(document.shape?.shape.points == [PixelPoint(x: 10, y: 10), PixelPoint(x: 40, y: 10)] && document.bitmap[25, 10] == red.packed,
          "Shift keeps a line horizontal")
    canvas.finishShape()
    drag((10, 20), (30, 37), .shift)
    check(document.shape?.shape.points.last == PixelPoint(x: 29, y: 39), "Shift snaps a line to 45°")
    controller.undoEdit(nil)

    // Curve: the line, then two control points.
    reset()
    pick(.curve)
    drag((10, 40), (70, 40))
    check(document.shape?.stage == .curveControl(1) && document.bitmap[40, 40] == red.packed, "the curve starts as a straight line")
    drag((40, 0), (40, 4))
    check(document.shape?.stage == .curveControl(2) && document.shape?.shape.points[1] == PixelPoint(x: 40, y: 4)
          && document.bitmap[40, 40] == white && document.bitmap[40, 13] != white, "the first control point bends the curve")
    click((60, 58))
    check(document.shape?.stage == .complete && document.shape?.shape.points == [PixelPoint(x: 10, y: 40), PixelPoint(x: 40, y: 4),
                                                                                   PixelPoint(x: 60, y: 58), PixelPoint(x: 70, y: 40)],
          "the second control point finishes the curve")
    click((75, 55))
    check(document.shape == nil && document.bitmap[10, 40] != white, "a click outside fixes the curve")

    // Polygon: drag the first side, click the others, close near the start or with a double click.
    reset()
    pick(.polygon)
    fill(.solid)
    drag((10, 10), (40, 10))
    check(document.shape?.stage == .polygonOpen && document.bitmap[25, 10] == red.packed, "the polygon starts with a dragged side")
    click((40, 40))
    click((10, 40))
    check(document.shape?.shape.points.count == 4 && document.bitmap[25, 25] == white, "each click adds a vertex; an open polygon is not filled")
    click((11, 11))
    check(document.shape?.stage == .complete && document.shape?.shape.isClosed == true && document.shape?.shape.points.count == 4
          && document.bitmap[25, 25] == blue.packed, "a click near the start closes and fills the polygon")
    canvas.finishShape()
    drag((50, 10), (70, 10))
    click((70, 30))
    click((50, 30))
    click((50, 30), clicks: 2)
    check(document.shape?.shape.isClosed == true && document.shape?.shape.points.count == 4, "a double click closes the polygon")
    drag((50, 40), (70, 40), .shift)
    check(document.shape?.stage == .polygonOpen && document.shape?.shape.points.count == 2, "a press outside fixes the polygon and starts another")
    mouse(.leftMouseDown, view((71, 55)), .shift)
    mouse(.leftMouseUp, view((71, 55)), .shift)
    check(document.shape?.shape.points.last == PixelPoint(x: 70, y: 55), "Shift keeps polygon sides at 45°")
    controller.chooseTool(menuItem(#selector(MainWindowController.chooseTool(_:)), tag: ToolKind.select.rawValue))
    check(document.shape == nil && document.bitmap[65, 44] == blue.packed, "another tool closes and fixes an open polygon")
    fill(.none)

    // Document commands fix the shape first.
    reset()
    pick(.rectangle)
    drag((10, 10), (20, 20))
    controller.invertColors(nil)
    check(document.shape == nil && document.bitmap[10, 10] == RGB(r: 0, g: 255, b: 255).packed, "Invert color fixes the shape, then inverts it")
    controller.undoEdit(nil)
    check(document.bitmap[10, 10] == red.packed, "the invert and the shape are separate steps")
}
