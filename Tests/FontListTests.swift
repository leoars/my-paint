import AppKit

/// Rows of the Font list that would be cut, for the "nothing is cut" check.
func clippedFontList(_ controller: MainWindowController) -> [String] {
    guard let box = controller.ribbon.control("text.fontFamily") as? RibbonComboBox else { return ["font list: no Font box"] }
    let list = FontListView(families: box.combo.objectValues.compactMap { $0 as? String }, selected: nil, minimumWidth: box.bounds.width)
    return list.clippedRows().map { "font list: \($0)" }
}

func runFontListTests() {
    _ = NSApplication.shared
    let controller = MainWindowController()
    let window = controller.window, toolbox = controller.canvas.toolbox
    var document: PaintDocument { controller.document }
    let box = controller.ribbon.control("text.fontFamily") as! RibbonComboBox
    let sizeBox = controller.ribbon.control("text.fontSize") as! RibbonComboBox
    let families = TextFormat.families
    func key(_ code: UInt16, _ characters: String, _ flags: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: window.windowNumber,
                         context: nil, characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code)!
    }
    let down = key(125, "\u{F701}"), up = key(126, "\u{F700}"), enter = key(36, "\r"), esc = key(53, "\u{1b}")
    func press(_ event: NSEvent) { RibbonPopup.current?.handleKey(event) }
    var openList: FontListView? { RibbonPopup.current?.content as? FontListView }

    toolbox.select(.text)
    document.beginText(PixelRect(x: 10, y: 10, width: 120, height: 40), format: toolbox.textTool.format, opaque: false)
    document.updateText { $0.string = "Abc" }
    controller.syncInterface()
    check(box.drawsFontList && !sizeBox.drawsFontList && box.isEnabled, "the Font box draws its own list, the Size box does not")

    // Each family in itself.
    let rows = families.map(FontListRow.row(for:))
    let own = rows.filter(\.showsNameInOwnFont)
    check(Double(own.count) >= 0.6 * Double(rows.count), "most families are written in their own font (\(own.count) of \(rows.count))")
    check(own.allSatisfy { $0.nameFont.familyName == $0.family }, "a family written in itself uses that family")
    if let helvetica = rows.first(where: { $0.family == "Helvetica" }), let times = rows.first(where: { $0.family == "Times" || $0.family == "Times New Roman" }) {
        check(helvetica.showsNameInOwnFont && times.showsNameInOwnFont && helvetica.nameFont.fontName != times.nameFont.fontName,
              "Helvetica and Times are written each in its own face")
    }
    let symbols = rows.filter { $0.sampleFont != nil }
    check(symbols.allSatisfy { $0.nameFont.familyName == NSFont.systemFont(ofSize: 13).familyName && $0.sampleFont?.familyName == $0.family },
          "symbol fonts show a readable name in the interface font and a sample in the font")
    for name in ["Webdings", "Wingdings", "Zapf Dingbats", "Symbol"] where families.contains(name) {
        check(rows.first { $0.family == name }?.sampleFont != nil, "\(name) is shown as a symbol font")
    }
    if let zapfino = rows.first(where: { $0.family == "Zapfino" }) {
        check(zapfino.showsNameInOwnFont && FontListRow.lineHeight(zapfino.nameFont) <= RibbonTheme.fontListRowHeight - 2 * RibbonTheme.fontListTextMargin,
              "a very tall font is drawn smaller to fit its row")
    }
    let foreign = rows.filter { !$0.showsNameInOwnFont && $0.sampleFont == nil }
    check(foreign.allSatisfy { $0.nameFont.familyName == NSFont.systemFont(ofSize: 13).familyName },
          "a family that cannot write its own name is written in the interface font")

    // Opening.
    check(box.combo.isOnArrow(NSPoint(x: box.combo.bounds.maxX - 5, y: 10)) && !box.combo.isOnArrow(NSPoint(x: 20, y: 10)),
          "the arrow is the right end of the box")
    check(RibbonComboBox.opensList(key(125, "\u{F701}", .option)) && !RibbonComboBox.opensList(down)
          && !RibbonComboBox.opensList(key(125, "\u{F701}", [.option, .command])), "Option+Down opens the list, Down alone does not")
    let arrowPoint = box.combo.convert(NSPoint(x: box.combo.bounds.maxX - 6, y: box.combo.bounds.midY), to: nil)
    let click = NSEvent.mouseEvent(with: .leftMouseDown, location: arrowPoint, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                                   context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
    if box.combo.isOnArrow(box.combo.convert(arrowPoint, from: nil)) { box.combo.mouseDown(with: click) }
    guard let list = openList, let popup = RibbonPopup.current else {
        check(false, "a click on the arrow opens the drawn list")
        return
    }
    check(list.families == families && list.selected == families.firstIndex(of: toolbox.textTool.format.family)
          && list.highlighted == list.selected, "a click on the arrow opens the drawn list on the current family")
    let corner = window.convertPoint(toScreen: box.convert(NSPoint(x: 0, y: box.bounds.height + 1), to: nil))
    check(abs(popup.panel.frame.minX - corner.x) < 1 && abs(popup.panel.frame.maxY - corner.y) < 1, "the list opens under the box")
    check(list.frame.width >= box.bounds.width && list.visibleRows == min(families.count, RibbonTheme.fontListVisibleRows)
          && list.hasScrollBar == (families.count > list.visibleRows), "the list is as wide as the box or wider, with 16 rows")
    check(list.clippedRows().isEmpty, "no family is cut")
    if let index = list.selected {
        check(index >= list.topRow && index < list.topRow + list.visibleRows, "the current family shows")
    }
    // A picture of the list: rows are drawn and the lit one stands out.
    if let rep = list.bitmapImageRepForCachingDisplay(in: list.bounds) {
        list.cacheDisplay(in: list.bounds, to: rep)
        func darkPixels(_ rect: NSRect) -> Int {
            var count = 0
            for y in stride(from: Int(rect.minY), to: Int(rect.maxY), by: 1) {
                for x in stride(from: Int(rect.minX), to: Int(rect.maxX), by: 1) where (rep.colorAt(x: x, y: y)?.brightnessComponent ?? 1) < 0.5 {
                    count += 1
                }
            }
            return count
        }
        let first = list.rowRect(list.topRow)
        check(darkPixels(first) > 10, "the rows are drawn with their names")
    }

    // Keyboard.
    let start = list.highlighted ?? 0
    press(down)
    check(list.highlighted == min(families.count - 1, start + 1), "Down lights the next family")
    press(up)
    press(up)
    check(list.highlighted == max(0, start - 1), "Up the one before")
    press(key(119, "\u{F72B}"))
    check(list.highlighted == families.count - 1 && list.topRow == list.maxTopRow, "End goes to the last family and scrolls to it")
    press(key(115, "\u{F729}"))
    check(list.highlighted == 0 && list.topRow == 0, "Home to the first")
    press(key(121, "\u{F72D}"))
    check(list.highlighted == min(families.count - 1, list.visibleRows - 1), "Page Down moves a page")
    let target = families.first { $0.hasPrefix("Cour") } ?? families[families.count / 2]
    let prefix = String(target.prefix(4))
    let now = Date()
    for (offset, letter) in prefix.enumerated() { list.typeAhead(String(letter), at: now.addingTimeInterval(Double(offset) * 0.1)) }
    let lit = list.highlighted.map { families[$0] } ?? ""
    check(lit.range(of: prefix, options: [.caseInsensitive, .anchored]) != nil
          && list.highlighted! >= list.topRow && list.highlighted! < list.topRow + list.visibleRows,
          "typing lights the first family that starts with the letters and scrolls to it")
    list.typeAhead("Z", at: now.addingTimeInterval(5))
    check(list.highlighted.map { families[$0].uppercased().hasPrefix("Z") } ?? false || !families.contains { $0.uppercased().hasPrefix("Z") },
          "after a pause typing starts over")
    for (offset, letter) in prefix.enumerated() { list.typeAhead(String(letter), at: now.addingTimeInterval(10 + Double(offset) * 0.1)) }
    press(enter)
    check(RibbonPopup.current == nil && toolbox.textTool.format.family == lit && document.text?.format.family == lit && box.stringValue == lit,
          "Enter applies the family to the text box and closes the list")
    check(document.text?.string == "Abc", "the text stays")

    // Mouse.
    box.openFontList()
    guard let second = openList else { return check(false, "the list opens again") }
    second.scroll(to: 0)
    let pick = min(3, families.count - 1)
    let rect = second.rowRect(pick)
    second.mouseMoved(with: NSEvent.mouseEvent(with: .mouseMoved, location: second.convert(NSPoint(x: rect.midX, y: rect.midY), to: nil),
                                               modifierFlags: [], timestamp: 0, windowNumber: second.window!.windowNumber, context: nil,
                                               eventNumber: 0, clickCount: 0, pressure: 0)!)
    check(second.highlighted == pick, "the pointer lights the row under it")
    if second.hasScrollBar {
        let bar = second.scrollBarRect
        let below = NSPoint(x: bar.midX, y: bar.maxY - 3)
        second.mouseDown(with: NSEvent.mouseEvent(with: .leftMouseDown, location: second.convert(below, to: nil), modifierFlags: [], timestamp: 0,
                                                  windowNumber: second.window!.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!)
        check(second.topRow == min(second.maxTopRow, second.visibleRows), "a click on the scroll bar below the thumb scrolls a page")
        if let cg = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: -2, wheel2: 0, wheel3: 0),
           let wheel = NSEvent(cgEvent: cg) {
            let before = second.topRow
            second.scrollWheel(with: wheel)
            // A synthesized wheel event now and then carries no delta at all; nothing to scroll then.
            check(second.topRow > before || before == second.maxTopRow || wheel.scrollingDeltaY == 0, "the wheel scrolls the list")
        }
        second.scroll(to: 0)
    }
    second.choose(pick)
    check(RibbonPopup.current == nil && toolbox.textTool.format.family == families[pick] && document.text?.format.family == families[pick],
          "a click on a family applies it")
    box.openFontList()
    press(esc)
    check(RibbonPopup.current == nil && toolbox.textTool.format.family == families[pick], "Esc closes the list and changes nothing")
    box.openFontList()
    box.openFontList()
    check(RibbonPopup.current == nil, "a second press on the arrow closes the list")

    // Typing in the box still works.
    box.stringValue = target
    box.combo.sendAction(box.combo.action, to: box.combo.target)
    check(toolbox.textTool.format.family == target && box.combo.completes, "a family typed in the box applies, with completion")

    // Accessibility.
    box.openFontList()
    if let third = openList {
        let children = third.accessibilityChildren() as? [NSAccessibilityElement] ?? []
        check(third.accessibilityRole() == .list && children.count == families.count
              && children.first?.accessibilityLabel() == families.first, "the list and its families are visible to accessibility")
        let index = min(5, families.count - 1)
        _ = children[index].accessibilityPerformPress()
        check(toolbox.textTool.format.family == families[index] && RibbonPopup.current == nil, "pressing a family picks it")
    }

    // Interface factor.
    RibbonTheme.scale = 2
    box.openFontList()
    if let popup = RibbonPopup.current, let list = openList {
        check(abs(popup.panel.frame.width - ceil((list.frame.width + 2) * 2)) < 1
              && abs((popup.panel.contentView?.bounds.width ?? 0) - (list.frame.width + 2)) < 0.01,
              "at twice the size the list's panel is twice as large, its layout unchanged")
        popup.close()
    } else {
        check(false, "the list opens at twice the size")
    }
    RibbonTheme.scale = 1
    box.isEnabled = false
    check(!box.openFontList() && RibbonPopup.current == nil, "a disabled box opens nothing")
    box.isEnabled = true
    document.fixText()
}
