import AppKit

/// How the groups of a tab get narrower when the ribbon is too narrow: steps taken in order,
/// as the Windows ribbon applies its scaling policy, until the groups fit.
enum RibbonLayout {
    enum Step: Equatable {
        /// The group's gallery loses columns, one at a time, down to its narrowest form.
        case shrink(Int)
        /// The group becomes a single drop-down button.
        case collapse(Int)
    }

    /// The form of each group once the steps that are needed have been taken. `widths[i]` lists
    /// the widths of group `i`'s forms, widest first, with the collapsed button last; the result
    /// is an index into it. Steps that would not make a group narrower are skipped.
    static func forms(widths: [[CGFloat]], steps: [Step], available: CGFloat) -> [Int] {
        var forms = Array(repeating: 0, count: widths.count)
        var total = widths.map { $0.first ?? 0 }.reduce(0, +)
        func move(_ index: Int, to form: Int) {
            total += widths[index][form] - widths[index][forms[index]]
            forms[index] = form
        }
        for step in steps where total > available {
            switch step {
            case .shrink(let index):
                guard widths.indices.contains(index) else { continue }
                // The middle forms only; the last one is the collapse step's.
                while total > available, forms[index] + 2 < widths[index].count,
                      widths[index][forms[index] + 1] < widths[index][forms[index]] {
                    move(index, to: forms[index] + 1)
                }
            case .collapse(let index):
                guard widths.indices.contains(index), widths[index].count > 1 else { continue }
                let last = widths[index].count - 1
                guard forms[index] < last, widths[index][last] < widths[index][forms[index]] else { continue }
                move(index, to: last)
            }
        }
        return forms
    }

    /// Collapses groups in `order` until the widths fit in `available`. Groups that would not
    /// get narrower are skipped. Returns the indices of the collapsed groups.
    static func collapsed(expanded: [CGFloat], collapsed: [CGFloat], order: [Int], available: CGFloat) -> Set<Int> {
        let widths = zip(expanded, collapsed).map { [$0, $1] }
        let result = forms(widths: widths, steps: order.map(Step.collapse), available: available)
        return Set(result.indices.filter { result[$0] == 1 })
    }
}

/// One tab and its groups. `steps` lists how its groups get narrower, in order (see `RibbonLayout`).
/// A contextual tab (Text) has the title of its header and only shows while it applies.
struct RibbonPage {
    let title: String
    let groups: [RibbonGroupView]
    let steps: [RibbonLayout.Step]
    var contextualTitle: String? = nil
    /// Key tip of the tab (see `KeyTipController`).
    var keyTip: String?
    /// The Print preview tab: the only one shown while the preview lasts, hidden otherwise.
    var isPrintPreview = false

    /// Groups that only collapse, in `collapseOrder`; `steps`, when given, replaces it.
    init(title: String, groups: [RibbonGroupView], collapseOrder: [Int] = [], steps: [RibbonLayout.Step]? = nil,
         contextualTitle: String? = nil) {
        self.title = title
        self.groups = groups
        self.steps = steps ?? collapseOrder.map(RibbonLayout.Step.collapse)
        self.contextualTitle = contextualTitle
    }
}

/// A tab of the ribbon (Home, View). A double click minimizes or restores the ribbon.
final class RibbonTabButton: RibbonControl {
    var onDoubleClick: (() -> Void)?
    /// The second click of a double click does not also select the tab when it is released.
    private var ignoresMouseUp = false

    override init(title: String) {
        super.init(title: title)
        frame.size = NSSize(width: RibbonTheme.textWidth(title) + 2 * RibbonTheme.tabPadding, height: RibbonTheme.tabHeight + 1)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount >= 2, isEnabled, let onDoubleClick = onDoubleClick {
            ignoresMouseUp = true
            onDoubleClick()
            return
        }
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        if ignoresMouseUp {
            ignoresMouseUp = false
            isPressed = false
            return
        }
        super.mouseUp(with: event)
    }

    override func accessibilityRole() -> NSAccessibility.Role? { .radioButton }
    override func accessibilityValue() -> Any? { isChecked ? 1 : 0 }

