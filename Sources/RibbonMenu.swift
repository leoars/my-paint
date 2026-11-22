import AppKit

/// One line of a drawn drop-down menu: a command, a section header or a separator.
struct RibbonMenuEntry {
    enum Kind { case command, header, separator }

    var kind = Kind.command
    var title = ""
    var image: NSImage?
    var action: Selector?
    weak var target: AnyObject?
    var tag = 0
    var isEnabled = true
    var isChecked = false
    /// Size menu: the thickness the line sample shows, in pixels of the tool.
    var lineWidth: Int?
    /// Entries of the submenu that opens beside this one (Rotate in the context menu).
    var submenu: [RibbonMenuEntry] = []

    var hasSubmenu: Bool { !submenu.isEmpty }
    /// Whether the keyboard highlight stops here.
    var isSelectable: Bool { kind == .command && isEnabled }

    /// Marks the disabled title items of the menu bar that the drawn menus show as headers.
    static let headerIdentifier = NSUserInterfaceItemIdentifier("ribbonMenu.header")

    /// The drawn entries of the items that also fill the menu bar. `validate` gives each
    /// command its enabled and checked state, the same `validateMenuItem` the menu bar uses.
    static func entries(_ items: [NSMenuItem], validate: (NSMenuItem) -> Bool) -> [RibbonMenuEntry] {
        items.map { item in
            if item.isSeparatorItem { return RibbonMenuEntry(kind: .separator) }
            if item.identifier == headerIdentifier { return RibbonMenuEntry(kind: .header, title: item.title) }
            var entry = RibbonMenuEntry(title: item.title, image: item.image, action: item.action, target: item.target, tag: item.tag)
            if let submenu = item.submenu {
                entry.submenu = entries(submenu.items, validate: validate)
            } else if item.action != nil {
                entry.isEnabled = validate(item)
                entry.isChecked = item.state == .on
            } else {
                entry.isEnabled = item.isEnabled
            }
            return entry
        }
    }
}

/// A drop-down menu drawn like the Windows 7 ribbon menus, shown in a `RibbonPopup`: a list with
/// icons and text, the Size lines, or the gallery of brushes. The highlight follows the pointer
/// and the arrow keys; Enter or a click runs the command and closes the panel.
final class RibbonMenuView: FlippedView, RibbonPopupContent {
    enum Style: Equatable {
        case list
        /// The Size drop-down: one line of each thickness.
        case sizes
        /// Large icons in a grid (Brushes).
        case gallery(columns: Int)
    }

    let style: Style
    let entries: [RibbonMenuEntry]
    /// Prefix of the items' accessibility identifiers ("menu.size.0"…).
    let name: String
    private(set) var items: [RibbonMenuItemView] = []
    /// The entry under the pointer or chosen with the arrows.
    private(set) var highlighted: Int? {
        didSet { if oldValue != highlighted { items.forEach { $0.needsDisplay = true } } }
    }
    /// The open submenu and the entry it belongs to.
    private(set) var submenu: RibbonMenuView?
    private(set) var submenuIndex: Int?
    private var submenuPanel: NSPanel?
    private(set) weak var parentMenu: RibbonMenuView?

