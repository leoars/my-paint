import AppKit

/// The ribbon, the application menu and the status bar, driven through their own controls.
func runRibbonTests() {
    _ = NSApplication.shared
    AppSettings.defaults.set(true, forKey: MainWindowController.showsStatusBarKey)
    let controller = MainWindowController()
    let ribbon = controller.ribbon!
    let toolbox = controller.canvas.toolbox
    func control(_ name: String) -> RibbonControl { ribbon.control(name)! }

    // Tools and Size
    control("tool.eraser").perform()
    check(toolbox.kind == .eraser && control("tool.eraser").isChecked && !control("tool.pencil").isChecked,
          "a ribbon tool button selects the tool and shows it checked")
    check(control("home.size").isEnabled, "Size is enabled for the eraser")
    let eraserSizes = controller.sizeMenuItems()
    check(eraserSizes.map(\.tag) == [4, 6, 8, 10] && eraserSizes.map(\.title) == ["4 px", "6 px", "8 px", "10 px"],
          "the Size drop-down lists the eraser sizes")
    check(eraserSizes.filter { $0.state == .on }.map(\.tag) == [8], "the Size drop-down marks the current size")
    controller.chooseToolSize(eraserSizes[0])
    check(toolbox.current.size == 4, "a Size drop-down item sets the size")
    control("tool.fill").perform()
    check(!control("home.size").isEnabled, "Size is disabled for tools without a size")
    check(controller.sizeMenuItems().count == 1 && !controller.sizeMenuItems()[0].isEnabled, "the Size list says there is no size")
    control("tool.pencil").perform()
    check(controller.sizeMenuItems().map(\.tag) == [1, 2, 3, 4] && control("home.size").isEnabled, "the pencil offers 1 to 4 px")
    check(control("tool.text").isEnabled, "the Text tool is enabled")

    // Colors: the palette sets Color 1 or Color 2, whichever button is selected.
    let palette = control("home.palette") as! PaletteView
    let well1 = control("home.color1") as! ColorWellButton, well2 = control("home.color2") as! ColorWellButton
    check(well1.isChecked && !well2.isChecked, "Color 1 starts selected")
    well2.perform()
    check(controller.activeColorSlot == .color2 && well2.isChecked && !well1.isChecked, "the Color 2 button becomes the selected one")
    palette.press(3)
    check(controller.document.color2 == Palette.colors[3].color && controller.document.color1 == .black,
          "with Color 2 selected a palette click sets Color 2")
    check(well2.color == Palette.colors[3].color, "the Color 2 button shows the new color")
    well1.perform()
    palette.press(6)
    check(controller.document.color1 == Palette.colors[6].color && well1.color == Palette.colors[6].color
          && controller.document.color2 == Palette.colors[3].color, "with Color 1 selected a palette click sets Color 1")
    let before = (controller.document.color1, controller.document.color2)
    palette.press(25)
    check(controller.document.color1 == before.0 && controller.document.color2 == before.1, "an empty custom place does nothing")
    check(palette.colors.count == 30 && palette.colors[20...].allSatisfy { $0 == nil }, "the palette has 20 colors and 10 empty places")
    check(palette.index(at: NSPoint(x: PaletteView.cell * 3 + 5, y: 5)) == 3
          && palette.index(at: NSPoint(x: 5, y: PaletteView.cell + 5)) == 10, "palette cells map to the color order")
    check(palette.accessibilityChildren()?.count == 20, "each standard color is its own accessibility button")

    // Controls of the View and system phase are all enabled now.
    let later = ["home.editColors", "view.rulers", "view.gridlines", "view.fullScreen", "view.thumbnail", "view.interfaceSize"]
    controller.syncInterface()
    check(later.allSatisfy { control($0).isEnabled && control($0).action != nil }, "every View tab control and Edit colors work")
    let previous = toolbox.kind
    control("tool.eraser").isEnabled = false
    control("tool.eraser").perform()
    check(toolbox.kind == previous, "a disabled button does nothing")
    control("tool.eraser").isEnabled = true

    // Quick access strip
    check(!control("qat.undo").isEnabled && !control("qat.redo").isEnabled && control("qat.save").isEnabled,
          "Undo and Redo start disabled, Save enabled")
    let document = controller.document
    let snapshot = document.bitmap
    document.draw { $0.set(x: 1, y: 1, to: RGB.black.packed) }
    document.commit(before: snapshot, changed: PixelRect(x: 1, y: 1, width: 1, height: 1))
    controller.syncInterface()
    check(control("qat.undo").isEnabled, "an edit enables Undo in the quick access strip")
    control("qat.undo").perform()
    check(document.bitmap == snapshot && control("qat.redo").isEnabled && !control("qat.undo").isEnabled,
          "the quick access Undo undoes and enables Redo")

    // Tabs
    check(ribbon.selectedPage == 0 && ribbon.tabs[0].isChecked, "Home is the first tab")
    ribbon.tabs[1].perform()
    check(ribbon.selectedPage == 1 && ribbon.tabs[1].isChecked && !ribbon.tabs[0].isChecked
          && ribbon.pages[1].groups.allSatisfy { $0.superview != nil } && ribbon.pages[0].groups.allSatisfy { $0.superview == nil },
          "the View tab shows its own groups")

    // Zoom from the View tab and the status bar.
    let statusBar = controller.statusBar
    check(!control("view.zoomActual").isEnabled && statusBar.zoomText == "100%", "100% is disabled at 100%")
    control("view.zoomIn").perform()
    check(controller.canvas.zoom == 2 && statusBar.zoomText == "200%" && statusBar.slider.zoom == 2 && control("view.zoomActual").isEnabled,
          "Zoom in moves to 200% and the status bar follows")
    statusBar.zoomIn.perform()
    check(controller.canvas.zoom == 3, "the status bar + button zooms in")
    statusBar.zoomOut.perform()
    statusBar.zoomOut.perform()
    check(controller.canvas.zoom == 1, "the status bar − button zooms out")
    statusBar.slider.zoom = 4
    controller.chooseZoom(statusBar.slider)
    check(controller.canvas.zoom == 4 && statusBar.zoomText == "400%", "the slider sets the zoom")
    controller.chooseZoom(nil)
    check(controller.canvas.zoom == 4, "chooseZoom ignores other senders")
    for _ in 0..<12 { controller.zoomOut(nil) }
    check(!statusBar.zoomOut.isEnabled && statusBar.zoomIn.isEnabled && statusBar.zoomText == "12.5%", "the − button stops at 12.5%")
    control("view.zoomActual").perform()
    check(controller.canvas.zoom == 1, "100% goes back to actual size")
    check(ZoomScale.position(of: 0.125) == 0 && ZoomScale.position(of: 1) == 0.5 && ZoomScale.position(of: 8) == 1,
          "the slider spans 12.5% to 800% with 100% in the middle")
    check(MainWindowController.zoomLevels.allSatisfy { ZoomScale.zoom(at: ZoomScale.position(of: $0)) == $0 },
          "every zoom level has its own slider position")
    check(ZoomScale.zoom(at: 0.52) == 1 && ZoomScale.zoom(at: 0.9) == 7 && ZoomScale.zoom(at: -1) == 0.125,
          "slider positions snap to the nearest level")

    // Status bar texts
    check(statusBar.imageSizeText == "800 × 600px", "the status bar shows the image size")
    check(statusBar.diskSizeText.isEmpty, "a new image has no size on disk")
    let canvas = controller.canvas
    let inView = NSPoint(x: CanvasView.inset + 12.5, y: CanvasView.inset + 34.5)
    let moved = NSEvent.mouseEvent(with: .mouseMoved, location: canvas.convert(inView, to: nil), modifierFlags: [], timestamp: 0,
                                   windowNumber: controller.window.windowNumber, context: nil, eventNumber: 0, clickCount: 0, pressure: 0)!
    canvas.mouseMoved(with: moved)
    check(statusBar.positionText == "12, 34px" && controller.pointer == PixelPoint(x: 12, y: 34), "the status bar shows the pointer pixel")
    let outside = NSEvent.mouseEvent(with: .mouseMoved, location: canvas.convert(NSPoint(x: 900, y: 700), to: nil), modifierFlags: [],
                                     timestamp: 0, windowNumber: controller.window.windowNumber, context: nil, eventNumber: 0,
                                     clickCount: 0, pressure: 0)!
    canvas.mouseMoved(with: outside)
    check(statusBar.positionText.isEmpty, "the position clears outside the image")
    check(statusBar.selectionText.isEmpty, "the selection size is empty until selections exist")
    check(StatusText.diskSize(512) == "Size: 512 bytes" && StatusText.diskSize(1434) == "Size: 1.4KB"
          && StatusText.diskSize(3 * 1024 * 1024) == "Size: 3MB" && StatusText.diskSize(nil).isEmpty, "file sizes read like Paint's")
    do {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("mypaint-ribbon-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("small.png")
        try? ImageFile.write(Bitmap(width: 30, height: 20), to: url, format: .png)
        let fresh = MainWindowController()
        fresh.open(url)
        let bytes = MainWindowController.fileSize(of: url) ?? -1
        check(fresh.fileSize == bytes && fresh.statusBar.diskSizeText == StatusText.diskSize(bytes)
              && fresh.statusBar.imageSizeText == "30 × 20px", "an opened file shows its size and its size on disk")
    }

    // Show and hide the status bar.
    let content = controller.window.contentView!
    check(!statusBar.isHidden && control("view.statusBar").isChecked, "the status bar starts visible")
    control("view.statusBar").perform()
    check(statusBar.isHidden && !controller.showsStatusBar && !control("view.statusBar").isChecked
          && controller.scrollView.frame.maxY == content.bounds.height, "the check box hides the status bar and the workspace grows")
    let menuItem = NSMenuItem(title: "", action: #selector(MainWindowController.toggleStatusBar(_:)), keyEquivalent: "")
    _ = controller.validateMenuItem(menuItem)
    check(menuItem.state == .off, "the View menu mirrors the hidden status bar")
    controller.toggleStatusBar(menuItem)
    _ = controller.validateMenuItem(menuItem)
    check(!statusBar.isHidden && menuItem.state == .on && control("view.statusBar").isChecked
          && controller.scrollView.frame.maxY == content.bounds.height - RibbonTheme.statusBarHeight,
          "the View menu shows it again")

    // Collapsing groups by width.
    check(RibbonLayout.collapsed(expanded: [100, 100, 100], collapsed: [50, 50, 120], order: [2, 1, 0], available: 260) == [1],
          "groups collapse in order, skipping those that would not get narrower")
    check(RibbonLayout.collapsed(expanded: [100, 100], collapsed: [50, 50], order: [1, 0], available: 400).isEmpty,
          "nothing collapses when everything fits")
    check(RibbonLayout.collapsed(expanded: [100, 100], collapsed: [50, 50], order: [1, 0], available: 10) == [0, 1],
          "everything collapses when nothing fits")
    ribbon.tabs[0].perform()
    let home = ribbon.pages[0].groups
    let wide = MainWindowController.ribbonWidth(ribbon)
    controller.window.setContentSize(NSSize(width: wide + 10, height: 700))
    check(home.allSatisfy { !$0.isCollapsed }, "a wide window shows every Home group")
    controller.window.setContentSize(NSSize(width: 640, height: 700))
    let colorsGroup = home[6]
    check(colorsGroup.isCollapsed && home[4].isCollapsed && !home[0].isCollapsed && !home[2].isCollapsed,
          "a narrow window collapses Colors and Shapes first")
    check(colorsGroup.content.superview == nil && colorsGroup.collapsedButton.superview === colorsGroup,
          "a collapsed group shows its drop-down button")
    check(home.last!.frame.maxX <= 640, "the collapsed ribbon fits the window")
    ribbon.openCollapsed(colorsGroup)
    let popup = RibbonPopup.current
    check(popup != nil && colorsGroup.content.window === popup?.panel && colorsGroup.collapsedButton.isChecked,
          "the collapsed button opens the group in a panel")
    check(popup.map { $0.panel.frame.maxX <= controller.window.frame.maxX } ?? false, "the panel stays inside the window")
    well2.perform()
    check(RibbonPopup.current == nil && controller.activeColorSlot == .color2 && colorsGroup.content.superview == nil
          && !colorsGroup.collapsedButton.isChecked, "a command in the panel runs and closes it")
    well1.perform()
    controller.window.setContentSize(NSSize(width: wide + 10, height: 700))
    check(!colorsGroup.isCollapsed && colorsGroup.content.superview === colorsGroup, "widening the window brings the controls back")
    controller.window.setContentSize(NSSize(width: 300, height: 700))
    check(home.allSatisfy { $0.isCollapsed || $0.collapsedWidth >= $0.expandedWidth }, "a very narrow window collapses every group it can")
    controller.window.setContentSize(NSSize(width: wide + 10, height: 700))

    // Application menu
    let entries = controller.applicationMenuEntries
    check(entries.map(\.name) == ["new", "open", "save", "saveAs", "print", "wallpaper", "properties", "about", "exit"],
          "the application menu lists the commands in the original order")
    check(entries.allSatisfy(\.isEnabled), "every application menu command is enabled")
    check(entries.allSatisfy { entry in entry.action.map { (entry.target as AnyObject).responds(to: $0) } ?? true },
          "every enabled entry reaches its target")
    controller.showApplicationMenu()
    let menuPopup = RibbonPopup.current
    let menuView = menuPopup?.panel.contentView?.subviews.first as? ApplicationMenuView
    check(menuView != nil && ribbon.applicationButton.isChecked, "the application button opens the menu")
    if let menuView = menuView {
        check(!menuView.showsFormats, "the right side starts with the recent pictures")
        menuView.items[3].hover(at: NSPoint(x: 10, y: 10))
        check(menuView.showsFormats && menuView.formatItems.allSatisfy { !$0.isHidden }, "pointing at Save as shows the formats")
        menuView.items[1].hover(at: NSPoint(x: 10, y: 10))
        check(!menuView.showsFormats && menuView.formatItems.allSatisfy(\.isHidden), "pointing elsewhere goes back to recent pictures")
        let png = menuView.formatItems[0]
        check(png.action == #selector(MainWindowController.saveDocumentAsFormat(_:))
              && ImageFormat.allCases[png.tag] == .png && menuView.formatItems.last?.action == #selector(MainWindowController.saveDocumentAs(_:)),
              "the formats save as PNG, JPEG, BMP and GIF, and Other formats opens the dialog")
        check(menuView.items.allSatisfy(\.isEnabled), "the menu draws every command enabled")
    }
    menuPopup?.close()
    check(RibbonPopup.current == nil && !ribbon.applicationButton.isChecked, "closing the menu releases the button")

    // Canvas handles
    let handles = CanvasView.handleRects(around: CGRect(x: 5, y: 5, width: 100, height: 50))
    check(handles.count == 3 && handles.allSatisfy { $0.minX >= 105 || $0.minY >= 55 }, "three resize handles sit outside the image")
}
