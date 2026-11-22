import AppKit

/// Key tips, as the Windows 7 ribbon shows them after Alt or F10: Option pressed and released
/// alone (Option with a letter types a character on the Mac, so it is never used) or F10 shows
/// a letter over the application button, the tabs and the quick access buttons; a tab's letter
/// shows the letters of its controls; typing them presses the control. Esc goes back a level,
/// a click or a key that matches nothing puts the tips away.
final class KeyTipController {
    enum Level: Equatable {
        case top
        /// The controls of a tab.
        case page(Int)
    }

    /// Something a key tip reaches: where the tip is drawn and what its letters do.
    struct Target {
        let keys: String
        let view: NSView
        /// Draws the tip under the middle of the view instead of under its icon (tabs, large buttons).
        let centered: Bool
        let press: () -> Void

        /// Read when the letters are typed: a control may have changed since the tips showed.
        var isEnabled: Bool { (view as? RibbonControl)?.isEnabled ?? true }
    }

    private weak var controller: MainWindowController?
    private(set) var level: Level?
    /// Letters typed so far towards a tip of two letters.
    private(set) var typed = ""
    private(set) var targets: [Target] = []
    private(set) var overlay: KeyTipOverlay?
    /// Option went down with nothing else; releasing it shows the tips.
    private var optionArmed = false
    /// The body panel of a minimized ribbon is being closed by the tips themselves.
    private var closingBody = false

    init(controller: MainWindowController) {
        self.controller = controller
    }

    var isActive: Bool { level != nil }

    /// The tips shown now (those still matching what was typed).
    var visibleKeys: [String] { targets.filter { $0.keys.hasPrefix(typed) }.map(\.keys) }

    // MARK: Events

    /// Every event of the main window passes here first; true when the tips used it.
    func filter(_ event: NSEvent) -> Bool {
        switch event.type {
        case .flagsChanged:
            let flags = event.modifierFlags.intersection([.option, .command, .control, .shift, .function])
            if flags == .option, event.keyCode == 58 || event.keyCode == 61 {
                optionArmed = true
            } else if flags.isEmpty, optionArmed {
                optionArmed = false
                toggle()
                return true
            } else {
                optionArmed = false
            }
            return false
        case .keyDown:
            optionArmed = false
            return isActive ? handleKey(event) : false
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            optionArmed = false
            if isActive { stop() }
            return false
        default:
            return false
        }
    }

    /// Option alone or F10: shows the tips, or puts them away when they show.
    func toggle() {
        if isActive { stop() } else { start() }
    }

    func start() {
        guard controller != nil else { return }
        if let popup = RibbonPopup.current {
            closingBody = true
            popup.close()
            closingBody = false
        }
        show(.top)
    }

    func stop() {
        level = nil
        typed = ""
        targets = []
        overlay?.removeFromSuperview()
        overlay = nil
    }