    init(entries: [RibbonMenuEntry], style: Style = .list, name: String) {
        self.entries = entries
        self.style = style
        self.name = name
        super.init(frame: .zero)
        layoutItems()
        setAccessibilityElement(true)
        setAccessibilityRole(.menu)
        setAccessibilityIdentifier(name)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: Layout

    /// The width a list needs for its longest text, its icons and the submenu triangle.
    static func listWidth(_ entries: [RibbonMenuEntry]) -> CGFloat {
        let widest = entries.map { entry -> CGFloat in
            switch entry.kind {
            case .separator: return 0
            case .header: return headerTextWidth(entry.title) + 2 * RibbonTheme.dropdownTextGap
            case .command:
                if entry.lineWidth != nil { return RibbonTheme.sizeSampleWidth }
                return RibbonTheme.dropdownGutterWidth + RibbonTheme.dropdownTextGap + RibbonTheme.textWidth(entry.title)
                    + RibbonTheme.dropdownTrailing
            }
        }.max() ?? 0
        return max(RibbonTheme.dropdownMinWidth, ceil(widest))
    }

    static func headerTextWidth(_ text: String) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: RibbonTheme.dropdownHeaderFont]).width)
    }

    /// Thickness of the line drawn for a size, scaled down when the largest would not fit.
    func sampleThickness(_ size: Int) -> CGFloat {
        let largest = CGFloat(entries.compactMap(\.lineWidth).max() ?? 1)
        let limit = RibbonTheme.sizeSampleMaxThickness
        return largest <= limit ? CGFloat(size) : max(1, round(CGFloat(size) * limit / largest))
    }

    private func height(of entry: RibbonMenuEntry) -> CGFloat {
        switch entry.kind {
        case .separator: return RibbonTheme.dropdownSeparatorHeight
        case .header: return RibbonTheme.dropdownHeaderHeight
        case .command:
            guard let size = entry.lineWidth else { return RibbonTheme.dropdownItemHeight }
            return max(RibbonTheme.sizeSampleMinHeight, sampleThickness(size) + 12)
        }
    }

    private func layoutItems() {
        let pad = RibbonTheme.dropdownPadding
        var frames: [NSRect] = []
        var size = NSSize.zero
        switch style {
        case .gallery(let columns):
            let cell = RibbonTheme.brushGalleryCell
            for index in entries.indices {
                frames.append(NSRect(x: pad + CGFloat(index % columns) * cell, y: pad + CGFloat(index / columns) * cell, width: cell, height: cell))
            }
            let rows = (entries.count + columns - 1) / columns
            size = NSSize(width: 2 * pad + CGFloat(min(columns, entries.count)) * cell, height: 2 * pad + CGFloat(rows) * cell)
        case .list, .sizes:
            let width = RibbonMenuView.listWidth(entries)
            var y = pad
            for entry in entries {
                let rowHeight = height(of: entry)
                frames.append(NSRect(x: pad, y: y, width: width, height: rowHeight))
                y += rowHeight
            }
            size = NSSize(width: width + 2 * pad, height: y + pad)
        }
        frame.size = size
        for (index, entry) in entries.enumerated() {
            let item = RibbonMenuItemView(entry: entry, index: index, menu: self)
            item.frame = frames[index]
            addSubview(item)
            items.append(item)
        }
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        RibbonTheme.dropdownBackground.setFill()
        bounds.fill()
        guard style == .list else { return }
        let gutter = NSRect(x: RibbonTheme.dropdownPadding, y: 0, width: RibbonTheme.dropdownGutterWidth, height: bounds.height)
        RibbonTheme.dropdownGutter.setFill()
        gutter.fill()
        RibbonTheme.dropdownGutterLine.setFill()
        NSRect(x: gutter.maxX, y: 0, width: 1, height: bounds.height).fill()
        NSColor.white.setFill()
        NSRect(x: gutter.maxX + 1, y: 0, width: 1, height: bounds.height).fill()
    }

    // MARK: Highlight

    var selectableIndices: [Int] { entries.indices.filter { entries[$0].isSelectable } }

    func hoverItem(_ index: Int) {
        highlighted = index
        if entries[index].hasSubmenu {
            openSubmenu(index, highlightFirst: false)
        } else if submenu != nil {
            closeSubmenu()
        }
    }

    func unhoverItem(_ index: Int) {
        // The entry of an open submenu stays lit while the pointer is over the submenu.
        if highlighted == index && submenuIndex != index { highlighted = nil }
    }

    /// Moves the highlight `step` entries, skipping headers, separators and disabled commands.
    /// Lists wrap around; in a gallery an up or down step that leaves the grid stays put.
    func moveHighlight(by step: Int, wraps: Bool = true) {
        let selectable = selectableIndices
        guard !selectable.isEmpty else { return }
        guard let current = highlighted else {
            highlighted = step > 0 ? selectable.first : selectable.last
            return
        }
        var next = current
        for _ in entries.indices {
            next += step
            if !wraps && !entries.indices.contains(next) { return }
            next = (next % entries.count + entries.count) % entries.count
            if entries[next].isSelectable { break }
        }
        if entries[next].isSelectable { highlighted = next }
    }

    // MARK: Commands

    /// A click or Enter on an entry: its submenu opens, or its command runs and the panel closes.
    func choose(_ index: Int) {
        guard entries.indices.contains(index), entries[index].isSelectable else { return }
        if entries[index].hasSubmenu {
            highlighted = index
            openSubmenu(index, highlightFirst: true)
        } else {
            items[index].perform()
        }
    }

    // MARK: Submenu

    func openSubmenu(_ index: Int, highlightFirst: Bool) {
        if submenuIndex == index, let open = submenu {
            if highlightFirst && open.highlighted == nil { open.moveHighlight(by: 1) }
            return
        }
        closeSubmenu()
        guard entries[index].hasSubmenu, let window = window else { return }
        let menu = RibbonMenuView(entries: entries[index].submenu, name: "\(name).\(index)")
        menu.parentMenu = self
        let panel = RibbonPopup.makePanel(for: menu)
        let item = items[index]
        let corner = window.convertPoint(toScreen: item.convert(NSPoint(x: item.bounds.maxX + RibbonTheme.dropdownPadding, y: item.bounds.minY - 3),
                                                                to: nil))
        var frame = NSRect(x: corner.x, y: corner.y - panel.frame.height, width: panel.frame.width, height: panel.frame.height)
        // Beside the menu, on its left when the screen ends on the right.
        if let visible = window.screen?.visibleFrame {
            if frame.maxX > visible.maxX { frame.origin.x = window.frame.minX - frame.width }
            if frame.minY < visible.minY { frame.origin.y = min(visible.minY, visible.maxY - frame.height) }
        }
        panel.setFrameOrigin(frame.origin)
        window.addChildWindow(panel, ordered: .above)
        panel.orderFront(nil)
        submenu = menu
        submenuIndex = index
        submenuPanel = panel
        if highlightFirst { menu.moveHighlight(by: 1) }
    }

    func closeSubmenu() {
        submenu?.closeSubmenu()
        if let panel = submenuPanel {
            panel.parent?.removeChildWindow(panel)
            panel.orderOut(nil)
        }
        submenu = nil
        submenuIndex = nil
        submenuPanel = nil
    }

    /// The submenu's panel, for the tests.
    var openSubmenuPanel: NSPanel? { submenuPanel }

    // MARK: Keys

    /// Up and Down move the highlight (Left and Right too in a gallery); Right opens a submenu
    /// and Left or Esc closes it; Enter and Space run the highlighted command.
    func popupKeyDown(_ event: NSEvent) -> Bool {
        // Shortcuts with Cmd, Ctrl or Option go on to the window.
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return false }
        if let open = submenu, open.highlighted != nil || event.keyCode == 53 || event.keyCode == 123 {
            return open.popupKeyDown(event)
        }
        let columns: Int? = { if case .gallery(let columns) = style { return columns } else { return nil } }()
        switch event.keyCode {
        case 125: moveHighlight(by: columns ?? 1, wraps: columns == nil)  // Down
        case 126: moveHighlight(by: -(columns ?? 1), wraps: columns == nil)  // Up
        case 123:  // Left
            if columns != nil {
                moveHighlight(by: -1)
            } else if let parent = parentMenu {
                parent.closeSubmenu()
            } else if submenu != nil {
                closeSubmenu()
            }
        case 124:  // Right
            if columns != nil {
                moveHighlight(by: 1)
            } else if let index = highlighted, entries[index].hasSubmenu {
                openSubmenu(index, highlightFirst: true)
            }
        case 36, 76, 49:  // Return, Enter, Space
            if let index = highlighted { choose(index) }
        case 53:  // Esc: a submenu closes on its own; the menu itself is closed by the panel
            guard let parent = parentMenu else { return false }
            parent.closeSubmenu()
        default: return false
        }
        return true
    }

    func popupWillClose() { closeSubmenu() }
}

