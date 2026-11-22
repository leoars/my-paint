import AppKit

/// What Resize and Skew does: a new size in pixels, then a skew in degrees.
struct ResizeSkew: Equatable {
    var width: Int
    var height: Int
    var skewHorizontal = 0
    var skewVertical = 0
}

/// The values typed in the Resize and Skew dialog, apart from the window so they can be tested.
struct ResizeSkewForm {
    enum Unit: Int { case percentage, pixels }

    let baseWidth: Int
    let baseHeight: Int
    private(set) var unit = Unit.percentage
    private(set) var horizontal = "100"
    private(set) var vertical = "100"
    var keepsAspectRatio = true
    var skewHorizontal = "0"
    var skewVertical = "0"

    /// Limits of the fields (a conferir com o original). Pixels allow the same 500% as the percentage.
    static let percentRange = 1...500
    static let skewRange = -89...89
    var widthRange: ClosedRange<Int> { unit == .percentage ? ResizeSkewForm.percentRange : 1...max(1, baseWidth * 5) }
    var heightRange: ClosedRange<Int> { unit == .percentage ? ResizeSkewForm.percentRange : 1...max(1, baseHeight * 5) }

    init(width: Int, height: Int) {
        baseWidth = max(1, width)
        baseHeight = max(1, height)
    }

    private static func scaled(_ value: Int, _ numerator: Int, _ denominator: Int) -> Int {
        max(1, Int((Double(value) * Double(numerator) / Double(denominator)).rounded()))
    }

    /// Percentage and Pixels convert the values already typed.
    mutating func setUnit(_ new: Unit) {
        guard new != unit else { return }
        if let h = Int(horizontal), let v = Int(vertical) {
            switch new {
            case .pixels:
                horizontal = String(ResizeSkewForm.scaled(baseWidth, h, 100))
                vertical = String(ResizeSkewForm.scaled(baseHeight, v, 100))
            case .percentage:
                horizontal = String(ResizeSkewForm.scaled(h, 100, baseWidth))
                vertical = String(ResizeSkewForm.scaled(v, 100, baseHeight))
            }
        }
        unit = new
    }

    /// With Maintain aspect ratio, typing one value fills in the other.
    mutating func editHorizontal(_ text: String) {
        horizontal = text
        guard keepsAspectRatio, let value = Int(text) else { return }
        vertical = unit == .percentage ? String(value) : String(ResizeSkewForm.scaled(value, baseHeight, baseWidth))
    }

    mutating func editVertical(_ text: String) {
        vertical = text
        guard keepsAspectRatio, let value = Int(text) else { return }
        horizontal = unit == .percentage ? String(value) : String(ResizeSkewForm.scaled(value, baseWidth, baseHeight))
    }

    /// The change, or the range a value falls outside of.
    func validate() -> (change: ResizeSkew?, invalid: ClosedRange<Int>?) {
        let trim = { (text: String) in Int(text.trimmingCharacters(in: .whitespaces)) }
        guard let h = trim(horizontal), widthRange.contains(h) else { return (nil, widthRange) }
        guard let v = trim(vertical), heightRange.contains(v) else { return (nil, heightRange) }
        guard let sh = trim(skewHorizontal), ResizeSkewForm.skewRange.contains(sh) else { return (nil, ResizeSkewForm.skewRange) }
        guard let sv = trim(skewVertical), ResizeSkewForm.skewRange.contains(sv) else { return (nil, ResizeSkewForm.skewRange) }
        let width = unit == .percentage ? ResizeSkewForm.scaled(baseWidth, h, 100) : h
        let height = unit == .percentage ? ResizeSkewForm.scaled(baseHeight, v, 100) : v
        return (ResizeSkew(width: width, height: height, skewHorizontal: sh, skewVertical: sv), nil)
    }
}

