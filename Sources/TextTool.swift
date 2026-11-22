import AppKit

/// How the text of a box looks. As in Paint, it applies to the whole box, not to parts of it.
struct TextFormat: Equatable {
    var family: String
    /// In points, as the Size list shows it.
    var size: Int
    var bold = false
    var italic = false
    var underline = false
    var strikethrough = false

    /// The Size list of the original.
    static let sizes = [8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24, 26, 28, 36, 48, 72]
    /// Sizes typed into the box are kept within this range (a conferir com o original).
    static let sizeRange = 1...999
    /// Paint works at 96 dpi: a point is 4/3 of an image pixel.
    static let pixelsPerPoint: CGFloat = 96.0 / 72.0

    /// The original uses Calibri 11; without it (it comes with Office), Helvetica Neue.
    static var standard: TextFormat {
        TextFormat(family: TextFormat.families.contains("Calibri") ? "Calibri" : "Helvetica Neue", size: 11)
    }

    /// Font families installed on the Mac, sorted for the Font list.
    static let families: [String] = NSFontManager.shared.availableFontFamilies
        .filter { !$0.hasPrefix(".") }
        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

    /// The installed family named `name`, ignoring case, or nil.
    static func family(named name: String) -> String? {
        let wanted = name.trimmingCharacters(in: .whitespaces)
        return families.first { $0.caseInsensitiveCompare(wanted) == .orderedSame }
    }

    var pixelSize: CGFloat { CGFloat(size) * TextFormat.pixelsPerPoint }

    /// The font, plus whether bold or italic had to be imitated because the family lacks them.
    var font: (font: NSFont, fakeBold: Bool, fakeItalic: Bool) {
        let manager = NSFontManager.shared
        var traits: NSFontTraitMask = []
        if bold { traits.insert(.boldFontMask) }
        if italic { traits.insert(.italicFontMask) }
        if let exact = manager.font(withFamily: family, traits: traits, weight: bold ? 9 : 5, size: pixelSize),
           manager.traits(of: exact).contains(traits) {
            return (exact, false, false)
        }
        let plain = manager.font(withFamily: family, traits: [], weight: 5, size: pixelSize)
            ?? NSFont.systemFont(ofSize: pixelSize)
        var font = plain
        if bold { font = manager.convert(font, toHaveTrait: .boldFontMask) }
        if italic { font = manager.convert(font, toHaveTrait: .italicFontMask) }
        let has = manager.traits(of: font)
        return (font, bold && !has.contains(.boldFontMask), italic && !has.contains(.italicFontMask))
    }

    /// Attributes for the whole text in `color`, the same on screen and in the image.
    func attributes(color: RGB) -> [NSAttributedString.Key: Any] {
        let (font, fakeBold, fakeItalic) = self.font
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color.nsColor, .paragraphStyle: paragraph]
        if underline { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if strikethrough { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        // Windows imitates missing bold and italic; so does this.
        if fakeBold { attributes[.strokeWidth] = -3.0; attributes[.strokeColor] = color.nsColor }
        if fakeItalic { attributes[.obliqueness] = 0.2 }
        return attributes
    }
}

/// A text box being typed in: it can still move, stretch and change its format and colors.
/// The image is not touched until the box is fixed; the canvas shows the text over it.
struct TextEdit {
    var rect: PixelRect
    var string = ""
    var format: TextFormat
    /// Opaque boxes paint their whole area with Color 2 first.
    var opaque: Bool
}

/// Lays text out the way the text view on the canvas does, measured in image pixels.
enum TextLayout {
    /// Width of a box made by a click, and the smallest a box can be (a conferir com o original).
    static let clickWidth = 150
    static let minimumWidth = 8

    private static func layout(_ string: String, format: TextFormat, width: Int, color: RGB = .black)
        -> (NSLayoutManager, NSTextContainer, NSTextStorage) {
        let storage = NSTextStorage(string: string, attributes: format.attributes(color: color))
        let manager = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: CGFloat(max(1, width)), height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        manager.ensureLayout(for: container)
        return (manager, container, storage)
    }

