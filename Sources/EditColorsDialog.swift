import AppKit

/// Hue, luminance and saturation on the 0–240 scale of the Windows color dialog
/// (hue 0–239), with its integer conversions.
struct WinHLS: Equatable {
    static let max = 240
    var h: Int
    var l: Int
    var s: Int

    init(h: Int, l: Int, s: Int) {
        self.h = Swift.max(0, Swift.min(WinHLS.max - 1, h))
        self.l = Swift.max(0, Swift.min(WinHLS.max, l))
        self.s = Swift.max(0, Swift.min(WinHLS.max, s))
    }

    init(_ color: RGB) {
        let hlsMax = WinHLS.max, rgbMax = 255
        let r = Int(color.r), g = Int(color.g), b = Int(color.b)
        let cMax = Swift.max(r, g, b), cMin = Swift.min(r, g, b)
        let l = ((cMax + cMin) * hlsMax + rgbMax) / (2 * rgbMax)
        guard cMax != cMin else {
            // Grays have no hue; the dialog shows 160.
            self.init(h: hlsMax * 2 / 3, l: l, s: 0)
            return
        }
        let sum = cMax + cMin, delta = cMax - cMin
        let s = l <= hlsMax / 2 ? (delta * hlsMax + sum / 2) / sum
                                : (delta * hlsMax + (2 * rgbMax - sum) / 2) / (2 * rgbMax - sum)
        let rDelta = ((cMax - r) * (hlsMax / 6) + delta / 2) / delta
        let gDelta = ((cMax - g) * (hlsMax / 6) + delta / 2) / delta
        let bDelta = ((cMax - b) * (hlsMax / 6) + delta / 2) / delta
        var h: Int
        if r == cMax {
            h = bDelta - gDelta
        } else if g == cMax {
            h = hlsMax / 3 + rDelta - bDelta
        } else {
            h = 2 * hlsMax / 3 + gDelta - rDelta
        }
        if h < 0 { h += hlsMax }
        if h >= hlsMax { h -= hlsMax }
        self.init(h: h, l: l, s: s)
    }

    private static func hueToRGB(_ n1: Int, _ n2: Int, _ hue: Int) -> Int {
        let hlsMax = WinHLS.max
        var hue = hue
        if hue < 0 { hue += hlsMax }
        if hue > hlsMax { hue -= hlsMax }
        if hue < hlsMax / 6 { return n1 + ((n2 - n1) * hue + hlsMax / 12) / (hlsMax / 6) }
        if hue < hlsMax / 2 { return n2 }
        if hue < hlsMax * 2 / 3 { return n1 + ((n2 - n1) * (hlsMax * 2 / 3 - hue) + hlsMax / 12) / (hlsMax / 6) }
        return n1
    }

    var rgb: RGB {
        let hlsMax = WinHLS.max, rgbMax = 255
        let clamp = { (value: Int) in UInt8(Swift.max(0, Swift.min(rgbMax, value))) }
        guard s > 0 else {
            let gray = clamp(l * rgbMax / hlsMax)
            return RGB(r: gray, g: gray, b: gray)
        }
        let magic2 = l <= hlsMax / 2 ? (l * (hlsMax + s) + hlsMax / 2) / hlsMax : l + s - (l * s + hlsMax / 2) / hlsMax
        let magic1 = 2 * l - magic2
        let channel = { (hue: Int) in clamp((WinHLS.hueToRGB(magic1, magic2, hue) * rgbMax + hlsMax / 2) / hlsMax) }
        return RGB(r: channel(h + hlsMax / 3), g: channel(h), b: channel(h - hlsMax / 3))
    }
}

