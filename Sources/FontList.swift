import AppKit

/// How one family is shown in the Font list: its name in the family itself or, when the family
/// cannot write its own name (symbol fonts, fonts of other scripts), in the interface font with
/// a sample in the family after it (symbol fonts only, where the sample shows the symbols).
struct FontListRow {
    let family: String
    let nameFont: NSFont
    /// The family itself for the sample, or nil when there is none.
    let sampleFont: NSFont?
    let width: CGFloat

    var showsNameInOwnFont: Bool { sampleFont == nil && nameFont.familyName == family }

    private static var cache: [String: FontListRow] = [:]

    static func row(for family: String) -> FontListRow {
        if let row = cache[family] { return row }
        let row = FontListRow(measuring: family)
        cache[family] = row
        return row
    }

    /// The size at which `font` fits a row: the line height (with tall ascenders, as in Zapfino)
    /// no taller than the room for the text.
    static func fitted(_ font: NSFont) -> NSFont {
        let room = RibbonTheme.fontListRowHeight - 2 * RibbonTheme.fontListTextMargin
        let line = lineHeight(font)
        guard line > room else { return font }
        return NSFont(descriptor: font.fontDescriptor, size: floor(font.pointSize * room / line * 2) / 2) ?? font
    }

    static func lineHeight(_ font: NSFont) -> CGFloat { ceil(font.ascender - font.descender) }

    /// Symbol fonts (the font class says so, or they support no language) and families that
    /// lack a letter of their own name.
    static func isSymbolOrForeign(_ font: NSFont, family: String) -> (symbol: Bool, foreign: Bool) {
        let fontClass = font.fontDescriptor.symbolicTraits.rawValue >> 28
        let languages = CTFontCopySupportedLanguages(font as CTFont) as? [String] ?? []
        let symbol = fontClass == 12 || languages.isEmpty
        let covered = font.coveredCharacterSet
        let foreign = !family.unicodeScalars.filter { CharacterSet.letters.contains($0) }.allSatisfy { covered.contains($0) }
        return (symbol, foreign)
    }

    private init(measuring family: String) {
        self.family = family
        let size = RibbonTheme.fontListNameSize
        let own = NSFontManager.shared.font(withFamily: family, traits: [], weight: 5, size: size) ?? NSFont(name: family, size: size)
        let ui = NSFont.systemFont(ofSize: size)
        var nameFont = ui, sample: NSFont?
        if let own = own {
            let kind = FontListRow.isSymbolOrForeign(own, family: family)
            if kind.symbol {
                sample = FontListRow.fitted(own)
            } else if !kind.foreign {
                nameFont = FontListRow.fitted(own)
            }
        }
        self.nameFont = nameFont
        sampleFont = sample
        var width = RibbonTheme.fontListTextInset * 2 + ceil((family as NSString).size(withAttributes: [.font: nameFont]).width)
        if let sample = sample {
            width += RibbonTheme.fontListSampleGap + ceil((RibbonTheme.fontListSample as NSString).size(withAttributes: [.font: sample]).width)
        }
        self.width = width
    }
}

/// The drop-down list of the Font box, drawn like the ribbon menus: every family written in its
/// own font, with a scroll bar, the wheel, the arrows, Page Up/Down, Home/End and type-ahead.
/// Enter or a click picks the family; Esc (through the panel) closes the list.
final class FontListView: FlippedView, RibbonPopupContent {
    let families: [String]
    let selected: Int?
    let visibleRows: Int
    var onChoose: ((String) -> Void)?
    private(set) var topRow = 0 { didSet { if oldValue != topRow { needsDisplay = true } } }
    private(set) var highlighted: Int? { didSet { if oldValue != highlighted { needsDisplay = true } } }
    private var typed = ""
    private var lastTyped = Date.distantPast
    private var thumbGrab: CGFloat?
    private var rowElements: [FontListRowElement] = []

    var hasScrollBar: Bool { families.count > visibleRows }
    /// Width of the rows, without the scroll bar.
    let rowWidth: CGFloat

