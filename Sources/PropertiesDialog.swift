import AppKit

/// What Image Properties changes: the size in pixels and, optionally, black and white.
struct ImageProperties: Equatable {
    var width: Int
    var height: Int
    var blackAndWhite: Bool
}

/// The values of the Image Properties dialog, apart from the window so they can be tested.
struct ImagePropertiesForm {
    enum Unit: Int, CaseIterable { case inches, centimeters, pixels }

    /// Paint's resolution.
    static let dpi = 96.0
    /// Limits of Width and Height in pixels (a conferir com o original).
    static let pixelRange = 1...10000

    let defaultWidth: Int
    let defaultHeight: Int
    private(set) var unit = Unit.pixels
    private(set) var width: String
    private(set) var height: String
    var blackAndWhite: Bool

    init(width: Int, height: Int, blackAndWhite: Bool, defaultWidth: Int, defaultHeight: Int) {
        self.width = String(width)
        self.height = String(height)
        self.blackAndWhite = blackAndWhite
        self.defaultWidth = defaultWidth
        self.defaultHeight = defaultHeight
    }

    /// `pixels` written in `unit`: whole pixels, or inches and centimetres with two decimals.
    static func text(_ pixels: Int, in unit: Unit, locale: Locale = .current) -> String {
        guard unit != .pixels else { return String(pixels) }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let inches = Double(pixels) / dpi
        return formatter.string(from: NSNumber(value: unit == .inches ? inches : inches * 2.54)) ?? ""
    }

    /// The pixels typed as `text` in `unit`, rounded; nil when it is not a number. A comma or
    /// a point is taken as the decimal separator.
    static func pixels(_ text: String, in unit: Unit) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(trimmed), value.isFinite else { return nil }
        switch unit {
        case .pixels: return Int(value.rounded())
        case .inches: return Int((value * dpi).rounded())
        case .centimeters: return Int((value / 2.54 * dpi).rounded())
        }
    }

    /// Changing the unit rewrites the typed values in the new unit.
    mutating func setUnit(_ new: Unit) {
        guard new != unit else { return }
        if let w = ImagePropertiesForm.pixels(width, in: unit) { width = ImagePropertiesForm.text(w, in: new) }
        if let h = ImagePropertiesForm.pixels(height, in: unit) { height = ImagePropertiesForm.text(h, in: new) }
        unit = new
    }

    mutating func editWidth(_ text: String) { width = text }
    mutating func editHeight(_ text: String) { height = text }

    /// Default: the size of a new picture, in the current unit.
    mutating func restoreDefault() {
        width = ImagePropertiesForm.text(defaultWidth, in: unit)
        height = ImagePropertiesForm.text(defaultHeight, in: unit)
    }

    /// The new properties, or nil when a value is out of `pixelRange`.
    func validate() -> ImageProperties? {
        let range = ImagePropertiesForm.pixelRange
        guard let w = ImagePropertiesForm.pixels(width, in: unit), range.contains(w),
              let h = ImagePropertiesForm.pixels(height, in: unit), range.contains(h) else { return nil }
        return ImageProperties(width: w, height: h, blackAndWhite: blackAndWhite)
    }
}

extension PaintDocument {
    /// Whether every pixel is black or white, which the dialog shows as Black and white.
    var isBlackAndWhite: Bool {
        let black = RGB.black.packed, white = RGB.white.packed
        var bitmap = self.bitmap
        return bitmap.withPixels { pixels in pixels.allSatisfy { $0 == black || $0 == white } }
    }

    /// Image Properties OK: the new size (new area in Color 2, as the canvas handles do), the
    /// conversion to black and white and the switch of the mode, together as one undoable step.
    /// Going back to Color keeps the pixels and gives the palette back.
    func applyProperties(_ properties: ImageProperties) {
        let resize = properties.width != bitmap.width || properties.height != bitmap.height
        let switchMode = properties.blackAndWhite != blackAndWhite
        guard resize || switchMode || (blackAndWhite && !isBlackAndWhite) else { return }
        // A shape or a text box still being edited becomes its own step, in the old mode.
        fixShape()
        fixText()
        selection = nil
        let before = bitmap, oldMode = blackAndWhite
        blackAndWhite = properties.blackAndWhite
        if resize {
            let result = bitmap.cropped(to: PixelRect(x: 0, y: 0, width: properties.width, height: properties.height),
                                        fill: color2.packed)
            draw { $0 = result }
        }
        // `commit` turns the whole image into black and white in that mode.
        commit(before: before, changed: bitmap.bounds, mode: switchMode ? (oldMode, blackAndWhite) : nil)
    }
}

extension RGB {
    /// Black or white by brightness, the threshold of Image Properties > Black and white.
    var blackOrWhite: RGB {
        299 * Int(r) + 587 * Int(g) + 114 * Int(b) >= 128_000 ? .white : .black
    }
}