/// Layout of the dialog, drawn after the original (a conferir com o original).
enum ResizeDialogMetrics {
    static let width: CGFloat = 300
    static let height: CGFloat = 300
    static let margin: CGFloat = 12
    static let resizeBox = NSRect(x: 12, y: 8, width: 276, height: 146)
    static let skewBox = NSRect(x: 12, y: 160, width: 276, height: 92)
    static let iconX: CGFloat = 28
    static let radioX: CGFloat = 62
    static let secondRadioX: CGFloat = 180
    static let labelX: CGFloat = 52
    static let fieldX: CGFloat = 170
    static let fieldWidth: CGFloat = 90
    static let rowHeight: CGFloat = 28
    static let buttonWidth: CGFloat = 82
    static let buttonY: CGFloat = 262
}

/// Resize and Skew: Resize (by percentage or pixels, horizontal, vertical, maintain aspect
/// ratio) and Skew (horizontal and vertical degrees), then OK and Cancel.
final class ResizeSkewDialog: NSObject, NSTextFieldDelegate, NSWindowDelegate {
    let window: NSPanel
    private(set) var form: ResizeSkewForm
    let percentage = NSButton(radioButtonWithTitle: L("resize.percentage"), target: nil, action: nil)
    let pixels = NSButton(radioButtonWithTitle: L("resize.pixels"), target: nil, action: nil)
    let horizontalField = NSTextField(string: "100")
    let verticalField = NSTextField(string: "100")
    let keepRatio = NSButton(checkboxWithTitle: L("resize.keepRatio"), target: nil, action: nil)
    let skewHorizontalField = NSTextField(string: "0")
    let skewVerticalField = NSTextField(string: "0")
    let okButton = NSButton(title: L("ok"), target: nil, action: nil)
    let cancelButton = NSButton(title: L("cancel"), target: nil, action: nil)
    /// Shows a message for a value out of range; the dialog stays open.
    var onInvalid: ((String) -> Void)?
    private(set) var result: ResizeSkew?