    override func draw(_ dirtyRect: NSRect) {
        // The selected tab is one pixel taller and covers the top border of the body.
        let rect = NSRect(x: 0.5, y: 0.5, width: bounds.width - 1, height: bounds.height)
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX, y: rect.maxY))
        path.line(to: NSPoint(x: rect.minX, y: rect.minY + 3))
        path.curve(to: NSPoint(x: rect.minX + 3, y: rect.minY), controlPoint1: NSPoint(x: rect.minX, y: rect.minY + 1.5),
                   controlPoint2: NSPoint(x: rect.minX + 1.5, y: rect.minY))
        path.line(to: NSPoint(x: rect.maxX - 3, y: rect.minY))
        path.curve(to: NSPoint(x: rect.maxX, y: rect.minY + 3), controlPoint1: NSPoint(x: rect.maxX - 1.5, y: rect.minY),
                   controlPoint2: NSPoint(x: rect.maxX, y: rect.minY + 1.5))
        path.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
        if isChecked {
            NSGradient(starting: RibbonTheme.bodyTop, ending: RibbonTheme.bodyTop)?.draw(in: path, angle: 90)
            RibbonTheme.tabBorder.setStroke()
            path.stroke()
        } else if isHovered {
            NSGradient(starting: RibbonTheme.tabHoverTop, ending: RibbonTheme.tabHoverBottom)?.draw(in: path, angle: 90)
            RibbonTheme.tabHoverBorder.setStroke()
            path.stroke()
        }
        let attributes = RibbonTheme.attributes()
        let size = (title as NSString).size(withAttributes: attributes)
        (title as NSString).draw(at: NSPoint(x: floor((bounds.width - size.width) / 2), y: floor((RibbonTheme.tabHeight - size.height) / 2) + 1),
                                 withAttributes: attributes)
    }
}

/// The blue button at the left of the tabs that opens the application menu.
final class ApplicationButton: RibbonControl {
    override init(title: String) {
        super.init(title: title)
        frame.size = NSSize(width: RibbonTheme.applicationButtonWidth, height: RibbonTheme.applicationButtonHeight)
        actsOnPress = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // A plain button: it opens a panel, not an NSMenu.
    override func accessibilityRole() -> NSAccessibility.Role? { .button }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX, y: rect.maxY + 0.5))
        path.line(to: NSPoint(x: rect.minX, y: rect.minY + 3))
        path.curve(to: NSPoint(x: rect.minX + 3, y: rect.minY), controlPoint1: NSPoint(x: rect.minX, y: rect.minY + 1.5),
                   controlPoint2: NSPoint(x: rect.minX + 1.5, y: rect.minY))
        path.line(to: NSPoint(x: rect.maxX - 3, y: rect.minY))
        path.curve(to: NSPoint(x: rect.maxX, y: rect.minY + 3), controlPoint1: NSPoint(x: rect.maxX - 1.5, y: rect.minY),
                   controlPoint2: NSPoint(x: rect.maxX, y: rect.minY + 1.5))
        path.line(to: NSPoint(x: rect.maxX, y: rect.maxY + 0.5))
        let top, bottom: NSColor
        if isPressed || isChecked {
            (top, bottom) = (RibbonTheme.applicationPressedTop, RibbonTheme.applicationPressedBottom)
        } else if isHovered {
            (top, bottom) = (RibbonTheme.applicationHoverTop, RibbonTheme.applicationHoverBottom)
        } else {
            (top, bottom) = (RibbonTheme.applicationTop, RibbonTheme.applicationBottom)
        }
        NSGradient(starting: top, ending: bottom)?.draw(in: path, angle: 90)
        // Glassy upper half.
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        RibbonTheme.rgb(0xFFFFFF, alpha: 0.18).setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: floor(bounds.height / 2)).fill()
        NSGraphicsContext.restoreGraphicsState()
        RibbonTheme.applicationBorder.setStroke()
        path.stroke()
        let iconX = floor(bounds.width / 2 - 13)
        RibbonIcon.application.draw(in: NSRect(x: iconX, y: floor((bounds.height - 16) / 2), width: 16, height: 16))
        RibbonTheme.drawArrow(center: NSPoint(x: iconX + 23, y: bounds.midY), enabled: true, color: .white)
    }
}

