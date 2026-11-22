import AppKit

/// Opaque or Transparent, in the order of the Background group; the raw value is the tag.
enum TextBackground: Int, CaseIterable {
    case opaque, transparent

    var nameKey: String { self == .opaque ? "text.opaque" : "text.transparent" }
    var icon: RibbonIcon { self == .opaque ? .textOpaque : .textTransparent }
}

/// The text field of a `RibbonComboBox`: a click on its arrow can open a drawn list instead of
/// the system one; typing and completion stay the system's.
final class RibbonComboField: NSComboBox {
    /// Opens the drawn list; true when it did, so the system list stays closed.
    var opensList: (() -> Bool)?

    /// Whether a point (in the field's coordinates) is on the arrow part.
    func isOnArrow(_ point: NSPoint) -> Bool {
        bounds.contains(point) && point.x >= bounds.maxX - RibbonTheme.comboButtonWidth
    }

    override func mouseDown(with event: NSEvent) {
        if isEnabled, isOnArrow(convert(event.locationInWindow, from: nil)), opensList?() == true { return }
        super.mouseDown(with: event)
    }
}

/// A combo box of the ribbon (font family and size): a list that can also be typed into.
/// It sends its action when an item is picked or Return is pressed; the controller reads `stringValue`.
/// With `drawsFontList`, the arrow (or Option+Down) opens a `FontListView` with each family in itself.
final class RibbonComboBox: RibbonControl, NSComboBoxDelegate {
    let combo: RibbonComboField
    var drawsFontList = false
    /// The open drawn list, if any.
    private(set) weak var fontList: FontListView?

    init(title: String, width: CGFloat, items: [String]) {
        combo = RibbonComboField(frame: NSRect(x: 0, y: 0, width: width, height: RibbonTheme.comboHeight))
        super.init(title: title)
        frame.size = combo.frame.size
        combo.addItems(withObjectValues: items)
        combo.font = RibbonTheme.font
        combo.completes = true
        combo.numberOfVisibleItems = 16
        combo.target = self
        combo.action = #selector(comboAction(_:))
        combo.delegate = self
        combo.opensList = { [weak self] in self?.openFontList() ?? false }
        combo.setAccessibilityLabel(title)
        // The ribbon is always light, as in Windows 7, whatever the Mac appearance.
        combo.appearance = NSAppearance(named: .aqua)
        addSubview(combo)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isEnabled: Bool { didSet { combo.isEnabled = isEnabled } }

    var stringValue: String {
        get { combo.stringValue }
        set { combo.stringValue = newValue }
    }

    /// Shows `value` unless the user is typing in the box.
    func show(_ value: String) {
        guard combo.currentEditor() == nil, combo.stringValue != value else { return }
        combo.stringValue = value
    }

    @objc private func comboAction(_ sender: Any?) {
        guard isEnabled, let action = action else { return }
        send(action)
    }

    /// Opens the drawn list under the box, the current family lit; a second press closes it.
    @discardableResult
    func openFontList() -> Bool {
        guard drawsFontList, isEnabled else { return false }
        if let open = fontList, RibbonPopup.current?.content === open {
            RibbonPopup.current?.close()
            return true
        }
        let items = combo.objectValues.compactMap { $0 as? String }
        let list = FontListView(families: items, selected: combo.stringValue, minimumWidth: bounds.width)
        list.onChoose = { [weak self] family in self?.pick(family) }
        guard RibbonPopup.show(list, from: self, at: NSPoint(x: 0, y: bounds.height + 1)) != nil else { return false }
        fontList = list
        return true
    }

    /// A family picked in the drawn list: the box shows it and the action goes out.
    private func pick(_ family: String) {
        RibbonPopup.current?.close()
        combo.stringValue = family
        comboAction(nil)
    }

    /// Option+Down in the box opens the drawn list, as Alt+Down does in Windows.
    static func opensList(_ event: NSEvent?) -> Bool {
        guard let event = event, event.type == .keyDown, event.keyCode == 125 else { return false }
        return event.modifierFlags.intersection([.command, .control, .option, .shift]) == .option
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard drawsFontList, RibbonComboBox.opensList(NSApp.currentEvent) else { return false }
        return openFontList()
    }

    // The combo box itself is the accessibility element.
    override func isAccessibilityElement() -> Bool { false }
    override func draw(_ dirtyRect: NSRect) {}
}

/// Commands of the Text tab and the Text menu. As in Paint, the format applies to the whole box.
/// Names avoid the selectors AppKit and NSTextView already answer (bold:, underline:, changeFont:…).
extension MainWindowController {
    private var textTool: TextTool { canvas.toolbox.textTool }

    /// Formatting works while a box is open and, for the next box, with the Text tool selected.
    var textFormattingEnabled: Bool { document.text != nil || canvas.toolbox.kind == .text }

    private func changeTextFormat(_ change: (inout TextFormat) -> Void) {
        guard textFormattingEnabled else { return }
        change(&canvas.toolbox.textTool.format)
        textFormatChanged()
    }

    private func textFormatChanged() {
        canvas.textFormatChanged()
        canvas.focusText()
        syncInterface()
    }

    @objc func toggleTextBold(_ sender: Any?) { changeTextFormat { $0.bold.toggle() } }
    @objc func toggleTextItalic(_ sender: Any?) { changeTextFormat { $0.italic.toggle() } }
    @objc func toggleTextUnderline(_ sender: Any?) { changeTextFormat { $0.underline.toggle() } }
    @objc func toggleTextStrikethrough(_ sender: Any?) { changeTextFormat { $0.strikethrough.toggle() } }

