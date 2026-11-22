import AppKit

/// One command of the application menu. Entries without an action belong to later phases
/// and are shown disabled, in their place in the original.
struct ApplicationMenuEntry {
    let name: String
    let titleKey: String
    let icon: RibbonIcon
    let action: Selector?
    let target: AnyObject?
    let hasSubmenu: Bool
    let separatorBefore: Bool

    var isEnabled: Bool { action != nil }
}

/// A Save As format offered on the right of the application menu.
struct SaveFormatEntry {
    /// Index in `ImageFormat.allCases`, or nil for "Other formats" (the full dialog).
    let format: ImageFormat?
    let titleKey: String
    let detailKey: String
}

extension MainWindowController {
    var applicationMenuEntries: [ApplicationMenuEntry] {
        func entry(_ name: String, _ key: String, _ icon: RibbonIcon, _ action: Selector?, target: AnyObject? = nil,
                   submenu: Bool = false, separator: Bool = false) -> ApplicationMenuEntry {
            ApplicationMenuEntry(name: name, titleKey: key, icon: icon, action: action, target: target ?? self,
                                 hasSubmenu: submenu, separatorBefore: separator)
        }
        return [
            entry("new", "appmenu.new", .newFile, #selector(newDocument(_:))),
            entry("open", "appmenu.open", .open, #selector(openDocument(_:))),
            entry("save", "appmenu.save", .saveLarge, #selector(saveDocument(_:))),
            entry("saveAs", "appmenu.saveAs", .saveAs, #selector(saveDocumentAs(_:)), submenu: true),
            entry("print", "appmenu.print", .print, #selector(printImage(_:)), submenu: true, separator: true),
            // The entry itself fills the desktop; the pane offers the three ways.
            entry("wallpaper", "appmenu.wallpaper", .wallpaper, #selector(setDesktopBackground(_:)), submenu: true, separator: true),
            entry("properties", "appmenu.properties", .properties, #selector(showImageProperties(_:)), separator: true),
            entry("about", "appmenu.about", .about, #selector(showAboutPanel(_:)), separator: true),
            entry("exit", "appmenu.exit", .exit, #selector(NSApplication.terminate(_:)), target: NSApp, separator: true),
        ]
    }

    static let saveFormats = [
        SaveFormatEntry(format: .png, titleKey: "saveas.png", detailKey: "saveas.png.detail"),
        SaveFormatEntry(format: .jpeg, titleKey: "saveas.jpeg", detailKey: "saveas.jpeg.detail"),
        SaveFormatEntry(format: .bmp, titleKey: "saveas.bmp", detailKey: "saveas.bmp.detail"),
        SaveFormatEntry(format: .gif, titleKey: "saveas.gif", detailKey: "saveas.gif.detail"),
        SaveFormatEntry(format: nil, titleKey: "saveas.other", detailKey: "saveas.other.detail"),
    ]

    /// Print ▸ and Set as desktop background ▸ on the right of the menu.
    var printPaneEntries: [ApplicationPaneEntry] {
        [ApplicationPaneEntry(name: "print", title: L("appmenu.printItem"), detail: L("appmenu.printItem.detail"), icon: .print,
                              action: #selector(printImage(_:))),
         ApplicationPaneEntry(name: "pageSetup", title: L("appmenu.pageSetup"), detail: L("appmenu.pageSetup.detail"), icon: .pageSetup,
                              action: #selector(showPageSetup(_:))),
         ApplicationPaneEntry(name: "printPreview", title: L("appmenu.printPreview"), detail: L("appmenu.printPreview.detail"),
                              icon: .printPreview, action: #selector(showPrintPreview(_:)))]
    }

    var wallpaperPaneEntries: [ApplicationPaneEntry] {
        WallpaperStyle.allCases.map { style in
            ApplicationPaneEntry(name: "wallpaper.\(style.rawValue)", title: L(style.nameKey), detail: nil, icon: nil,
                                 action: #selector(setDesktopBackground(_:)), tag: style.rawValue)
        }
    }

    var recentPaneEntries: [ApplicationPaneEntry] {
        recentPictures.urls.enumerated().map { index, url in
            ApplicationPaneEntry(name: "recent.\(index)", title: MainWindowController.recentTitle(url, index: index), detail: nil,
                                 icon: nil, action: #selector(openRecentPicture(_:)), tag: index,
                                 pinned: recentPictures.isPinned(url))
        }
    }

    @objc func showAboutPanel(_ sender: Any?) {
        presentingDialog { NSApp.orderFrontStandardAboutPanel(sender) }
    }

    /// Opens the application menu under the blue button.
    func showApplicationMenu() {
        let button = ribbon.applicationButton
        let menu = ApplicationMenuView(entries: applicationMenuEntries, formats: MainWindowController.saveFormats,
                                       panes: [.print: printPaneEntries, .wallpaper: wallpaperPaneEntries, .recent: recentPaneEntries],
                                       target: self)
        menu.onTogglePin = { [weak self] index in
            guard let self = self else { return [] }
            self.toggleRecentPin(at: index)
            return self.recentPaneEntries
        }
        button.isChecked = true
        RibbonPopup.show(menu, from: button, at: NSPoint(x: 0, y: button.bounds.height)) { [weak button] in
            button?.isChecked = false
        }
    }
}

/// What the right side of the application menu shows.
enum ApplicationPane: Hashable {
    case recent, saveAs, print, wallpaper

    var headerKey: String {
        switch self {
        case .recent: return "appmenu.recent"
        case .saveAs: return "appmenu.saveAsHeader"
        case .print: return "appmenu.printHeader"
        case .wallpaper: return "appmenu.wallpaperHeader"
        }
    }

    /// The pane of a command with a submenu, by the command's name.
    init?(entry name: String) {
        switch name {
        case "saveAs": self = .saveAs
        case "print": self = .print
        case "wallpaper": self = .wallpaper
        default: return nil
        }
    }
}

/// A command on the right of the application menu: Print ▸, desktop background ▸ or a recent picture.
struct ApplicationPaneEntry {
    let name: String
    let title: String
    /// One line under the title, for the larger items with an icon.
    let detail: String?
    let icon: RibbonIcon?
    let action: Selector
    var tag = 0
    /// For the recent pictures: whether the picture is pinned; nil shows no pin.
    var pinned: Bool? = nil
}

/// The application menu: commands on the left; on the right the recent pictures, or the
/// choices of the command with a submenu under the pointer (Save as, Print, desktop background).
final class ApplicationMenuView: FlippedView {
    private(set) var items: [ApplicationMenuItem] = []
    private(set) var formatItems: [SaveFormatItem] = []
    /// The items of each pane but Save as.
    private(set) var paneItems: [ApplicationPane: [ApplicationPaneItem]] = [:]
    private let right = FlippedView()
    private(set) var pane = ApplicationPane.recent
    var showsFormats: Bool { pane == .saveAs }
    private let header = NSTextField(labelWithString: "")
    /// A click on the pin of the recent picture at an index; answers the new recent entries.
    var onTogglePin: ((Int) -> [ApplicationPaneEntry])?

    init(entries: [ApplicationMenuEntry], formats: [SaveFormatEntry], panes: [ApplicationPane: [ApplicationPaneEntry]] = [:],
         target: AnyObject) {
        let frameWidth: CGFloat = 6
        var y = frameWidth
        super.init(frame: .zero)
        for entry in entries {
            if entry.separatorBefore { y += 5 }
            let item = ApplicationMenuItem(entry: entry)
            item.frame = NSRect(x: frameWidth, y: y, width: RibbonTheme.menuLeftWidth, height: RibbonTheme.menuItemHeight)
            item.onHover = { [weak self] item in self?.show(ApplicationPane(entry: item.entry.name) ?? .recent) }
            addSubview(item)
            items.append(item)
            y += RibbonTheme.menuItemHeight
        }
        let height = y + frameWidth
        frame.size = NSSize(width: frameWidth * 2 + RibbonTheme.menuLeftWidth + 1 + RibbonTheme.menuRightWidth, height: height)
        right.frame = NSRect(x: frameWidth + RibbonTheme.menuLeftWidth + 1, y: frameWidth,
                             width: RibbonTheme.menuRightWidth, height: height - 2 * frameWidth)
        addSubview(right)
        header.font = NSFont.boldSystemFont(ofSize: 11)
        header.textColor = RibbonTheme.menuHeaderColor
        header.frame = NSRect(x: 10, y: 6, width: right.frame.width - 20, height: 16)
        right.addSubview(header)
        var formatY: CGFloat = 30
        for entry in formats {
            let item = SaveFormatItem(entry: entry)
            item.target = target
            if let format = entry.format {
                item.action = #selector(MainWindowController.saveDocumentAsFormat(_:))
                item.tag = ImageFormat.allCases.firstIndex(of: format) ?? 0
            } else {
                item.action = #selector(MainWindowController.saveDocumentAs(_:))
            }
            item.frame = NSRect(x: 3, y: formatY, width: right.frame.width - 6, height: RibbonTheme.menuPaneItemHeight)
            right.addSubview(item)
            formatItems.append(item)
            formatY += RibbonTheme.menuPaneItemHeight
        }
        for (pane, entries) in panes {
            var itemY: CGFloat = 30
            paneItems[pane] = entries.map { entry in
                let item = ApplicationPaneItem(entry: entry)
                item.target = target
                item.pinButton?.handler = { [weak self, weak item] _ in
                    guard let self = self, let item = item else { return }
                    self.togglePin(item.entry.tag)
                }
                let itemHeight: CGFloat = entry.detail == nil ? RibbonTheme.menuPaneLineHeight : RibbonTheme.menuPaneItemHeight
                item.frame = NSRect(x: 3, y: itemY, width: right.frame.width - 6, height: itemHeight)
                itemY += itemHeight
                right.addSubview(item)
                return item
            }
        }
        show(.recent)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func show(_ newPane: ApplicationPane) {
        pane = newPane
        header.stringValue = L(newPane.headerKey)
        formatItems.forEach { $0.isHidden = newPane != .saveAs }
        for (pane, items) in paneItems { items.forEach { $0.isHidden = pane != newPane } }
        needsDisplay = true
    }

    func showFormats(_ show: Bool) { self.show(show ? .saveAs : .recent) }

    /// The pin of a recent picture was clicked: the list is reordered in place and the menu stays open.
    func togglePin(_ index: Int) {
        guard let entries = onTogglePin?(index), let items = paneItems[.recent], entries.count == items.count else { return }
        for (item, entry) in zip(items, entries) { item.entry = entry }
    }

    override func draw(_ dirtyRect: NSRect) {
        RibbonTheme.fillVertical(bounds, top: RibbonTheme.menuFrame.blended(withFraction: 0.4, of: .white) ?? RibbonTheme.menuFrame,
                                 bottom: RibbonTheme.menuFrame)
        let left = NSRect(x: 6, y: 6, width: RibbonTheme.menuLeftWidth, height: bounds.height - 12)
        RibbonTheme.menuLeftBackground.setFill()
        left.fill()
        RibbonTheme.menuRightBackground.setFill()
        right.frame.fill()
        RibbonTheme.separatorDark.setFill()
        NSRect(x: left.maxX, y: left.minY, width: 1, height: left.height).fill()
        NSRect(x: right.frame.minX + 8, y: right.frame.minY + 25, width: right.frame.width - 16, height: 1).fill()
        for item in items where item.entry.separatorBefore {
            NSRect(x: item.frame.minX + 44, y: item.frame.minY - 3, width: item.frame.width - 50, height: 1).fill()
        }
    }
}

/// An item on the right of the application menu: icon, bold title and a line of detail, or a
/// plain line (desktop background styles, recent pictures).
final class ApplicationPaneItem: RibbonControl {
    /// What the item shows; a recent picture's item takes a new entry when the list is reordered.
    var entry: ApplicationPaneEntry {
        didSet {
            title = entry.title
            tag = entry.tag
            pinButton?.isPinned = entry.pinned ?? false
            setAccessibilityIdentifier("appmenu.\(entry.name)")
        }
    }
    /// The pin at the right of a recent picture.
    private(set) var pinButton: RecentPinButton?

    init(entry: ApplicationPaneEntry) {
        self.entry = entry
        super.init(title: entry.title)
        action = entry.action
        tag = entry.tag
        setAccessibilityIdentifier("appmenu.\(entry.name)")
        if let pinned = entry.pinned {
            let pin = RecentPinButton(pinned: pinned)
            addSubview(pin)
            pinButton = pin
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        pinButton?.frame = pinRect
    }

    /// Where the pin sits: a square-ish column at the right edge.
    var pinRect: NSRect {
        let width = RibbonTheme.menuPinWidth
        return NSRect(x: bounds.width - width - 2, y: 2, width: width, height: max(0, bounds.height - 4))
    }

    /// Width the title may take, between the indent (or icon) and the pin.
    var titleRoom: CGFloat { bounds.width - titleX - 6 - (pinButton == nil ? 0 : RibbonTheme.menuPinWidth + 2) }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func accessibilityRole() -> NSAccessibility.Role? { .menuItem }

    /// Room for the title, after the icon or the indent.
    var titleX: CGFloat { entry.icon == nil ? 10 : 46 }

    override func draw(_ dirtyRect: NSRect) {
        RibbonTheme.drawButton(bounds.insetBy(dx: 1, dy: 1), look == .normal ? .normal : .hover)
        guard let detail = entry.detail else {
            let attributes = RibbonTheme.attributes()
            let height = (title as NSString).size(withAttributes: attributes).height
            (title as NSString).draw(with: NSRect(x: titleX, y: floor((bounds.height - height) / 2), width: titleRoom,
                                                  height: height), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                                     attributes: attributes)
            return
        }
        entry.icon?.draw(in: NSRect(x: 6, y: 7, width: 32, height: 32))
        (title as NSString).draw(at: NSPoint(x: titleX, y: 6), withAttributes: SaveFormatItem.boldAttributes)
        (detail as NSString).draw(with: NSRect(x: titleX, y: 20, width: bounds.width - titleX - 6, height: RibbonTheme.menuPaneDetailHeight),
                                  options: [.usesLineFragmentOrigin],
                                  attributes: RibbonTheme.attributes(color: RibbonTheme.rgb(0x4C5A6E)))
    }
}

/// The pin at the right of a recent picture: sideways while the picture is free, upright once
/// it is pinned. A click pins or unpins without opening the picture or closing the menu.
final class RecentPinButton: RibbonControl {
    var isPinned: Bool {
        didSet { if oldValue != isPinned { update() } }
    }

    init(pinned: Bool) {
        isPinned = pinned
        super.init(title: "")
        update()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func update() {
        title = L(isPinned ? "appmenu.unpin" : "appmenu.pin")
        isChecked = isPinned
    }

    override func accessibilityValue() -> Any? { isPinned ? 1 : 0 }
    override func accessibilityIdentifier() -> String {
        ((superview as? ApplicationPaneItem).map { "appmenu.\($0.entry.name).pin" }) ?? "appmenu.pin"
    }

    override func draw(_ dirtyRect: NSRect) {
        if isPressed {
            RibbonTheme.drawButton(bounds.insetBy(dx: 1, dy: 1), .pressed)
        } else if isHovered {
            RibbonTheme.drawButton(bounds.insetBy(dx: 1, dy: 1), .hover)
        }
        RecentPinButton.drawPin(in: NSRect(x: floor(bounds.midX - 8), y: floor(bounds.midY - 8), width: 16, height: 16), pinned: isPinned)
    }

    /// A push pin in a 16-point square of a flipped view: upright (needle down) when pinned,
    /// lying with the needle to the left when not.
    static func drawPin(in rect: NSRect, pinned: Bool) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        var transform = AffineTransform(translationByX: rect.midX, byY: rect.midY)
        if !pinned { transform.rotate(byDegrees: 90) }
        (transform as NSAffineTransform).concat()
        // Drawn upright around the centre: head, body, collar and needle.
        let head = NSBezierPath(roundedRect: NSRect(x: -3.5, y: -7, width: 7, height: 2.5), xRadius: 1, yRadius: 1)
        let body = NSBezierPath(rect: NSRect(x: -2, y: -4.5, width: 4, height: 5))
        let collar = NSBezierPath(roundedRect: NSRect(x: -5, y: 0.5, width: 10, height: 2), xRadius: 1, yRadius: 1)
        let needle = NSBezierPath()
        needle.move(to: NSPoint(x: 0, y: 2.5))
        needle.line(to: NSPoint(x: 0, y: 7.5))
        (pinned ? RibbonTheme.menuPinPinnedFill : RibbonTheme.menuPinFill).setFill()
        RibbonTheme.menuPinOutline.setStroke()
        for part in [body, head, collar] {
            part.lineWidth = 1
            part.fill()
            part.stroke()
        }
        needle.lineWidth = 1.5
        needle.lineCapStyle = .round
        needle.stroke()
    }
}

/// A command on the left of the application menu: 32 px icon, label and, for submenus, a triangle.
final class ApplicationMenuItem: RibbonControl {
    let entry: ApplicationMenuEntry
    var onHover: ((ApplicationMenuItem) -> Void)?

    init(entry: ApplicationMenuEntry) {
        self.entry = entry
        super.init(title: L(entry.titleKey))
        target = entry.target
        action = entry.action
        isEnabled = entry.isEnabled
        setAccessibilityIdentifier("appmenu.\(entry.name)")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func accessibilityRole() -> NSAccessibility.Role? { .menuItem }

    override func hover(at point: NSPoint?) {
        if point != nil { onHover?(self) }
    }

    override func draw(_ dirtyRect: NSRect) {
        RibbonTheme.drawButton(bounds.insetBy(dx: 2, dy: 1), look == .normal ? .normal : .hover)
        entry.icon.draw(in: NSRect(x: 6, y: floor((bounds.height - 32) / 2), width: 32, height: 32), enabled: isEnabled)
        let textRect = NSRect(x: 46, y: 0, width: bounds.width - 46 - (entry.hasSubmenu ? 18 : 6), height: bounds.height)
        let attributes = RibbonTheme.attributes(isEnabled)
        let needed = (title as NSString).boundingRect(with: NSSize(width: textRect.width, height: 100),
                                                      options: [.usesLineFragmentOrigin], attributes: attributes)
        (title as NSString).draw(with: NSRect(x: textRect.minX, y: floor((bounds.height - needed.height) / 2),
                                              width: textRect.width, height: needed.height),
                                 options: [.usesLineFragmentOrigin], attributes: attributes)
        if entry.hasSubmenu {
            let path = NSBezierPath()
            let center = NSPoint(x: bounds.width - 11, y: bounds.midY)
            path.move(to: NSPoint(x: center.x - 1.5, y: center.y - 3.5))
            path.line(to: NSPoint(x: center.x + 2, y: center.y))
            path.line(to: NSPoint(x: center.x - 1.5, y: center.y + 3.5))
            path.close()
            (isEnabled ? RibbonTheme.rgb(0x2C3E55) : RibbonTheme.disabledTextColor).setFill()
            path.fill()
        }
    }
}

/// A format in the Save As pane: picture icon, name in bold and a one-line description.
final class SaveFormatItem: RibbonControl {
    let entry: SaveFormatEntry

    init(entry: SaveFormatEntry) {
        self.entry = entry
        super.init(title: L(entry.titleKey))
        setAccessibilityIdentifier("saveas.\(entry.format?.fileExtension ?? "other")")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    static let boldAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 11),
                                                                 .foregroundColor: RibbonTheme.textColor]

    override func accessibilityRole() -> NSAccessibility.Role? { .menuItem }

    override func draw(_ dirtyRect: NSRect) {
        RibbonTheme.drawButton(bounds.insetBy(dx: 1, dy: 1), look == .normal ? .normal : .hover)
        RibbonIcon.picture.draw(in: NSRect(x: 6, y: 7, width: 32, height: 32))
        (title as NSString).draw(at: NSPoint(x: 46, y: 6), withAttributes: SaveFormatItem.boldAttributes)
        let detail = L(entry.detailKey) as NSString
        detail.draw(with: NSRect(x: 46, y: 20, width: bounds.width - 52, height: RibbonTheme.menuPaneDetailHeight), options: [.usesLineFragmentOrigin],
                    attributes: RibbonTheme.attributes(color: RibbonTheme.rgb(0x4C5A6E)))
    }
}