    /// A key while the tips show. Every key is used: it presses a tip, goes on towards one,
    /// goes back a level (Esc) or puts the tips away.
    func handleKey(_ event: NSEvent) -> Bool {
        guard let level = level else { return false }
        let flags = event.modifierFlags.intersection([.option, .command, .control])
        if !flags.isEmpty {
            // A shortcut puts the tips away and still runs.
            stop()
            return false
        }
        switch event.keyCode {
        case 53:  // Esc
            back(from: level)
            return true
        case 109:  // F10
            stop()
            closeBody()
            return true
        default: break
        }
        guard let character = event.charactersIgnoringModifiers?.uppercased(), character.count == 1,
              character.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) }) else {
            cancel()
            return true
        }
        let next = typed + character
        let matching = targets.filter { $0.keys.hasPrefix(next) }
        if let target = matching.first(where: { $0.keys == next }) {
            guard target.isEnabled else {
                typed = ""
                overlay?.typed = ""
                return true
            }
            target.press()
        } else if matching.isEmpty {
            cancel()
        } else {
            typed = next
            overlay?.typed = next
        }
        return true
    }

    /// The body panel of a minimized ribbon closed on its own: Esc goes back to the tabs, a
    /// click outside puts the tips away.
    func bodyPopupClosed() {
        guard !closingBody, case .page = level else { return }
        let event = NSApp.currentEvent
        if event?.type == .keyDown, event?.keyCode == 53 { show(.top) } else { stop() }
    }

    private func back(from level: Level) {
        switch level {
        case .top: stop()
        case .page:
            closeBody()
            show(.top)
        }
    }

    private func cancel() {
        stop()
        closeBody()
    }

    private func closeBody() {
        guard let ribbon = controller?.ribbon, let popup = ribbon.bodyPopup else { return }
        closingBody = true
        popup.close()
        closingBody = false
    }

    // MARK: Levels

    private func show(_ level: Level) {
        guard let controller = controller, let ribbon = controller.ribbon else { return }
        self.level = level
        typed = ""
        switch level {
        case .top: targets = topTargets(controller, ribbon)
        case .page(let index): targets = pageTargets(ribbon, index)
        }
        overlay?.removeFromSuperview()
        let host: NSView = { if case .page = level, ribbon.isMinimized, let body = ribbon.bodyHost { return body } else { return ribbon } }()
        let view = KeyTipOverlay(frame: host.bounds)
        view.tips = targets.map { target in
            KeyTipOverlay.Tip(keys: target.keys, anchor: KeyTipOverlay.anchor(for: target.view.convert(target.view.bounds, to: host),
                                                                               centered: target.centered),
                              isEnabled: target.isEnabled)
        }
        host.addSubview(view)
        overlay = view
    }

    private func topTargets(_ controller: MainWindowController, _ ribbon: RibbonView) -> [Target] {
        var result: [Target] = []
        let application = ribbon.applicationButton
        if let keys = application.keyTip {
            result.append(Target(keys: keys, view: application, centered: true) { [weak self, weak controller] in
                self?.stop()
                controller?.showApplicationMenu()
            })
        }
        for (index, tab) in ribbon.tabs.enumerated() where !tab.isHidden {
            guard let keys = tab.keyTip else { continue }
            result.append(Target(keys: keys, view: tab, centered: true) { [weak self, weak ribbon] in
                guard let self = self, let ribbon = ribbon else { return }
                self.closingBody = true
                ribbon.selectPage(index)
                if ribbon.isMinimized { ribbon.showBodyPopup() }
                self.closingBody = false
                self.show(.page(index))
            })
        }
        for button in ribbon.quickAccess {
            guard let keys = button.keyTip else { continue }
            result.append(Target(keys: keys, view: button, centered: true) { [weak self, weak button] in
                self?.stop()
                button?.perform()
            })
        }
        return result
    }

    private func pageTargets(_ ribbon: RibbonView, _ index: Int) -> [Target] {
        var result: [Target] = []
        let controls = ribbon.controls.values.sorted { ($0.accessibilityIdentifier(), $0.tag) < ($1.accessibilityIdentifier(), $1.tag) }
        for group in ribbon.pages[index].groups {
            if group.isCollapsed {
                let button = group.collapsedButton
                if let keys = button.keyTip {
                    result.append(Target(keys: keys, view: button, centered: true) { [weak self, weak button] in
                        self?.stop()
                        button?.perform()
                    })
                }
                continue
            }
            for control in controls where control.isDescendant(of: group.content) {
                guard let keys = control.keyTip else { continue }
                let large = (control as? RibbonButton)?.style == .large || control is ColorWellButton
                result.append(Target(keys: keys, view: control, centered: large) { [weak self, weak control] in
                    self?.stop()
                    if let control = control { KeyTipController.press(control) }
                })
            }
        }
        return result
    }

    /// What a key tip does to a control: a box takes the focus, the gallery opens every shape,
    /// a split button runs its command, the rest are pressed.
    static func press(_ control: RibbonControl) {
        switch control {
        case let box as RibbonComboBox:
            box.window?.makeFirstResponder(box.combo)
        case let gallery as ShapeGalleryView:
            gallery.openAll()
        case let button as RibbonButton where button.isSplit:
            button.perform()
        default:
            control.activate(at: NSPoint(x: control.bounds.midX, y: control.bounds.midY))
        }
    }
}

/// The key tips drawn over the ribbon (or the body of a minimized ribbon). Clicks go through.
final class KeyTipOverlay: FlippedView {
    struct Tip: Equatable {
        let keys: String
        /// Top middle of the tip.
        let anchor: NSPoint
        let isEnabled: Bool
    }

    var tips: [Tip] = [] { didSet { needsDisplay = true } }
    /// Letters typed so far; tips that no longer match are hidden.
    var typed = "" { didSet { needsDisplay = true } }

    var shownTips: [Tip] { tips.filter { $0.keys.hasPrefix(typed) } }

    /// Under the middle of a tab or a large button, under the icon of the others.
    static func anchor(for rect: NSRect, centered: Bool) -> NSPoint {
        let tall = rect.height > 30
        let x = centered ? rect.midX : rect.minX + min(rect.width / 2, 11)
        let y = tall || centered ? rect.maxY - RibbonTheme.keyTipHeight + 3 : rect.maxY - RibbonTheme.keyTipHeight / 2
        return NSPoint(x: floor(x), y: floor(y))
    }