    @objc func chooseTextBackground(_ sender: Any?) {
        guard textFormattingEnabled, let background = TextBackground(rawValue: senderTag(sender)) else { return }
        canvas.toolbox.textTool.opaque = background == .opaque
        textFormatChanged()
    }

    /// A family from the Font box (typed or picked) or the Font menu. Unknown names are ignored.
    @objc func chooseTextFontFamily(_ sender: Any?) {
        let name: String
        if let item = sender as? NSMenuItem {
            name = item.representedObject as? String ?? item.title
        } else if let box = sender as? RibbonComboBox {
            name = box.stringValue
        } else {
            return
        }
        guard let family = TextFormat.family(named: name) else { return forceSyncTextBoxes() }
        changeTextFormat { $0.family = family }
    }

    /// A size from the Size box (typed or picked) or the Font size menu (its tag).
    @objc func chooseTextFontSize(_ sender: Any?) {
        let size: Int?
        if let box = sender as? RibbonComboBox {
            size = Int(box.stringValue.trimmingCharacters(in: .whitespaces))
        } else {
            size = senderTag(sender)
        }
        guard let value = size, TextFormat.sizeRange.contains(value) else { return forceSyncTextBoxes() }
        changeTextFormat { $0.size = value }
    }

    /// Puts the current family and size back in the boxes after something invalid was typed.
    private func forceSyncTextBoxes() {
        let format = textTool.format
        (ribbon.control("text.fontFamily") as? RibbonComboBox)?.stringValue = format.family
        (ribbon.control("text.fontSize") as? RibbonComboBox)?.stringValue = String(format.size)
    }

    /// State of the Text commands for `commandState`, or nil for other actions.
    func textCommandState(_ action: Selector, tag: Int) -> (enabled: Bool, checked: Bool?)? {
        let format = textTool.format
        switch action {
        case #selector(toggleTextBold(_:)): return (textFormattingEnabled, format.bold)
        case #selector(toggleTextItalic(_:)): return (textFormattingEnabled, format.italic)
        case #selector(toggleTextUnderline(_:)): return (textFormattingEnabled, format.underline)
        case #selector(toggleTextStrikethrough(_:)): return (textFormattingEnabled, format.strikethrough)
        case #selector(chooseTextBackground(_:)): return (textFormattingEnabled, (tag == TextBackground.opaque.rawValue) == textTool.opaque)
        case #selector(chooseTextFontFamily(_:)): return (textFormattingEnabled, nil)
        case #selector(chooseTextFontSize(_:)): return (textFormattingEnabled, format.size == tag)
        default: break
        }
        // Inside a text box Cut, Copy, Paste and Delete work on the text.
        guard let view = canvas.textView else { return nil }
        switch action {
        case #selector(cut(_:)), #selector(copy(_:)): return (view.selectedRange().length > 0, nil)
        case #selector(paste(_:)): return (view.canPaste, nil)
        case #selector(delete(_:)), #selector(selectAll(_:)): return (true, nil)
        default: return nil
        }
    }

    /// The ribbon's family and size boxes follow the format.
    func syncTextControls() {
        let format = textTool.format
        (ribbon.control("text.fontFamily") as? RibbonComboBox)?.show(format.family)
        (ribbon.control("text.fontSize") as? RibbonComboBox)?.show(String(format.size))
        (ribbon.control("text.color1") as? ColorWellButton)?.color = document.color1
        (ribbon.control("text.color2") as? ColorWellButton)?.color = document.color2
        // The Text tab shows, and is selected, while a box is open.
        ribbon.setContextualVisible(document.text != nil)
    }

    // MARK: Menu bar mirror

    /// The Text menu: the Font and Background groups of the Text tab.
    func makeTextMenu() -> NSMenu {
        let menu = NSMenu(title: L("menu.text"))
        func add(_ key: String, _ action: Selector, tag: Int = 0, key equivalent: String = "") {
            let item = menu.addItem(withTitle: L(key), action: action, keyEquivalent: equivalent)
            item.tag = tag
            item.target = self
        }
        // Cmd+B, Cmd+I and Cmd+U; Ctrl+B, Ctrl+I and Ctrl+U come through the window, as in Windows.
        add("text.bold", #selector(toggleTextBold(_:)), key: "b")
        add("text.italic", #selector(toggleTextItalic(_:)), key: "i")
        add("text.underline", #selector(toggleTextUnderline(_:)), key: "u")
        add("text.strikethrough", #selector(toggleTextStrikethrough(_:)))
        menu.addItem(.separator())
        let families = NSMenu(title: L("menu.font"))
        for family in TextFormat.families {
            let item = families.addItem(withTitle: family, action: #selector(chooseTextFontFamily(_:)), keyEquivalent: "")
            item.representedObject = family
            item.target = self
        }
        menu.addItem(withTitle: L("menu.font"), action: nil, keyEquivalent: "").submenu = families
        let sizes = NSMenu(title: L("menu.fontSize"))
        for size in TextFormat.sizes {
            let item = sizes.addItem(withTitle: String(size), action: #selector(chooseTextFontSize(_:)), keyEquivalent: "")
            item.tag = size
            item.target = self
        }
        menu.addItem(withTitle: L("menu.fontSize"), action: nil, keyEquivalent: "").submenu = sizes
        menu.addItem(.separator())
        for background in TextBackground.allCases { add(background.nameKey, #selector(chooseTextBackground(_:)), tag: background.rawValue) }
        return menu
    }
}