extension Bitmap {
    /// Each pixel black or white by its brightness (a conferir com o original, which may dither).
    func blackAndWhite() -> Bitmap {
        var result = self
        result.makeBlackAndWhite(in: bounds)
        return result
    }

    /// Turns the pixels of `rect` black or white by their brightness.
    mutating func makeBlackAndWhite(in rect: PixelRect) {
        let area = rect.intersection(bounds)
        guard !area.isEmpty else { return }
        let black = RGB.black.packed, white = RGB.white.packed, w = width
        withPixels { pixels in
            for y in area.y..<(area.y + area.height) {
                for index in (y * w + area.x)..<(y * w + area.x + area.width) {
                    let value = pixels[index]
                    guard value != black, value != white else { continue }
                    pixels[index] = RGB(packed: value).blackOrWhite == .white ? white : black
                }
            }
        }
    }
}

/// Image Properties: file attributes, Units, Colors, Width and Height, Default, OK and Cancel,
/// laid out after the original (a conferir com o original).
final class ImagePropertiesDialog: NSObject, NSTextFieldDelegate, NSWindowDelegate {
    /// The narrowest the dialog gets; it widens when the Width, Height and Default row needs it.
    static let width: CGFloat = 320
    static let margin: CGFloat = 12
    private(set) var dialogWidth = ImagePropertiesDialog.width

    let window: NSPanel
    private(set) var form: ImagePropertiesForm
    let savedLabel: NSTextField
    let diskLabel: NSTextField
    let resolutionLabel: NSTextField
    let unitButtons = ImagePropertiesForm.Unit.allCases.map { unit -> NSButton in
        let key = ["properties.inches", "properties.centimeters", "properties.pixels"][unit.rawValue]
        return NSButton(radioButtonWithTitle: L(key), target: nil, action: nil)
    }
    let blackAndWhiteButton = NSButton(radioButtonWithTitle: L("properties.blackAndWhite"), target: nil, action: nil)
    let colorButton = NSButton(radioButtonWithTitle: L("properties.color"), target: nil, action: nil)
    let widthField = NSTextField(string: "")
    let heightField = NSTextField(string: "")
    let defaultButton = NSButton(title: L("properties.default"), target: nil, action: nil)
    let okButton = NSButton(title: L("ok"), target: nil, action: nil)
    let cancelButton = NSButton(title: L("cancel"), target: nil, action: nil)
    let content: FlippedView
    var onInvalid: ((String) -> Void)?
    private(set) var result: ImageProperties?