/// The light gradient behind the groups.
final class RibbonBodyView: FlippedView {
    override func draw(_ dirtyRect: NSRect) {
        let split = floor(bounds.height * 0.7)
        RibbonTheme.fillVertical(NSRect(x: 0, y: 0, width: bounds.width, height: split), top: RibbonTheme.bodyTop, bottom: RibbonTheme.bodyMiddle)
        RibbonTheme.fillVertical(NSRect(x: 0, y: split, width: bounds.width, height: bounds.height - split),
                                 top: RibbonTheme.bodyMiddle, bottom: RibbonTheme.bodyBottom)
        RibbonTheme.bodyBorder.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 1).fill()
        RibbonTheme.bodyBottomBorder.setFill()
        NSRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1).fill()
    }
}

/// Quick access strip, application button and tabs, and the groups of the selected tab.
final class RibbonView: FlippedView {
    let quickAccess: [RibbonButton]
    let applicationButton: ApplicationButton
    let pages: [RibbonPage]
    private(set) var tabs: [RibbonTabButton] = []
    private(set) var selectedPage = 0
    /// Whether the contextual tabs (and their header) are shown.
    private(set) var showsContextual = false
    private let body = RibbonBodyView()
    /// Every control by name, so commands can be synced and tests can find them.
    private(set) var controls: [String: RibbonControl] = [:]
    /// Only the quick access strip and the tabs show; a tab click shows the body over the
    /// workspace in a panel until a command runs or a click lands elsewhere.
    private(set) var isMinimized = false
    /// The body shown over the workspace while the ribbon is minimized.
    private(set) var bodyPopup: RibbonPopup?
    /// What holds the body in that panel.
    private(set) var bodyHost: FlippedView?
    /// A double click on a tab; the controller minimizes or restores the ribbon.
    var onTabDoubleClick: (() -> Void)?
    /// The body panel closed (a command, a click outside, Esc).
    var onBodyPopupClose: (() -> Void)?

    var preferredHeight: CGFloat { isMinimized ? RibbonTheme.minimizedRibbonHeight : RibbonTheme.ribbonHeight }

