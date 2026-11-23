import AppKit

/// The menus inside the window, above the ribbon, as in the other applications of the My suite:
/// each title opens, under itself, the same menu the menu bar of the system shows.
final class MenuStripView: FlippedView {
    static let height: CGFloat = 22

    private var buttons: [MenuStripButton] = []

    /// Rebuilds the titles from the application's menus, all but the first (the application's own).
    func reload() {
        buttons.forEach { $0.removeFromSuperview() }
        buttons = (NSApp.mainMenu?.items ?? []).dropFirst().compactMap { item in
            guard let menu = item.submenu, !item.isHidden else { return nil }
            let button = MenuStripButton(title: item.title, menu: menu)
            addSubview(button)
            return button
        }
        needsLayout = true
        layoutButtons()
    }

    var titles: [String] { buttons.map(\.title) }

    private func layoutButtons() {
        var x: CGFloat = 4
        for button in buttons {
            let width = ceil((button.title as NSString).size(withAttributes: [.font: RibbonTheme.font]).width) + 14
            button.frame = NSRect(x: x, y: 1, width: width, height: Self.height - 2)
            x += width
        }
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) { layoutButtons() }

    override func draw(_ dirtyRect: NSRect) {
        NSGradient(starting: RibbonTheme.statusTop, ending: RibbonTheme.statusBottom)?.draw(in: bounds, angle: 90)
        RibbonTheme.statusBorder.setFill()
        NSRect(x: 0, y: bounds.maxY - 1, width: bounds.width, height: 1).fill()
    }
}

/// One title of the strip. The menu opens on the press, as menus do.
final class MenuStripButton: NSView {
    let title: String
    private let stripMenu: NSMenu
    private var hovered = false { didSet { needsDisplay = true } }
    private var pressed = false { didSet { needsDisplay = true } }
    private var tracking: NSTrackingArea?

    init(title: String, menu: NSMenu) {
        self.title = title
        stripMenu = menu
        super.init(frame: .zero)
        setAccessibilityRole(.menuButton)
        setAccessibilityLabel(title)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) { hovered = true }
    override func mouseExited(with event: NSEvent) { hovered = false }

    override func mouseDown(with event: NSEvent) { showMenu() }

    func showMenu() {
        pressed = true
        stripMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: bounds.maxY + 1), in: self)
        pressed = false
        hovered = false
    }

    override func draw(_ dirtyRect: NSRect) {
        if pressed || hovered {
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 3, yRadius: 3)
            RibbonTheme.menuHeaderColor.withAlphaComponent(pressed ? 0.22 : 0.12).setFill()
            path.fill()
        }
        let attributes: [NSAttributedString.Key: Any] = [.font: RibbonTheme.font, .foregroundColor: RibbonTheme.textColor]
        let size = (title as NSString).size(withAttributes: attributes)
        (title as NSString).draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2), withAttributes: attributes)
    }
}