/// An entry of a drawn menu, as a control: hover, click and an accessibility menu item.
final class RibbonMenuItemView: RibbonControl {
    let entry: RibbonMenuEntry
    let index: Int
    private(set) weak var owner: RibbonMenuView?

    init(entry: RibbonMenuEntry, index: Int, menu: RibbonMenuView) {
        self.entry = entry
        self.index = index
        self.owner = menu
        super.init(title: entry.title)
        target = entry.target
        action = entry.action
        tag = entry.tag
        isEnabled = entry.isSelectable
        isChecked = entry.isChecked
        // Lists show their text; the lines and the gallery explain themselves in a tooltip.
        if case .list = menu.style, entry.lineWidth == nil { toolTip = nil }
        if entry.kind == .separator { toolTip = nil }
        setAccessibilityIdentifier("\(menu.name).\(index)")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    var isHighlighted: Bool { owner?.highlighted == index }

    override func hover(at point: NSPoint?) {
        guard let menu = owner, entry.isSelectable else { return }
        if point != nil { menu.hoverItem(index) } else { menu.unhoverItem(index) }
    }

    override func activate(at point: NSPoint) {
        if entry.hasSubmenu { owner?.choose(index) } else { perform() }
    }

    // MARK: Accessibility

    override func isAccessibilityElement() -> Bool { entry.kind != .separator }
    override func accessibilityRole() -> NSAccessibility.Role? { entry.kind == .header ? .staticText : .menuItem }
    override func accessibilityValue() -> Any? { entry.kind == .header ? entry.title : (isChecked ? 1 : nil) }
    override func accessibilityPerformPress() -> Bool {
        guard entry.isSelectable else { return false }
        activate(at: NSPoint(x: bounds.midX, y: bounds.midY))
        return true
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let menu = owner else { return }
        switch entry.kind {
        case .separator:
            let x = menu.style == .list ? RibbonTheme.dropdownGutterWidth + 2 : 2
            RibbonTheme.dropdownSeparator.setFill()
            NSRect(x: x, y: floor(bounds.midY), width: bounds.width - x - 2, height: 1).fill()
        case .header:
            RibbonTheme.dropdownHeaderBackground.setFill()
            bounds.fill()
            RibbonTheme.dropdownHeaderLine.setFill()
            NSRect(x: 0, y: bounds.maxY - 1, width: bounds.width, height: 1).fill()
            let attributes: [NSAttributedString.Key: Any] = [.font: RibbonTheme.dropdownHeaderFont,
                                                             .foregroundColor: RibbonTheme.dropdownHeaderText]
            let height = (title as NSString).size(withAttributes: attributes).height
            (title as NSString).draw(at: NSPoint(x: RibbonTheme.dropdownTextGap, y: floor((bounds.height - height) / 2)), withAttributes: attributes)
        case .command:
            switch menu.style {
            case .gallery: drawGalleryCell()
            case .list, .sizes:
                if let size = entry.lineWidth { drawSizeLine(size, menu: menu) } else { drawListItem() }
            }
        }
    }

    private var highlightLook: RibbonTheme.Look {
        if isHighlighted { return isChecked ? .checkedHover : .hover }
        return .normal
    }

    private func drawListItem() {
        RibbonTheme.drawButton(bounds.insetBy(dx: 1, dy: 0.5), highlightLook, radius: 3)
        let gutter = RibbonTheme.dropdownGutterWidth
        let iconSide = RibbonTheme.dropdownIcon
        let iconRect = NSRect(x: floor((gutter - iconSide) / 2), y: floor((bounds.height - iconSide) / 2), width: iconSide, height: iconSide)
        if isChecked {
            RibbonTheme.drawButton(iconRect.insetBy(dx: -3, dy: -2), .checked, radius: 2)
            if entry.image == nil { drawCheckmark(in: iconRect) }
        }
        entry.image?.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: isEnabled ? 1 : 0.4,
                          respectFlipped: true, hints: nil)
        let attributes = RibbonTheme.attributes(isEnabled)
        let textHeight = (title as NSString).size(withAttributes: attributes).height
        (title as NSString).draw(at: NSPoint(x: gutter + RibbonTheme.dropdownTextGap, y: floor((bounds.height - textHeight) / 2)),
                                 withAttributes: attributes)
        if entry.hasSubmenu {
            let path = NSBezierPath()
            let center = NSPoint(x: bounds.width - 10, y: bounds.midY)
            path.move(to: NSPoint(x: center.x - 1.5, y: center.y - 3.5))
            path.line(to: NSPoint(x: center.x + 2, y: center.y))
            path.line(to: NSPoint(x: center.x - 1.5, y: center.y + 3.5))
            path.close()
            (isEnabled ? RibbonTheme.rgb(0x2C3E55) : RibbonTheme.disabledTextColor).setFill()
            path.fill()
        }
    }

