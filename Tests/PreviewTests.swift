import AppKit

/// Print preview as a tab of the ribbon with the pages in the workspace. Nothing is printed.
func runPreviewTests() {
    _ = NSApplication.shared
    AppSettings.defaults.set(false, forKey: AppSettings.ribbonMinimizedKey)
    AppSettings.defaults.set(false, forKey: AppSettings.rulersKey)
    let controller = MainWindowController()
    let window = controller.window, ribbon = controller.ribbon!
    window.setFrame(NSRect(x: 0, y: 0, width: 1400, height: 900), display: false)
    func control(_ name: String) -> RibbonControl { ribbon.control(name)! }
    func key(_ code: UInt16, _ characters: String, _ modifiers: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0, windowNumber: window.windowNumber,
                         context: nil, characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code)!
    }
    func option() {
        for flags in [NSEvent.ModifierFlags.option, []] {
            window.sendEvent(NSEvent.keyEvent(with: .flagsChanged, location: .zero, modifierFlags: flags, timestamp: 0,
                                              windowNumber: window.windowNumber, context: nil, characters: "", charactersIgnoringModifiers: "",
                                              isARepeat: false, keyCode: 58)!)
        }
    }
    let esc = key(53, "\u{1B}")
    var printed = 0, setups = 0
    controller.startPrinting = { printed += 1 }
    controller.document.replaceImage(Bitmap(width: 800, height: 600))
    controller.printInfo.orientation = .portrait
    controller.printOptions = PrintOptions()
    controller.canvas.reload()
    controller.syncInterface()
    guard let previewIndex = ribbon.printPreviewPage else { return check(false, "the ribbon has a Print preview tab") }
    check(ribbon.tabs[previewIndex].isHidden && ribbon.pages[previewIndex].title == "Print Preview", "the Print preview tab is hidden at first")
    let normalWork = controller.scrollView.frame

    // MARK: Entering
    ribbon.selectPage(1)
    controller.showPrintPreview(nil)
    guard let preview = controller.printPreview else { return check(false, "Print preview opens") }
    check(controller.isShowingPrintPreview && ribbon.showsPrintPreview && ribbon.selectedPage == previewIndex
          && ribbon.tabs.enumerated().allSatisfy { $0.element.isHidden == ($0.offset != previewIndex) },
          "the ribbon shows only the Print preview tab, selected")
    check(ribbon.pages[previewIndex].groups.map(\.title) == ["Print", "Zoom", "Preview", "Close"]
          && ["preview.print", "preview.pageSetup", "preview.zoomIn", "preview.zoomOut", "preview.next", "preview.previous", "preview.close"]
            .allSatisfy { name in ribbon.pages[previewIndex].groups.contains { ribbon.control(name)?.isDescendant(of: $0) == true } },
          "with the groups Print, Zoom, Preview and Close and their buttons")
    check(ribbon.pages[previewIndex].groups.allSatisfy { !$0.isCollapsed && $0.frame.maxX <= ribbon.bounds.width }, "the groups fit the ribbon")
    check(controller.scrollView.isHidden && !controller.previewScroll.isHidden && controller.previewScroll.documentView === preview
          && controller.previewScroll.frame.minY == ribbon.frame.maxY && controller.previewScroll.frame.width == window.contentView!.bounds.width
          && abs(controller.previewScroll.frame.maxY - normalWork.maxY) < 0.5, "the workspace shows the pages instead of the canvas")
    check(window.firstResponder === preview, "the pages take the keys")
    controller.showPrintPreview(nil)
    check(controller.printPreview === preview, "asking again keeps the same preview")

    // MARK: Pages and navigation
    check(preview.layout.pageCount == 2 && preview.page == 0 && preview.pageLabel == "Page 1 of 2", "an 800 × 600 picture takes two pages")
    check(!control("preview.previous").isEnabled && control("preview.next").isEnabled, "on the first page only Next page is enabled")
    let paper = preview.paperRect
    let shot = ViewSnapshot(preview)
    check(shot.color(NSPoint(x: paper.minX + 3, y: paper.minY + 3)) == (255, 255, 255) && shot.color(NSPoint(x: 3, y: 3)) != (255, 255, 255),
          "the page is drawn white over a gray background")
    check(paper.maxY + RibbonTheme.previewLabelHeight <= preview.bounds.height + 0.5 && preview.bounds.contains(paper),
          "the page and its number fit the workspace")
    control("preview.next").perform()
    check(preview.page == 1 && preview.pageLabel == "Page 2 of 2" && !control("preview.next").isEnabled && control("preview.previous").isEnabled,
          "Next page goes to the second page")
    control("preview.previous").perform()
    check(preview.page == 0, "Previous page goes back")
    window.sendEvent(key(121, String(UnicodeScalar(NSPageDownFunctionKey)!)))
    check(preview.page == 1, "Page Down goes to the next page")
    window.sendEvent(key(123, String(UnicodeScalar(NSLeftArrowFunctionKey)!)))
    check(preview.page == 0, "← goes to the previous page")
    window.sendEvent(key(123, String(UnicodeScalar(NSLeftArrowFunctionKey)!)))
    check(preview.page == 0, "and stops at the first")

    // MARK: Zoom
    let fit = controller.previewScroll.contentSize
    check(preview.zoom == 1 && preview.frame.size == fit && !control("preview.zoomOut").isEnabled && control("preview.zoomIn").isEnabled,
          "the preview starts with the whole page in sight")
    control("preview.zoomIn").perform()
    check(preview.zoom == 1.5 && preview.frame.height > fit.height && preview.paperRect.height > paper.height * 1.4
          && control("preview.zoomOut").isEnabled, "Zoom in makes the page larger, and the pages scroll")
    for _ in 0..<5 { control("preview.zoomIn").perform() }
    check(preview.zoom == MainWindowController.previewZoomLevels.last && !control("preview.zoomIn").isEnabled, "Zoom in stops at the largest step")
    for _ in 0..<5 { control("preview.zoomOut").perform() }
    check(preview.zoom == 1 && preview.frame.size == fit && !control("preview.zoomOut").isEnabled, "Zoom out comes back to the whole page")

    // MARK: Commands
    control("preview.print").perform()
    check(printed == 1 && controller.isShowingPrintPreview, "Print asks to print (replaced here) and the preview stays")
    controller.startPageSetup = { next in
        setups += 1
        controller.printInfo.orientation = .landscape
        next()
    }
    control("preview.pageSetup").perform()
    check(setups == 1 && preview.layout.pageCount == 1 && preview.pageLabel == "Page 1 of 1" && !control("preview.next").isEnabled,
          "Page setup runs, and the pages follow it (landscape: one page)")
    controller.printInfo.orientation = .portrait
    controller.document.replaceImage(Bitmap(width: 80, height: 60))
    controller.syncInterface()
    check(preview.layout.imageSize == CGSize(width: 80, height: 60) && preview.layout.pageCount == 1, "the pages follow the picture")
    controller.document.replaceImage(Bitmap(width: 800, height: 600))
    controller.syncInterface()
    check(preview.layout.pageCount == 2, "and the page setup")
    check(!controller.commandState(#selector(MainWindowController.toggleRibbonMinimized(_:)), tag: 0).enabled, "the ribbon cannot be minimized meanwhile")

    // Key tips in the preview.
    option()
    check(controller.keyTips.visibleKeys.sorted() == ["1", "2", "3", "F", "P"], "the key tips offer only the Print preview tab")
    for (code, letter) in [(UInt16(35), "p"), (45, "n")] { window.sendEvent(key(code, letter)) }
    check(preview.page == 1 && !controller.keyTips.isActive, "P then N goes to the next page")

    // MARK: Leaving
    window.sendEvent(esc)
    check(!controller.isShowingPrintPreview && controller.printPreview == nil && !ribbon.showsPrintPreview, "Esc closes the preview")
    check(ribbon.selectedPage == 1 && ribbon.tabs[previewIndex].isHidden && !ribbon.tabs[0].isHidden && !ribbon.tabs[1].isHidden
          && ribbon.tabs[2].isHidden, "the tabs come back, with the one that was selected")
    check(!controller.scrollView.isHidden && controller.previewScroll.isHidden && controller.scrollView.frame == normalWork
          && controller.previewScroll.documentView == nil && window.firstResponder === controller.canvas, "and the canvas")
    controller.showPrintPreview(nil)
    control("preview.close").perform()
    check(!controller.isShowingPrintPreview && ribbon.selectedPage == 1, "Close print preview closes it too")

    // The Text tab and the minimized ribbon are kept as they were.
    ribbon.setContextualVisible(true)
    controller.showPrintPreview(nil)
    check(ribbon.tabs[2].isHidden && ribbon.contextualHeaderRect == nil, "the Text tab hides during the preview")
    controller.closePrintPreview(nil)
    check(ribbon.tabs[2].isHidden && ribbon.selectedPage == 0,
          "the preview finishes the text box, so the Text tab does not come back and Home is selected")
    ribbon.setContextualVisible(true)
    ribbon.setPrintPreview(true)
    ribbon.setPrintPreview(false)
    check(!ribbon.tabs[2].isHidden && ribbon.selectedPage == 2, "a Text tab that still applies comes back selected")
    ribbon.setContextualVisible(false)
    controller.isRibbonMinimized = true
    controller.showPrintPreview(nil)
    check(!ribbon.isMinimized && controller.isRibbonMinimized && ribbon.frame.height == RibbonTheme.ribbonHeight,
          "a minimized ribbon opens for the preview")
    controller.toggleRibbonMinimized(nil)
    check(controller.isRibbonMinimized && !ribbon.isMinimized, "Ctrl+F1 does nothing meanwhile")
    controller.closePrintPreview(nil)
    check(ribbon.isMinimized && ribbon.frame.height == RibbonTheme.minimizedRibbonHeight, "and is minimized again afterwards")
    controller.isRibbonMinimized = false

    // Both menus open it.
    let fileMenu = controller.makeFileMenu()
    check(fileMenu.items.contains { $0.action == #selector(MainWindowController.showPrintPreview(_:)) }
          && controller.printPaneEntries.contains { $0.action == #selector(MainWindowController.showPrintPreview(_:)) },
          "File and the application menu open the preview")
    // clippedLabels opens the preview for its tab, measures it and closes it.
    let problems = clippedLabels(controller)
    check(problems.isEmpty && !controller.isShowingPrintPreview,
          "the Print preview tab is measured and nothing is cut" + (problems.isEmpty ? "" : " — " + problems.joined(separator: "; ")))
    check(printed == 1, "nothing was printed for real")
    AppSettings.defaults.set(false, forKey: AppSettings.ribbonMinimizedKey)
    window.close()
}