    init(families: [String], selected: String?, minimumWidth: CGFloat) {
        self.families = families
        self.selected = selected.flatMap { name in families.firstIndex { $0.caseInsensitiveCompare(name) == .orderedSame } }
        visibleRows = max(1, min(families.count, RibbonTheme.fontListVisibleRows))
        let widest = families.map { FontListRow.row(for: $0).width }.max() ?? 0
        let bar = families.count > visibleRows ? RibbonTheme.fontListScrollBarWidth : 0
        rowWidth = max(minimumWidth - 2 * RibbonTheme.dropdownPadding - bar, ceil(widest))
        super.init(frame: NSRect(x: 0, y: 0, width: rowWidth + bar + 2 * RibbonTheme.dropdownPadding,
                                 height: CGFloat(visibleRows) * RibbonTheme.fontListRowHeight + 2 * RibbonTheme.dropdownPadding))
        highlighted = self.selected
        if let index = self.selected { scrollToShow(index, centered: true) }
        setAccessibilityElement(true)
        setAccessibilityRole(.list)
        setAccessibilityIdentifier("text.fontFamily.list")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: Geometry

    var maxTopRow: Int { max(0, families.count - visibleRows) }

    func rowRect(_ index: Int) -> NSRect {
        let pad = RibbonTheme.dropdownPadding
        return NSRect(x: pad, y: pad + CGFloat(index - topRow) * RibbonTheme.fontListRowHeight,
                      width: rowWidth, height: RibbonTheme.fontListRowHeight)
    }

    func row(at point: NSPoint) -> Int? {
        let pad = RibbonTheme.dropdownPadding
        guard point.x >= pad, point.x < pad + rowWidth, point.y >= pad else { return nil }
        let index = topRow + Int(floor((point.y - pad) / RibbonTheme.fontListRowHeight))
        return index < min(families.count, topRow + visibleRows) ? index : nil
    }

    var scrollBarRect: NSRect {
        let pad = RibbonTheme.dropdownPadding
        return NSRect(x: pad + rowWidth, y: pad, width: RibbonTheme.fontListScrollBarWidth, height: bounds.height - 2 * pad)
    }

    var thumbRect: NSRect {
        let track = scrollBarRect.insetBy(dx: 2, dy: 2)
        let height = max(RibbonTheme.fontListThumbMinimum, track.height * CGFloat(visibleRows) / CGFloat(max(1, families.count)))
        let travel = track.height - height
        let y = track.minY + (maxTopRow == 0 ? 0 : travel * CGFloat(topRow) / CGFloat(maxTopRow))
        return NSRect(x: track.minX, y: y, width: track.width, height: height)
    }

    func scroll(to row: Int) { topRow = min(maxTopRow, max(0, row)) }

    /// Scrolls just enough for `index` to show, or puts it in the middle.
    func scrollToShow(_ index: Int, centered: Bool = false) {
        if centered {
            scroll(to: index - visibleRows / 2)
        } else if index < topRow {
            scroll(to: index)
        } else if index >= topRow + visibleRows {
            scroll(to: index - visibleRows + 1)
        }
    }

    /// Rows whose text needs more room than the row gives, for the "nothing is cut" check.
    func clippedRows() -> [String] {
        families.filter { family in
            let row = FontListRow.row(for: family)
            let fonts = [row.nameFont] + (row.sampleFont.map { [$0] } ?? [])
            let tall = fonts.contains { FontListRow.lineHeight($0) > RibbonTheme.fontListRowHeight - 2 * RibbonTheme.fontListTextMargin + 0.5 }
            return row.width > rowWidth || tall
        }
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        RibbonTheme.dropdownBackground.setFill()
        bounds.fill()
        let last = min(families.count, topRow + visibleRows)
        for index in topRow..<last {
            let rect = rowRect(index)
            guard rect.intersects(dirtyRect) else { continue }
            if index == highlighted {
                RibbonTheme.drawButton(rect.insetBy(dx: 1, dy: 0.5), index == selected ? .checkedHover : .hover, radius: 3)
            } else if index == selected {
                RibbonTheme.drawButton(rect.insetBy(dx: 1, dy: 0.5), .checked, radius: 3)
            }
            drawRow(index, in: rect)
        }
        guard hasScrollBar else { return }
        RibbonTheme.fontListTrack.setFill()
        scrollBarRect.fill()
        RibbonTheme.drawButton(thumbRect, thumbGrab != nil ? .pressed : .hover, radius: 2)
    }

    private func drawRow(_ index: Int, in rect: NSRect) {
        let row = FontListRow.row(for: families[index])
        let color = RibbonTheme.textColor
        var x = rect.minX + RibbonTheme.fontListTextInset
        func draw(_ text: String, _ font: NSFont) -> CGFloat {
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            // Baseline in the middle of the row for the font's own ascender and descender.
            let y = rect.minY + floor((rect.height - (font.ascender - font.descender)) / 2)
            (text as NSString).draw(with: NSRect(x: x, y: y, width: rect.maxX - x, height: font.ascender - font.descender + 2),
                                    options: [.usesLineFragmentOrigin], attributes: attributes)
            return ceil((text as NSString).size(withAttributes: attributes).width)
        }
        x += draw(row.family, row.nameFont)
        if let sample = row.sampleFont {
            x += RibbonTheme.fontListSampleGap
            _ = draw(RibbonTheme.fontListSample, sample)
        }
    }

    // MARK: Pointer

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    override func mouseMoved(with event: NSEvent) {
        if let index = row(at: convert(event.locationInWindow, from: nil)) { highlighted = index }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if hasScrollBar, scrollBarRect.contains(point) {
            let thumb = thumbRect
            if thumb.contains(point) {
                thumbGrab = point.y - thumb.minY
                needsDisplay = true
            } else {
                scroll(to: topRow + (point.y < thumb.minY ? -visibleRows : visibleRows))
            }
            return
        }
        if let index = row(at: point) { choose(index) }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let grab = thumbGrab else { return }
        let track = scrollBarRect.insetBy(dx: 2, dy: 2)
        let travel = track.height - thumbRect.height
        guard travel > 0 else { return }
        let y = convert(event.locationInWindow, from: nil).y - grab - track.minY
        scroll(to: Int((y / travel * CGFloat(maxTopRow)).rounded()))
    }

    override func mouseUp(with event: NSEvent) {
        thumbGrab = nil
        needsDisplay = true
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY / RibbonTheme.fontListRowHeight : event.scrollingDeltaY * 3
        guard delta != 0 else { return }
        scroll(to: topRow - Int(delta > 0 ? ceil(delta) : floor(delta)))
    }

    // MARK: Choosing

    func choose(_ index: Int) {
        guard families.indices.contains(index) else { return }
        onChoose?(families[index])
    }

    func moveHighlight(to index: Int) {
        guard !families.isEmpty else { return }
        let target = min(families.count - 1, max(0, index))
        highlighted = target
        scrollToShow(target)
    }

    /// Typing while the list is open lights the first family that starts with what was typed.
    func typeAhead(_ text: String, at time: Date = Date()) {
        if time.timeIntervalSince(lastTyped) > 1 { typed = "" }
        lastTyped = time
        typed += text
        let match = families.firstIndex { $0.range(of: typed, options: [.caseInsensitive, .anchored]) != nil }
        if let index = match { moveHighlight(to: index) }
    }

    func popupKeyDown(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return false }
        let current = highlighted ?? selected ?? -1
        switch event.keyCode {
        case 125: moveHighlight(to: current + 1)  // Down
        case 126: moveHighlight(to: highlighted == nil ? families.count - 1 : current - 1)  // Up
        case 121: moveHighlight(to: current + visibleRows - 1)  // Page Down
        case 116: moveHighlight(to: current - visibleRows + 1)  // Page Up
        case 115: moveHighlight(to: 0)  // Home
        case 119: moveHighlight(to: families.count - 1)  // End
        case 36, 76:  // Return, Enter
            if let index = highlighted { choose(index) }
        case 53, 48: return false  // Esc closes the panel; Tab goes on
        default:
            guard let characters = event.characters, !characters.isEmpty,
                  characters.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) && $0.value < 0xF700 }) else { return false }
            typeAhead(characters, at: Date(timeIntervalSinceReferenceDate: event.timestamp))
        }
        return true
    }

    func popupWillClose() {}

    // MARK: Accessibility

    override func accessibilityChildren() -> [Any]? {
        if rowElements.isEmpty {
            rowElements = families.indices.map { FontListRowElement(list: self, index: $0) }
        }
        return rowElements
    }

    override func accessibilityLabel() -> String? { L("text.fontFamily") }
}

/// A family of the Font list as seen by accessibility clients.
private final class FontListRowElement: NSAccessibilityElement {
    private weak var list: FontListView?
    private let index: Int

    init(list: FontListView, index: Int) {
        self.list = list
        self.index = index
        super.init()
        setAccessibilityParent(list)
        setAccessibilityRole(.cell)
        setAccessibilityLabel(list.families[index])
    }

    override func accessibilityFrame() -> NSRect {
        guard let list = list, let window = list.window else { return .zero }
        return window.convertToScreen(list.convert(list.rowRect(index), to: nil))
    }

    override func isAccessibilitySelected() -> Bool { list?.selected == index }

    override func accessibilityPerformPress() -> Bool {
        list?.choose(index)
        return true
    }
}