    init(quickAccess: [RibbonButton], applicationButton: ApplicationButton, pages: [RibbonPage], controls: [String: RibbonControl]) {
        self.quickAccess = quickAccess
        self.applicationButton = applicationButton
        self.pages = pages
        self.controls = controls
        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: RibbonTheme.ribbonHeight))
        addSubview(body)
        quickAccess.forEach(addSubview)
        addSubview(applicationButton)
        for (index, page) in pages.enumerated() {
            let tab = RibbonTabButton(title: page.title)
            if page.isPrintPreview { tab.isHidden = true }
            if let header = page.contextualTitle {
                // Wide enough for its header, as in the original.
                tab.frame.size.width = max(tab.frame.width, RibbonTheme.textWidth(header) + 2 * RibbonTheme.tabPadding)
                tab.isHidden = true
            }
            tab.tag = index
            tab.keyTip = page.keyTip
            tab.handler = { [weak self] control in self?.clickTab(control.tag) }
            tab.onDoubleClick = { [weak self] in self?.onTabDoubleClick?() }
            tabs.append(tab)
            addSubview(tab)
        }
        selectPage(0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func draw(_ dirtyRect: NSRect) {
        RibbonTheme.fillVertical(NSRect(x: 0, y: 0, width: bounds.width, height: RibbonTheme.quickAccessHeight + RibbonTheme.tabRowHeight),
                                 top: RibbonTheme.frameTop, bottom: RibbonTheme.frameBottom)
        if isMinimized {
            // The line the body's top border would draw, under the tabs.
            RibbonTheme.frameBottom.setFill()
            NSRect(x: 0, y: RibbonTheme.quickAccessHeight + RibbonTheme.tabRowHeight, width: bounds.width, height: 1).fill()
            RibbonTheme.bodyBorder.setFill()
            NSRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1).fill()
        }
        guard let header = contextualHeaderRect, let title = contextualTitle else { return }
        // A tint behind the tab and the colored header with its name above it.
        RibbonTheme.contextualTabTint.setFill()
        NSRect(x: header.minX, y: header.maxY, width: header.width, height: RibbonTheme.tabRowHeight).fill()
        RibbonTheme.fillVertical(header, top: RibbonTheme.contextualHeaderTop, bottom: RibbonTheme.contextualHeaderBottom)
        RibbonTheme.contextualHeaderBorder.setStroke()
        NSBezierPath(rect: header.insetBy(dx: 0.5, dy: 0.5)).stroke()
        let attributes = RibbonTheme.attributes(color: RibbonTheme.contextualHeaderText)
        let size = (title as NSString).size(withAttributes: attributes)
        (title as NSString).draw(at: NSPoint(x: header.minX + floor((header.width - size.width) / 2),
                                             y: header.minY + floor((header.height - size.height) / 2)), withAttributes: attributes)
    }

    /// Whether Print preview has the ribbon to itself.
    private(set) var showsPrintPreview = false
    /// The tab to go back to after Print preview.
    private var pageBeforePreview = 0

    var printPreviewPage: Int? { pages.firstIndex { $0.isPrintPreview } }

    /// Print preview hides every other tab and shows its own; closing it brings the tabs back
    /// (the Text tab only if it still applies) and the tab that was selected.
    func setPrintPreview(_ on: Bool) {
        guard on != showsPrintPreview, let preview = printPreviewPage else { return }
        showsPrintPreview = on
        if on { pageBeforePreview = selectedPage }
        for (index, tab) in tabs.enumerated() {
            if on {
                tab.isHidden = index != preview
            } else {
                tab.isHidden = pages[index].isPrintPreview || (pages[index].contextualTitle != nil && !showsContextual)
            }
        }
        if on {
            selectPage(preview)
        } else {
            selectPage(tabs[pageBeforePreview].isHidden ? (showsContextual ? contextualPages.first ?? 0 : 0) : pageBeforePreview)
        }
        needsDisplay = true
    }

    /// Indices of the contextual tabs.
    var contextualPages: [Int] { pages.indices.filter { pages[$0].contextualTitle != nil } }

    /// Name of the contextual header ("Text Tools") while it shows.
    var contextualTitle: String? { showsContextual ? contextualPages.first.flatMap { pages[$0].contextualTitle } : nil }

    /// Where the header of the contextual tabs is drawn, above them, while they show.
    var contextualHeaderRect: NSRect? {
        guard showsContextual, !showsPrintPreview else { return nil }
        let frames = contextualPages.map { tabs[$0].frame }
        guard let first = frames.first, let last = frames.last else { return nil }
        return NSRect(x: first.minX, y: 2, width: last.maxX - first.minX, height: RibbonTheme.quickAccessHeight - 2)
    }

    /// Shows or hides the contextual tabs. Showing selects the first one and hiding goes back to
    /// Home if one was selected, as in Paint.
    func setContextualVisible(_ visible: Bool) {
        guard visible != showsContextual else { return }
        showsContextual = visible
        // During Print preview only the record changes; the tabs come back when it closes.
        guard !showsPrintPreview else { return }
        for index in contextualPages { tabs[index].isHidden = !visible }
        if visible, let first = contextualPages.first {
            selectPage(first)
        } else if !visible, contextualPages.contains(selectedPage) {
            selectPage(0)
        } else {
            layoutRibbon()
        }
        needsDisplay = true
    }

    func selectPage(_ index: Int) {
        guard pages.indices.contains(index), !tabs[index].isHidden else { return }
        RibbonPopup.current?.close()
        selectedPage = index
        syncTabs()
        body.subviews.forEach { $0.removeFromSuperview() }
        pages[index].groups.forEach(body.addSubview)
        layoutRibbon()
    }

    /// The selected tab shows as such, except on a minimized ribbon whose body is not shown.
    private func syncTabs() {
        for (position, tab) in tabs.enumerated() { tab.isChecked = position == selectedPage && (!isMinimized || bodyPopup != nil) }
    }

    /// A click on a tab. On a minimized ribbon it shows that tab's body over the workspace, or
    /// hides it when it is already shown.
    func clickTab(_ index: Int) {
        guard isMinimized else { return selectPage(index) }
        if bodyPopup != nil, index == selectedPage { return bodyPopup?.close() ?? () }
        selectPage(index)
        showBodyPopup()
    }

    func setMinimized(_ minimized: Bool) {
        guard minimized != isMinimized else { return }
        bodyPopup?.close()
        isMinimized = minimized
        body.removeFromSuperview()
        if !minimized {
            // Behind the tabs: the selected one covers the body's top border.
            addSubview(body, positioned: .below, relativeTo: subviews.first)
            bodyHost = nil
        }
        syncTabs()
        layoutRibbon()
        needsDisplay = true
    }

    /// Shows the body of the selected tab under the tabs of the minimized ribbon, over the
    /// workspace, until a command runs or a click lands outside it.
    @discardableResult
    func showBodyPopup() -> RibbonPopup? {
        guard isMinimized else { return nil }
        bodyPopup?.close()
        let width = max(0, bounds.width - 2)
        let host = FlippedView(frame: NSRect(x: 0, y: 0, width: width, height: RibbonTheme.bodyHeight))
        body.removeFromSuperview()
        body.frame = host.bounds
        host.addSubview(body)
        bodyHost = host
        layoutGroups(width: width)
        let popup = RibbonPopup.show(host, from: self, at: NSPoint(x: 0, y: RibbonTheme.quickAccessHeight + RibbonTheme.tabRowHeight)) { [weak self] in
            guard let self = self else { return }
            self.bodyPopup = nil
            self.syncTabs()
            self.onBodyPopupClose?()
        }
        // The tabs stay clickable: another tab switches the body, a double click restores the ribbon.
        popup?.passesClick = { [weak self] event in
            guard let self = self, event.window === self.window else { return false }
            let point = self.convert(event.locationInWindow, from: nil)
            return self.tabs.contains { !$0.isHidden && $0.frame.contains(point) }
        }
        bodyPopup = popup
        syncTabs()
        return popup
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) { layoutRibbon() }

    func layoutRibbon() {
        var x: CGFloat = 5
        for button in quickAccess {
            button.frame = NSRect(x: x, y: floor((RibbonTheme.quickAccessHeight - RibbonTheme.smallButtonHeight) / 2),
                                  width: RibbonTheme.iconButtonWidth, height: RibbonTheme.smallButtonHeight)
            x += RibbonTheme.iconButtonWidth
        }
        let tabTop = RibbonTheme.quickAccessHeight
        let bodyTop = tabTop + RibbonTheme.tabRowHeight
        applicationButton.frame.origin = NSPoint(x: RibbonTheme.tabRowMargin, y: bodyTop - RibbonTheme.applicationButtonHeight)
        x = applicationButton.frame.maxX + 3
        var afterNormal = true
        for (index, tab) in tabs.enumerated() where !tab.isHidden {
            if pages[index].contextualTitle != nil, afterNormal {
                afterNormal = false
                x += RibbonTheme.contextualGap
            }
            tab.frame.origin = NSPoint(x: x, y: bodyTop - RibbonTheme.tabHeight)
            x += tab.frame.width + RibbonTheme.tabSpacing
        }
        // The body of a minimized ribbon is laid out when its panel opens.
        guard !isMinimized else { return }
        body.frame = NSRect(x: 0, y: bodyTop, width: bounds.width, height: RibbonTheme.bodyHeight)
        layoutGroups(width: bounds.width)
    }

    private func layoutGroups(width: CGFloat) {
        let groups = pages[selectedPage].groups
        let available = width - 2 * RibbonTheme.bodyMargin
        let forms = RibbonLayout.forms(widths: groups.map(\.formWidths), steps: pages[selectedPage].steps, available: available)
        var x = RibbonTheme.bodyMargin
        for (index, group) in groups.enumerated() {
            if forms[index] != group.form {
                if let popup = RibbonPopup.current, popup !== bodyPopup, group.content.window === popup.panel { popup.close() }
                group.form = forms[index]
            }
            group.frame.origin = NSPoint(x: x, y: RibbonTheme.groupTop)
            x += group.frame.width
        }
    }

    /// Shows a collapsed group's controls in a panel under its button.
    func openCollapsed(_ group: RibbonGroupView) {
        guard group.isCollapsed else { return }
        let panel = GroupPanelView(title: group.title, content: group.content)
        group.collapsedButton.isChecked = true
        RibbonPopup.show(panel, from: group.collapsedButton, at: NSPoint(x: 0, y: group.collapsedButton.bounds.height)) {
            group.collapsedButton.isChecked = false
            group.content.removeFromSuperview()
            group.arrange()
        }
    }

    func control(_ name: String) -> RibbonControl? { controls[name] }
}