/// What the Edit Colors dialog holds, apart from the window so it can be tested.
struct EditColorsModel {
    /// The 48 basic colors of the system color dialog, eight per row, as widely documented
    /// (checked again in phase 8, including the repeated 400040 of the last row).
    static let basicColors: [RGB] = [
        0xFF8080, 0xFFFF80, 0x80FF80, 0x00FF80, 0x80FFFF, 0x0080FF, 0xFF80C0, 0xFF80FF,
        0xFF0000, 0xFFFF00, 0x80FF00, 0x00FF40, 0x00FFFF, 0x0080C0, 0x8080C0, 0xFF00FF,
        0x804040, 0xFF8040, 0x00FF00, 0x008080, 0x004080, 0x8080FF, 0x800040, 0xFF0080,
        0x800000, 0xFF8000, 0x008000, 0x008040, 0x0000FF, 0x0000A0, 0x800080, 0x8000FF,
        0x400000, 0x804000, 0x004000, 0x004040, 0x000080, 0x000040, 0x400040, 0x400080,
        0x000000, 0x808000, 0x808040, 0x808080, 0x408080, 0xC0C0C0, 0x400040, 0xFFFFFF,
    ].map { RGB(r: UInt8($0 >> 16 & 0xFF), g: UInt8($0 >> 8 & 0xFF), b: UInt8($0 & 0xFF)) }
    static let customCount = 16

    private(set) var rgb: RGB
    /// Kept as typed or picked, not recomputed from `rgb`, so hue survives at zero saturation.
    private(set) var hls: WinHLS
    private(set) var customColors: [RGB?]
    /// The custom box the next Add to Custom Colors fills.
    private(set) var selectedCustom = 0

    init(color: RGB, customColors: [RGB?]) {
        rgb = color
        hls = WinHLS(color)
        self.customColors = Array((customColors + [RGB?](repeating: nil, count: EditColorsModel.customCount))
            .prefix(EditColorsModel.customCount))
    }

    mutating func setRGB(_ color: RGB) {
        rgb = color
        hls = WinHLS(color)
    }

    mutating func setHLS(_ value: WinHLS) {
        hls = value
        rgb = value.rgb
    }

    /// A click on the spectrum picks hue and saturation; a color at the ends of the luminance
    /// bar (black or white) moves to the middle so the pick shows.
    mutating func pickSpectrum(hue: Int, saturation: Int) {
        let l = hls.l == 0 || hls.l == WinHLS.max ? WinHLS.max / 2 : hls.l
        setHLS(WinHLS(h: hue, l: l, s: saturation))
    }

    mutating func pickLuminance(_ luminance: Int) {
        setHLS(WinHLS(h: hls.h, l: luminance, s: hls.s))
    }

    /// Selects a custom box; one holding a color also makes it the current color.
    mutating func selectCustom(_ index: Int) {
        guard customColors.indices.contains(index) else { return }
        selectedCustom = index
        if let color = customColors[index] { setRGB(color) }
    }

    /// Add to Custom Colors: the current color goes into the selected box and the next one is selected.
    mutating func addCustom() {
        customColors[selectedCustom] = rgb
        selectedCustom = (selectedCustom + 1) % EditColorsModel.customCount
    }
}

/// A grid of color boxes: the basic and the custom colors of the dialog.
final class SwatchGridView: FlippedView {
    let columns: Int
    let rows: Int
    var colors: [RGB?] { didSet { needsDisplay = true } }
    var selected: Int? { didSet { needsDisplay = true } }
    var onPick: ((Int) -> Void)?
    static let cell = NSSize(width: 28, height: 21)