    private func drawCheckmark(in rect: NSRect) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX + 3.5, y: rect.midY))
        path.line(to: NSPoint(x: rect.minX + 6.5, y: rect.midY + 3.5))
        path.line(to: NSPoint(x: rect.maxX - 3, y: rect.minY + 4))
        path.lineWidth = 1.8
        RibbonTheme.checkmark.setStroke()
        path.stroke()
    }

    private func drawSizeLine(_ size: Int, menu: RibbonMenuView) {
        let look: RibbonTheme.Look = isChecked ? (isHighlighted ? .checkedHover : .checked) : highlightLook
        RibbonTheme.drawButton(bounds.insetBy(dx: 1, dy: 1), look, radius: 3)
        let thickness = menu.sampleThickness(size)
        RibbonTheme.dropdownSample.setFill()
        NSRect(x: 10, y: floor((bounds.height - thickness) / 2), width: bounds.width - 20, height: thickness).fill()
    }

    private func drawGalleryCell() {
        let look: RibbonTheme.Look = isChecked ? (isHighlighted ? .checkedHover : .checked) : highlightLook
        RibbonTheme.drawButton(bounds.insetBy(dx: 1, dy: 1), look, radius: 3)
        let side = RibbonTheme.brushGalleryIcon
        let rect = NSRect(x: floor((bounds.width - side) / 2), y: floor((bounds.height - side) / 2), width: side, height: side)
        if let kind = BrushKind(rawValue: entry.tag), entry.action == #selector(MainWindowController.chooseBrush(_:)) {
            kind.icon.draw(in: rect, enabled: isEnabled)
        } else {
            entry.image?.draw(in: rect, from: .zero, operation: .sourceOver, fraction: isEnabled ? 1 : 0.4, respectFlipped: true, hints: nil)
        }
    }
}

extension MainWindowController {
    /// A drawn menu made of the same items as the menu bar, with their state from `validateMenuItem`.
    func makeRibbonMenu(_ items: [NSMenuItem], style: RibbonMenuView.Style = .list, name: String) -> RibbonMenuView {
        var entries = RibbonMenuEntry.entries(items, validate: validateMenuItem)
        if style == .sizes {
            for index in entries.indices where entries[index].action == #selector(chooseToolSize(_:)) {
                entries[index].lineWidth = entries[index].tag
            }
        }
        return RibbonMenuView(entries: entries, style: style, name: name)
    }

    /// Opens a drawn menu under a ribbon button, as the original drop-downs do.
    func showRibbonMenu(_ items: [NSMenuItem], style: RibbonMenuView.Style = .list, name: String, under sender: Any?) {
        guard let view = sender as? NSView else { return }
        presentMenu(makeRibbonMenu(items, style: style, name: name), NSPoint(x: 0, y: view.bounds.height + 1), view)
    }
}
