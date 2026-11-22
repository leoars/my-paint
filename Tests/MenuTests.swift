import AppKit

/// Phase 9: the ribbon's and the canvas's drop-downs are drawn menus in a `RibbonPopup`, not NSMenus.
func runMenuTests() {
    let controller = MainWindowController()
    let window = controller.window
    let canvas = controller.canvas
    let toolbox = canvas.toolbox
    let document = controller.document
    window.setFrame(NSRect(x: 0, y: 0, width: 1240, height: 860), display: false)
    window.orderFront(nil)
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("local.mypaint.tests.\(UUID().uuidString)"))
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    controller.pasteboard = pasteboard
    let ribbon = controller.ribbon!
    ribbon.selectPage(0)
    ribbon.layoutSubtreeIfNeeded()
    func control(_ name: String) -> RibbonControl { ribbon.control(name)! }
    func key(_ code: UInt16) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                         context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: code)!
    }
    let down: UInt16 = 125, up: UInt16 = 126, left: UInt16 = 123, right: UInt16 = 124, enter: UInt16 = 36, esc: UInt16 = 53
    @discardableResult
    func press(_ code: UInt16, times: Int = 1) -> Bool {
        var used = true
        for _ in 0..<times { used = (RibbonPopup.current?.handleKey(key(code)) ?? false) && used }
        return used
    }
    /// The drawn menu of the open panel.
    func openMenu() -> RibbonMenuView? { RibbonPopup.current?.content as? RibbonMenuView }
    func click(_ item: NSView) {
        guard let itemWindow = item.window else { return }
        let point = item.convert(NSPoint(x: item.bounds.midX, y: item.bounds.midY), to: nil)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0, windowNumber: itemWindow.windowNumber,
                                           context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
            type == .leftMouseDown ? item.mouseDown(with: event) : item.mouseUp(with: event)
        }
    }
    /// The panel's top-left corner sits one point under the button's bottom-left corner.
    func isUnder(_ button: NSView) -> Bool {
        guard let panel = RibbonPopup.current?.panel, let buttonWindow = button.window else { return false }
        let expected = buttonWindow.convertPoint(toScreen: button.convert(NSPoint(x: 0, y: button.bounds.height + 1), to: nil))
        return abs(panel.frame.minX - expected.x) < 1 && abs(panel.frame.maxY - expected.y) < 1
    }

    // MARK: Size
    toolbox.select(.pencil)
    controller.syncInterface()
    let sizeButton = control("home.size")
    sizeButton.perform()
    var menu = openMenu()
    check(menu != nil && menu?.name == "menu.size" && menu?.style == .sizes, "Size opens a drawn menu, not an NSMenu")
    check(isUnder(sizeButton), "the Size menu opens under its button")
    if let menu = menu {
        check(menu.entries.map(\.lineWidth) == [1, 2, 3, 4] && menu.entries.map(\.isChecked) == [true, false, false, false],
              "Size lists the pencil's four thicknesses as lines, the current one checked")
        check(menu.items[0].isChecked && menu.items.allSatisfy { $0.toolTip != nil }, "the lines say their size in a tooltip")
        check(menu.items.map(\.frame.height) == menu.items.map(\.frame.height).sorted(), "thicker lines get taller rows")
        check(menu.highlighted == nil && press(down) && menu.highlighted == 0 && press(down) && menu.highlighted == 1,
              "Down lights the first size, then the next")
        press(up, times: 2)
        check(menu.highlighted == 3, "Up wraps around to the last size")
        press(up, times: 2)
        check(press(enter) && toolbox.current.size == 2 && RibbonPopup.current == nil, "Enter picks the lit size and closes the menu")
    }
    toolbox.brushTool.kind = .oil
    toolbox.select(.brush)
    controller.showSizeMenu(sizeButton)
    if let menu = openMenu() {
        let thickness = menu.entries.compactMap(\.lineWidth).map(menu.sampleThickness)
        check(menu.entries.map(\.lineWidth) == [8, 16, 30, 40] && thickness == thickness.sorted() && Set(thickness).count == 4
              && thickness.last! <= RibbonTheme.sizeSampleMaxThickness, "large sizes are drawn smaller but still distinct")
        click(menu.items[2])
        check(toolbox.current.size == 30 && RibbonPopup.current == nil, "a click on a line picks that size and closes the menu")
    } else {
        check(false, "the brush's Size menu opens")
    }
    toolbox.select(.select)
    controller.showSizeMenu(sizeButton)
    if let menu = openMenu() {
        check(menu.entries.count == 1 && !menu.entries[0].isEnabled && menu.entries[0].lineWidth == nil && !menu.items[0].isEnabled,
              "a tool without sizes shows one disabled line")
        press(down)
        check(menu.highlighted == nil, "the arrows skip disabled items")
        check(press(esc) && RibbonPopup.current == nil, "Esc closes the menu")
    }

    // MARK: Outline and Fill
    controller.chooseShape(RibbonControl(title: ""))  // tag 0: the line
    let outlineButton = control("home.outline"), fillButton = control("home.shapeFill")
    controller.showOutlineMenu(outlineButton)
    if let menu = openMenu() {
        check(menu.name == "menu.outline" && menu.entries.map(\.title) == controller.outlineMenuItems().map(\.title)
              && menu.entries.allSatisfy { $0.image != nil }, "Outline lists the styles with their samples")
        check(!menu.entries[0].isEnabled && menu.entries[1].isChecked, "for a line No outline is disabled and Solid checked")
        press(down)
        check(menu.highlighted == 1, "Down skips the disabled No outline")
        check(isUnder(outlineButton), "the Outline menu opens under its button")
        RibbonPopup.current?.close()
    } else {
        check(false, "Outline opens a drawn menu")
    }
    controller.showShapeFillMenu(fillButton)
    if let menu = openMenu() {
        check(menu.entries.allSatisfy { !$0.isEnabled }, "a line has every fill disabled")
        press(down)
        check(menu.highlighted == nil, "and nothing to light")
        RibbonPopup.current?.close()
    }
    let rectangle = RibbonControl(title: "")
    rectangle.tag = GalleryShape.rectangle.rawValue
    controller.chooseShape(rectangle)
    fillButton.perform()
    if let menu = openMenu() {
        check(menu.name == "menu.shapeFill" && menu.entries.allSatisfy(\.isEnabled) && menu.entries[0].isChecked,
              "a rectangle offers every fill, No fill checked")
        click(menu.items[ShapeStyle.solid.rawValue])
        check(toolbox.shapeTool.fill == .solid && RibbonPopup.current == nil, "a click picks the fill and closes the menu")
    } else {
        check(false, "Fill opens a drawn menu")
    }
    controller.chooseShapeFill(RibbonControl(title: ""))  // tag 0: No fill

    // MARK: Brushes
    guard let brushes = control("home.brushes") as? RibbonButton else {
        check(false, "the Brushes split button exists")
        return
    }
    toolbox.brushTool.kind = .brush
    brushes.pressMenuPart()
    menu = openMenu()
    check(menu?.style == .gallery(columns: 3) && menu?.entries.count == 9, "Brushes opens a gallery of the nine brushes")
    if let menu = menu {
        let cell = RibbonTheme.brushGalleryCell
        check(menu.items.allSatisfy { $0.frame.width == cell && $0.frame.height == cell }
              && abs(menu.frame.width - (3 * cell + 2 * RibbonTheme.dropdownPadding)) < 0.01, "in three columns of large cells")
        check(menu.entries[0].isChecked && menu.entries.dropFirst().allSatisfy { !$0.isChecked }, "the current brush is checked")
        press(right)
        check(menu.highlighted == 0, "Right lights the first brush")
        press(right)
        press(down)
        check(menu.highlighted == 4, "Right and Down move across and down the grid")
        press(down, times: 2)
        check(menu.highlighted == 7, "Down stops at the last row")
        press(left)
        check(menu.highlighted == 6, "Left goes back")
        press(enter)
        check(toolbox.kind == .brush && toolbox.brushTool.kind == .marker && RibbonPopup.current == nil,
              "Enter picks the brush and closes the gallery")
    }

    // MARK: Paste
    guard let paste = control("home.paste") as? RibbonButton else { return }
    paste.pressMenuPart()
    menu = openMenu()
    check(menu?.name == "menu.paste" && menu?.entries.map(\.title) == ["Paste", "Paste from"], "Paste lists Paste and Paste from")
    if let menu = menu {
        check(!menu.entries[0].isEnabled && menu.entries[1].isEnabled, "Paste is disabled with nothing to paste")
        check(isUnder(paste), "the Paste menu opens under the button")
        press(down)
        check(menu.highlighted == 1, "Down goes straight to Paste from")
        check(press(esc) && RibbonPopup.current == nil, "Esc closes it")
    }

    // MARK: Select
    guard let select = control("home.select") as? RibbonButton else { return }
    toolbox.selectionTool.shape = .rectangle
    select.pressMenuPart()
    menu = openMenu()
    if let menu = menu {
        check(menu.entries.map(\.kind) == [.header, .command, .command, .separator, .header, .command, .command, .command, .command],
              "Select has two headers, a separator and six commands")
        check(menu.entries[0].title == "Selection shapes" && menu.entries[4].title == "Selection options",
              "the headers are Selection shapes and Selection options")
        check(menu.entries[1].isChecked && !menu.entries[2].isChecked && !menu.entries[8].isChecked,
              "the rectangle is checked, transparency is not")
        check(!menu.entries[6].isEnabled && !menu.entries[7].isEnabled, "Invert selection and Delete wait for a selection")
        check(menu.items[0].accessibilityRole() == .staticText && !menu.items[3].isAccessibilityElement()
              && menu.items[1].accessibilityRole() == .menuItem, "headers read as text, separators are skipped")
        press(down)
        check(menu.highlighted == 1, "Down skips the first header")
        press(down, times: 2)
        check(menu.highlighted == 5, "and the separator with the second header")
        press(down)
        check(menu.highlighted == 8, "and the disabled commands")
        press(down)
        check(menu.highlighted == 1, "then wraps to the top")
        press(up)
        check(menu.highlighted == 8, "Up wraps to the bottom")
        press(enter)
        check(document.transparentSelection && RibbonPopup.current == nil, "Enter toggles Transparent selection")
    } else {
        check(false, "Select opens a drawn menu")
    }
    select.pressMenuPart()
    if let menu = openMenu() {
        check(menu.entries[8].isChecked && menu.items[8].accessibilityValue() as? Int == 1, "the menu shows it checked")
        click(menu.items[2])
        check(toolbox.selectionTool.shape == .freeForm && toolbox.kind == .select && RibbonPopup.current == nil,
              "a click on Free-form selection picks it and closes the menu")
    }
    controller.toggleTransparentSelection(nil)
    toolbox.selectionTool.shape = .rectangle

    // MARK: Rotate
    let rotateButton = control("home.rotate")
    let width = document.bitmap.width, height = document.bitmap.height
    rotateButton.perform()
    menu = openMenu()
    check(menu?.name == "menu.rotate" && menu?.entries.count == 5 && menu?.entries.allSatisfy { $0.isEnabled && $0.image != nil } == true,
          "Rotate lists the five turns with their icons")
    check(isUnder(rotateButton), "the Rotate menu opens under the button")
    press(down)
    press(enter)
    check(document.bitmap.width == height && document.bitmap.height == width && RibbonPopup.current == nil,
          "Enter on Rotate right turns the image and closes the menu")
    controller.undoEdit(nil)

    // MARK: Interface text size
    ribbon.selectPage(1)
    let sizeDropdown = control("view.interfaceSize")
    sizeDropdown.perform()
    menu = openMenu()
    if let menu = menu {
        check(menu.name == "menu.interfaceSize" && menu.entries.map(\.title) == ["Small", "Normal", "Large", "Extra large"]
              && menu.entries.map(\.isChecked) == [false, true, false, false], "Text size lists the four sizes, Normal checked")
        check(isUnder(sizeDropdown), "the Text size menu opens under its button")
        check(menu.accessibilityRole() == .menu && menu.items.allSatisfy { $0.accessibilityRole() == .menuItem }
              && menu.items[2].accessibilityLabel() == "Large", "the menu and its items are accessible")
        check(menu.items[2].accessibilityPerformPress() && controller.interfaceSize == .large && RibbonPopup.current == nil,
              "pressing an item through accessibility runs it")
    } else {
        check(false, "Text size opens a drawn menu")
    }
    controller.interfaceSize = .normal
    ribbon.selectPage(0)

    // MARK: Context menu and its Rotate submenu
    toolbox.select(.select)
    let point = NSPoint(x: canvas.imageRect.minX + 40, y: canvas.imageRect.minY + 30)
    let rightClick = NSEvent.mouseEvent(with: .rightMouseDown, location: canvas.convert(point, to: nil), modifierFlags: [], timestamp: 0,
                                        windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
    canvas.rightMouseDown(with: rightClick)
    menu = openMenu()
    check(menu?.name == "menu.context", "a right click with the selection tool opens the drawn context menu")
    if let menu = menu, let popup = RibbonPopup.current {
        let expected = window.convertPoint(toScreen: canvas.convert(point, to: nil))
        check(abs(popup.panel.frame.minX - expected.x) < 1 && abs(popup.panel.frame.maxY - expected.y) < 1,
              "it opens at the pointer")
        check(menu.entries.map(\.title) == ["Cut", "Copy", "Paste", "", "Select all", "Invert selection", "Delete", "", "Rotate", "Resize",
                                            "Invert color"] && menu.entries[8].hasSubmenu, "it has the commands of the original")
        check(menu.entries[0...2].allSatisfy { !$0.isEnabled } && menu.entries[4].isEnabled, "Cut, Copy and Paste wait for something to use")
        press(down)
        check(menu.highlighted == 4, "Down lights Select all, the first command available")
        press(down)
        check(menu.highlighted == 8, "and skips the disabled commands and the separator to Rotate")
        press(right)
        let submenu = menu.submenu
        check(submenu != nil && submenu?.entries.count == 5 && submenu?.highlighted == 0, "Right opens the Rotate submenu on its first turn")
        if let subPanel = menu.openSubmenuPanel {
            check(subPanel.isVisible && popup.owns(subPanel) && subPanel.frame.minX >= popup.panel.frame.maxX - 1,
                  "the submenu opens beside the menu, in a panel of its own")
        }
        press(left)
        check(menu.submenu == nil && menu.openSubmenuPanel == nil && popup.isOpen, "Left closes only the submenu")
        press(enter)
        check(menu.submenu?.highlighted == 0, "Enter on Rotate opens it too")
        press(down)
        check(menu.submenu?.highlighted == 1 && menu.highlighted == 8, "Down moves inside the submenu")
        press(esc)
        check(menu.submenu == nil && popup.isOpen, "Esc closes the submenu first")
        menu.items[8].hover(at: NSPoint(x: 5, y: 5))
        check(menu.submenu != nil && menu.highlighted == 8, "pointing at Rotate opens the submenu")
        menu.items[8].hover(at: nil)
        check(menu.submenu != nil && menu.highlighted == 8, "and it stays open while the pointer goes into it")
        menu.items[9].hover(at: NSPoint(x: 5, y: 5))
        check(menu.submenu == nil && menu.highlighted == 9, "pointing at another command closes it")
        menu.items[8].hover(at: NSPoint(x: 5, y: 5))
        if let turn = menu.submenu?.items[0] {
            let before = document.bitmap
            click(turn)
            check(document.bitmap.width == before.height && document.bitmap.height == before.width && RibbonPopup.current == nil
                  && menu.openSubmenuPanel == nil, "a click in the submenu runs the command and closes both panels")
            controller.undoEdit(nil)
        } else {
            check(false, "the submenu has Rotate right")
        }
    }
    controller.showContextMenuFromKeyboard(nil)
    check(openMenu()?.name == "menu.context", "Shift+F10 opens the same drawn menu")
    press(esc)

    // MARK: Interface factor
    RibbonTheme.scale = 2
    toolbox.select(.pencil)
    controller.showSizeMenu(sizeButton)
    if let popup = RibbonPopup.current, let menu = openMenu() {
        check(abs(popup.panel.frame.width - ceil((menu.frame.width + 2) * 2)) < 1
              && abs((popup.panel.contentView?.bounds.width ?? 0) - (menu.frame.width + 2)) < 0.01,
              "at twice the size the menu's panel is twice as large, its layout unchanged")
        popup.close()
    } else {
        check(false, "the Size menu opens at twice the size")
    }
    RibbonTheme.scale = 1

    // MARK: Drawing
    controller.showRotateMenu(rotateButton)
    if let menu = openMenu() {
        func pixels(_ view: NSView) -> Data? {
            guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
            view.cacheDisplay(in: view.bounds, to: rep)
            return rep.tiffRepresentation
        }
        let plain = pixels(menu.items[1])
        press(down, times: 2)
        check(menu.highlighted == 1 && pixels(menu.items[1]) != plain, "the lit item is drawn with a highlight")
        RibbonPopup.current?.close()
    }
    window.orderOut(nil)
}

