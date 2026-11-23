import AppKit

/// Records what would have gone to the desktop.
final class FakeDesktopPicture: DesktopPictureSetting {
    private(set) var calls: [(url: URL, style: WallpaperStyle)] = []
    func setDesktopPicture(_ url: URL, style: WallpaperStyle) throws { calls.append((url, style)) }
}

/// Draws `view` offscreen and reads its pixels, in view coordinates.
struct ViewSnapshot {
    let rep: NSBitmapImageRep
    let view: NSView
    let rect: NSRect

    init(_ view: NSView, rect: NSRect? = nil) {
        let area = rect ?? view.bounds
        self.view = view
        self.rect = area
        rep = view.bitmapImageRepForCachingDisplay(in: area)!
        view.cacheDisplay(in: area, to: rep)
    }

    /// The color at `point` of the view, as 0–255 red, green and blue.
    func color(_ point: NSPoint) -> (r: Int, g: Int, b: Int) {
        let sx = CGFloat(rep.pixelsWide) / rect.width, sy = CGFloat(rep.pixelsHigh) / rect.height
        let x = Int((point.x - rect.minX) * sx)
        let yInView = view.isFlipped ? point.y - rect.minY : rect.maxY - point.y
        let y = Int(yInView * sy)
        guard let color = rep.colorAt(x: min(rep.pixelsWide - 1, max(0, x)), y: min(rep.pixelsHigh - 1, max(0, y)))?
            .usingColorSpace(.sRGB) else { return (0, 0, 0) }
        return (Int((color.redComponent * 255).rounded()), Int((color.greenComponent * 255).rounded()), Int((color.blueComponent * 255).rounded()))
    }
}