    init(width: Int, height: Int) {
        form = ResizeSkewForm(width: width, height: height)
        window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: ResizeDialogMetrics.width, height: ResizeDialogMetrics.height),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init()
        window.title = L("resize.title")
        // Light, like the rest of the Windows 7 look, even when the Mac is in dark mode.
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.delegate = self
        build()
        sync()
    }

    private func build() {
        typealias M = ResizeDialogMetrics
        let content = FlippedView(frame: NSRect(x: 0, y: 0, width: M.width, height: M.height))
        for (frame, key) in [(M.resizeBox, "resize.group"), (M.skewBox, "skew.group")] {
            let box = NSBox(frame: frame)
            box.title = L(key)
            content.addSubview(box)
        }
        @discardableResult func label(_ key: String, x: CGFloat, y: CGFloat) -> NSTextField {
            let text = NSTextField(labelWithString: L(key))
            text.frame.origin = NSPoint(x: x, y: y + 3)
            text.sizeToFit()
            content.addSubview(text)
            return text
        }
        func row(_ icon: RibbonIcon, _ key: String, _ field: NSTextField, y: CGFloat) {
            let image = NSImageView(frame: NSRect(x: M.iconX, y: y + 3, width: 16, height: 16))
            image.image = icon.menuImage
            content.addSubview(image)
            label(key, x: M.labelX, y: y)
            field.frame = NSRect(x: M.fieldX, y: y, width: M.fieldWidth, height: 22)
            field.alignment = .right
            field.delegate = self
            field.setAccessibilityLabel(L(key))
            content.addSubview(field)
        }
        let top = M.resizeBox.minY + 26
        let by = label("resize.by", x: M.iconX, y: top)
        percentage.sizeToFit()
        pixels.sizeToFit()
        // After the label, however long it is in the current language.
        percentage.frame.origin = NSPoint(x: max(M.radioX, by.frame.maxX + 6), y: top + 2)
        pixels.frame.origin = NSPoint(x: max(M.secondRadioX, percentage.frame.maxX + 12), y: top + 2)
        for (button, unit) in [(percentage, ResizeSkewForm.Unit.percentage), (pixels, .pixels)] {
            button.tag = unit.rawValue
            button.target = self
            button.action = #selector(chooseUnit(_:))
            content.addSubview(button)
        }
        row(.resizeHorizontal, "resize.horizontal", horizontalField, y: top + M.rowHeight)
        row(.resizeVertical, "resize.vertical", verticalField, y: top + 2 * M.rowHeight)
        keepRatio.frame = NSRect(x: M.iconX, y: top + 3 * M.rowHeight + 2, width: 240, height: 18)
        keepRatio.target = self
        keepRatio.action = #selector(toggleRatio(_:))
        content.addSubview(keepRatio)
        let skewTop = M.skewBox.minY + 26
        row(.skewHorizontal, "resize.horizontal", skewHorizontalField, y: skewTop)
        row(.skewVertical, "resize.vertical", skewVerticalField, y: skewTop + M.rowHeight)
        skewHorizontalField.setAccessibilityLabel(L("skew.group") + " " + L("resize.horizontal"))
        skewVerticalField.setAccessibilityLabel(L("skew.group") + " " + L("resize.vertical"))

        let buttonWidth = dialogButtonWidth([okButton, cancelButton], minimum: M.buttonWidth)
        okButton.frame = NSRect(x: M.width - M.margin - 2 * buttonWidth - 6, y: M.buttonY, width: buttonWidth, height: 28)
        cancelButton.frame = NSRect(x: M.width - M.margin - buttonWidth, y: M.buttonY, width: buttonWidth, height: 28)
        okButton.keyEquivalent = "\r"
        cancelButton.keyEquivalent = "\u{1b}"
        okButton.target = self
        okButton.action = #selector(confirmDialog(_:))
        cancelButton.target = self
        cancelButton.action = #selector(cancelDialog(_:))
        [okButton, cancelButton].forEach(content.addSubview)
        window.initialFirstResponder = horizontalField
        // Drawn at the interface text size, like the ribbon.
        ScaledContentView.install(content, in: window)
    }

    /// Fields and buttons from the form.
    private func sync() {
        percentage.state = form.unit == .percentage ? .on : .off
        pixels.state = form.unit == .pixels ? .on : .off
        horizontalField.stringValue = form.horizontal
        verticalField.stringValue = form.vertical
        keepRatio.state = form.keepsAspectRatio ? .on : .off
    }

    @objc func chooseUnit(_ sender: NSButton) {
        form.setUnit(ResizeSkewForm.Unit(rawValue: sender.tag) ?? .percentage)
        sync()
    }

    @objc func toggleRatio(_ sender: NSButton) {
        form.keepsAspectRatio = sender.state == .on
        // Turning it back on brings the vertical value in line, as typing would.
        if form.keepsAspectRatio { form.editHorizontal(form.horizontal) }
        sync()
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        switch field {
        case horizontalField: form.editHorizontal(field.stringValue); verticalField.stringValue = form.vertical
        case verticalField: form.editVertical(field.stringValue); horizontalField.stringValue = form.horizontal
        case skewHorizontalField: form.skewHorizontal = field.stringValue
        case skewVerticalField: form.skewVertical = field.stringValue
        default: break
        }
    }

    /// Typing into a field, as the tests and accessibility clients do.
    func type(_ text: String, into field: NSTextField) {
        field.stringValue = text
        controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
    }

    @objc func confirmDialog(_ sender: Any?) {
        let checked = form.validate()
        guard let change = checked.change else {
            if let range = checked.invalid {
                onInvalid?(String(format: L("resize.range"), range.lowerBound, range.upperBound))
            }
            return
        }
        result = change
        stop(.OK)
    }

    @objc func cancelDialog(_ sender: Any?) {
        result = nil
        stop(.cancel)
    }

    private func stop(_ response: NSApplication.ModalResponse) {
        if NSApp.modalWindow === window { NSApp.stopModal(withCode: response) }
        window.orderOut(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        cancelDialog(sender)
        return false
    }
}