    init(columns: Int, rows: Int, colors: [RGB?]) {
        self.columns = columns
        self.rows = rows
        self.colors = colors
        super.init(frame: NSRect(x: 0, y: 0, width: CGFloat(columns) * SwatchGridView.cell.width,
                                 height: CGFloat(rows) * SwatchGridView.cell.height))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func cellRect(_ index: Int) -> NSRect {
        NSRect(x: CGFloat(index % columns) * SwatchGridView.cell.width, y: CGFloat(index / columns) * SwatchGridView.cell.height,
               width: SwatchGridView.cell.width, height: SwatchGridView.cell.height)
    }

    func index(at point: NSPoint) -> Int? {
        let column = Int(point.x / SwatchGridView.cell.width), row = Int(point.y / SwatchGridView.cell.height)
        guard (0..<columns).contains(column), (0..<rows).contains(row), point.x >= 0, point.y >= 0 else { return nil }
        return row * columns + column
    }

    override func mouseDown(with event: NSEvent) {
        guard let index = index(at: convert(event.locationInWindow, from: nil)) else { return }
        onPick?(index)
    }

    override func draw(_ dirtyRect: NSRect) {
        for index in 0..<(columns * rows) {
            let box = cellRect(index).insetBy(dx: 3, dy: 3)
            if index == selected {
                NSColor.black.setStroke()
                NSBezierPath(rect: box.insetBy(dx: -1.5, dy: -1.5)).stroke()
            }
            RibbonTheme.rgb(0x808080).setFill()
            NSRect(x: box.minX, y: box.minY, width: box.width, height: 1).fill()
            NSRect(x: box.minX, y: box.minY, width: 1, height: box.height).fill()
            NSColor.white.setFill()
            NSRect(x: box.minX, y: box.maxY - 1, width: box.width, height: 1).fill()
            NSRect(x: box.maxX - 1, y: box.minY, width: 1, height: box.height).fill()
            ((colors.indices.contains(index) ? colors[index] : nil)?.nsColor ?? NSColor.white).setFill()
            box.insetBy(dx: 1, dy: 1).fill()
        }
    }
}

/// The hue (across) and saturation (down) spectrum, at the middle luminance, with a cross at the pick.
final class SpectrumView: FlippedView {
    var hls = WinHLS(h: 0, l: 120, s: 0) { didSet { needsDisplay = true } }
    var onPick: ((Int, Int) -> Void)?
    private var cached: CGImage?

    /// Hue and saturation at `point`.
    func value(at point: NSPoint) -> (hue: Int, saturation: Int) {
        let x = max(0, min(bounds.width - 1, point.x)), y = max(0, min(bounds.height - 1, point.y))
        return (Int(x / bounds.width * CGFloat(WinHLS.max)), WinHLS.max - Int((y / (bounds.height - 1) * CGFloat(WinHLS.max)).rounded()))
    }

    override func mouseDown(with event: NSEvent) { pick(event) }
    override func mouseDragged(with event: NSEvent) { pick(event) }

    private func pick(_ event: NSEvent) {
        let value = value(at: convert(event.locationInWindow, from: nil))
        onPick?(value.hue, value.saturation)
    }

    private func spectrum() -> CGImage? {
        if let cached = cached { return cached }
        let width = 120, height = 100
        var bitmap = Bitmap(width: width, height: height)
        for y in 0..<height {
            for x in 0..<width {
                let color = WinHLS(h: x * WinHLS.max / width, l: WinHLS.max / 2, s: WinHLS.max - y * WinHLS.max / (height - 1)).rgb
                bitmap.set(x: x, y: y, to: color.packed)
            }
        }
        cached = bitmap.makeImage()
        return cached
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext, let image = spectrum() else { return }
        context.saveGState()
        context.interpolationQuality = .high
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: bounds.size))
        context.restoreGState()
        // The cross at the current hue and saturation.
        let x = floor(CGFloat(hls.h) / CGFloat(WinHLS.max) * bounds.width)
        let y = floor(CGFloat(WinHLS.max - hls.s) / CGFloat(WinHLS.max) * (bounds.height - 1))
        NSColor.black.setFill()
        for (dx, dy, w, h) in [(-9.0, -1.0, 6.0, 3.0), (4.0, -1.0, 6.0, 3.0), (-1.0, -9.0, 3.0, 6.0), (-1.0, 4.0, 3.0, 6.0)] {
            NSRect(x: x + CGFloat(dx), y: y + CGFloat(dy), width: CGFloat(w), height: CGFloat(h)).fill()
        }
        RibbonTheme.rgb(0x808080).setStroke()
        NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5)).stroke()
    }
}

