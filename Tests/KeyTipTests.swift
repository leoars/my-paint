import AppKit

/// Key tips (Option alone, F10) and the minimized ribbon (Ctrl+F1, Cmd+F1, double click on a tab).
func runKeyTipTests() {
    _ = NSApplication.shared
    AppSettings.defaults.set(false, forKey: AppSettings.ribbonMinimizedKey)
    let controller = MainWindowController()
    let window = controller.window, ribbon = controller.ribbon!, tips = controller.keyTips
    let toolbox = controller.canvas.toolbox
    window.setFrame(NSRect(x: 0, y: 0, width: 1400, height: 860), display: false)
    func control(_ name: String) -> RibbonControl { ribbon.control(name)! }
    func flags(_ code: UInt16, _ flags: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.keyEvent(with: .flagsChanged, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: window.windowNumber,
                         context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: code)!
    }
    func key(_ code: UInt16, _ characters: String, _ modifiers: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0, windowNumber: window.windowNumber,
                         context: nil, characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code)!
    }
    func mouse(_ type: NSEvent.EventType, _ view: NSView, clicks: Int = 1) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: view.convert(NSPoint(x: view.bounds.midX, y: view.bounds.midY), to: nil),
                           modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0,
                           clickCount: clicks, pressure: 1)!
    }
    func click(_ view: NSView, clicks: Int = 1) {
        view.mouseDown(with: mouse(.leftMouseDown, view, clicks: clicks))
        view.mouseUp(with: mouse(.leftMouseUp, view, clicks: clicks))
    }
    // Letters as they come from the keyboard, sent to the real window.
    let codes: [Character: UInt16] = ["A": 0, "S": 1, "D": 2, "F": 3, "H": 4, "G": 5, "Z": 6, "X": 7, "C": 8, "V": 9, "B": 11, "Q": 12,
                                      "E": 14, "R": 15, "T": 17, "1": 18, "2": 19, "3": 20, "O": 31, "U": 32, "I": 34, "P": 35, "L": 37,
                                      "K": 40, "N": 45, "M": 46]
    func type(_ text: String) {
        for character in text { window.sendEvent(key(codes[character] ?? 0, String(character).lowercased())) }
    }
    func option() {
        window.sendEvent(flags(58, .option))
        window.sendEvent(flags(58, []))
    }
    let esc = key(53, "\u{1B}")
    let f10 = String(UnicodeScalar(NSF10FunctionKey)!), f1 = String(UnicodeScalar(NSF1FunctionKey)!)
    ribbon.selectPage(0)

    // MARK: Showing and hiding the tips
    check(!tips.isActive && tips.overlay == nil, "no key tips show at first")
    option()
    check(tips.level == .top && tips.visibleKeys.sorted() == ["1", "2", "3", "F", "H", "V"] && tips.overlay?.superview === ribbon,
          "Option pressed and released alone shows F, H, V and the quick access numbers over the ribbon")
    check(tips.overlay?.shownTips.count == 6, "six tips are drawn")
    if let overlay = tips.overlay, let tab = tips.overlay?.tips.first(where: { $0.keys == "H" }) {
        let rect = overlay.rect(of: tab)
        check(abs(rect.midX - ribbon.tabs[0].frame.midX) <= 1 && rect.maxY <= ribbon.bounds.height && overlay.bounds.contains(rect),
              "the Home tip sits under the middle of its tab")
        check(overlay.hitTest(NSPoint(x: rect.midX, y: rect.midY)) == nil, "clicks go through the tips")
        let image = overlay.bitmapImageRepForCachingDisplay(in: overlay.bounds)!
        overlay.cacheDisplay(in: overlay.bounds, to: image)
        let color = image.colorAt(x: Int(rect.minX + 2), y: Int(rect.midY))
        check((color?.alphaComponent ?? 0) > 0.5, "the tip is drawn")
    }
    option()
    check(!tips.isActive && tips.overlay == nil, "Option again puts them away")
    window.sendEvent(flags(58, .option))
    window.sendEvent(key(0, "å", .option))
    window.sendEvent(flags(58, []))
    check(!tips.isActive, "Option with a letter types a character and shows nothing")
    window.sendEvent(flags(58, .option))
    window.sendEvent(flags(55, [.option, .command]))
    window.sendEvent(flags(55, .option))
    window.sendEvent(flags(58, []))
    check(!tips.isActive, "Option with Cmd shows nothing")
    window.sendEvent(flags(58, .option))
    _ = tips.filter(mouse(.leftMouseDown, controller.statusBar))
    window.sendEvent(flags(58, []))
    check(!tips.isActive, "Option with a click shows nothing")
    window.sendEvent(flags(61, .option))
    window.sendEvent(flags(61, []))
    check(tips.isActive, "the right Option key works too")
    window.sendEvent(key(109, f10))
    check(!tips.isActive, "F10 puts them away")
    check(window.performKeyEquivalent(with: key(109, f10)) && tips.level == .top, "F10 shows them, as in Windows")
    _ = tips.filter(mouse(.leftMouseDown, controller.statusBar))
    check(!tips.isActive, "a click puts them away")

    // MARK: Levels
    option()
    type("H")
    let homeKeys = ["V", "X", "C", "SE", "RC", "RE", "RO", "P", "K", "T", "E", "I", "M", "B", "SH", "SO", "SF", "SZ", "1", "2", "D"]
    check(tips.level == .page(0) && Set(tips.visibleKeys) == Set(homeKeys) && tips.visibleKeys.count == homeKeys.count,
          "H shows a tip on each control of Home")
    check(tips.targets.allSatisfy { target in
        guard let overlay = tips.overlay, let tip = overlay.tips.first(where: { $0.keys == target.keys }) else { return false }
        let frame = target.view.convert(target.view.bounds, to: overlay)
        return overlay.rect(of: tip).intersects(frame.insetBy(dx: -8, dy: -8))
    }, "each tip is drawn on its control")
    type("S")
    check(tips.typed == "S" && Set(tips.visibleKeys) == ["SE", "SH", "SO", "SF", "SZ"] && tips.overlay?.shownTips.count == 5,
          "a first letter keeps only the tips that start with it")
    type("Z")
    let sizeMenu = RibbonPopup.current?.content as? RibbonMenuView
    check(!tips.isActive && sizeMenu?.name == "menu.size", "the second letter presses Size, which opens its menu")
    RibbonPopup.current?.close()
    option()
    type("HE")
    check(toolbox.kind == .eraser && !tips.isActive, "E picks the eraser")
    option()
    type("HSH")
    let all = RibbonPopup.current?.content as? ShapeGalleryView
    check(all?.columns == 7 && all?.totalRows == all?.visibleRows, "SH opens every shape")
    RibbonPopup.current?.close()
    option()
    type("V")
    check(tips.level == .page(1) && ribbon.selectedPage == 1 && tips.visibleKeys.contains("R"), "V goes to the View tab and shows its tips")
    type("R")
    check(controller.showsRulers && !tips.isActive, "R there shows the rulers")
    controller.showsRulers = false
    option()
    type("H")
    window.sendEvent(esc)
    check(tips.level == .top && ribbon.selectedPage == 0, "Esc goes back to the tabs")
    window.sendEvent(esc)
    check(!tips.isActive, "and Esc again puts the tips away")
    option()
    type("Q")
    check(!tips.isActive, "a letter that matches no tip puts them away")
    option()
    type("H")
    window.sendEvent(key(126, String(UnicodeScalar(NSUpArrowFunctionKey)!)))
    check(!tips.isActive, "so does another key")
    option()
    check(!tips.filter(key(31, "o", .command)) && !tips.isActive, "a shortcut puts them away and still goes to the window")
    option()
    type("2")
    check(tips.level == .top && !control("qat.undo").isEnabled, "a disabled control's tip does nothing and the tips stay")
    type("F")
    check(!tips.isActive && RibbonPopup.current?.content is ApplicationMenuView, "F opens the application menu")
    RibbonPopup.current?.close()

    // Collapsed groups and the Text tab.
    window.setContentSize(NSSize(width: 640, height: 700))
    let colors = ribbon.pages[0].groups[6]
    option()
    type("H")
    check(colors.isCollapsed && tips.visibleKeys.contains("ZO") && !tips.visibleKeys.contains("D") && !tips.visibleKeys.contains("1"),
          "a collapsed group has one tip instead of its controls'")
    type("ZO")
    check(RibbonPopup.current != nil && colors.content.window === RibbonPopup.current?.panel, "its tip opens the group's panel")
    RibbonPopup.current?.close()
    window.setContentSize(NSSize(width: 1400, height: 700))
    ribbon.setContextualVisible(true)
    option()
    check(tips.visibleKeys.contains("T"), "T shows while the Text tab does")
    type("T")
    check(tips.level == .page(2) && ribbon.selectedPage == 2, "T goes to the Text tab")
    type("FF")
    let family = control("text.fontFamily") as! RibbonComboBox
    check(tips.level == .page(2) && tips.typed == "" && !family.isEnabled, "without a text box the font box is disabled and FF does nothing")
    family.isEnabled = true
    type("FF")
    check(!tips.isActive && family.combo.currentEditor() != nil, "FF puts the focus in the font box")
    ribbon.setContextualVisible(false)
    window.makeFirstResponder(controller.canvas)
    option()
    check(!tips.visibleKeys.contains("T"), "T is gone with the Text tab")
    option()

    // Every control has a tip, and no tip of a level is the start of another.
    func prefixFree(_ keys: [String]) -> Bool {
        keys.allSatisfy { key in keys.filter { $0.hasPrefix(key) }.count == 1 }
    }
    let named = ribbon.controls.filter { !($0.value is PaletteView) }
    check(named.allSatisfy { $0.value.keyTip != nil }, "every control but the palettes has a key tip")
    check(ribbon.pages.allSatisfy { page in page.groups.allSatisfy { $0.keyTip != nil } && page.keyTip != nil },
          "every tab and every group has one")
    let top = [ribbon.applicationButton.keyTip!] + ribbon.pages.compactMap(\.keyTip) + ribbon.quickAccess.compactMap(\.keyTip)
    var levelsFree = prefixFree(top)
    for page in ribbon.pages {
        let inside = named.values.filter { control in page.groups.contains { control.isDescendant(of: $0.content) } }.compactMap(\.keyTip)
        levelsFree = levelsFree && prefixFree(inside + page.groups.compactMap(\.keyTip))
    }
    check(levelsFree, "within each level the tips are unique and none starts another")

    // MARK: Minimized ribbon
    check(PaintWindow.windowsShortcut(for: key(122, f1, .control)) == #selector(MainWindowController.toggleRibbonMinimized(_:))
          && PaintWindow.windowsShortcut(for: key(122, f1, .command)) == #selector(MainWindowController.toggleRibbonMinimized(_:)),
          "Ctrl+F1 and Cmd+F1 minimize the ribbon")
    let viewMenu = controller.makeViewMenu()
    let menuItem = viewMenu.items.first { $0.action == #selector(MainWindowController.toggleRibbonMinimized(_:)) }
    check(menuItem?.title == "Minimize the Ribbon" && menuItem?.keyEquivalent == f1 && menuItem?.keyEquivalentModifierMask == .command,
          "View has Minimize the Ribbon with Cmd+F1")
    ribbon.selectPage(0)
    check(window.performKeyEquivalent(with: key(122, f1, .control)) && controller.isRibbonMinimized, "Ctrl+F1 minimizes the ribbon")
    let small = RibbonTheme.minimizedRibbonHeight
    check(ribbon.frame.height == small && controller.scrollView.frame.minY == small, "only the tabs show and the workspace moves up")
    check(ribbon.tabs.allSatisfy { !$0.isChecked } && ribbon.pages[0].groups[0].window == nil, "no tab shows selected and the groups are gone")
    check(AppSettings.defaults.bool(forKey: AppSettings.ribbonMinimizedKey), "the minimized ribbon is remembered")
    if let menuItem = menuItem {
        _ = controller.validateMenuItem(menuItem)
        check(menuItem.state == .on, "the View menu shows it checked")
    }
    let reopened = MainWindowController()
    check(reopened.isRibbonMinimized && reopened.ribbon.frame.height == small, "a new window opens with the ribbon minimized")
    reopened.window.close()
    check(window.performKeyEquivalent(with: key(122, f1, .command)) && !controller.isRibbonMinimized
          && ribbon.frame.height == RibbonTheme.ribbonHeight && controller.scrollView.frame.minY == RibbonTheme.ribbonHeight
          && ribbon.tabs[0].isChecked && ribbon.pages[0].groups[0].superview != nil, "Cmd+F1 brings it back")
    check(!AppSettings.defaults.bool(forKey: AppSettings.ribbonMinimizedKey), "and that is remembered too")

    // Double click on a tab.
    click(ribbon.tabs[1])
    check(ribbon.selectedPage == 1 && !controller.isRibbonMinimized, "a click on a tab selects it")
    click(ribbon.tabs[1], clicks: 2)
    check(controller.isRibbonMinimized && ribbon.selectedPage == 1 && ribbon.bodyPopup == nil,
          "a double click minimizes the ribbon, without showing the body")
    click(ribbon.tabs[0])
    let body = ribbon.bodyPopup
    let homeGroups = ribbon.pages[0].groups
    check(body != nil && RibbonPopup.current === body && ribbon.selectedPage == 0 && homeGroups[0].window === body?.panel
          && ribbon.tabs[0].isChecked, "on a minimized ribbon a click on a tab shows its body in a panel")
    if let panel = body?.panel {
        let underTabs = window.convertPoint(toScreen: ribbon.convert(NSPoint(x: 0, y: RibbonTheme.quickAccessHeight + RibbonTheme.tabRowHeight), to: nil))
        check(abs(panel.frame.maxY - underTabs.y) < 1 && abs(panel.frame.minX - window.frame.minX) < 1
              && abs(panel.frame.width - ribbon.bounds.width) < 1, "the panel lies under the tabs, over the workspace, as wide as the ribbon")
        check(homeGroups.allSatisfy { $0.frame.maxX <= (ribbon.bodyHost?.bounds.width ?? 0) + 0.5 }, "the groups fit the panel")
        check(body?.passesClick?(mouse(.leftMouseDown, ribbon.tabs[1])) == true
              && body?.passesClick?(mouse(.leftMouseDown, controller.statusBar)) == false,
              "clicks on the tabs reach them; other clicks close the panel")
    }
    control("tool.pencil").perform()
    check(toolbox.kind == .pencil && ribbon.bodyPopup == nil && RibbonPopup.current == nil && !ribbon.tabs[0].isChecked,
          "a command in the panel runs and closes it")
    click(ribbon.tabs[1])
    check(ribbon.bodyPopup != nil && ribbon.selectedPage == 1 && ribbon.pages[1].groups[0].window === ribbon.bodyPopup?.panel,
          "another tab shows its own body")
    click(ribbon.tabs[0])
    check(ribbon.bodyPopup != nil && ribbon.selectedPage == 0, "a tab under the open panel switches it")
    click(ribbon.tabs[0])
    check(ribbon.bodyPopup == nil && !ribbon.tabs[0].isChecked, "the same tab again hides it")
    click(ribbon.tabs[0])
    ribbon.bodyPopup?.close()
    check(ribbon.bodyPopup == nil && controller.isRibbonMinimized, "closing the panel leaves the ribbon minimized")

    // Key tips on the minimized ribbon.
    option()
    type("H")
    check(tips.level == .page(0) && ribbon.bodyPopup != nil && tips.overlay?.superview === ribbon.bodyHost,
          "H shows the body and its tips in the panel")
    type("E")
    check(toolbox.kind == .eraser && ribbon.bodyPopup == nil && !tips.isActive, "a tip there runs the command and closes the panel")
    option()
    type("V")
    window.sendEvent(esc)
    check(tips.level == .top && ribbon.bodyPopup == nil, "Esc closes the panel and goes back to the tabs")
    type("H")
    ribbon.bodyPopup?.close()
    check(!tips.isActive, "a click outside the panel puts the tips away")
    option()
    type("H")
    type("Q")
    check(!tips.isActive && ribbon.bodyPopup == nil, "an unknown key closes the panel too")

    // Double click on a tab of the minimized ribbon restores it.
    click(ribbon.tabs[0])
    click(ribbon.tabs[0], clicks: 2)
    check(!controller.isRibbonMinimized && ribbon.bodyPopup == nil && ribbon.tabs[0].isChecked && ribbon.frame.height == RibbonTheme.ribbonHeight
          && homeGroups[0].window === window, "a double click on a tab of the minimized ribbon restores it")
    controller.toggleRibbonMinimized(nil)
    controller.toggleRibbonMinimized(nil)
    check(!controller.isRibbonMinimized && homeGroups.allSatisfy { $0.frame.maxX <= ribbon.bounds.width + 0.5 },
          "the menu command toggles it, and the groups are laid out again")
    let problems = clippedLabels(controller)
    check(problems.isEmpty, "after minimizing and restoring nothing is cut" + (problems.isEmpty ? "" : " — " + problems.joined(separator: "; ")))
    AppSettings.defaults.set(false, forKey: AppSettings.ribbonMinimizedKey)
    window.close()
}