    init(form: ImagePropertiesForm, saved: Date?, diskBytes: Int?) {
        self.form = form
        let none = L("properties.notAvailable")
        let date = saved.map { DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .short) } ?? none
        savedLabel = NSTextField(labelWithString: String(format: L("properties.saved"), date))
        diskLabel = NSTextField(labelWithString: String(format: L("properties.disk"), diskBytes.map(StatusText.byteCount) ?? none))
        resolutionLabel = NSTextField(labelWithString: String(format: L("properties.resolution"), Int(ImagePropertiesForm.dpi)))
        content = FlippedView(frame: NSRect(x: 0, y: 0, width: ImagePropertiesDialog.width, height: 100))
        window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: ImagePropertiesDialog.width, height: 100),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init()
        window.title = L("properties.title")
        // Light, like the rest of the Windows 7 look, even when the Mac is in dark mode.
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.delegate = self
        build()
        ScaledContentView.install(content, in: window)
        sync()
    }

    private func box(_ key: String, y: CGFloat, height: CGFloat) -> NSBox {
        let box = NSBox(frame: NSRect(x: ImagePropertiesDialog.margin, y: y,
                                      width: dialogWidth - 2 * ImagePropertiesDialog.margin, height: height))
        box.title = L(key)
        content.addSubview(box)
        return box
    }

    /// Radio buttons left to right inside a box, from its left edge.
    private func row(_ buttons: [NSButton], y: CGFloat) {
        var x = ImagePropertiesDialog.margin + 14
        for button in buttons {
            button.sizeToFit()
            button.frame.origin = NSPoint(x: x, y: y)
            x = button.frame.maxX + 14
            content.addSubview(button)
        }
    }

    private func build() {
        let m = ImagePropertiesDialog.margin
        // Width, Height and Default on one row under the boxes, measured first.
        let rowLabels = [L("properties.width"), L("properties.height")].map { NSTextField(labelWithString: $0) }
        rowLabels.forEach { $0.sizeToFit() }
        defaultButton.sizeToFit()
        let defaultWidth = max(76, defaultButton.frame.width)
        let rowWidth = m + rowLabels.map { $0.frame.width + 4 + 64 + 12 }.reduce(0, +) + defaultWidth + m
        dialogWidth = max(ImagePropertiesDialog.width, ceil(rowWidth))
        content.frame.size.width = dialogWidth
        let attributes = box("properties.attributes", y: 6, height: 88)
        var y = attributes.frame.minY + 24
        for label in [savedLabel, diskLabel, resolutionLabel] {
            label.sizeToFit()
            label.frame.origin = NSPoint(x: m + 14, y: y)
            content.addSubview(label)
            y += 19
        }
        let units = box("properties.units", y: attributes.frame.maxY + 6, height: 52)
        row(unitButtons, y: units.frame.minY + 24)
        for (index, button) in unitButtons.enumerated() {
            button.tag = index
            button.target = self
            button.action = #selector(chooseUnit(_:))
        }
        let colors = box("properties.colors", y: units.frame.maxY + 6, height: 52)
        row([blackAndWhiteButton, colorButton], y: colors.frame.minY + 24)
        for button in [blackAndWhiteButton, colorButton] {
            button.target = self
            button.action = #selector(chooseColors(_:))
        }
        y = colors.frame.maxY + 14
        var x = m
        for ((key, field), label) in zip([("properties.width", widthField), ("properties.height", heightField)], rowLabels) {
            label.frame.origin = NSPoint(x: x, y: y + 3)
            content.addSubview(label)
            field.frame = NSRect(x: label.frame.maxX + 4, y: y, width: 64, height: 22)
            field.alignment = .right
            field.delegate = self
            field.setAccessibilityLabel(L(key))
            content.addSubview(field)
            x = field.frame.maxX + 12
        }
        defaultButton.frame = NSRect(x: dialogWidth - m - defaultWidth, y: y - 3, width: defaultWidth, height: 28)
        defaultButton.target = self
        defaultButton.action = #selector(restoreDefault(_:))
        content.addSubview(defaultButton)
        y += 40
        let buttonWidth = dialogButtonWidth([okButton, cancelButton])
        okButton.frame = NSRect(x: dialogWidth - m - 2 * buttonWidth - 6, y: y, width: buttonWidth, height: 28)
        cancelButton.frame = NSRect(x: dialogWidth - m - buttonWidth, y: y, width: buttonWidth, height: 28)
        okButton.keyEquivalent = "\r"
        cancelButton.keyEquivalent = "\u{1b}"
        okButton.target = self
        okButton.action = #selector(confirmDialog(_:))
        cancelButton.target = self
        cancelButton.action = #selector(cancelDialog(_:))
        [okButton, cancelButton].forEach(content.addSubview)
        content.frame.size.height = y + 28 + m
        window.initialFirstResponder = widthField
    }

    private func sync() {
        for button in unitButtons { button.state = button.tag == form.unit.rawValue ? .on : .off }
        blackAndWhiteButton.state = form.blackAndWhite ? .on : .off
        colorButton.state = form.blackAndWhite ? .off : .on
        widthField.stringValue = form.width
        heightField.stringValue = form.height
    }

    @objc func chooseUnit(_ sender: NSButton) {
        form.setUnit(ImagePropertiesForm.Unit(rawValue: sender.tag) ?? .pixels)
        sync()
    }

    @objc func chooseColors(_ sender: NSButton) {
        form.blackAndWhite = sender === blackAndWhiteButton
        sync()
    }

    @objc func restoreDefault(_ sender: Any?) {
        form.restoreDefault()
        sync()
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        if field === widthField { form.editWidth(field.stringValue) }
        if field === heightField { form.editHeight(field.stringValue) }
    }

    /// Typing into a field, as the tests and accessibility clients do.
    func type(_ text: String, into field: NSTextField) {
        field.stringValue = text
        controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
    }

    @objc func confirmDialog(_ sender: Any?) {
        guard let properties = form.validate() else {
            let range = ImagePropertiesForm.pixelRange
            onInvalid?(String(format: L("properties.range"), range.lowerBound, range.upperBound))
            return
        }
        result = properties
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

extension MainWindowController {
    /// When the open file was last saved, for Image Properties.
    static func savedDate(of url: URL?) -> Date? {
        guard let url = url else { return nil }
        return (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    func makePropertiesDialog() -> ImagePropertiesDialog {
        canvas.finishEditing()
        let bitmap = document.bitmap
        let form = ImagePropertiesForm(width: bitmap.width, height: bitmap.height, blackAndWhite: document.blackAndWhite,
                                       defaultWidth: MainWindowController.defaultSize.width,
                                       defaultHeight: MainWindowController.defaultSize.height)
        let dialog = ImagePropertiesDialog(form: form, saved: MainWindowController.savedDate(of: document.url), diskBytes: fileSize)
        dialog.onInvalid = { [weak self] message in
            let alert = NSAlert()
            alert.messageText = message
            _ = self?.runAlert(alert)
        }
        return dialog
    }

    /// Image Properties (Ctrl+E).
    @objc func showImageProperties(_ sender: Any?) {
        let dialog = makePropertiesDialog()
        guard runDialog(dialog.window) == .OK, let result = dialog.result else { return }
        applyProperties(result)
    }

    func applyProperties(_ properties: ImageProperties) {
        document.applyProperties(properties)
        documentChanged()
    }
}