/// The luminance bar for the current hue and saturation, white on top, with the arrow beside it.
final class LuminanceView: FlippedView {
    static let barWidth: CGFloat = 12
    var hls = WinHLS(h: 0, l: 120, s: 0) { didSet { needsDisplay = true } }
    var onPick: ((Int) -> Void)?

    func luminance(at point: NSPoint) -> Int {
        let y = max(0, min(bounds.height - 1, point.y))
        return WinHLS.max - Int((y / (bounds.height - 1) * CGFloat(WinHLS.max)).rounded())
    }

    override func mouseDown(with event: NSEvent) { onPick?(luminance(at: convert(event.locationInWindow, from: nil))) }
    override func mouseDragged(with event: NSEvent) { onPick?(luminance(at: convert(event.locationInWindow, from: nil))) }

    override func draw(_ dirtyRect: NSRect) {
        let bar = NSRect(x: 0, y: 0, width: LuminanceView.barWidth, height: bounds.height)
        let steps = 60
        for step in 0..<steps {
            let l = WinHLS.max - step * WinHLS.max / (steps - 1)
            WinHLS(h: hls.h, l: l, s: hls.s).rgb.nsColor.setFill()
            NSRect(x: bar.minX, y: floor(CGFloat(step) * bar.height / CGFloat(steps)), width: bar.width,
                   height: ceil(bar.height / CGFloat(steps)) + 1).fill()
        }
        RibbonTheme.rgb(0x808080).setStroke()
        NSBezierPath(rect: bar.insetBy(dx: 0.5, dy: 0.5)).stroke()
        let y = CGFloat(WinHLS.max - hls.l) / CGFloat(WinHLS.max) * (bounds.height - 1)
        let arrow = NSBezierPath()
        arrow.move(to: NSPoint(x: bar.maxX + 2, y: y))
        arrow.line(to: NSPoint(x: bar.maxX + 8, y: y - 5))
        arrow.line(to: NSPoint(x: bar.maxX + 8, y: y + 5))
        arrow.close()
        NSColor.black.setFill()
        arrow.fill()
    }
}

/// The Color|Solid box: the current color.
final class ColorPreviewView: FlippedView {
    var color = RGB.black { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        color.nsColor.setFill()
        bounds.fill()
        RibbonTheme.rgb(0x808080).setStroke()
        NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5)).stroke()
    }
}

/// Edit Colors, after the Windows color dialog with custom colors open: basic and custom colors,
/// spectrum, luminance, the six fields, Add to Custom Colors, OK and Cancel.
final class EditColorsDialog: NSObject, NSTextFieldDelegate, NSWindowDelegate {
    static let size = NSSize(width: 510, height: 314)

    let window: NSPanel
    let content: FlippedView
    private(set) var model: EditColorsModel
    let basicGrid: SwatchGridView
    let customGrid: SwatchGridView
    let spectrum = SpectrumView(frame: NSRect(x: 242, y: 10, width: 226, height: 166))
    let luminance = LuminanceView(frame: NSRect(x: 476, y: 10, width: 24, height: 166))
    let preview = ColorPreviewView(frame: NSRect(x: 242, y: 188, width: 44, height: 32))
    /// Hue, Sat, Lum, Red, Green, Blue.
    let fields = (0..<6).map { _ in NSTextField(string: "") }
    let defineButton = NSButton(title: L("editColors.define"), target: nil, action: nil)
    let addButton = NSButton(title: L("editColors.add"), target: nil, action: nil)
    let okButton = NSButton(title: L("ok"), target: nil, action: nil)
    let cancelButton = NSButton(title: L("cancel"), target: nil, action: nil)
    private(set) var result: RGB?
    /// The field being typed in, which is not rewritten while typing.
    private var editing: NSTextField?

    static let fieldKeys = ["editColors.hue", "editColors.sat", "editColors.lum", "editColors.red", "editColors.green", "editColors.blue"]

