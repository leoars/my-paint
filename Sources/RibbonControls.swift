import AppKit

/// Top-left origin, like the Windows layout the ribbon reproduces.
class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// Base of the ribbon's own controls: target and action, tag, hover and press tracking,
/// checked and disabled states, and an accessibility button for VoiceOver and the tests.
class RibbonControl: NSView {
    weak var target: AnyObject?
    var action: Selector?
    /// Runs instead of the action, for controls that only change the ribbon itself.
    var handler: ((RibbonControl) -> Void)?
    /// Fires on mouse down instead of mouse up, as drop-down buttons do.
    var actsOnPress = false
    var title: String { didSet { needsDisplay = true; toolTip = title.replacingOccurrences(of: "\n", with: " ") } }
    var isEnabled = true { didSet { if oldValue != isEnabled { isHovered = false; isPressed = false; needsDisplay = true } } }
    var isChecked = false { didSet { if oldValue != isChecked { needsDisplay = true } } }
    private(set) var isHovered = false
    var isPressed = false { didSet { if oldValue != isPressed { needsDisplay = true } } }
    /// Letters typed after Option (Alt) or F10 to reach the control (see `KeyTipController`).
    var keyTip: String?
    private var storedTag = 0
    override var tag: Int {
        get { storedTag }
        set { storedTag = newValue }
    }