    /// Height the text needs at `width`, at least one line (also for an empty last line).
    static func height(of string: String, format: TextFormat, width: Int) -> Int {
        // A trailing letter makes an empty last line count with the box's font.
        let measured = string.isEmpty || string.hasSuffix("\n") ? string + "X" : string
        // The storage owns the layout manager, so it is kept until the end.
        let (manager, container, storage) = layout(measured, format: format, width: width)
        return withExtendedLifetime(storage) { Int(ceil(manager.usedRect(for: container).maxY)) }
    }

    /// Height of one line of `format`.
    static func lineHeight(_ format: TextFormat) -> Int { height(of: "", format: format, width: 1000) }

    /// Draws the text in `color` (and the opaque background in `background`) with antialiasing,
    /// clipped to the box and the image. Returns the area changed; nothing for an empty box.
    @discardableResult
    static func draw(_ edit: TextEdit, color: RGB, background: RGB, on bitmap: inout Bitmap) -> PixelRect {
        let area = edit.rect.intersection(bitmap.bounds)
        guard !edit.string.isEmpty, !area.isEmpty else { return PixelRect(x: 0, y: 0, width: 0, height: 0) }
        let (manager, container, storage) = layout(edit.string, format: edit.format, width: edit.rect.width, color: color)
        defer { withExtendedLifetime(storage) {} }
        let w = bitmap.width, h = bitmap.height
        bitmap.withPixels { pixels in
            guard let context = CGContext(
                data: pixels.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return }
            // Image coordinates: y goes down.
            context.translateBy(x: 0, y: CGFloat(h))
            context.scaleBy(x: 1, y: -1)
            let clip = CGRect(x: area.x, y: area.y, width: area.width, height: area.height)
            context.clip(to: clip)
            if edit.opaque {
                context.setFillColor(background.cgColor)
                context.fill(clip)
            }
            context.setShouldAntialias(true)
            context.setAllowsFontSmoothing(false)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
            let glyphs = manager.glyphRange(for: container)
            manager.drawGlyphs(forGlyphRange: glyphs, at: NSPoint(x: edit.rect.x, y: edit.rect.y))
            NSGraphicsContext.restoreGraphicsState()
            // Core Graphics leaves the unused byte undefined; the document keeps it opaque.
            for y in area.y..<area.maxY {
                for index in (y * w + area.x)..<(y * w + area.maxX) { pixels[index] |= 0xFF00_0000 }
            }
        }
        return area
    }
}

/// Text boxes. Fixing a box with text is one undoable step; undoing while typing drops it.
extension PaintDocument {
    /// Opens a text box at `rect` (clipped to the image), fixing anything still being edited.
    func beginText(_ rect: PixelRect, format: TextFormat, opaque: Bool) {
        fixShape()
        fixText()
        selection = nil
        text = TextEdit(rect: rect, format: format, opaque: opaque)
        updateText { _ in }
    }

    /// Changes the box being edited. It stays inside the image and grows down when the text
    /// does not fit, as in Paint.
    func updateText(_ change: (inout TextEdit) -> Void) {
        guard var edit = text else { return }
        change(&edit)
        edit.rect = fitted(edit)
        text = edit
    }

    /// The box kept inside the image, at least as tall as its text (up to the bottom of the image).
    private func fitted(_ edit: TextEdit) -> PixelRect {
        var rect = edit.rect
        let bounds = bitmap.bounds
        rect.width = max(1, min(max(rect.width, min(TextLayout.minimumWidth, bounds.width)), bounds.width))
        rect.x = min(max(0, rect.x), bounds.width - rect.width)
        rect.y = min(max(0, rect.y), bounds.height - 1)
        let needed = TextLayout.height(of: edit.string, format: edit.format, width: rect.width)
        rect.height = min(max(rect.height, needed), bounds.height - rect.y)
        return rect
    }

