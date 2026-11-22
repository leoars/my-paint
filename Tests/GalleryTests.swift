import AppKit

/// The Shapes gallery losing columns before its group collapses.
func runGalleryTests() {
    _ = NSApplication.shared

    // The layout steps on their own.
    let widths: [[CGFloat]] = [[100, 50], [200, 180, 160, 140, 60], [100, 40]]
    let steps: [RibbonLayout.Step] = [.shrink(1), .collapse(2), .collapse(1), .collapse(0)]
    check(RibbonLayout.forms(widths: widths, steps: steps, available: 400) == [0, 0, 0], "nothing gets narrower when everything fits")
    check(RibbonLayout.forms(widths: widths, steps: steps, available: 385) == [0, 1, 0], "the gallery loses one column when one is enough")
    check(RibbonLayout.forms(widths: widths, steps: steps, available: 345) == [0, 3, 0], "and keeps losing them, one at a time")
    check(RibbonLayout.forms(widths: widths, steps: steps, available: 320) == [0, 3, 1],
          "past its narrowest form the next group collapses, the gallery staying narrow")
    check(RibbonLayout.forms(widths: widths, steps: steps, available: 200) == [0, 4, 1], "then the gallery's own group collapses")
    check(RibbonLayout.forms(widths: widths, steps: steps, available: 10) == [1, 4, 1], "and at the end every group")
    check(RibbonLayout.forms(widths: [[100, 90, 120]], steps: [.shrink(0), .collapse(0)], available: 10) == [1],
          "a collapse that would not be narrower is skipped")
    check(RibbonLayout.forms(widths: [[100, 80, 60, 50]], steps: [.collapse(0)], available: 70) == [3],
          "without a shrink step a group collapses straight from its widest form")

    // The gallery itself, in fewer columns.
    let gallery = ShapeGalleryView(title: "Shapes")
    gallery.shapeNames = GalleryShape.allCases.map { "\($0)" }
    gallery.scrollNames = ["up", "down", "more"]
    let cell = ShapeGalleryView.cell
    check(gallery.columns == 7 && gallery.totalRows == 4 && gallery.frame.width == 7 * cell + 2 + ShapeGalleryView.scrollWidth,
          "the gallery starts with seven columns in four rows")
    gallery.columns = 5
    check(gallery.frame.width == 5 * cell + 2 + ShapeGalleryView.scrollWidth && gallery.totalRows == 5 && gallery.lastFirstRow == 2,
          "five columns make it narrower and need five rows")
    check(gallery.index(at: NSPoint(x: 1 + 4 * cell + 5, y: 1 + cell + 5)) == 9 && gallery.index(at: NSPoint(x: 1 + 5 * cell + 5, y: 5)) == nil,
          "a point maps to the shape of its row and column, and nothing past the last column")
    check(gallery.cellRect(5) == NSRect(x: 1, y: 1 + cell, width: cell, height: cell) && gallery.cellRect(15) == nil,
          "shapes wrap to the next row and the rows past the third are scrolled away")
    gallery.scroll(5)
    check(gallery.firstRow == 2 && gallery.cellRect(22) == NSRect(x: 1 + 2 * cell, y: 1 + 2 * cell, width: cell, height: cell),
          "the gallery scrolls down to the last row and stops there")
    gallery.columns = 7
    check(gallery.firstRow == 1, "widening it again keeps the first row inside the four rows")
    gallery.scroll(-5)
    gallery.columns = 3
    gallery.selected = .lightning
    let lightning = GalleryShape.lightning.rawValue
    check(gallery.totalRows == 8 && gallery.cellRect(lightning) != nil && gallery.firstRow == lightning / 3 - 2,
          "in three columns picking a shape scrolls it into sight")
    gallery.columns = 6
    check(gallery.cellRect(lightning) != nil, "changing the columns keeps the chosen shape in sight")
    gallery.columns = 4
    gallery.scroll(-10)
    let host = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
    host.contentView?.addSubview(gallery)
    let elements = (gallery.accessibilityChildren() ?? []).compactMap { $0 as? NSAccessibilityElement }
    let visible = elements.prefix(23).filter { $0.accessibilityFrame() != .zero }
    check(elements.count == 26 && visible.count == 12, "accessibility still has every shape, and frames for the twelve in sight")
    let scrollFrame = elements[24].accessibilityFrame()
    check(abs(scrollFrame.minX - host.convertToScreen(gallery.convert(NSRect(x: 4 * cell + 1, y: 0, width: 1, height: 1), to: nil)).minX) < 0.5,
          "the scroll buttons sit right after the fourth column")
    _ = elements[25].accessibilityPerformPress()
    let all = RibbonPopup.current?.panel.contentView?.subviews.first as? ShapeGalleryView
    check(all?.columns == 7 && all?.visibleRows == 4 && all?.totalRows == 4 && all?.scrolls == false,
          "the \"more\" button of a narrow gallery still opens every shape in seven columns")
    RibbonPopup.current?.close()
    gallery.removeFromSuperview()

    // Through the window.
    let controller = MainWindowController()
    let ribbon = controller.ribbon!
    ribbon.selectPage(0)
    let home = ribbon.pages[0].groups
    let shapes = home[4]
    let shapesGallery = ribbon.control("home.shapes") as! ShapeGalleryView
    let outline = ribbon.control("home.outline")!, fill = ribbon.control("home.shapeFill")!
    let wide = MainWindowController.ribbonWidth(ribbon)
    func width(_ value: CGFloat) { controller.window.setContentSize(NSSize(width: value, height: 700)) }
    width(wide)
    check(shapesGallery.columns == 7 && home.allSatisfy { !$0.isCollapsed } && shapes.form == 0, "with room to spare the gallery has seven columns")
    check(shapes.formWidths.count == 6 && shapes.formWidths.last == shapes.collapsedWidth
          && zip(shapes.formWidths, shapes.formWidths.dropFirst()).allSatisfy { $0.0 - $0.1 == cell || $0.1 == shapes.collapsedWidth },
          "the Shapes group has five widths, a column apart, then the collapsed one")
    width(wide - 1)
    check(shapesGallery.columns == 7 && home[6].isCollapsed && home.filter(\.isCollapsed).count == 1,
          "a point short, Colors collapses first and the gallery keeps seven columns")
    let colorsSaved = home[6].expandedWidth - home[6].collapsedWidth
    width(wide - colorsSaved)
    check(shapesGallery.columns == 7 && home.filter(\.isCollapsed).count == 1, "with Colors collapsed the seven columns fit")
    width(wide - colorsSaved - 1)
    check(shapesGallery.columns == 6 && home.filter(\.isCollapsed).count == 1, "a point less and the gallery loses a column, nothing else collapses")
    width(wide - colorsSaved - cell - 1)
    check(shapesGallery.columns == 5, "another column short, it loses another")
    width(wide - colorsSaved - 4 * cell)
    check(shapesGallery.columns == 3 && home.filter(\.isCollapsed).count == 1, "down to three columns before another group collapses")
    check(outline.frame.minX >= shapesGallery.frame.maxX && fill.frame.minX >= shapesGallery.frame.maxX
          && outline.frame.maxX <= shapes.content.bounds.width + 0.5 && shapes.content.frame.maxX <= shapes.bounds.width,
          "Outline and Fill follow the narrower gallery and stay inside the group")
    width(wide - colorsSaved - 4 * cell - 1)
    check(home.filter(\.isCollapsed).count == 2 && (shapes.isCollapsed || shapesGallery.columns == 3),
          "then the next group from the right collapses, the gallery not taking its columns back")
    // Every width from wide to narrow: the columns never come back as the window narrows, and nothing leaves the ribbon.
    var previous = (columns: 7, collapsed: 0)
    var monotonic = true, inside = true, columnsSeen = Set<Int>()
    var value = wide
    while value >= 300 {
        width(value)
        let collapsed = home.filter(\.isCollapsed).count
        if !shapes.isCollapsed {
            columnsSeen.insert(shapesGallery.columns)
            if shapesGallery.columns > previous.columns { monotonic = false }
            previous.columns = shapesGallery.columns
        }
        if collapsed < previous.collapsed { monotonic = false }
        previous.collapsed = collapsed
        if (home.last?.frame.maxX ?? 0) > ribbon.bounds.width + 0.5 && home.contains(where: { !$0.isCollapsed && $0.collapsedWidth < $0.expandedWidth }) {
            inside = false
        }
        for group in home where !group.isCollapsed {
            if group.content.subviews.contains(where: { $0.frame.maxX > group.content.bounds.width + 0.5 }) { inside = false }
        }
        value -= 5
    }
    check(columnsSeen == [3, 4, 5, 6, 7], "narrowing the window goes through 7, 6, 5, 4 and 3 columns")
    check(monotonic, "as the window narrows the gallery only loses columns and groups only collapse")
    check(inside, "at every width the groups fit the ribbon and no control leaves its group")
    width(640)
    check(shapes.isCollapsed && shapesGallery.columns == 7, "in the end the Shapes group collapses, its gallery back to seven columns")
    ribbon.openCollapsed(shapes)
    check(shapesGallery.window === RibbonPopup.current?.panel && shapesGallery.frame.maxX <= outline.frame.minX,
          "the collapsed group's panel shows the full gallery")
    RibbonPopup.current?.close()
    width(wide - colorsSaved - 2 * cell)
    check(!shapes.isCollapsed && shapesGallery.columns == 5 && shapes.content.superview === shapes,
          "widening the window brings the group back at the width that fits")
    let clipped = clippedLabels(controller)
    check(clipped.isEmpty, "with a narrower gallery nothing is cut" + (clipped.isEmpty ? "" : " — " + clipped.joined(separator: "; ")))
    width(wide)
    check(shapesGallery.columns == 7, "and the full width gives the seven columns back")
    controller.window.close()
}