func runSystemTests() {
    _ = NSApplication.shared
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("mypaint-system-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }

    let controller = MainWindowController()
    let window = controller.window
    window.setContentSize(NSSize(width: 1100, height: 820))
    let ribbon = controller.ribbon!
    let canvas = controller.canvas
    func control(_ name: String) -> RibbonControl { ribbon.control(name)! }
    func key(_ code: UInt16, _ characters: String, _ flags: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: window.windowNumber,
                         context: nil, characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code)!
    }
    func move(to pixel: PixelPoint) {
        let inView = NSPoint(x: CanvasView.inset + (CGFloat(pixel.x) + 0.5) * canvas.zoom, y: CanvasView.inset + (CGFloat(pixel.y) + 0.5) * canvas.zoom)
        let event = NSEvent.mouseEvent(with: .mouseMoved, location: canvas.convert(inView, to: nil), modifierFlags: [], timestamp: 0,
                                       windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 0, pressure: 0)!
        canvas.mouseMoved(with: event)
    }
    func menuItem(_ action: Selector, tag: Int = 0) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: action, keyEquivalent: "")
        item.tag = tag
        return item
    }
    func state(_ action: Selector, tag: Int = 0) -> (enabled: Bool, checked: Bool?) { controller.commandState(action, tag: tag) }

    // MARK: Shortcuts
    let shortcuts: [(UInt16, String, NSEvent.ModifierFlags, Selector)] = [
        (15, "r", .control, #selector(MainWindowController.toggleRulers(_:))),
        (5, "g", .control, #selector(MainWindowController.toggleGridlines(_:))),
        (14, "e", .control, #selector(MainWindowController.showImageProperties(_:))),
        (35, "p", .control, #selector(MainWindowController.printImage(_:))),
        (103, "\u{F70E}", [], #selector(MainWindowController.viewFullScreen(_:))),
    ]
    check(shortcuts.allSatisfy { PaintWindow.windowsShortcut(for: key($0.0, $0.1, $0.2)) == $0.3 },
          "Ctrl+R, Ctrl+G, Ctrl+E, Ctrl+P and F11 are Paint's shortcuts")
    check(PaintWindow.windowsShortcut(for: key(15, "r", .command)) == #selector(MainWindowController.toggleRulers(_:))
          && PaintWindow.windowsShortcut(for: key(103, "\u{F70E}", .command)) == nil,
          "Cmd+R toggles the rulers like Ctrl+R, and Cmd+F11 is left to the system")
    let viewMenu = controller.makeViewMenu(), fileMenu = controller.makeFileMenu()
    func find(_ menu: NSMenu, _ action: Selector) -> NSMenuItem? { menu.items.first { $0.action == action } }
    let cmd: [(NSMenu, Selector, String, NSEvent.ModifierFlags)] = [
        (viewMenu, #selector(MainWindowController.toggleRulers(_:)), "r", .command),
        (viewMenu, #selector(MainWindowController.toggleGridlines(_:)), "g", .command),
        (fileMenu, #selector(MainWindowController.showImageProperties(_:)), "e", .command),
        (fileMenu, #selector(MainWindowController.printImage(_:)), "p", .command),
        (fileMenu, #selector(MainWindowController.showPageSetup(_:)), "P", .command),
    ]
    check(cmd.allSatisfy { entry in find(entry.0, entry.1).map { $0.keyEquivalent == entry.2 && $0.keyEquivalentModifierMask == entry.3 } ?? false },
          "the menus have Cmd+R, Cmd+G, Cmd+E, Cmd+P and Shift+Cmd+P")
    let reserved: Set<String> = ["w", "q", "h", "m", ","]
    check((viewMenu.items + fileMenu.items).allSatisfy { !reserved.contains($0.keyEquivalent) || $0.keyEquivalentModifierMask != .command },
          "no new item takes Cmd+W, Q, H, M or the comma")
    check(find(viewMenu, #selector(MainWindowController.viewFullScreen(_:)))?.keyEquivalent == String(UnicodeScalar(NSF11FunctionKey)!),
          "View > Full Screen shows F11")
    check(["toggleRulers:", "toggleGridlines:", "printImage:", "viewFullScreen:", "showImageProperties:",
           "toggleKeyTips:", "toggleRibbonMinimized:"].allSatisfy { name in
        !NSTextView().responds(to: NSSelectorFromString(name)) && !NSWindow().responds(to: NSSelectorFromString(name)) },
          "the new actions are not AppKit's own (toggleRuler:, print:, toggleFullScreen:)")

    // MARK: Rulers
    let defaults = AppSettings.defaults
    check(!controller.showsRulers && horizontalHidden(controller) && controller.scrollView.frame.minX == 0,
          "the rulers start hidden")
    check(window.performKeyEquivalent(with: key(15, "r", .control)) && controller.showsRulers, "Ctrl+R shows the rulers")
    let thickness = RibbonTheme.rulerThickness
    check(!controller.horizontalRuler.isHidden && !controller.verticalRuler.isHidden && control("view.rulers").isChecked
          && controller.scrollView.frame.minX == thickness && controller.scrollView.frame.minY == MenuStripView.height + RibbonTheme.ribbonHeight + thickness
          && controller.horizontalRuler.frame.height == thickness && controller.verticalRuler.frame.width == thickness,
          "the rulers sit along the top and the left of the workspace")
    check(defaults.bool(forKey: AppSettings.rulersKey) && MainWindowController().showsRulers, "the rulers are remembered")
    let hRuler = controller.horizontalRuler, vRuler = controller.verticalRuler
    check(abs(hRuler.origin - CanvasView.inset) < 0.01 && abs(hRuler.pixelLength - 1) < 0.001 && hRuler.imageLength == 800
          && abs(vRuler.origin - CanvasView.inset) < 0.01 && vRuler.imageLength == 600, "the rulers start at the image, one point per pixel")
    move(to: PixelPoint(x: 120, y: 34))
    check(hRuler.pointer == 120 && vRuler.pointer == 34, "the rulers mark the pointer")
    controller.zoomIn(nil)
    check(abs(hRuler.pixelLength - 2) < 0.001 && abs(vRuler.pixelLength - 2) < 0.001, "the rulers follow the zoom")
    canvas.scroll(NSPoint(x: 300, y: 100))
    check(abs(hRuler.origin - (CanvasView.inset - 300)) < 0.5 && abs(vRuler.origin - (CanvasView.inset - 100)) < 0.5,
          "the rulers follow the scrolling")
    canvas.scroll(.zero)
    controller.zoomActual(nil)
    check(RulerView.steps(pixelLength: 1) == (50, 5) && RulerView.steps(pixelLength: 8) == (10, 1)
          && RulerView.steps(pixelLength: 0.125) == (500, 50), "ruler labels stay apart at every zoom")
    let rulerShot = ViewSnapshot(hRuler)
    let tick = rulerShot.color(NSPoint(x: hRuler.position(of: 50) + 0.5, y: hRuler.bounds.height - 2))
    let white = rulerShot.color(NSPoint(x: hRuler.position(of: 52) + 0.5, y: hRuler.bounds.height - 2))
    let outside = rulerShot.color(NSPoint(x: hRuler.position(of: 0) - 3, y: hRuler.bounds.height / 2))
    check(tick.r < 150 && white == (255, 255, 255) && outside != (255, 255, 255), "the ruler draws ticks, white over the image and its frame beyond")
    check(window.performKeyEquivalent(with: key(15, "r", .control)) && !controller.showsRulers && hRuler.isHidden
          && controller.scrollView.frame.minX == 0, "Ctrl+R hides them again")
    controller.toggleRulers(menuItem(#selector(MainWindowController.toggleRulers(_:))))
    check(controller.showsRulers && state(#selector(MainWindowController.toggleRulers(_:))).checked == true, "View > Rulers mirrors the check box")
    control("view.rulers").perform()
    check(!controller.showsRulers, "the check box turns them off")

    // MARK: Gridlines
    check(!canvas.showsGrid, "gridlines start off")
    check(window.performKeyEquivalent(with: key(5, "g", .control)) && controller.showsGridlines && canvas.showsGrid
          && control("view.gridlines").isChecked, "Ctrl+G turns the gridlines on")
    check(!canvas.drawsGrid, "gridlines do not show at 100%")
    canvas.zoom = 3
    check(!canvas.drawsGrid, "nor at 300%")
    canvas.zoom = 4
    check(canvas.drawsGrid, "they show from 400%")
    let before = controller.document.bitmap
    let gridRect = NSRect(x: 0, y: 0, width: 120, height: 120)
    let gridShot = ViewSnapshot(canvas, rect: gridRect)
    let onLine = gridShot.color(NSPoint(x: CanvasView.inset + 4 * 10 + 0.5, y: CanvasView.inset + 4 * 10 + 2))
    let inPixel = gridShot.color(NSPoint(x: CanvasView.inset + 4 * 10 + 2.5, y: CanvasView.inset + 4 * 10 + 2.5))
    check(onLine.r < 230 && inPixel == (255, 255, 255), "a gridline runs between pixels, the pixels stay white")
    check(controller.document.bitmap == before, "gridlines do not change the picture")
    check(defaults.bool(forKey: AppSettings.gridlinesKey) && MainWindowController().canvas.showsGrid, "gridlines are remembered")
    control("view.gridlines").perform()
    let noGrid = ViewSnapshot(canvas, rect: gridRect).color(NSPoint(x: CanvasView.inset + 4 * 10 + 0.5, y: CanvasView.inset + 4 * 10 + 2))
    check(!controller.showsGridlines && noGrid == (255, 255, 255), "the check box turns them off")
    canvas.zoom = 1

    // MARK: Magnifier preview
    canvas.toolbox.select(.magnifier)
    move(to: PixelPoint(x: 400, y: 300))
    let clip = controller.scrollView.contentView.bounds.size
    if let preview = canvas.magnifierPreviewRect {
        check(abs(preview.width - floor(clip.width / 2)) <= 1 && abs(preview.height - floor(min(600, clip.height / 2))) <= 1
              && preview.contains(NSPoint(x: CanvasView.inset + 400, y: CanvasView.inset + 300)),
              "the magnifier outlines the area a click would show, around the pointer")
        check(preview.minX >= canvas.imageRect.minX && preview.maxX <= canvas.imageRect.maxX, "the outline stays on the picture")
    } else {
        check(false, "the magnifier shows its preview")
    }
    move(to: PixelPoint(x: 2, y: 2))
    check(canvas.magnifierPreviewRect.map { $0.minX == canvas.imageRect.minX && $0.minY == canvas.imageRect.minY } ?? false,
          "near the corner the outline is pushed inside the picture")
    canvas.toolbox.select(.pencil)
    check(canvas.magnifierPreviewRect == nil && canvas.magnifierPoint == nil, "other tools show no preview")

    // MARK: Size submenu
    let tools = controller.makeToolsMenu()
    if let sizeItem = tools.items.first(where: { $0.submenu?.title == "size" }) {
        canvas.toolbox.select(.fill)
        check(!controller.validateMenuItem(sizeItem), "Tools > Size is disabled for tools without a size")
        canvas.toolbox.select(.pencil)
        check(controller.validateMenuItem(sizeItem), "and enabled for the pencil")
    } else {
        check(false, "Tools > Size exists")
    }

    // MARK: Full screen
    let mainFrame = window.frame
    check(window.performKeyEquivalent(with: key(103, "\u{F70E}", [])) && controller.fullScreenWindow != nil, "F11 opens full screen")
    if let full = controller.fullScreenWindow, let view = full.contentView as? FullScreenView {
        let screen = (window.screen ?? NSScreen.main)!.frame
        check(full.frame == screen && full.styleMask == [.borderless], "full screen is a borderless window over the whole screen")
        let rect = view.imageRect
        check(abs(rect.midX - view.bounds.midX) <= 1 && abs(rect.midY - view.bounds.midY) <= 1
              && (rect.width == 800 || rect.width < 800 && rect.width <= view.bounds.width), "the picture is centred, at 100% when it fits")
        let shot = ViewSnapshot(view, rect: NSRect(x: rect.midX - 2, y: rect.midY - 2, width: 4, height: 4))
        check(shot.color(NSPoint(x: rect.midX, y: rect.midY)) == (255, 255, 255)
              && ViewSnapshot(view, rect: NSRect(x: 0, y: 0, width: 4, height: 4)).color(NSPoint(x: 1, y: 1)) == (0, 0, 0),
              "it shows only the picture over the background")
        let click = NSEvent.mouseEvent(with: .leftMouseDown, location: NSPoint(x: 10, y: 10), modifierFlags: [], timestamp: 0,
                                       windowNumber: full.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        full.mouseDown(with: click)
        check(controller.fullScreenWindow == nil && window.frame == mainFrame, "a click goes back, the window as it was")
    }
    controller.viewFullScreen(nil)
    controller.fullScreenWindow?.keyDown(with: key(53, "\u{1b}", []))
    check(controller.fullScreenWindow == nil, "Esc goes back too")
    controller.viewFullScreen(nil)
    check(controller.fullScreenWindow?.performKeyEquivalent(with: key(15, "r", .control)) == true && controller.fullScreenWindow == nil
          && !controller.showsRulers, "a shortcut in full screen only goes back")
    control("view.fullScreen").perform()
    check(controller.fullScreenWindow != nil, "the Full screen button opens it")
    controller.closeFullScreen()

    // MARK: Thumbnail
    check(controller.thumbnailPanel == nil, "the thumbnail starts hidden")
    control("view.thumbnail").perform()
    let thumbnail = controller.thumbnailPanel?.contentView as? ThumbnailView
    check(controller.showsThumbnail && control("view.thumbnail").isChecked && thumbnail != nil
          && thumbnail.map { $0.imageSize == (800, 600) } == true, "the Thumbnail button shows the picture in a small panel")
    check(thumbnail?.visibleArea == nil, "at 100% with the whole picture in view, nothing is outlined")
    canvas.zoom = 8
    controller.syncThumbnail()
    if let area = thumbnail?.visibleArea {
        check(area.width < 800 && area.height < 600 && area.minX >= 0 && area.minY >= 0, "zoomed in, the thumbnail outlines the part in view")
    } else {
        check(false, "zoomed in, the thumbnail outlines the part in view")
    }
    if let thumbnail = thumbnail {
        let plain = controller.document.bitmap
        controller.document.draw { $0.fill(PixelRect(x: 0, y: 0, width: 800, height: 600), with: RGB(r: 0, g: 0, b: 255).packed) }
        canvas.refresh()
        let rect = thumbnail.imageRect
        check(rect.width <= thumbnail.bounds.width && rect.height <= thumbnail.bounds.height && abs(rect.width / rect.height - 4.0 / 3.0) < 0.03,
              "the whole picture fits the thumbnail, reduced")
        let center = ViewSnapshot(thumbnail).color(NSPoint(x: rect.midX + 20, y: rect.midY + 20))
        check(center.b > 200 && center.r < 60, "the thumbnail follows the picture")
        controller.document.revert(to: plain)
    }
    canvas.zoom = 1
    check(defaults.bool(forKey: AppSettings.thumbnailKey), "the thumbnail is remembered")
    controller.thumbnailPanel?.close()
    check(!controller.showsThumbnail && controller.thumbnailPanel == nil && !control("view.thumbnail").isChecked,
          "closing the panel turns the thumbnail off")
    controller.toggleThumbnail(nil)
    controller.toggleThumbnail(nil)
    check(controller.thumbnailPanel == nil && !controller.showsThumbnail, "toggling twice leaves it off")

    // MARK: Printing
    controller.printInfo.paperSize = NSSize(width: 612, height: 792)
    controller.printInfo.orientation = .portrait
    check(controller.printInfo.leftMargin == 54 && controller.printInfo.scalingFactor == 1, "printing starts with 0.75 inch margins at 100%")
    let layout = controller.printLayout
    check(layout.printedSize == CGSize(width: 600, height: 450) && layout.columns == 2 && layout.rows == 1 && layout.pageCount == 2,
          "800 × 600 px print at 96 dpi, two pages wide on letter paper")
    check(layout.imageRect(onPage: 0).origin == CGPoint(x: 54, y: 54) && layout.imageRect(onPage: 1).minX == 54 - 504,
          "the second page carries on where the first stops")
    let half = PrintLayout(paper: CGSize(width: 612, height: 792), margins: NSEdgeInsets(top: 54, left: 54, bottom: 54, right: 54),
                           imageWidth: 800, imageHeight: 600, scale: 0.5,
                           options: PrintOptions(centersHorizontally: true, centersVertically: true))
    check(half.pageCount == 1 && half.printedSize == CGSize(width: 300, height: 225)
          && half.imageRect(onPage: 0).origin == CGPoint(x: 54 + 102, y: 54 + 229.5), "scale and centering place the picture")
    let fit = PrintLayout(paper: CGSize(width: 612, height: 792), margins: NSEdgeInsets(top: 54, left: 54, bottom: 54, right: 54),
                          imageWidth: 2000, imageHeight: 100, scale: 1, options: PrintOptions(fitsToPages: true, columns: 1, rows: 1))
    check(fit.pageCount == 1 && abs(fit.printedSize.width - 504) < 0.01, "Fit to 1 by 1 page shrinks a wide picture to the page")
    // Print to a PDF in the temporary folder: never to a printer.
    let unprinted = controller.document.bitmap
    controller.document.draw { $0.fill(PixelRect(x: 0, y: 0, width: 800, height: 600), with: RGB(r: 255, g: 0, b: 0).packed) }
    let pdfURL = folder.appendingPathComponent("print.pdf")
    let operation = controller.makePrintOperation(saveTo: pdfURL)
    check(!operation.showsPrintPanel && !operation.showsProgressPanel && operation.printInfo.jobDisposition == .save,
          "the test print job only saves a PDF")
    check(operation.run(), "the print job runs")
    if let pdf = CGPDFDocument(pdfURL as CFURL), let page = pdf.page(at: 1) {
        let box = page.getBoxRect(.mediaBox)
        check(pdf.numberOfPages == 2 && box.size == CGSize(width: 612, height: 792), "the PDF has the two letter pages")
        let context = CGContext(data: nil, width: 612, height: 792, bitsPerComponent: 8, bytesPerRow: 612 * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 612, height: 792))
        context.drawPDFPage(page)
        let image = context.makeImage()!
        let rep = NSBitmapImageRep(cgImage: image)
        func pixel(_ x: Int, _ yFromTop: Int) -> (Int, Int, Int) {
            let color = rep.colorAt(x: x, y: yFromTop)!.usingColorSpace(.sRGB)!
            return (Int(color.redComponent * 255 + 0.5), Int(color.greenComponent * 255 + 0.5), Int(color.blueComponent * 255 + 0.5))
        }
        // Red, give or take the color conversion of the PDF.
        func red(_ p: (Int, Int, Int)) -> Bool { p.0 > 230 && p.1 < 70 && p.2 < 50 }
        let reds = (x: (0..<612).filter { red(pixel($0, 200)) }, y: (0..<792).filter { red(pixel(200, $0)) })
        check(reds.x.first == 54 && reds.x.last == 557 && reds.y.first == 54 && reds.y.last == 503,
              "the picture is printed from the 0.75 inch margins, cut at the right margin")
        check(pixel(20, 20) == (255, 255, 255) && pixel(100, 600) == (255, 255, 255), "the margins and the rest of the page stay blank")
    } else {
        check(false, "the print job wrote a PDF")
    }
    controller.document.revert(to: unprinted)
    // Page setup, without running its sheet.
    let accessory = PageSetupAccessory(options: PrintOptions())
    _ = accessory.view
    check(accessory.fit.state == .off && accessory.columnsField.stringValue == "1", "the page setup options start as Paint's")
    accessory.fit.state = .on
    accessory.columnsField.stringValue = "2"
    accessory.rowsField.stringValue = "x"
    accessory.centerHorizontally.state = .on
    check(accessory.options == PrintOptions(fitsToPages: true, columns: 2, rows: 1, centersHorizontally: true, centersVertically: false),
          "the page setup options read the controls, with 1 for a wrong count")
    controller.finishPageSetup(accepted: false, accessory: accessory)
    check(controller.printOptions == PrintOptions(), "a cancelled page setup changes nothing")
    controller.finishPageSetup(accepted: true, accessory: accessory)
    check(controller.printOptions.fitsToPages && controller.printLayout.columns == 2, "an accepted page setup takes the options")
    controller.printOptions = PrintOptions()
    controller.printInfo.orientation = .landscape
    check(controller.printInfo.paperSize.width > controller.printInfo.paperSize.height && controller.printLayout.pageCount == 1,
          "landscape fits the picture on one page")
    controller.printInfo.orientation = .portrait
    // Print preview is a mode of the window now; see PreviewTests.swift.

    // MARK: Desktop background
    let fake = FakeDesktopPicture()
    controller.desktopPicture = fake
    controller.wallpaperFolder = folder.appendingPathComponent("Support/My Paint")
    controller.setDesktopBackground(menuItem(#selector(MainWindowController.setDesktopBackground(_:)), tag: WallpaperStyle.tile.rawValue))
    let screenSize = controller.screenPixelSize
    if let call = fake.calls.last {
        let written = try? ImageFile.read(call.url)
        check(call.style == .tile && call.url.deletingLastPathComponent().standardizedFileURL.path == controller.wallpaperFolder.standardizedFileURL.path
              && written?.width == screenSize.width && written?.height == screenSize.height,
              "Tile writes the picture tiled over the screen in the app's folder")
    } else {
        check(false, "Tile reaches the desktop setter")
    }
    controller.setDesktopBackground(menuItem(#selector(MainWindowController.setDesktopBackground(_:)), tag: WallpaperStyle.fill.rawValue))
    let files = (try? FileManager.default.contentsOfDirectory(atPath: controller.wallpaperFolder.path)) ?? []
    check(fake.calls.count == 2 && fake.calls[1].style == .fill && files.count == 1
          && (try? ImageFile.read(fake.calls[1].url))?.width == 800, "Fill writes the picture as it is and drops the old file")
    controller.setDesktopBackground(menuItem(#selector(MainWindowController.setDesktopBackground(_:)), tag: WallpaperStyle.center.rawValue))
    check(fake.calls.last?.style == .center, "Center reaches the setter")
    let fillOptions = SystemDesktopPicture.options(for: .fill), centerOptions = SystemDesktopPicture.options(for: .center)
    check(fillOptions[.imageScaling] as? UInt == NSImageScaling.scaleProportionallyUpOrDown.rawValue && fillOptions[.allowClipping] as? Bool == true
          && centerOptions[.imageScaling] as? UInt == NSImageScaling.scaleNone.rawValue && centerOptions[.allowClipping] as? Bool == false
          && SystemDesktopPicture.options(for: .tile)[.imageScaling] as? UInt == NSImageScaling.scaleAxesIndependently.rawValue,
          "Fill, Tile and Center map to the Mac's scaling options")
    var small = Bitmap(width: 3, height: 2)
    small.set(x: 1, y: 1, to: RGB.black.packed)
    let tiled = MainWindowController.wallpaperBitmap(small, style: .tile, screen: (10, 7))
    check(tiled.width == 10 && tiled[4, 1] == RGB.black.packed && tiled[7, 5] == RGB.black.packed && tiled[5, 5] == RGB.white.packed,
          "Tile repeats the picture")
    check(controller.wallpaperMenuItems().map(\.tag) == [0, 1, 2] && controller.wallpaperPaneEntries.count == 3,
          "the menus offer Fill, Tile and Center")

    // MARK: Image properties
    var form = ImagePropertiesForm(width: 800, height: 600, blackAndWhite: false, defaultWidth: 800, defaultHeight: 600)
    let us = Locale(identifier: "en_US")
    check(ImagePropertiesForm.text(800, in: .inches, locale: us) == "8.33" && ImagePropertiesForm.text(600, in: .centimeters, locale: us) == "15.88"
          && ImagePropertiesForm.text(800, in: .inches, locale: Locale(identifier: "pt_BR")) == "8,33", "sizes read in inches and centimetres")
    check(ImagePropertiesForm.pixels("8,33", in: .inches) == 800 && ImagePropertiesForm.pixels("21.17", in: .centimeters) == 800
          && ImagePropertiesForm.pixels("abc", in: .pixels) == nil, "typed sizes come back as pixels")
    form.setUnit(.centimeters)
    check(form.unit == .centimeters && ImagePropertiesForm.pixels(form.width, in: .centimeters) == 800, "a new unit rewrites the values")
    form.setUnit(.pixels)
    check(form.width == "800" && form.height == "600", "and back to pixels")
    form.editWidth("0")
    check(form.validate() == nil, "a width of 0 is refused")
    form.editWidth("20000")
    check(form.validate() == nil, "so is one beyond the limit")
    form.restoreDefault()
    check(form.validate() == ImageProperties(width: 800, height: 600, blackAndWhite: false), "Default brings back the new picture size")
    let dialog = controller.makePropertiesDialog()
    check(dialog.savedLabel.stringValue == "Last saved: Not available" && dialog.diskLabel.stringValue == "Size on disk: Not available"
          && dialog.resolutionLabel.stringValue == "Resolution: 96 DPI", "a new picture has no file attributes")
    check(dialog.unitButtons[2].state == .on && dialog.colorButton.state == .on && dialog.widthField.stringValue == "800",
          "the dialog starts in pixels and colors")
    dialog.unitButtons[0].performClick(nil)
    check(dialog.widthField.stringValue == ImagePropertiesForm.text(800, in: .inches), "Inches converts the fields")
    dialog.unitButtons[2].performClick(nil)
    dialog.type("640", into: dialog.widthField)
    dialog.type("480", into: dialog.heightField)
    var invalid: String?
    dialog.onInvalid = { invalid = $0 }
    dialog.confirmDialog(nil)
    check(invalid == nil && dialog.result == ImageProperties(width: 640, height: 480, blackAndWhite: false), "OK gives the new size")
    controller.document.color2 = RGB(r: 0, g: 200, b: 0)
    controller.applyProperties(ImageProperties(width: 900, height: 700, blackAndWhite: false))
    check(controller.document.bitmap.width == 900 && controller.document.bitmap[850, 650] == RGB(r: 0, g: 200, b: 0).packed
          && controller.document.bitmap[10, 10] == RGB.white.packed, "a larger size adds Color 2 on the right and the bottom")
    controller.undoEdit(nil)
    check(controller.document.bitmap.width == 800 && controller.document.bitmap.height == 600, "one undo restores the size")
    controller.document.color2 = .white
    controller.document.draw { $0.fill(PixelRect(x: 0, y: 0, width: 10, height: 10), with: RGB(r: 250, g: 240, b: 30).packed)
                               $0.fill(PixelRect(x: 10, y: 0, width: 10, height: 10), with: RGB(r: 90, g: 0, b: 40).packed) }
    check(!controller.document.isBlackAndWhite, "a colored picture is not black and white")
    controller.applyProperties(ImageProperties(width: 800, height: 600, blackAndWhite: true))
    check(controller.document.isBlackAndWhite && controller.document.bitmap[2, 2] == RGB.white.packed
          && controller.document.bitmap[12, 2] == RGB.black.packed, "Black and white turns light colors white and dark ones black")
    check(controller.makePropertiesDialog().blackAndWhiteButton.state == .on, "the dialog then shows Black and white")
    controller.undoEdit(nil)
    check(controller.document.bitmap[12, 2] == RGB(r: 90, g: 0, b: 40).packed, "one undo brings the colors back")
    controller.document.revert(to: Bitmap(width: 800, height: 600))
    let wrong = controller.makePropertiesDialog()
    var message: String?
    wrong.onInvalid = { message = $0 }
    wrong.type("0", into: wrong.widthField)
    wrong.confirmDialog(nil)
    check(message == "Type a size between 1 and 10000 pixels." && wrong.result == nil, "an invalid size keeps the dialog open")

    // MARK: Edit colors
    check(WinHLS(RGB(r: 255, g: 0, b: 0)) == WinHLS(h: 0, l: 120, s: 240) && WinHLS(RGB(r: 0, g: 0, b: 255)) == WinHLS(h: 160, l: 120, s: 240)
          && WinHLS(.white) == WinHLS(h: 160, l: 240, s: 0) && WinHLS(.black) == WinHLS(h: 160, l: 0, s: 0),
          "RGB to hue, luminance and saturation on the 0–240 scale")
    check(WinHLS(h: 80, l: 120, s: 240).rgb == RGB(r: 0, g: 255, b: 0) && WinHLS(h: 40, l: 120, s: 240).rgb == RGB(r: 255, g: 255, b: 0)
          && WinHLS(h: 0, l: 60, s: 240).rgb == RGB(r: 128, g: 0, b: 0), "and back")
    check(EditColorsModel.basicColors.count == 48 && EditColorsModel.basicColors.allSatisfy { color in
        let back = WinHLS(color).rgb
        return abs(Int(back.r) - Int(color.r)) <= 2 && abs(Int(back.g) - Int(color.g)) <= 2 && abs(Int(back.b) - Int(color.b)) <= 2
    }, "the 48 basic colors survive the round trip")
    var model = EditColorsModel(color: .black, customColors: [])
    model.pickSpectrum(hue: 120, saturation: 240)
    check(model.hls == WinHLS(h: 120, l: 120, s: 240) && model.rgb == RGB(r: 0, g: 255, b: 255), "a spectrum pick on black moves to the middle luminance")
    model.pickLuminance(240)
    check(model.rgb == .white && model.hls.h == 120, "the luminance bar keeps hue and saturation")
    model.addCustom()
    check(model.customColors[0] == .white && model.selectedCustom == 1 && model.customColors.count == 16, "Add fills the selected box and moves on")
    model.setRGB(.black)
    model.selectCustom(0)
    check(model.rgb == .white, "a filled custom box picks its color")
    let editor = controller.makeEditColorsDialog()
    check(editor.fields.map(\.stringValue) == ["160", "0", "0", "0", "0", "0"] && editor.preview.color == .black,
          "Edit colors opens on the active color")
    editor.type("255", into: editor.fields[3])
    check(editor.preview.color == RGB(r: 255, g: 0, b: 0) && editor.fields[0].stringValue == "0" && editor.fields[2].stringValue == "120"
          && editor.fields[1].stringValue == "240", "typing Red updates hue, saturation and luminance")
    editor.type("80", into: editor.fields[0])
    check(editor.preview.color == RGB(r: 0, g: 255, b: 0) && editor.fields[4].stringValue == "255", "typing Hue updates the red, green and blue")
    let blueIndex = EditColorsModel.basicColors.firstIndex(of: RGB(r: 0, g: 0, b: 255))!
    editor.pickBasic(blueIndex)
    check(editor.fields[5].stringValue == "255" && editor.basicGrid.selected == blueIndex, "a basic color is picked")
    editor.addCustomColor(nil)
    check(editor.customGrid.colors[0] == RGB(r: 0, g: 0, b: 255) && editor.customGrid.selected == 1, "Add to Custom Colors fills a box")
    editor.confirmDialog(nil)
    check(editor.result == RGB(r: 0, g: 0, b: 255), "OK gives the color")
    controller.activeColorSlot = .color2
    controller.applyEditedColor(RGB(r: 0, g: 0, b: 255))
    let palette = control("home.palette") as! PaletteView
    check(controller.document.color2 == RGB(r: 0, g: 0, b: 255) && controller.customColors[0] == RGB(r: 0, g: 0, b: 255)
          && palette.colors[20] == RGB(r: 0, g: 0, b: 255) && (control("text.palette") as! PaletteView).colors[20] == RGB(r: 0, g: 0, b: 255),
          "OK sets the active color and the first custom place of the palette")
    controller.activeColorSlot = .color1
    controller.applyEditedColor(RGB(r: 10, g: 20, b: 30))
    check(controller.document.color1 == RGB(r: 10, g: 20, b: 30) && controller.customColors[1] == RGB(r: 10, g: 20, b: 30)
          && palette.colors[22] == nil, "the next color takes the next place")
    palette.press(20)
    check(controller.document.color1 == RGB(r: 0, g: 0, b: 255) && state(#selector(MainWindowController.choosePaletteColor(_:)), tag: 20).checked == true,
          "a filled custom place picks its color")
    check(palette.accessibilityChildren()?.count == 22, "filled custom places become accessibility buttons")
    for value in 2..<11 { controller.applyEditedColor(RGB(r: UInt8(value), g: 0, b: 0)) }
    check(controller.customColors[0] == RGB(r: 10, g: 0, b: 0) && controller.customColors[9] == RGB(r: 9, g: 0, b: 0),
          "once the ten places are full, the oldest is replaced")
    check(MainWindowController().customColors == controller.customColors, "the custom places are remembered")
    check(control("home.editColors").isEnabled && controller.makeColorsMenu().items.contains { $0.action == #selector(MainWindowController.showEditColors(_:)) },
          "Edit colors is in the ribbon and in the Colors menu")

    // MARK: Recent pictures
    var pictures: [URL] = []
    for index in 0..<12 {
        let url = folder.appendingPathComponent("picture \(index).png")
        try? ImageFile.write(Bitmap(width: 10 + index, height: 10), to: url, format: .png)
        pictures.append(url)
    }
    let recent = controller.recentPictures
    recent.clear()
    recent.add(pictures[0])
    recent.add(pictures[1])
    recent.add(pictures[2])
    check(recent.urls.map(\.lastPathComponent) == ["picture 2.png", "picture 1.png", "picture 0.png"], "the most recent picture comes first")
    recent.add(pictures[0])
    check(recent.urls.map(\.lastPathComponent) == ["picture 0.png", "picture 2.png", "picture 1.png"], "opening one again moves it up, once")
    pictures.forEach(recent.add)
    check(recent.urls.count == RecentPictures.limit && RecentPictures.limit == 9 && recent.urls.first?.lastPathComponent == "picture 11.png",
          "the list keeps nine")
    check(RecentPictures().urls == recent.urls, "the list is remembered")
    controller.document.isDirty = false
    controller.openRecentPicture(menuItem(#selector(MainWindowController.openRecentPicture(_:)), tag: 3))
    check(controller.document.url?.lastPathComponent == "picture 8.png" && controller.document.bitmap.width == 18
          && recent.urls.first?.lastPathComponent == "picture 8.png", "a recent picture opens and moves to the top")
    let entries = controller.recentPaneEntries
    check(entries.count == 9 && entries[0].title == "1  picture 8.png" && entries[1].title == "2  picture 11.png",
          "the application menu numbers the recent pictures")
    let menuView = ApplicationMenuView(entries: controller.applicationMenuEntries, formats: MainWindowController.saveFormats,
                                       panes: [.recent: entries, .print: controller.printPaneEntries, .wallpaper: controller.wallpaperPaneEntries],
                                       target: controller)
    check(menuView.pane == .recent && menuView.paneItems[.recent]?.allSatisfy { !$0.isHidden } == true
          && menuView.paneItems[.print]?.allSatisfy(\.isHidden) == true, "the application menu shows the recent pictures on the right")
    menuView.items[4].hover(at: NSPoint(x: 5, y: 5))
    check(menuView.pane == .print && menuView.paneItems[.print]?.map(\.action) == [#selector(MainWindowController.printImage(_:)),
          #selector(MainWindowController.showPageSetup(_:)), #selector(MainWindowController.showPrintPreview(_:))]
          && menuView.paneItems[.recent]?.allSatisfy(\.isHidden) == true, "pointing at Print shows Print, Page setup and Print preview")
    menuView.items[5].hover(at: NSPoint(x: 5, y: 5))
    check(menuView.pane == .wallpaper && menuView.paneItems[.wallpaper]?.map(\.tag) == [0, 1, 2], "pointing at the desktop background shows its three ways")
    menuView.paneItems[.recent]?[1].perform()
    check(controller.document.url?.lastPathComponent == "picture 11.png", "a click on a recent picture opens it")
    let recentMenu = NSMenu(title: MainWindowController.recentMenuTitle)
    controller.menuNeedsUpdate(recentMenu)
    check(recentMenu.items.count == 11 && recentMenu.items[0].title == "picture 11.png" && recentMenu.items.last?.action == #selector(MainWindowController.clearRecentPictures(_:)),
          "File > Open Recent lists them with Clear Menu")
    check(fileMenu.items.contains { $0.submenu?.title == MainWindowController.recentMenuTitle }, "File has Open Recent")
    let saved = folder.appendingPathComponent("saved.bmp")
    controller.clearRecentPictures(nil)
    check(recent.urls.isEmpty && !state(#selector(MainWindowController.clearRecentPictures(_:))).enabled, "Clear Menu empties the list")
    try? ImageFile.write(Bitmap(width: 5, height: 5), to: saved, format: .bmp)
    controller.open(saved)
    check(recent.urls.map(\.lastPathComponent) == ["saved.bmp"], "opening a file adds it")
    recent.remove(saved)
    check(recent.urls.isEmpty, "a picture can leave the list")

    // MARK: Interface text size
    check(controller.interfaceSize == .normal && RibbonTheme.scale == 1, "the interface starts at Normal")
    controller.chooseInterfaceSize(menuItem(#selector(MainWindowController.chooseInterfaceSize(_:)), tag: InterfaceSize.large.rawValue))
    check(controller.interfaceSize == .large && RibbonTheme.scale == 1.25 && defaults.integer(forKey: AppSettings.interfaceSizeKey) == 2,
          "Large takes the factor 1.25 and is saved")
    check(ribbon.frame.height == RibbonTheme.ribbonHeight * 1.25 && ribbon.bounds.height == RibbonTheme.ribbonHeight
          && abs(ribbon.bounds.width - ribbon.frame.width / 1.25) < 0.01, "the ribbon is drawn larger with the same layout")
    check(controller.statusBar.frame.height == RibbonTheme.statusBarHeight * 1.25 && controller.statusBar.bounds.height == RibbonTheme.statusBarHeight
          && controller.scrollView.frame.minY == ribbon.frame.maxY, "the status bar too, and the workspace follows")
    check(window.contentMinSize == MainWindowController.minimumContentSize(1.25) && window.contentMinSize.width == 400,
          "the minimum window size takes the factor")
    let collapsedAtLarge = ribbon.pages[0].groups.filter(\.isCollapsed).count
    controller.interfaceSize = .extraLarge
    let collapsedAtExtra = ribbon.pages[0].groups.filter(\.isCollapsed).count
    controller.interfaceSize = .small
    let collapsedAtSmall = ribbon.pages[0].groups.filter(\.isCollapsed).count
    check(collapsedAtSmall <= collapsedAtLarge && collapsedAtLarge <= collapsedAtExtra && collapsedAtExtra > collapsedAtSmall,
          "larger text collapses more groups in the same window")
    let interfaceItems = controller.interfaceSizeMenuItems()
    check(interfaceItems.map(\.title) == ["Small", "Normal", "Large", "Extra large"] && interfaceItems[0].state == .on,
          "the View menu lists the four sizes and marks the current one")
    check(state(#selector(MainWindowController.chooseInterfaceSize(_:)), tag: 0).checked == true
          && state(#selector(MainWindowController.chooseInterfaceSize(_:)), tag: 1).checked == false, "the state marks the current size")
    check(control("view.interfaceSize").isEnabled && (control("view.interfaceSize") as? RibbonButton)?.hasDropdown == true,
          "the View tab has the Text size drop-down")
    controller.interfaceSize = .extraLarge
    check(MainWindowController().interfaceSize == .extraLarge, "the size is remembered")
    controller.showApplicationMenu()
    if let popup = RibbonPopup.current, let menu = popup.panel.contentView?.subviews.first {
        check(abs(popup.panel.frame.width - ceil((menu.frame.width + 2) * 1.5)) < 1 && abs((popup.panel.contentView?.bounds.width ?? 0) - (menu.frame.width + 2)) < 0.01,
              "the application menu grows with the factor")
        popup.close()
    } else {
        check(false, "the application menu opens")
    }
    let scaledDialog = controller.makePropertiesDialog()
    let logical = (scaledDialog.window.contentView as? ScaledContentView)?.content.bounds.size ?? .zero
    check(abs(scaledDialog.window.contentRect(forFrameRect: scaledDialog.window.frame).width - ceil(logical.width * 1.5)) < 1
          && logical.width == scaledDialog.dialogWidth, "the app's dialogs grow with the factor")
    let settings = SettingsWindow(controller: controller)
    check(settings.sizePopup.selectedTag() == InterfaceSize.extraLarge.rawValue, "Settings shows the current size")
    settings.sizePopup.selectItem(withTag: InterfaceSize.normal.rawValue)
    controller.chooseInterfaceSize(settings.sizePopup)
    check(controller.interfaceSize == .normal && RibbonTheme.scale == 1, "Settings changes it")
    controller.openAppSettings(nil)
    check(controller.settingsWindow != nil, "My Paint > Settings opens its window")
    if let settingsWindow = controller.settingsWindow?.window {
        check(abs(settingsWindow.frame.midX - window.frame.midX) <= 1, "centred on the main window")
        settingsWindow.orderOut(nil)
    }

    // Nothing cut: every label of the ribbon, the application menu, the status bar and the app's own
    // dialogs fits its room, in each language of Resources and at each size.
    let languages = (Bundle.main.paths(forResourcesOfType: "lproj", inDirectory: nil)).sorted()
    check(languages.count == 8, "the eight languages are found next to the tests")
    for path in languages {
        guard let bundle = Bundle(path: path) else { continue }
        Localization.bundle = bundle
        let language = (path as NSString).lastPathComponent
        for size in InterfaceSize.allCases {
            AppSettings.defaults.set(size.rawValue, forKey: AppSettings.interfaceSizeKey)
            let fresh = MainWindowController()
            let problems = clippedLabels(fresh)
            check(problems.isEmpty, "\(language), \(L(size.nameKey)): nothing is cut" + (problems.isEmpty ? "" : " — " + problems.joined(separator: "; ")))
        }
    }
    Localization.bundle = .main
    AppSettings.defaults.set(InterfaceSize.normal.rawValue, forKey: AppSettings.interfaceSizeKey)
    controller.interfaceSize = .normal
}

private func horizontalHidden(_ controller: MainWindowController) -> Bool {
    controller.horizontalRuler.isHidden && controller.verticalRuler.isHidden && controller.rulerCorner.isHidden
}

/// Labels that do not fit their room, by name. Measures text against the space each control
/// gives it, so it works for any language.
func clippedLabels(_ controller: MainWindowController) -> [String] {
    var problems: [String] = []
    let width = RibbonTheme.textWidth
    func lineFits(_ lines: [String], in control: NSView, extra: CGFloat = 0) -> Bool {
        (lines.map(width).max() ?? 0) + extra + 2 <= control.bounds.width
    }
    func checkControl(_ view: NSView, _ where_: String) {
        switch view {
        case let button as RibbonButton:
            let fits: Bool
            switch button.style {
            case .large:
                let last = button.inlineArrow ? width(button.lines.last ?? "") + RibbonButton.inlineArrowWidth : 0
                let height = 3 + RibbonTheme.largeIcon + 2 + 13 * CGFloat(button.lines.count) + (button.hasDropdown && !button.inlineArrow ? 9 : 0)
                fits = lineFits(button.lines, in: button) && last + 2 <= button.bounds.width && height <= button.bounds.height + 1
            case .small: fits = 23 + width(button.title) + (button.hasDropdown ? 12 : 0) <= button.bounds.width
            case .icon: fits = true
            }
            if !fits { problems.append("\(where_): \(button.title.replacingOccurrences(of: "\n", with: " "))") }
        case let box as RibbonCheckbox:
            if 21 + width(box.title) > box.bounds.width { problems.append("\(where_): \(box.title)") }
        case let well as ColorWellButton:
            if !lineFits(well.title.components(separatedBy: "\n"), in: well) { problems.append("\(where_): \(well.title)") }
        default: break
        }
        view.subviews.forEach { checkControl($0, where_) }
    }
    let ribbon = controller.ribbon!
    ribbon.setContextualVisible(true)
    for (index, page) in ribbon.pages.enumerated() {
        // The Print preview tab only shows in its mode.
        if page.isPrintPreview { controller.showPrintPreview(nil) }
        defer { if page.isPrintPreview { controller.closePrintPreview(nil) } }
        ribbon.selectPage(index)
        if ribbon.selectedPage != index { problems.append("tab \(page.title) cannot be shown") }
        for tab in ribbon.tabs where !tab.isHidden && width(tab.title) + 4 > tab.bounds.width { problems.append("tab \(tab.title)") }
        for group in page.groups {
            if group.frame.maxX > ribbon.bounds.width + 0.5 { problems.append("group \(group.title) off the ribbon") }
            if group.isCollapsed {
                checkControl(group.collapsedButton, group.title)
            } else {
                if width(group.title) + 2 > group.bounds.width - 2 { problems.append("group label \(group.title)") }
                for control in group.content.subviews where control.frame.maxX > group.content.bounds.width + 0.5 {
                    problems.append("\(group.title): control outside its group")
                }
                checkControl(group.content, group.title)
            }
        }
    }
    ribbon.setContextualVisible(false)
    checkControl(ribbon, "quick access")
    // Application menu.
    // Recent pictures with their pins, one free and one pinned, with a typical file name.
    let recentSample = (0..<2).map { index in
        ApplicationPaneEntry(name: "recent.\(index)", title: MainWindowController.recentTitle(URL(fileURLWithPath: "/tmp/Holiday picture.png"), index: index),
                             detail: nil, icon: nil, action: #selector(MainWindowController.openRecentPicture(_:)), tag: index, pinned: index == 1)
    }
    let menu = ApplicationMenuView(entries: controller.applicationMenuEntries, formats: MainWindowController.saveFormats,
                                   panes: [.print: controller.printPaneEntries, .wallpaper: controller.wallpaperPaneEntries, .recent: recentSample],
                                   target: controller)
    for item in menu.items {
        let room = item.bounds.width - 46 - (item.entry.hasSubmenu ? 18 : 6)
        let attributes = RibbonTheme.attributes()
        let needed = (item.title as NSString).boundingRect(with: NSSize(width: room, height: 200), options: [.usesLineFragmentOrigin],
                                                           attributes: attributes)
        let longestWord = item.title.split(separator: " ").map { width(String($0)) }.max() ?? 0
        if needed.height > item.bounds.height || longestWord > room { problems.append("menu \(item.title)") }
    }
    let bold = SaveFormatItem.boldAttributes
    let detail = RibbonTheme.attributes()
    func detailFits(_ text: String, _ room: CGFloat) -> Bool {
        (text as NSString).boundingRect(with: NSSize(width: room, height: 200), options: [.usesLineFragmentOrigin], attributes: detail).height <= RibbonTheme.menuPaneDetailHeight + 0.5
    }
    for item in menu.formatItems where (item.title as NSString).size(withAttributes: bold).width + 52 > item.bounds.width
        || !detailFits(L(item.entry.detailKey), item.bounds.width - 52) {
        problems.append("Save as \(item.title)")
    }
    for items in menu.paneItems.values {
        for item in items {
            if let text = item.entry.detail {
                if (item.title as NSString).size(withAttributes: bold).width + item.titleX + 6 > item.bounds.width
                    || !detailFits(text, item.bounds.width - item.titleX - 6) { problems.append("pane \(item.title)") }
            } else if width(item.title) > item.titleRoom {
                problems.append("pane \(item.title)")
            }
            if let pin = item.pinButton {
                if !item.bounds.contains(pin.frame) || pin.frame.minX < item.titleX + item.titleRoom
                    || pin.bounds.width < 16 || pin.bounds.height < 16 { problems.append("pin of \(item.title)") }
            }
        }
    }
    for pane in [ApplicationPane.recent, .saveAs, .print, .wallpaper]
    where (L(pane.headerKey) as NSString).size(withAttributes: bold).width > RibbonTheme.menuRightWidth - 20 {
        problems.append("menu header \(L(pane.headerKey))")
    }
    // The drawn drop-down menus.
    problems += clippedMenuLabels(controller)
    problems += clippedFontList(controller)
    // Status bar, with the longest values it shows.
    let room = RibbonTheme.statusSectionWidth - 27 - 3
    for text in [StatusText.position(PixelPoint(x: 9999, y: 9999)), StatusText.imageSize(width: 9999, height: 9999),
                 StatusText.diskSize(1000 * 1024), StatusText.diskSize(999)] where width(text) > room {
        problems.append("status \(text)")
    }
    if width(StatusText.zoom(0.125)) > RibbonTheme.zoomLabelWidth { problems.append("status zoom") }
    // The app's own dialogs.
    func checkDialog(_ root: NSView, _ name: String) {
        func walk(_ view: NSView) {
            for sub in view.subviews {
                let frame = sub.convert(sub.bounds, to: root)
                if frame.maxX > root.bounds.width + 0.5 || frame.minX < -0.5 { problems.append("\(name): \(describe(sub)) outside") }
                if let field = sub as? NSTextField, !field.isEditable, !field.stringValue.isEmpty {
                    if field.cell!.cellSize.width > sub.bounds.width + 0.5 { problems.append("\(name): \(field.stringValue)") }
                } else if let button = sub as? NSButton, !(sub is NSPopUpButton) {
                    let text = (button.title as NSString).size(withAttributes: [.font: button.font ?? NSFont.systemFont(ofSize: 13)]).width
                    let needed = button.bezelStyle == .rounded ? text + 14 : button.fittingSize.width
                    // A point of rounding at the fractional sizes does not cut a letter.
                    if needed > sub.bounds.width + 1.5 { problems.append("\(name): \(button.title)") }
                } else if let box = sub as? NSBox {
                    let text = (box.title as NSString).size(withAttributes: [.font: box.titleFont]).width
                    if text + 16 > box.bounds.width { problems.append("\(name): \(box.title)") }
                }
                walk(sub)
            }
        }
        root.layoutSubtreeIfNeeded()
        walk(root)
        // Controls side by side must not overlap (boxes hold others, so they are left out).
        let controls = root.subviews.filter { $0 is NSControl && !$0.isHidden }
        for (index, first) in controls.enumerated() {
            for second in controls[(index + 1)...] where first.frame.insetBy(dx: 1, dy: 1).intersects(second.frame.insetBy(dx: 1, dy: 1)) {
                problems.append("\(name): \(describe(first)) overlaps \(describe(second))")
            }
        }
    }
    func describe(_ view: NSView) -> String {
        if let field = view as? NSTextField { return field.stringValue }
        if let button = view as? NSButton { return button.title }
        return String(describing: type(of: view))
    }
    let resize = ResizeSkewDialog(width: 800, height: 600)
    checkDialog((resize.window.contentView as! ScaledContentView).content, "Resize")
    checkDialog(controller.makePropertiesDialog().content, "Properties")
    checkDialog(controller.makeEditColorsDialog().content, "Edit colors")
    let accessory = PageSetupAccessory(options: PrintOptions())
    checkDialog(accessory.view, "Page setup")
    // Settings: the label and the menu on one row, the note on as many lines as it takes.
    if let root = SettingsWindow(controller: controller).window.contentView {
        for case let field as NSTextField in root.subviews {
            let needed = field.cell!.cellSize(forBounds: NSRect(x: 0, y: 0, width: field.bounds.width, height: 1000))
            if needed.width > field.bounds.width + 0.5 || needed.height > field.bounds.height + 0.5 || field.frame.maxY > root.bounds.height {
                problems.append("Settings: \(field.stringValue)")
            }
        }
        if root.subviews.contains(where: { $0.frame.maxX > root.bounds.width + 0.5 }) { problems.append("Settings: control outside") }
    }
    return problems
}