    /// Draws the text on the image as one undoable step. An empty box leaves no step.
    func fixText() {
        guard let edit = text else { return }
        text = nil
        guard !edit.string.isEmpty else { return }
        let before = bitmap
        var changed = PixelRect(x: 0, y: 0, width: 0, height: 0)
        let color = color1, background = color2
        draw { changed = TextLayout.draw(edit, color: color, background: background, on: &$0) }
        commit(before: before, changed: changed)
    }

    /// Throws the box away. Returns false when there was none.
    @discardableResult
    func discardText() -> Bool {
        guard text != nil else { return false }
        text = nil
        return true
    }
}

/// The Text tool: a click opens a box of a standard width at the pointer, a drag opens one of
/// the dragged size. The canvas puts a text view over the box for typing; its border moves it,
/// its handles stretch it, and a click outside fixes it.
final class TextTool: Tool {
    let sizes: [Int] = []
    var size = 0
    /// Used for the next box and changed together with the box being edited.
    var format = TextFormat.standard
    var opaque = false

    private enum Mode {
        case creating(start: PixelPoint)
        case moving(start: PixelPoint, from: PixelRect)
        case resizing(SelectionHandle, from: PixelRect)
    }
    private var mode: Mode?

    /// The box being dragged out, for the canvas to outline.
    private(set) var creatingRect: PixelRect?

    func press(at point: PixelPoint, button: MouseButton, host: ToolHost) {
        begin(at: point, hit: .outside, button: button, host: host)
    }

    /// A press with what the canvas knows: where it landed on the box being edited.
    /// Either button opens a box; the text is always in Color 1, as in Paint.
    func begin(at point: PixelPoint, hit: SelectionHit, button: MouseButton, host: ToolHost) {
        let document = host.document
        if let edit = document.text {
            switch hit {
            case .inside: mode = .moving(start: point, from: edit.rect)
            case .handle(let handle): mode = .resizing(handle, from: edit.rect)
            case .outside:
                // A click outside the box fixes it without opening another one.
                document.fixText()
                mode = nil
            }
            return
        }
        mode = .creating(start: point)
        creatingRect = nil
    }

    func drag(to point: PixelPoint, host: ToolHost) {
        let document = host.document
        switch mode {
        case .creating(let start)?:
            creatingRect = point == start ? nil : TextTool.box(from: start, to: point).intersection(document.bitmap.bounds)
        case .moving(let start, let from)?:
            // The box stays whole inside the image.
            let bounds = document.bitmap.bounds
            let x = min(max(0, from.x + point.x - start.x), max(0, bounds.width - from.width))
            let y = min(max(0, from.y + point.y - start.y), max(0, bounds.height - from.height))
            document.updateText { $0.rect = PixelRect(x: x, y: y, width: from.width, height: from.height) }
        case .resizing(let handle, let from)?:
            let rect = handle.resize(from, to: point)
            // The box never gets shorter than its text (see `updateText`).
            document.updateText { $0.rect = rect }
        case nil:
            break
        }
    }

    func release(at point: PixelPoint, host: ToolHost) {
        drag(to: point, host: host)
        let document = host.document
        if case .creating(let start)? = mode {
            let click = PixelRect(x: start.x, y: start.y, width: TextLayout.clickWidth, height: TextLayout.lineHeight(format))
            let rect = creatingRect ?? click.intersection(document.bitmap.bounds)
            creatingRect = nil
            if !rect.isEmpty { document.beginText(rect, format: format, opaque: opaque) }
        }
        mode = nil
    }

    func cancel(host: ToolHost) {
        switch mode {
        case .moving(_, let from)?, .resizing(_, let from)?: host.document.updateText { $0.rect = from }
        default: break
        }
        creatingRect = nil
        mode = nil
    }

    static func box(from a: PixelPoint, to b: PixelPoint) -> PixelRect {
        PixelRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x) + 1, height: abs(b.y - a.y) + 1)
    }
}
