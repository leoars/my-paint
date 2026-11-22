import Foundation

/// The open image plus everything that belongs to it: file, colors and undo history.
final class PaintDocument {
    /// Paint keeps 50 levels of undo.
    static let undoLimit = 50

    private(set) var bitmap: Bitmap
    var url: URL?
    var format: ImageFormat = .png
    var isDirty = false
    /// In black-and-white mode the two colors can only be black or white (by brightness).
    var color1 = RGB.black { didSet { if blackAndWhite { color1 = color1.blackOrWhite } } }
    var color2 = RGB.white { didSet { if blackAndWhite { color2 = color2.blackOrWhite } } }
    /// The marked area and, once moved or changed, its floating pixels (see Selection.swift).
    var selection: Selection?
    /// Image > Select > Transparent selection: Color 2 pixels of a floating selection let the image show through.
    var transparentSelection = false
    /// A shape still being adjusted with its handles (see ShapeTool.swift); the bitmap already shows it.
    var shape: ShapeEdit?
    /// Black-and-white mode (Image Properties > Black and white, or a 1-bit BMP opened): the palette
    /// shows only black and white, both colors are black or white and every step is turned into
    /// black and white when it is recorded (see `commit`). Entering it makes Color 1 black and Color 2 white.
    var blackAndWhite = false {
        didSet {
            guard blackAndWhite != oldValue, blackAndWhite else { return }
            color1 = .black
            color2 = .white
        }
    }
    /// A text box still being typed in (see TextTool.swift); the image does not show it yet.
    var text: TextEdit?

    private enum Change {
        case region(PixelRect, before: [UInt32], after: [UInt32])
        case whole(before: Bitmap, after: Bitmap)
    }

    /// One undoable step: pixels changed and, for Image Properties, the black-and-white mode switched.
    private struct Step {
        var change: Change?
        var mode: (before: Bool, after: Bool)?
    }

    private var undoStack: [Step] = []
    private var redoStack: [Step] = []

    /// Undo also drops a shape or a text box being edited; redo waits until it is fixed.
    var canUndo: Bool { !undoStack.isEmpty || shape != nil || text != nil }
    var canRedo: Bool { !redoStack.isEmpty && shape == nil && text == nil }

    init(bitmap: Bitmap, url: URL? = nil, format: ImageFormat = .png) {
        self.bitmap = bitmap
        self.url = url
        self.format = format
    }

    /// Edits the image without recording history; pair with `commit` or `revert`.
    func draw(_ body: (inout Bitmap) -> Void) {
        body(&bitmap)
    }

    /// Records one undoable step covering everything drawn since `before` was taken.
    /// In black-and-white mode the changed area (and a floating selection) is turned into black
    /// and white first, so antialiased brushes, shapes and text end up black or white.
    /// `mode` records a switch of the black-and-white mode in the same step.
    func commit(before: Bitmap, changed: PixelRect, mode: (before: Bool, after: Bool)? = nil) {
        let resized = before.width != bitmap.width || before.height != bitmap.height
        let rect = (resized ? bitmap.bounds : changed).intersection(bitmap.bounds)
        if blackAndWhite { enforceBlackAndWhite(in: rect) }
        let change: Change?
        if resized {
            change = .whole(before: before, after: bitmap)
        } else if !rect.isEmpty, case let (old, new) = (before.region(rect), bitmap.region(rect)), old != new {
            change = .region(rect, before: old, after: new)
        } else {
            change = nil
        }
        guard change != nil || mode != nil else { return }
        push(Step(change: change, mode: mode))
    }

    /// Turns `rect` and the pixels of a floating selection into black and white.
    private func enforceBlackAndWhite(in rect: PixelRect) {
        if var s = selection, let content = s.content, let base = s.base {
            s.content = content.blackAndWhite()
            s.base = base.blackAndWhite()
            selection = s
            composite(replacing: s.rect)
        }
        guard !rect.isEmpty else { return }
        bitmap.makeBlackAndWhite(in: rect)
    }

    /// Starts over with `newBitmap`, with no selection and no history.
    func replaceImage(_ newBitmap: Bitmap) {
        bitmap = newBitmap
        selection = nil
        shape = nil
        text = nil
        undoStack.removeAll()
        redoStack.removeAll()
        isDirty = false
    }

    /// Throws away uncommitted drawing, as when a stroke is cancelled.
    func revert(to before: Bitmap) {
        bitmap = before
    }

    private func push(_ change: Step) {
        undoStack.append(change)
        if undoStack.count > PaintDocument.undoLimit { undoStack.removeFirst() }
        redoStack.removeAll()
        isDirty = true
    }

    @discardableResult
    func undo() -> Bool {
        // Undoing while a shape is being edited throws the shape away, as in Paint.
        if discardShape() || discardText() { return true }
        guard let step = undoStack.popLast() else { return false }
        // The image already holds the floating pixels, so dropping the selection keeps what is shown.
        selection = nil
        switch step.change {
        case .region(let rect, let before, _)?: bitmap.write(before, to: rect)
        case .whole(let before, _)?: bitmap = before
        case nil: break
        }
        if let mode = step.mode { blackAndWhite = mode.before }
        redoStack.append(step)
        isDirty = true
        return true
    }

    @discardableResult
    func redo() -> Bool {
        fixShape()
        fixText()
        guard let step = redoStack.popLast() else { return false }
        selection = nil
        switch step.change {
        case .region(let rect, _, let after)?: bitmap.write(after, to: rect)
        case .whole(_, let after)?: bitmap = after
        case nil: break
        }
        if let mode = step.mode { blackAndWhite = mode.after }
        undoStack.append(step)
        isDirty = true
        return true
    }
}
