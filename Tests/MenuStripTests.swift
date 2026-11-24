import AppKit

/// The menus inside the window, above the ribbon.
func runMenuStripTests() {
    let previous = NSApp.mainMenu
    defer { NSApp.mainMenu = previous }
    let main = NSMenu()
    for title in ["My Paint", "File", "Edit", "Help"] {
        let item = main.addItem(withTitle: title, action: nil, keyEquivalent: "")
        item.submenu = NSMenu(title: title)
    }
    main.addItem(withTitle: "No submenu", action: nil, keyEquivalent: "")
    NSApp.mainMenu = main

    let controller = MainWindowController()
    let window = controller.window
    window.setFrame(NSRect(x: 0, y: 0, width: 1240, height: 860), display: false)
    controller.menuStrip.reload()
    controller.layoutContent()
    let strip = controller.menuStrip, ribbon = controller.ribbon!
    check(strip.titles == ["My Paint", "File", "Edit", "Help"], "the strip shows every menu, the application's own first under its name")
    check(strip.frame.minY == 0 && strip.frame.height == MenuStripView.height && strip.frame.width == window.contentView!.bounds.width,
          "the strip runs along the top of the window")
    check(ribbon.frame.minY == strip.frame.maxY && ribbon.frame.height == RibbonTheme.ribbonHeight, "the ribbon starts right under it, at its usual height")
    check(controller.scrollView.frame.minY == ribbon.frame.maxY, "and the workspace under the ribbon")
    let buttons = strip.subviews.compactMap { $0 as? MenuStripButton }
    check(buttons.count == 4 && zip(buttons, buttons.dropFirst()).allSatisfy { $0.frame.maxX <= $1.frame.minX }, "the titles follow one another without overlapping")
    main.removeItem(at: 2)
    strip.reload()
    check(strip.titles == ["My Paint", "File", "Help"], "the strip follows the menus when they are built again")
    window.close()
}