    init(color: RGB, customColors: [RGB?]) {
        model = EditColorsModel(color: color, customColors: customColors)
        basicGrid = SwatchGridView(columns: 8, rows: 6, colors: EditColorsModel.basicColors.map { Optional($0) })
        customGrid = SwatchGridView(columns: 8, rows: 2, colors: model.customColors)
        content = FlippedView(frame: NSRect(origin: .zero, size: EditColorsDialog.size))
        window = NSPanel(contentRect: NSRect(origin: .zero, size: EditColorsDialog.size), styleMask: [.titled, .closable],
                         backing: .buffered, defer: false)
        super.init()
        window.title = L("editColors.title")
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.delegate = self
        build()
        ScaledContentView.install(content, in: window)
        sync()
    }

    private func label(_ key: String, at origin: NSPoint) -> NSTextField {
        let text = NSTextField(labelWithString: L(key))
        text.sizeToFit()
        text.frame.origin = origin
        content.addSubview(text)
        return text
    }

    private func build() {
        let basicLabel = label("editColors.basic", at: NSPoint(x: 10, y: 8))
        basicGrid.frame.origin = NSPoint(x: 8, y: basicLabel.frame.maxY + 2)
        let customLabel = label("editColors.custom", at: NSPoint(x: 10, y: basicGrid.frame.maxY + 8))
        customGrid.frame.origin = NSPoint(x: 8, y: customLabel.frame.maxY + 2)
        basicGrid.onPick = { [weak self] index in self?.pickBasic(index) }
        customGrid.onPick = { [weak self] index in self?.pickCustom(index) }
        spectrum.onPick = { [weak self] hue, saturation in self?.change { $0.pickSpectrum(hue: hue, saturation: saturation) } }
        luminance.onPick = { [weak self] value in self?.change { $0.pickLuminance(value) } }
        [basicGrid, customGrid, spectrum, luminance, preview].forEach(content.addSubview)
        defineButton.frame = NSRect(x: 8, y: customGrid.frame.maxY + 8, width: basicGrid.frame.width, height: 28)
        defineButton.isEnabled = false
        content.addSubview(defineButton)
        let buttonY = EditColorsDialog.size.height - 40
        let buttonWidth = dialogButtonWidth([okButton, cancelButton])
        okButton.frame = NSRect(x: 8, y: buttonY, width: buttonWidth, height: 28)
        cancelButton.frame = NSRect(x: okButton.frame.maxX + 6, y: buttonY, width: buttonWidth, height: 28)
        okButton.keyEquivalent = "\r"
        cancelButton.keyEquivalent = "\u{1b}"
        okButton.target = self
        okButton.action = #selector(confirmDialog(_:))
        cancelButton.target = self
        cancelButton.action = #selector(cancelDialog(_:))
        [okButton, cancelButton].forEach(content.addSubview)
        let solid = label("editColors.solid", at: NSPoint(x: preview.frame.minX, y: preview.frame.maxY + 1))
        // Small, under the box, as in the original.
        solid.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        solid.sizeToFit()
        // Two columns of three fields, labels right-aligned to their fields.
        let labels = EditColorsDialog.fieldKeys.map { key -> NSTextField in
            let text = NSTextField(labelWithString: L(key))
            text.alignment = .right
            text.sizeToFit()
            return text
        }
        let fieldWidth: CGFloat = 38
        let right = EditColorsDialog.size.width - 10
        let secondWidth = labels[3...].map(\.frame.width).max() ?? 0
        let secondField = right - fieldWidth
        let secondLabel = secondField - 3 - secondWidth
        let firstField = secondLabel - 8 - fieldWidth
        for (index, field) in fields.enumerated() {
            let column = index / 3, row = CGFloat(index % 3)
            let y = preview.frame.minY + row * 25
            let text = labels[index]
            let fieldX = column == 0 ? firstField : secondField
            text.frame.origin = NSPoint(x: fieldX - 3 - text.frame.width, y: y + 3)
            field.frame = NSRect(x: fieldX, y: y, width: fieldWidth, height: 22)
            field.alignment = .right
            field.delegate = self
            field.setAccessibilityLabel(L(EditColorsDialog.fieldKeys[index]))
            content.addSubview(text)
            content.addSubview(field)
        }
        addButton.frame = NSRect(x: spectrum.frame.minX, y: buttonY, width: right - spectrum.frame.minX, height: 28)
        addButton.target = self
        addButton.action = #selector(addCustomColor(_:))
        content.addSubview(addButton)
    }