    static func size(of keys: String) -> NSSize {
        let width = ceil((keys as NSString).size(withAttributes: [.font: RibbonTheme.keyTipFont]).width) + 2 * RibbonTheme.keyTipPadding
        return NSSize(width: max(RibbonTheme.keyTipMinWidth, width), height: RibbonTheme.keyTipHeight)
    }

    /// Where a tip is drawn, kept inside the overlay.
    func rect(of tip: Tip) -> NSRect {
        let size = KeyTipOverlay.size(of: tip.keys)
        var rect = NSRect(x: tip.anchor.x - floor(size.width / 2), y: tip.anchor.y, width: size.width, height: size.height)
        rect.origin.x = max(1, min(rect.minX, bounds.width - rect.width - 1))
        rect.origin.y = max(1, min(rect.minY, bounds.height - rect.height - 1))
        return rect
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func isAccessibilityElement() -> Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        for tip in shownTips {
            let rect = self.rect(of: tip).insetBy(dx: 0.5, dy: 0.5)
            let path = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
            NSGradient(starting: RibbonTheme.keyTipTop, ending: RibbonTheme.keyTipBottom)?.draw(in: path, angle: 90)
            RibbonTheme.keyTipBorder.setStroke()
            path.stroke()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: RibbonTheme.keyTipFont,
                .foregroundColor: tip.isEnabled ? RibbonTheme.keyTipText : RibbonTheme.keyTipDisabledText,
            ]
            let size = (tip.keys as NSString).size(withAttributes: attributes)
            (tip.keys as NSString).draw(at: NSPoint(x: rect.minX + floor((rect.width - size.width) / 2),
                                                    y: rect.minY + floor((rect.height - size.height) / 2)), withAttributes: attributes)
        }
    }
}

extension MainWindowController {
    /// Letters of the key tips, the same in every language, as Windows keeps Latin letters even in
    /// Japanese and Korean (a conferir com o original). Within a level no tip is the start of
    /// another, and collapsed groups take Z and a letter. Keys are control names, tab and group
    /// title keys.
    static let keyTipTable: [String: String] = [
        // Top level
        "application": "F", "ribbon.home": "H", "ribbon.view": "V", "ribbon.text": "T",
        "qat.save": "1", "qat.undo": "2", "qat.redo": "3",
        // Home
        "home.paste": "V", "home.cut": "X", "home.copy": "C",
        "home.select": "SE", "home.crop": "RC", "home.resize": "RE", "home.rotate": "RO",
        "tool.pencil": "P", "tool.fill": "K", "tool.text": "T", "tool.eraser": "E", "tool.colorPicker": "I", "tool.magnifier": "M",
        "home.brushes": "B", "home.shapes": "SH", "home.outline": "SO", "home.shapeFill": "SF", "home.size": "SZ",
        "home.color1": "1", "home.color2": "2", "home.editColors": "D",
        // View
        "view.zoomIn": "I", "view.zoomOut": "O", "view.zoomActual": "M", "view.rulers": "R", "view.gridlines": "G",
        "view.statusBar": "S", "view.fullScreen": "F", "view.thumbnail": "N", "view.interfaceSize": "L",
        // Text
        "text.paste": "V", "text.cut": "X", "text.copy": "C", "text.fontFamily": "FF", "text.fontSize": "FS",
        "text.bold": "B", "text.italic": "I", "text.underline": "U", "text.strikethrough": "K",
        "text.opaque": "O", "text.transparent": "TR", "text.color1": "1", "text.color2": "2", "text.editColors": "D",
        // Collapsed groups
        "group.clipboard": "ZC", "group.image": "ZI", "group.tools": "ZT", "group.brushes": "ZB", "group.shapes": "ZS",
        "group.size": "ZZ", "group.colors": "ZO", "group.zoom": "ZM", "group.showHide": "ZH", "group.display": "ZD",
        "group.font": "ZF", "group.background": "ZG",
        // Print preview
        "printPreview": "P", "preview.print": "P", "preview.pageSetup": "S", "preview.zoomIn": "I", "preview.zoomOut": "O",
        "preview.next": "N", "preview.previous": "B", "preview.close": "C",
        "group.print": "ZP", "group.preview": "ZV", "group.closePreview": "ZC",
    ]

    /// Option alone or F10.
    @objc func toggleKeyTips(_ sender: Any?) { keyTips.toggle() }

    /// Ctrl+F1, Cmd+F1, a double click on a tab, or View > Minimize the ribbon.
    @objc func toggleRibbonMinimized(_ sender: Any?) {
        // Print preview keeps the ribbon open; it is minimized again when the preview closes.
        guard !isShowingPrintPreview else { return }
        isRibbonMinimized.toggle()
    }
}