/// Text of the drawn menus that does not fit its item, for `clippedLabels`.
func clippedMenuLabels(_ controller: MainWindowController) -> [String] {
    var problems: [String] = []
    let none = RibbonMenuView(entries: [RibbonMenuEntry(title: L("size.none"), isEnabled: false)], style: .sizes, name: "size.none")
    var menus = [none, controller.makeRibbonMenu(controller.outlineMenuItems(), name: "outline"),
                 controller.makeRibbonMenu(controller.fillMenuItems(), name: "fill"),
                 controller.makeRibbonMenu(controller.interfaceSizeMenuItems(), name: "interfaceSize"),
                 controller.makeRibbonMenu(controller.pasteMenuItems(), name: "paste"),
                 controller.makeRibbonMenu(controller.selectMenuItems(), name: "select"),
                 controller.makeRibbonMenu(controller.rotateMenuItems(), name: "rotate"),
                 controller.makeCanvasContextMenu()]
    if let context = menus.last, let rotate = context.entries.first(where: \.hasSubmenu) {
        menus.append(RibbonMenuView(entries: rotate.submenu, name: "context.rotate"))
    }
    let attributes = RibbonTheme.attributes()
    for menu in menus {
        for item in menu.items where !item.entry.title.isEmpty && item.entry.lineWidth == nil {
            let entry = item.entry
            let text: CGFloat, start: CGFloat, end: CGFloat
            if entry.kind == .header {
                text = RibbonMenuView.headerTextWidth(entry.title)
                start = RibbonTheme.dropdownTextGap
                end = item.bounds.width
            } else {
                text = RibbonTheme.textWidth(entry.title)
                start = RibbonTheme.dropdownGutterWidth + RibbonTheme.dropdownTextGap
                end = item.bounds.width - (entry.hasSubmenu ? 18 : 2)
            }
            let lineHeight = (entry.title as NSString).size(withAttributes: attributes).height
            if start + text > end || lineHeight > item.bounds.height || item.frame.maxX > menu.bounds.width {
                problems.append("menu \(menu.name): \(entry.title)")
            }
        }
    }
    return problems
}