    /// Fields and pictures from the model; the field being typed in keeps its text.
    private func sync() {
        let values = [model.hls.h, model.hls.s, model.hls.l, Int(model.rgb.r), Int(model.rgb.g), Int(model.rgb.b)]
        for (field, value) in zip(fields, values) where field !== editing { field.stringValue = String(value) }
        spectrum.hls = model.hls
        luminance.hls = model.hls
        preview.color = model.rgb
        customGrid.colors = model.customColors
        customGrid.selected = model.selectedCustom
        basicGrid.selected = EditColorsModel.basicColors.firstIndex(of: model.rgb)
    }

    private func change(_ body: (inout EditColorsModel) -> Void) {
        editing = nil
        body(&model)
        sync()
    }

    func pickBasic(_ index: Int) {
        guard EditColorsModel.basicColors.indices.contains(index) else { return }
        change { $0.setRGB(EditColorsModel.basicColors[index]) }
    }

    func pickCustom(_ index: Int) { change { $0.selectCustom(index) } }

    @objc func addCustomColor(_ sender: Any?) { change { $0.addCustom() } }

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField, let index = fields.firstIndex(of: field) else { return }
        let number = { (field: NSTextField) in Int(field.stringValue.trimmingCharacters(in: .whitespaces)) ?? 0 }
        editing = field
        if index < 3 {
            model.setHLS(WinHLS(h: number(fields[0]), l: number(fields[2]), s: number(fields[1])))
        } else {
            let channel = { (field: NSTextField) in UInt8(max(0, min(255, number(field)))) }
            model.setRGB(RGB(r: channel(fields[3]), g: channel(fields[4]), b: channel(fields[5])))
        }
        sync()
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        editing = nil
        sync()
    }

    /// Typing into a field, as the tests and accessibility clients do.
    func type(_ text: String, into field: NSTextField) {
        field.stringValue = text
        controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
        controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: field))
    }

    @objc func confirmDialog(_ sender: Any?) {
        result = model.rgb
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
    var activeColor: RGB { activeColorSlot == .color1 ? document.color1 : document.color2 }

    func makeEditColorsDialog() -> EditColorsDialog {
        EditColorsDialog(color: activeColor, customColors: AppSettings.colors(AppSettings.dialogColorsKey, count: EditColorsModel.customCount))
    }

    /// Edit colors: the chosen color goes to the active color and to the next custom place of the palette.
    @objc func showEditColors(_ sender: Any?) {
        let dialog = makeEditColorsDialog()
        let response = runDialog(dialog.window)
        // The dialog's own custom colors are kept even when it is cancelled, as in Windows.
        AppSettings.setColors(dialog.model.customColors, forKey: AppSettings.dialogColorsKey)
        guard response == .OK, let color = dialog.result else { return }
        applyEditedColor(color)
    }

    func applyEditedColor(_ color: RGB) {
        switch activeColorSlot {
        case .color1: document.color1 = color
        case .color2: document.color2 = color
        }
        // In black-and-white mode the color became black or white and the custom places are hidden.
        if !document.blackAndWhite { addCustomColor(color) }
        canvas.redrawShape()
        syncInterface()
    }

    /// Fills the custom places of the palette in order; once all ten are used, the oldest goes
    /// first (a conferir com o original).
    func addCustomColor(_ color: RGB) {
        var colors = customColors
        let index: Int
        if let empty = colors.firstIndex(where: { $0 == nil }) {
            index = empty
        } else {
            index = AppSettings.defaults.integer(forKey: AppSettings.nextCustomColorKey) % colors.count
        }
        colors[index] = color
        AppSettings.defaults.set((index + 1) % colors.count, forKey: AppSettings.nextCustomColorKey)
        customColors = colors
    }
}
