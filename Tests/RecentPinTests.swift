import AppKit

/// Pins of the recent pictures in the application menu.
func runRecentPinTests() {
    _ = NSApplication.shared
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("mypaint-pins-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let pictures: [URL] = (0..<14).map { index in
        let url = folder.appendingPathComponent("p\(index).png")
        try? ImageFile.write(Bitmap(width: 10 + index, height: 10), to: url, format: .png)
        return url.standardizedFileURL
    }
    func names(_ urls: [URL]) -> [String] { urls.map { $0.deletingPathExtension().lastPathComponent } }

    let controller = MainWindowController()
    var errors = 0
    controller.reportOpenError = { _ in errors += 1 }
    let recent = controller.recentPictures
    recent.clear()
    pictures[0..<5].forEach(recent.add)
    check(names(recent.urls) == ["p4", "p3", "p2", "p1", "p0"] && recent.pinnedCount == 0, "the list starts without pins")

    // Order.
    recent.setPinned(pictures[2], true)
    check(names(recent.urls) == ["p2", "p4", "p3", "p1", "p0"] && recent.isPinned(pictures[2]), "a pinned picture goes to the top")
    recent.togglePin(pictures[0])
    check(names(recent.urls) == ["p2", "p0", "p4", "p3", "p1"] && names(recent.pinned) == ["p2", "p0"],
          "a second pin goes after the first, still above the others")
    recent.add(pictures[5])
    check(names(recent.urls) == ["p2", "p0", "p5", "p4", "p3", "p1"], "a new picture goes first after the pinned ones")
    recent.add(pictures[0])
    check(names(recent.urls) == ["p2", "p0", "p5", "p4", "p3", "p1"], "opening a pinned picture again leaves it in place")
    recent.add(pictures[3])
    check(names(recent.urls) == ["p2", "p0", "p3", "p5", "p4", "p1"], "opening a free picture again moves it up among the free ones")
    recent.togglePin(pictures[2])
    check(names(recent.urls) == ["p0", "p2", "p3", "p5", "p4", "p1"] && !recent.isPinned(pictures[2]),
          "an unpinned picture goes first among the free ones")
    recent.setPinned(pictures[2], true)
    recent.setPinned(folder.appendingPathComponent("not listed.png"), true)
    check(names(recent.pinned) == ["p0", "p2"], "only listed pictures can be pinned")

    // Limit of nine: the free ones make room, the pinned ones stay.
    pictures[6..<14].forEach(recent.add)
    check(recent.urls.count == RecentPictures.limit && names(Array(recent.urls.prefix(2))) == ["p0", "p2"]
          && names(Array(recent.urls.dropFirst(2))) == ["p13", "p12", "p11", "p10", "p9", "p8", "p7"],
          "new pictures push out the oldest free ones, never a pinned one")

    // Persistence.
    let reloaded = RecentPictures()
    check(reloaded.urls == recent.urls && reloaded.pinned == recent.pinned, "the pins are remembered between launches")
    check(AppSettings.defaults.stringArray(forKey: AppSettings.recentPinnedKey) == recent.pinned.map(\.path),
          "the pins are kept in the app's settings")

    // Every place pinned: the list stays as it is.
    recent.urls.forEach { recent.setPinned($0, true) }
    let full = recent.urls
    check(recent.pinnedCount == 9 && !recent.canClear, "all nine can be pinned")
    recent.add(pictures[1])
    check(recent.urls == full && !recent.urls.contains(pictures[1]), "with all nine pinned a new picture is not listed")
    recent.setPinned(full[4], false)
    check(recent.urls.last == full[4] && recent.pinnedCount == 8, "unpinning one frees a place at the bottom")
    recent.add(pictures[1])
    check(recent.urls.count == 9 && recent.urls.last == pictures[1] && !recent.urls.contains(full[4]),
          "the next picture takes the freed place")

    // Clear Menu keeps the pinned pictures.
    controller.clearRecentPictures(nil)
    check(recent.urls == recent.pinned && recent.pinnedCount == 8, "Clear Menu takes away only the free pictures")
    let clearItem = NSMenuItem(title: "", action: #selector(MainWindowController.clearRecentPictures(_:)), keyEquivalent: "")
    check(!controller.validateMenuItem(clearItem), "Clear Menu is disabled with only pinned pictures left")

    // A picture that can no longer be read leaves the list; the other pins stay.
    recent.urls.forEach { recent.setPinned($0, false) }
    recent.clear()
    pictures[0..<4].forEach(recent.add)
    recent.setPinned(pictures[0], true)
    recent.setPinned(pictures[2], true)
    try? Data("not an image".utf8).write(to: pictures[2])
    controller.document.isDirty = false
    controller.openRecentPicture(menuItem(#selector(MainWindowController.openRecentPicture(_:)), tag: 1))
    check(errors == 1 && names(recent.urls) == ["p0", "p3", "p1"] && names(recent.pinned) == ["p0"],
          "an unreadable pinned picture leaves the list and the other pins stay")
    try? FileManager.default.removeItem(at: pictures[3])
    controller.openRecentPicture(menuItem(#selector(MainWindowController.openRecentPicture(_:)), tag: 1))
    check(errors == 2 && names(recent.urls) == ["p0", "p1"] && names(recent.pinned) == ["p0"], "a missing free picture leaves too")
    check(RecentPictures().pinned == recent.pinned && RecentPictures().urls == recent.urls, "the cleaned list is remembered")

    // The menu: a pin on every recent picture, at the right.
    recent.add(pictures[4])
    let entries = controller.recentPaneEntries
    check(entries.map(\.pinned) == [true, false, false], "each recent entry says whether it is pinned")
    let menu = ApplicationMenuView(entries: controller.applicationMenuEntries, formats: MainWindowController.saveFormats,
                                   panes: [.recent: entries], target: controller)
    menu.onTogglePin = { index in
        controller.toggleRecentPin(at: index)
        return controller.recentPaneEntries
    }
    let window = NSWindow(contentRect: NSRect(origin: .zero, size: menu.frame.size), styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = menu
    let items = menu.paneItems[.recent]!
    check(items.allSatisfy { $0.pinButton != nil && $0.pinButton!.frame.maxX <= $0.bounds.width && $0.pinButton!.frame.minX > $0.bounds.width / 2 },
          "every recent picture has a pin at its right")
    check(items[0].pinButton!.isPinned && !items[1].pinButton!.isPinned, "the pin shows whether the picture is pinned")
    check(items[0].pinButton!.toolTip == "Unpin from this list" && items[1].pinButton!.toolTip == "Pin to this list",
          "the pin's tip says what a click does")
    check(controller.printPaneEntries.allSatisfy { $0.pinned == nil } && controller.wallpaperPaneEntries.allSatisfy { $0.pinned == nil },
          "other panes have no pins")

    // A click on the pin pins without opening the picture or closing the menu.
    let opened = controller.document.url
    let pin = items[2].pinButton!
    let center = pin.convert(NSPoint(x: pin.bounds.midX, y: pin.bounds.midY), to: nil)
    let hit = menu.hitTest(menu.superview!.convert(center, from: nil))
    check(hit === pin, "the pin, not the item, takes a click on it")
    for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
        let event = NSEvent.mouseEvent(with: type, location: center, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                                       context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        if type == .leftMouseDown { hit?.mouseDown(with: event) } else { hit?.mouseUp(with: event) }
    }
    check(controller.document.url == opened, "clicking the pin does not open the picture")
    check(names(recent.urls) == ["p0", "p1", "p4"] && names(recent.pinned) == ["p0", "p1"], "clicking the pin pins the picture")
    check(items.map(\.title) == ["1  p0.png", "2  p1.png", "3  p4.png"] && items.map(\.tag) == [0, 1, 2]
          && items.map { $0.pinButton!.isPinned } == [true, true, false], "the open menu reorders its items at once")
    check(items[1].pinButton!.toolTip == "Unpin from this list", "the tip changes with the pin")

    // Accessibility.
    let pinned = items[1].pinButton!, free = items[2].pinButton!
    check(pinned.isAccessibilityElement() && pinned.accessibilityRole() == .button
          && pinned.accessibilityLabel() == "Unpin from this list" && (pinned.accessibilityValue() as? Int) == 1
          && free.accessibilityLabel() == "Pin to this list" && (free.accessibilityValue() as? Int) == 0,
          "VoiceOver reads the pin's action and state")
    check(pinned.accessibilityIdentifier() == "appmenu.recent.1.pin" && pinned.accessibilityParent() != nil, "the pin has its own identifier")
    check(free.accessibilityPerformPress() && recent.isPinned(pictures[4]) && controller.document.url == opened,
          "pressing the pin with VoiceOver pins without opening")
    _ = items[0].pinButton!.accessibilityPerformPress()
    check(names(recent.urls) == ["p1", "p4", "p0"] && items[2].pinButton?.isPinned == false, "unpinning from the menu moves it down")

    // The item itself still opens its picture.
    items[0].perform()
    check(controller.document.url?.lastPathComponent == "p1.png", "a click on the name still opens the picture")

    // The drawing: upright when pinned, lying when free.
    func ink(_ pinned: Bool) -> (wide: Int, tall: Int) {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 16, pixelsHigh: 16, bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        RecentPinButton.drawPin(in: NSRect(x: 0, y: 0, width: 16, height: 16), pinned: pinned)
        NSGraphicsContext.restoreGraphicsState()
        var xs = Set<Int>(), ys = Set<Int>()
        for y in 0..<16 { for x in 0..<16 where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 { xs.insert(x); ys.insert(y) } }
        return (xs.count, ys.count)
    }
    let up = ink(true), lying = ink(false)
    check(up.tall > up.wide && lying.wide > lying.tall && up.wide > 4 && lying.tall > 4, "the pin stands when pinned and lies when free")
    recent.urls.forEach { recent.setPinned($0, false) }
    recent.clear()
}

private func menuItem(_ action: Selector, tag: Int) -> NSMenuItem {
    let item = NSMenuItem(title: "", action: action, keyEquivalent: "")
    item.tag = tag
    return item
}