    init(title: String) {
        self.title = title
        super.init(frame: .zero)
        toolTip = title.replacingOccurrences(of: "\n", with: " ")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    var look: RibbonTheme.Look {
        guard isEnabled else { return isChecked ? .checked : .normal }
        if isPressed { return .pressed }
        if isChecked { return isHovered ? .checkedHover : .checked }
        return isHovered ? .hover : .normal
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        guard isEnabled else { return }
        isHovered = true
        hover(at: convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    override func mouseMoved(with event: NSEvent) {
        guard isEnabled else { return }
        hover(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        hover(at: nil)
        needsDisplay = true
    }

    /// Pointer position inside the control, or nil when it leaves. For controls with parts.
    func hover(at point: NSPoint?) {}

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        if actsOnPress {
            isPressed = true
            activate(at: convert(event.locationInWindow, from: nil))
            isPressed = false
            return
        }
        isPressed = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEnabled, !actsOnPress else { return }
        isPressed = bounds.contains(convert(event.locationInWindow, from: nil))
    }

    override func mouseUp(with event: NSEvent) {
        guard isEnabled, !actsOnPress else { return }
        let point = convert(event.locationInWindow, from: nil)
        isPressed = false
        if bounds.contains(point) { activate(at: point) }
    }

    /// A click at `point`. Controls with several parts override this.
    func activate(at point: NSPoint) { perform() }

    /// Runs the handler, or closes the drop-down panel the control sits in and sends the action.
    func perform() {
        guard isEnabled else { return }
        if let handler = handler {
            handler(self)
        } else if let action = action {
            send(action)
        }
    }

    func send(_ action: Selector) {
        // The panel goes first, so a dialog the command opens is not covered by it.
        RibbonPopup.closeAfterCommand(from: self)
        NSApp.sendAction(action, to: target, from: self)
    }

    // MARK: Accessibility

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .button }
    override func accessibilityLabel() -> String? { title.replacingOccurrences(of: "\n", with: " ") }
    override func isAccessibilityEnabled() -> Bool { isEnabled }
    override func accessibilityValue() -> Any? { isChecked ? 1 : nil }
    override func accessibilityPerformPress() -> Bool {
        guard isEnabled else { return false }
        activate(at: NSPoint(x: bounds.midX, y: bounds.midY))
        return true
    }
}

/// A ribbon button: large (32 px icon over its label), small (16 px icon beside the label)
/// or icon only (the Tools group).
final class RibbonButton: RibbonControl {
    enum Style { case large, small, icon }

    let style: Style
    var icon: RibbonIcon?
    /// Shows the drop-down triangle.
    var hasDropdown: Bool
    /// Height of a large button; collapsed groups use the whole group height.
    var largeHeight = RibbonTheme.largeButtonHeight
    /// Split buttons (Paste, Select): the lower part, label and arrow, sends this instead of `action`.
    var menuAction: Selector?
    /// Whether the upper part of a split button works; the lower part stays usable.
    var isMainEnabled = true { didSet { if oldValue != isMainEnabled { needsDisplay = true } } }

    /// Where the lower part of a large split button starts.
    var splitY: CGFloat { 3 + RibbonTheme.largeIcon + 2 }

    enum SplitPart { case main, menu }
    var isSplit: Bool { menuAction != nil && style == .large }
    /// The part of a split button under the pointer, lit on its own as in the Windows 7 ribbon.
    private(set) var hoveredPart: SplitPart?

    override func hover(at point: NSPoint?) {
        let part = isSplit ? point.map { $0.y >= splitY ? SplitPart.menu : .main } : nil
        if part != hoveredPart {
            hoveredPart = part
            needsDisplay = true
        }
    }

    /// The upper (command) and lower (menu) rectangles of a split button.
    var splitRects: (main: NSRect, menu: NSRect) {
        (NSRect(x: 0, y: 0, width: bounds.width, height: splitY),
         NSRect(x: 0, y: splitY, width: bounds.width, height: bounds.height - splitY))
    }

    /// A split button under the pointer: the whole button framed, the part under the pointer
    /// lit (pressed while the mouse is down), the other left plain. False when not hovered.
    private func drawSplitBackground() -> Bool {
        guard isSplit, isEnabled, let part = hoveredPart, isHovered || isPressed else { return false }
        let rects = splitRects
        RibbonTheme.drawButton(bounds, isChecked ? .checked : .normal)
        RibbonTheme.drawButtonFrame(bounds)
        // The upper part does nothing while its command is unavailable, so it does not light up.
        if part == .menu || isMainEnabled {
            let lit: RibbonTheme.Look = isPressed ? .pressed : (isChecked ? .checkedHover : .hover)
            RibbonTheme.drawButton(part == .main ? rects.main : rects.menu, lit)
        }
        return true
    }

    override func activate(at point: NSPoint) {
        guard let menuAction = menuAction, style == .large else { return perform() }
        if point.y >= splitY {
            send(menuAction)
        } else if isMainEnabled {
            perform()
        }
    }

    /// Presses the lower part of a split button, for tests and accessibility clients.
    func pressMenuPart() { activate(at: NSPoint(x: bounds.midX, y: bounds.height - 4)) }

    init(_ style: Style, title: String, icon: RibbonIcon?, dropdown: Bool = false) {
        self.style = style
        self.icon = icon
        hasDropdown = dropdown
        super.init(title: title)
        frame.size = NSSize(width: preferredWidth, height: style == .large ? largeHeight : RibbonTheme.smallButtonHeight)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    var lines: [String] { title.components(separatedBy: "\n") }
    /// A two-line label with a drop-down has its triangle after the last line, as in the original.
    var inlineArrow: Bool { hasDropdown && style == .large && lines.count > 1 }
    static let inlineArrowWidth: CGFloat = 10

    var preferredWidth: CGFloat {
        switch style {
        case .large:
            var text = lines.map(RibbonTheme.textWidth).max() ?? 0
            if inlineArrow { text = max(text, RibbonTheme.textWidth(lines.last ?? "") + RibbonButton.inlineArrowWidth) }
            return max(RibbonTheme.largeButtonMinWidth, text + 10)
        case .small:
            return 3 + RibbonTheme.smallIcon + 4 + RibbonTheme.textWidth(title) + (hasDropdown ? 12 : 0) + 5
        case .icon:
            return RibbonTheme.iconButtonWidth
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        if !drawSplitBackground() { RibbonTheme.drawButton(bounds, look) }
        let attributes = RibbonTheme.attributes(isEnabled)
        switch style {
        case .large:
            let collapsedOffset: CGFloat = bounds.height > RibbonTheme.largeButtonHeight + 4 ? 8 : 0
            let iconRect = NSRect(x: floor((bounds.width - RibbonTheme.largeIcon) / 2), y: 3 + collapsedOffset,
                                  width: RibbonTheme.largeIcon, height: RibbonTheme.largeIcon)
            icon?.draw(in: iconRect, enabled: isEnabled && isMainEnabled)
            if isSplit, look == .hover || look == .checkedHover || (isPressed && hoveredPart != nil) {
                RibbonTheme.splitLine.setFill()
                NSRect(x: 2, y: splitY - 1, width: bounds.width - 4, height: 1).fill()
            }
            var y = iconRect.maxY + 2
            for (index, line) in lines.enumerated() {
                let width = RibbonTheme.textWidth(line)
                let last = index == lines.count - 1 && inlineArrow
                let x = floor((bounds.width - width - (last ? RibbonButton.inlineArrowWidth : 0)) / 2)
                (line as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attributes)
                if last { RibbonTheme.drawArrow(center: NSPoint(x: x + width + 6, y: y + 7), enabled: isEnabled) }
                y += 13
            }
            if hasDropdown, !inlineArrow { RibbonTheme.drawArrow(center: NSPoint(x: bounds.midX, y: y + 6), enabled: isEnabled) }
        case .small:
            icon?.draw(in: NSRect(x: 3, y: 3, width: 16, height: 16), enabled: isEnabled)
            let height = (title as NSString).size(withAttributes: attributes).height
            (title as NSString).draw(at: NSPoint(x: 23, y: floor((bounds.height - height) / 2)), withAttributes: attributes)
            if hasDropdown {
                RibbonTheme.drawArrow(center: NSPoint(x: 23 + RibbonTheme.textWidth(title) + 7, y: bounds.midY), enabled: isEnabled)
            }
        case .icon:
            let side = RibbonTheme.smallIcon
            icon?.draw(in: NSRect(x: floor((bounds.width - side) / 2), y: floor((bounds.height - side) / 2), width: side, height: side),
                       enabled: isEnabled)
        }
    }
}

/// A check box of the View tab (Rulers, Gridlines, Status bar).
final class RibbonCheckbox: RibbonControl {
    override init(title: String) {
        super.init(title: title)
        frame.size = NSSize(width: 22 + RibbonTheme.textWidth(title) + 4, height: RibbonTheme.smallButtonHeight)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func accessibilityRole() -> NSAccessibility.Role? { .checkBox }
    override func accessibilityValue() -> Any? { isChecked ? 1 : 0 }

    override func draw(_ dirtyRect: NSRect) {
        let box = NSRect(x: 3.5, y: floor((bounds.height - 13) / 2) + 0.5, width: 12, height: 12)
        let hovered = isEnabled && (isHovered || isPressed)
        RibbonTheme.fillVertical(box, top: hovered ? RibbonTheme.hoverTop : RibbonTheme.checkboxTop,
                                 bottom: hovered ? RibbonTheme.hoverBottom : RibbonTheme.checkboxBottom)
        (isEnabled ? (hovered ? RibbonTheme.pressedBorder : RibbonTheme.checkboxBorder) : RibbonTheme.disabledTextColor).setStroke()
        NSBezierPath(rect: box).stroke()
        if isChecked {
            let mark = NSBezierPath()
            mark.move(to: NSPoint(x: box.minX + 2.5, y: box.midY))
            mark.line(to: NSPoint(x: box.minX + 5, y: box.maxY - 3))
            mark.line(to: NSPoint(x: box.maxX - 2.5, y: box.minY + 2.5))
            mark.lineWidth = 1.8
            (isEnabled ? RibbonTheme.checkmark : RibbonTheme.disabledTextColor).setStroke()
            mark.stroke()
        }
        let attributes = RibbonTheme.attributes(isEnabled)
        let height = (title as NSString).size(withAttributes: attributes).height
        (title as NSString).draw(at: NSPoint(x: 21, y: floor((bounds.height - height) / 2)), withAttributes: attributes)
    }
}

/// The large Color 1 and Color 2 buttons: the current color over the label.
final class ColorWellButton: RibbonControl {
    var color = RGB.black { didSet { if oldValue != color { needsDisplay = true } } }
    private let swatchSide: CGFloat

    init(title: String, swatchSide: CGFloat) {
        self.swatchSide = swatchSide
        super.init(title: title)
        let text = title.components(separatedBy: "\n").map(RibbonTheme.textWidth).max() ?? 0
        frame.size = NSSize(width: max(RibbonTheme.largeButtonMinWidth, text + 10), height: RibbonTheme.largeButtonHeight)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func draw(_ dirtyRect: NSRect) {
        RibbonTheme.drawButton(bounds, look)
        let swatch = NSRect(x: floor((bounds.width - swatchSide) / 2), y: 3 + floor((RibbonTheme.largeIcon - swatchSide) / 2),
                            width: swatchSide, height: swatchSide)
        RibbonTheme.rgb(0x5B5B5B).setFill()
        swatch.fill()
        NSColor.white.setFill()
        swatch.insetBy(dx: 1, dy: 1).fill()
        color.nsColor.setFill()
        swatch.insetBy(dx: 2, dy: 2).fill()
        var y = 3 + RibbonTheme.largeIcon + 2
        let attributes = RibbonTheme.attributes(isEnabled)
        for line in title.components(separatedBy: "\n") {
            let width = RibbonTheme.textWidth(line)
            (line as NSString).draw(at: NSPoint(x: floor((bounds.width - width) / 2), y: y), withAttributes: attributes)
            y += 13
        }
    }
}

extension RGB {
    var nsColor: NSColor { NSColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1) }
}

/// The 20 standard colors in two rows of ten and a third row of ten custom places.
/// A click on a color sends the action with the palette index as the tag.
final class PaletteView: RibbonControl {
    static let columns = 10
    static let rows = 3
    /// Side of one cell, with its gap. A conferir com o original.
    static let cell: CGFloat = 21

    /// 30 places; nil means an empty custom place.
    var colors: [RGB?] { didSet { cellElements = []; needsDisplay = true } }
    /// Empty custom places are drawn as empty frames; black-and-white mode draws nothing there.
    var showsEmptyPlaces = true { didSet { needsDisplay = true } }
    private var hovered: Int?

    init(title: String, colors: [RGB?]) {
        self.colors = colors
        super.init(title: title)
        frame.size = NSSize(width: CGFloat(PaletteView.columns) * PaletteView.cell, height: CGFloat(PaletteView.rows) * PaletteView.cell)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Color names for the accessibility children, one per place.
    var colorNames: [String] = []
    private var cellElements: [PaletteCellElement] = []

    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityPerformPress() -> Bool { false }

    /// One button per color, so VoiceOver (and the tests) can press a single swatch.
    override func accessibilityChildren() -> [Any]? {
        if cellElements.isEmpty {
            cellElements = colors.indices.compactMap { index in
                guard colors[index] != nil else { return nil }
                return PaletteCellElement(palette: self, index: index,
                                          label: colorNames.indices.contains(index) ? colorNames[index] : "\(index + 1)")
            }
        }
        return cellElements
    }

    /// Picks the color at `index`, as a click on it would.
    func press(_ index: Int) {
        guard isEnabled, colors.indices.contains(index), colors[index] != nil else { return }
        tag = index
        perform()
    }

    func index(at point: NSPoint) -> Int? {
        let column = Int(floor(point.x / PaletteView.cell)), row = Int(floor(point.y / PaletteView.cell))
        guard (0..<PaletteView.columns).contains(column), (0..<PaletteView.rows).contains(row) else { return nil }
        return row * PaletteView.columns + column
    }

    func cellRect(_ index: Int) -> NSRect {
        NSRect(x: CGFloat(index % PaletteView.columns) * PaletteView.cell, y: CGFloat(index / PaletteView.columns) * PaletteView.cell,
               width: PaletteView.cell, height: PaletteView.cell)
    }

    override func hover(at point: NSPoint?) {
        let index = point.flatMap(index(at:))
        let next = index.flatMap { colors.indices.contains($0) && colors[$0] != nil ? $0 : nil }
        if next != hovered { hovered = next; needsDisplay = true }
    }

    override func activate(at point: NSPoint) {
        guard let index = index(at: point) else { return }
        press(index)
    }

    override func draw(_ dirtyRect: NSRect) {
        for index in 0..<(PaletteView.columns * PaletteView.rows) {
            let cell = cellRect(index)
            let box = cell.insetBy(dx: 2, dy: 2)
            if index == hovered { RibbonTheme.drawButton(cell.insetBy(dx: 0.5, dy: 0.5), .hover, radius: 1.5) }
            if let color = colors.indices.contains(index) ? colors[index] : nil {
                RibbonTheme.swatchBorder.setFill()
                box.fill()
                NSColor.white.setFill()
                box.insetBy(dx: 1, dy: 1).fill()
                color.nsColor.setFill()
                box.insetBy(dx: 2, dy: 2).fill()
            } else if showsEmptyPlaces {
                RibbonTheme.customSwatchBorder.setFill()
                box.fill()
                NSColor.white.setFill()
                box.insetBy(dx: 1, dy: 1).fill()
            }
        }
    }
}

/// A swatch of the palette as seen by accessibility clients.
private final class PaletteCellElement: NSAccessibilityElement {
    private weak var palette: PaletteView?
    private let index: Int

    init(palette: PaletteView, index: Int, label: String) {
        self.palette = palette
        self.index = index
        super.init()
        setAccessibilityRole(.button)
        setAccessibilityLabel(label)
        setAccessibilityParent(palette)
    }

    override func accessibilityFrame() -> NSRect {
        guard let palette = palette, let window = palette.window else { return .zero }
        return window.convertToScreen(palette.convert(palette.cellRect(index), to: nil))
    }

    override func accessibilityPerformPress() -> Bool {
        palette?.press(index)
        return palette != nil
    }
}

/// The Shapes gallery: three rows of seven thumbnails and, on the right, buttons to scroll a row
/// up or down and to open every shape at once. A click on a shape sends the action with the
/// shape as the tag; the chosen shape shows checked. When the ribbon runs short of room the
/// gallery shows fewer columns (and so more rows to scroll) before its group collapses.
final class ShapeGalleryView: RibbonControl {
    static let cell: CGFloat = 20
    static let scrollWidth: CGFloat = 14
    /// Rows needed to hold every shape in `columns` columns.
    static func totalRows(columns: Int) -> Int { (GalleryShape.allCases.count + columns - 1) / columns }

    /// Columns shown; changing them resizes the gallery and keeps the chosen shape in sight.
    var columns: Int {
        didSet {
            guard oldValue != columns else { return }
            frame.size.width = galleryWidth + (scrolls ? ShapeGalleryView.scrollWidth : 0)
            firstRow = min(firstRow, lastFirstRow)
            if let shape = selected { scrollTo(shape) }
            hovered = nil
            needsDisplay = true
        }
    }
    var totalRows: Int { ShapeGalleryView.totalRows(columns: columns) }
    /// Rows shown at once; the drop-down copy shows them all and has no scroll buttons.
    let visibleRows: Int
    let scrolls: Bool
    /// First row shown.
    private(set) var firstRow = 0 { didSet { if oldValue != firstRow { needsDisplay = true } } }
    var selected: GalleryShape? {
        didSet {
            guard oldValue != selected else { return }
            if let shape = selected { scrollTo(shape) }
            needsDisplay = true
        }
    }
    /// Shape names for accessibility, one per shape.
    var shapeNames: [String] = []
    private var hovered: Int?
    private var cellElements: [GalleryCellElement] = []
    /// Labels of the scroll up, scroll down and "more" buttons, for accessibility.
    var scrollNames: [String] = []

    init(title: String, columns: Int = RibbonTheme.shapeGalleryColumns, rows: Int = 3, scrolls: Bool = true) {
        self.columns = columns
        visibleRows = rows
        self.scrolls = scrolls
        super.init(title: title)
        frame.size = NSSize(width: galleryWidth + (scrolls ? ShapeGalleryView.scrollWidth : 0),
                            height: CGFloat(rows) * ShapeGalleryView.cell + 2)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private var galleryWidth: CGFloat { CGFloat(columns) * ShapeGalleryView.cell + 2 }
    var lastFirstRow: Int { max(0, totalRows - visibleRows) }

    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityPerformPress() -> Bool { false }

    /// One button per shape, then the scroll and "more" buttons, so VoiceOver (and the tests) can press each.
    override func accessibilityChildren() -> [Any]? {
        if cellElements.isEmpty {
            cellElements = GalleryShape.allCases.map { shape in
                GalleryCellElement(gallery: self, index: shape.rawValue,
                                   label: shapeNames.indices.contains(shape.rawValue) ? shapeNames[shape.rawValue] : "\(shape)")
            }
            if scrolls {
                for part in 0..<3 {
                    cellElements.append(GalleryCellElement(gallery: self, index: -1 - part,
                                                           label: scrollNames.indices.contains(part) ? scrollNames[part] : "\(part)"))
                }
            }
        }
        return cellElements
    }

    /// The scroll up, scroll down and "more" buttons, top to bottom.
    func scrollPartRect(_ part: Int) -> NSRect {
        let third = bounds.height / 3
        return NSRect(x: galleryWidth - 1, y: CGFloat(part) * third, width: ShapeGalleryView.scrollWidth + 1, height: third)
    }

    func pressScrollPart(_ part: Int) {
        guard isEnabled else { return }
        switch part {
        case 0: scroll(-1)
        case 1: scroll(1)
        default: openAll()
        }
    }

    /// Picks the shape at `index`, as a click on it would.
    func press(_ index: Int) {
        guard isEnabled, GalleryShape(rawValue: index) != nil else { return }
        tag = index
        perform()
    }

    /// Scrolls one row up (-1) or down (+1).
    func scroll(_ rows: Int) {
        firstRow = max(0, min(lastFirstRow, firstRow + rows))
    }

    private func scrollTo(_ shape: GalleryShape) {
        let row = shape.rawValue / columns
        if row < firstRow { firstRow = row } else if row >= firstRow + visibleRows { firstRow = row - visibleRows + 1 }
    }

    /// The shape under `point`, among the rows shown.
    func index(at point: NSPoint) -> Int? {
        let column = Int(floor((point.x - 1) / ShapeGalleryView.cell)), row = Int(floor((point.y - 1) / ShapeGalleryView.cell))
        guard (0..<columns).contains(column), (0..<visibleRows).contains(row) else { return nil }
        let index = (row + firstRow) * columns + column
        return GalleryShape(rawValue: index) == nil ? nil : index
    }

    /// Where the shape at `index` is drawn, or nil when its row is scrolled away.
    func cellRect(_ index: Int) -> NSRect? {
        let row = index / columns - firstRow
        guard (0..<visibleRows).contains(row) else { return nil }
        return NSRect(x: 1 + CGFloat(index % columns) * ShapeGalleryView.cell,
                      y: 1 + CGFloat(row) * ShapeGalleryView.cell, width: ShapeGalleryView.cell, height: ShapeGalleryView.cell)
    }

    override func hover(at point: NSPoint?) {
        let next = point.flatMap(index(at:))
        if next != hovered { hovered = next; needsDisplay = true }
    }

    override func activate(at point: NSPoint) {
        if let index = index(at: point) { return press(index) }
        guard scrolls, point.x >= galleryWidth - 1 else { return }
        pressScrollPart(min(2, Int(point.y / (bounds.height / 3))))
    }

    /// The third button: every shape in a panel over the gallery, as the original drops it down,
    /// always in the full number of columns, however narrow the gallery is.
    func openAll() {
        let full = RibbonTheme.shapeGalleryColumns
        let all = ShapeGalleryView(title: title, columns: full, rows: ShapeGalleryView.totalRows(columns: full), scrolls: false)
        all.target = target
        all.action = action
        all.shapeNames = shapeNames
        all.selected = selected
        RibbonPopup.show(all, from: self, at: NSPoint(x: 0, y: 0))
    }

    override func draw(_ dirtyRect: NSRect) {
        let box = NSRect(x: 0.5, y: 0.5, width: galleryWidth - 1, height: bounds.height - 1)
        NSColor.white.setFill()
        box.fill()
        RibbonTheme.separatorDark.setStroke()
        NSBezierPath(rect: box).stroke()
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let painter = IconPainter(context: context, enabled: isEnabled)
        for shape in GalleryShape.allCases {
            guard let cell = cellRect(shape.rawValue) else { continue }
            if shape == selected {
                RibbonTheme.drawButton(cell, isEnabled ? .checked : .normal, radius: 1.5)
            } else if shape.rawValue == hovered, isEnabled {
                RibbonTheme.drawButton(cell, .hover, radius: 1.5)
            }
            context.saveGState()
            context.translateBy(x: cell.minX + 2, y: cell.minY + 2)
            shape.draw(painter)
            context.restoreGState()
        }
        guard scrolls else { return }
        // Scroll up, scroll down and "more", stacked.
        let scroll = NSRect(x: galleryWidth - 1, y: 0, width: ShapeGalleryView.scrollWidth + 1, height: bounds.height)
        let third = scroll.height / 3
        for part in 0..<3 {
            let rect = NSRect(x: scroll.minX + 0.5, y: scroll.minY + CGFloat(part) * third + 0.5, width: scroll.width - 1, height: third - 1)
            RibbonTheme.fillVertical(rect, top: RibbonTheme.bodyTop, bottom: RibbonTheme.bodyBottom)
            RibbonTheme.separatorDark.setStroke()
            NSBezierPath(rect: rect).stroke()
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let enabled = isEnabled && (part == 0 ? firstRow > 0 : part == 1 ? firstRow < lastFirstRow : true)
            let color = enabled ? RibbonTheme.rgb(0x2C3E55) : RibbonTheme.disabledTextColor
            if part == 0 {
                let path = NSBezierPath()
                path.move(to: NSPoint(x: center.x - 3, y: center.y + 1.5))
                path.line(to: NSPoint(x: center.x + 3, y: center.y + 1.5))
                path.line(to: NSPoint(x: center.x, y: center.y - 1.5))
                path.close()
                color.setFill()
                path.fill()
            } else {
                RibbonTheme.drawArrow(center: center, enabled: enabled)
                if part == 2 {
                    color.setFill()
                    NSRect(x: center.x - 3, y: center.y - 4, width: 6, height: 1).fill()
                }
            }
        }
    }
}

/// A shape of the gallery, or one of its scroll buttons (negative index), as seen by accessibility clients.
private final class GalleryCellElement: NSAccessibilityElement {
    private weak var gallery: ShapeGalleryView?
    private let index: Int

    init(gallery: ShapeGalleryView, index: Int, label: String) {
        self.gallery = gallery
        self.index = index
        super.init()
        setAccessibilityRole(.button)
        setAccessibilityLabel(label)
        setAccessibilityParent(gallery)
    }

    override func accessibilityFrame() -> NSRect {
        guard let gallery = gallery, let window = gallery.window else { return .zero }
        guard let cell = index < 0 ? gallery.scrollPartRect(-1 - index) : gallery.cellRect(index) else { return .zero }
        return window.convertToScreen(gallery.convert(cell, to: nil))
    }

    override func accessibilityPerformPress() -> Bool {
        if index < 0 { gallery?.pressScrollPart(-1 - index) } else { gallery?.press(index) }
        return gallery != nil
    }
}

/// One ribbon group: its controls over its name, with a separator on the right.
/// When the ribbon runs out of room the group shows a single drop-down button that
/// opens the controls in a panel, as the Windows 7 ribbon does.
final class RibbonGroupView: FlippedView {
    let title: String
    let content: FlippedView
    let collapsedButton: RibbonButton
    /// Key tip of the collapsed button.
    var keyTip: String? {
        get { collapsedButton.keyTip }
        set { collapsedButton.keyTip = newValue }
    }
    var isCollapsed = false {
        didSet { if oldValue != isCollapsed { arrange() } }
    }

    init(title: String, icon: RibbonIcon, content: FlippedView) {
        self.title = title
        self.content = content
        collapsedButton = RibbonButton(.large, title: title, icon: icon, dropdown: true)
        super.init(frame: .zero)
        collapsedButton.largeHeight = RibbonTheme.groupContentHeight + RibbonTheme.groupLabelHeight - 2
        collapsedButton.actsOnPress = true
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(title)
        arrange()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Width with every control shown, separator included.
    var expandedWidth: CGFloat {
        max(content.frame.width, RibbonTheme.textWidth(title) + 4) + 2 * RibbonTheme.groupPadding + 2
    }

    var collapsedWidth: CGFloat { collapsedButton.preferredWidth + 2 * RibbonTheme.groupPadding + 2 }
    var width: CGFloat { isCollapsed ? collapsedWidth : expandedWidth }

    /// A gallery of the content that loses columns before the group collapses (Shapes), and the
    /// column counts it goes through, widest first. Controls right of the gallery move with it.
    private(set) weak var gallery: ShapeGalleryView?
    private(set) var galleryColumns: [Int] = []

    func setShrinkingGallery(_ gallery: ShapeGalleryView, columns: [Int]) {
        self.gallery = gallery
        galleryColumns = columns
        setGalleryColumns(columns.first ?? gallery.columns)
    }

    /// Expanded width with the gallery in `columns` columns.
    func expandedWidth(columns: Int) -> CGFloat {
        guard let gallery = gallery else { return expandedWidth }
        let content = self.content.frame.width + CGFloat(columns - gallery.columns) * ShapeGalleryView.cell
        return max(content, RibbonTheme.textWidth(title) + 4) + 2 * RibbonTheme.groupPadding + 2
    }

    /// Widths of the group's forms, widest first: expanded (once per gallery column count), then collapsed.
    var formWidths: [CGFloat] {
        (galleryColumns.isEmpty ? [expandedWidth] : galleryColumns.map(expandedWidth(columns:))) + [collapsedWidth]
    }

    /// Width with every control shown at its largest.
    var fullWidth: CGFloat { formWidths[0] }

    /// Index into `formWidths` of what the group shows now.
    var form: Int {
        get { isCollapsed ? formWidths.count - 1 : galleryColumns.firstIndex(of: gallery?.columns ?? 0) ?? 0 }
        set {
            let last = formWidths.count - 1
            if newValue >= last {
                // The panel of a collapsed group shows the gallery at its largest.
                if let full = galleryColumns.first { setGalleryColumns(full) }
                isCollapsed = true
            } else {
                isCollapsed = false
                if galleryColumns.indices.contains(newValue) { setGalleryColumns(galleryColumns[newValue]) }
            }
        }
    }

    private func setGalleryColumns(_ columns: Int) {
        guard let gallery = gallery, columns != gallery.columns else { return }
        let delta = CGFloat(columns - gallery.columns) * ShapeGalleryView.cell
        let edge = gallery.frame.maxX
        gallery.columns = columns
        for view in content.subviews where view !== gallery && view.frame.minX >= edge - 0.5 { view.frame.origin.x += delta }
        content.frame.size.width += delta
        if !isCollapsed { arrange() }
    }

    /// Puts the controls back after the drop-down panel closes.
    func arrange() {
        let height = RibbonTheme.groupContentHeight + RibbonTheme.groupLabelHeight
        frame.size = NSSize(width: width, height: height)
        if isCollapsed {
            content.removeFromSuperview()
            collapsedButton.frame = NSRect(x: RibbonTheme.groupPadding, y: 0, width: collapsedButton.preferredWidth,
                                           height: collapsedButton.largeHeight)
            if collapsedButton.superview !== self { addSubview(collapsedButton) }
        } else {
            collapsedButton.removeFromSuperview()
            content.frame.origin = NSPoint(x: floor((width - 2 - content.frame.width) / 2), y: 0)
            if content.superview !== self { addSubview(content) }
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let x = bounds.width - 1.5
        RibbonTheme.separatorDark.setStroke()
        let line = NSBezierPath()
        line.move(to: NSPoint(x: x, y: 1))
        line.line(to: NSPoint(x: x, y: bounds.height - 1))
        line.stroke()
        RibbonTheme.separatorLight.setStroke()
        let light = NSBezierPath()
        light.move(to: NSPoint(x: x + 1, y: 1))
        light.line(to: NSPoint(x: x + 1, y: bounds.height - 1))
        light.stroke()
        guard !isCollapsed else { return }
        RibbonGroupView.drawLabel(title, width: bounds.width - 2, top: RibbonTheme.groupContentHeight)
    }

    static func drawLabel(_ title: String, width: CGFloat, top: CGFloat) {
        let attributes = RibbonTheme.attributes(color: RibbonTheme.groupLabelColor)
        let size = (title as NSString).size(withAttributes: attributes)
        (title as NSString).draw(at: NSPoint(x: floor((width - size.width) / 2), y: top + floor((RibbonTheme.groupLabelHeight - size.height) / 2)),
                                 withAttributes: attributes)
    }
}

/// Background of a collapsed group's panel: the ribbon gradient with the group name below.
final class GroupPanelView: FlippedView {
    let title: String

    init(title: String, content: NSView) {
        self.title = title
        let width = max(content.frame.width, RibbonTheme.textWidth(title) + 4) + 2 * RibbonTheme.groupPadding
        super.init(frame: NSRect(x: 0, y: 0, width: width,
                                 height: RibbonTheme.groupTop + RibbonTheme.groupContentHeight + RibbonTheme.groupLabelHeight + 3))
        content.frame.origin = NSPoint(x: floor((width - content.frame.width) / 2), y: RibbonTheme.groupTop)
        addSubview(content)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func draw(_ dirtyRect: NSRect) {
        RibbonTheme.fillVertical(bounds, top: RibbonTheme.bodyTop, bottom: RibbonTheme.bodyBottom)
        RibbonGroupView.drawLabel(title, width: bounds.width, top: RibbonTheme.groupTop + RibbonTheme.groupContentHeight)
    }
}

/// Content of a panel that takes keys while it is open and hears when it closes (the drawn menus).
protocol RibbonPopupContent: AnyObject {
    /// A key pressed while the panel is open; true when it was used.
    func popupKeyDown(_ event: NSEvent) -> Bool
    func popupWillClose()
}

/// The panel of a `RibbonPopup`; it remembers the window it belongs to, so a control inside a
/// closed panel (a collapsed group) can still open another one over the same window.
final class RibbonPopupPanel: NSPanel {
    weak var host: NSWindow?
}

/// A borderless panel under a ribbon control (collapsed groups, the application menu, the drawn
/// drop-down menus). It closes on a click outside, on Esc, when the app loses focus and after a command.
final class RibbonPopup: NSObject {
    private(set) static var current: RibbonPopup?

    let panel: RibbonPopupPanel
    let content: NSView
    private weak var anchor: NSView?
    private var monitor: Any?
    private var observer: NSObjectProtocol?
    private let onClose: () -> Void
    /// Clicks outside the panel that should reach the window and leave it open (the tabs under
    /// the body of a minimized ribbon).
    var passesClick: ((NSEvent) -> Bool)?

    /// Shows `view` with its top-left corner at `topLeft`, in the coordinates of `anchor`.
    @discardableResult
    static func show(_ view: NSView, from anchor: NSView, at topLeft: NSPoint, onClose: @escaping () -> Void = {}) -> RibbonPopup? {
        current?.close()
        guard let window = anchor.window else { return nil }
        let host = (window as? RibbonPopupPanel)?.host ?? window
        let popup = RibbonPopup(view: view, anchor: anchor, onClose: onClose)
        popup.panel.host = host
        let inWindow = anchor.convert(topLeft, to: nil)
        let screenPoint = window.convertPoint(toScreen: inWindow)
        popup.panel.setFrameTopLeftPoint(screenPoint)
        popup.panel.setFrameOrigin(fitted(popup.panel.frame, in: host).origin)
        host.addChildWindow(popup.panel, ordered: .above)
        popup.panel.orderFront(nil)
        current = popup
        return popup
    }

    /// Keeps a panel inside the window and the screen, shifting it left when needed, and above
    /// the bottom of the screen, shifting it up.
    static func fitted(_ rect: NSRect, in window: NSWindow) -> NSRect {
        var frame = rect
        let limit = min(window.frame.maxX, window.screen?.visibleFrame.maxX ?? .greatestFiniteMagnitude)
        if frame.maxX > limit { frame.origin.x = max(window.frame.minX, limit - frame.width) }
        if let visible = window.screen?.visibleFrame, frame.minY < visible.minY {
            frame.origin.y = min(visible.minY, visible.maxY - frame.height)
        }
        return frame
    }

    /// A borderless panel holding `view` in a frame, drawn at the interface text size like the
    /// ribbon it drops from.
    static func makePanel(for view: NSView) -> RibbonPopupPanel {
        let logical = NSSize(width: view.frame.width + 2, height: view.frame.height + 2)
        let scale = RibbonTheme.scale
        let size = NSSize(width: ceil(logical.width * scale), height: ceil(logical.height * scale))
        let panel = RibbonPopupPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel],
                                     backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.hasShadow = true
        panel.level = .popUpMenu
        let frame = PopupFrameView(frame: NSRect(origin: .zero, size: size))
        frame.bounds = NSRect(origin: .zero, size: logical)
        view.frame.origin = NSPoint(x: 1, y: 1)
        frame.addSubview(view)
        panel.contentView = frame
        return panel
    }

    private init(view: NSView, anchor: NSView, onClose: @escaping () -> Void) {
        self.anchor = anchor
        self.onClose = onClose
        content = view
        panel = RibbonPopup.makePanel(for: view)
        super.init()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]) { [weak self] event in
            guard let self = self else { return event }
            if event.type == .keyDown { return self.handleKey(event) ? nil : event }
            if let window = event.window, self.owns(window) { return event }
            if self.passesClick?(event) == true { return event }
            // A click outside closes the panel and is used up, as with Windows menus.
            self.close()
            return nil
        }
        observer = NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: nil) { [weak self] _ in
            self?.close()
        }
    }

    var isOpen: Bool { RibbonPopup.current === self }

    /// The panel itself or a panel opened from it (a submenu).
    func owns(_ window: NSWindow) -> Bool {
        func contains(_ parent: NSWindow) -> Bool {
            parent === window || (parent.childWindows ?? []).contains(where: contains)
        }
        return contains(panel)
    }

    /// A key while the panel is open: the content gets it first (a menu moves its highlight),
    /// then Esc closes the panel. Other keys go on to the window. True when the key was used.
    @discardableResult
    func handleKey(_ event: NSEvent) -> Bool {
        if let content = content as? RibbonPopupContent, content.popupKeyDown(event) { return true }
        guard event.keyCode == 53 else { return false }  // Esc
        close()
        return true
    }

    func close() {
        guard RibbonPopup.current === self else { return }
        RibbonPopup.current = nil
        (content as? RibbonPopupContent)?.popupWillClose()
        if let monitor = monitor { NSEvent.removeMonitor(monitor) }
        if let observer = observer { NotificationCenter.default.removeObserver(observer) }
        monitor = nil
        observer = nil
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
        onClose()
    }

    /// Commands chosen inside a panel (or a submenu of it) close it, as in the original.
    static func closeAfterCommand(from control: NSView) {
        guard let popup = current, let window = control.window, popup.owns(window) else { return }
        popup.close()
    }
}

private final class PopupFrameView: FlippedView {
    override func draw(_ dirtyRect: NSRect) {
        RibbonTheme.popupBackground.setFill()
        bounds.fill()
        RibbonTheme.popupBorder.setStroke()
        NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5)).stroke()
    }
}
