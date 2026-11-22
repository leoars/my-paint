import Foundation

/// A shape drawn but not yet fixed: it can still move, stretch and change its outline, fill,
/// width and colors. The document bitmap always shows it, drawn over `base`.
struct ShapeEdit {
    enum Stage: Equatable {
        /// Drawn: the box with handles is shown.
        case complete
        /// A curve waiting for its first or second control point.
        case curveControl(Int)
        /// A polygon taking more vertices.
        case polygonOpen
    }

    var shape: DrawnShape
    var stage: Stage
    /// The left button outlines with Color 1 and fills with Color 2; the right button swaps them.
    let button: MouseButton
    var options: ShapeOptions
    /// The image under the shape.
    let base: Bitmap
    /// Pixels the shape was last drawn on.
    var drawn: PixelRect
}

/// Shapes being edited. Fixing a shape is one undoable step; undoing while editing drops it.
extension PaintDocument {
    /// Starts editing `shape` over the current image, fixing any shape still being edited.
    func beginShape(_ shape: DrawnShape, stage: ShapeEdit.Stage = .complete, button: MouseButton, options: ShapeOptions) {
        fixShape()
        self.shape = ShapeEdit(shape: shape, stage: stage, button: button, options: options, base: bitmap,
                               drawn: PixelRect(x: 0, y: 0, width: 0, height: 0))
        renderShape()
    }

    /// Changes the shape being edited and draws it again.
    func updateShape(_ change: (inout ShapeEdit) -> Void) {
        guard var edit = shape else { return }
        change(&edit)
        shape = edit
        renderShape()
    }

    /// Puts back an earlier state of the shape being edited, as when a drag is cancelled.
    func restoreShape(_ saved: ShapeEdit) {
        var edit = saved
        if let current = shape { edit.drawn = edit.drawn.union(current.drawn) }
        shape = edit
        renderShape()
    }

    /// Draws the shape again over the image it was started on, with the current colors.
    func renderShape() {
        guard var edit = shape else { return }
        let outline = edit.button == .left ? color1 : color2
        let fill = edit.button == .left ? color2 : color1
        draw { bitmap in
            let old = edit.drawn.intersection(bitmap.bounds)
            if !old.isEmpty { bitmap.write(edit.base.region(old), to: old) }
            edit.drawn = ShapeRenderer.draw(edit.shape, options: edit.options, outline: outline, fill: fill, on: &bitmap)
        }
        shape = edit
    }

    /// Leaves the shape on the image as one undoable step. An open polygon is closed first.
    func fixShape() {
        guard let edit = shape else { return }
        if edit.stage == .polygonOpen {
            updateShape { $0.shape.isClosed = true; $0.stage = .complete }
        }
        let final = shape ?? edit
        shape = nil
        commit(before: final.base, changed: final.drawn)
    }

    /// Throws the shape away and shows the image as it was. Returns false when there was none.
    @discardableResult
    func discardShape() -> Bool {
        guard let edit = shape else { return false }
        shape = nil
        revert(to: edit.base)
        return true
    }
}

/// The Shapes tool: drag to draw the shape chosen in the gallery, then adjust it with the
/// handles until it is fixed (a click outside it, Esc, Enter, another tool or another shape).
/// The curve takes two more clicks for its control points; the polygon takes a click per vertex.
final class ShapeTool: Tool {
    /// Outline widths of the Size group, as in the original.
    let sizes = [1, 3, 5, 8]
    var size = 1
    var kind = GalleryShape.line
    var outline = ShapeStyle.solid
    var fill = ShapeStyle.none
    /// Shift is down: squares, circles, regular figures and lines at multiples of 45°.
    var constrain = false
    /// Clicks of the press being handled; a double click closes a polygon.
    var clickCount = 1

    var options: ShapeOptions { ShapeOptions(outline: outline, fill: fill, width: size) }

    private enum Action {
        case move(start: PixelPoint)
        case resize(SelectionHandle)
        case control(Int)
        case vertex
    }

    private enum Mode {
        case drawing(start: PixelPoint, button: MouseButton)
        case editing(saved: ShapeEdit, action: Action)
    }
    private var mode: Mode?

    /// Whether a drag is drawing a new shape (the canvas hides the handles meanwhile).
    var isDrawing: Bool {
        if case .drawing? = mode { return true }
        return false
    }

    /// Where a press lands on the shape being edited, in image pixels (the canvas also finds handles).
    static func hit(_ point: PixelPoint, edit: ShapeEdit?) -> SelectionHit {
        guard let edit = edit, edit.stage == .complete else { return .outside }
        let rect = edit.shape.bounds
        let inside = point.x >= rect.x && point.y >= rect.y && point.x < rect.maxX && point.y < rect.maxY
        return inside ? .inside : .outside
    }

    func press(at point: PixelPoint, button: MouseButton, host: ToolHost) {
        begin(at: point, hit: ShapeTool.hit(point, edit: host.document.shape), button: button, host: host)
    }

    /// A press with what the canvas knows: where it landed on the shape being edited.
    func begin(at point: PixelPoint, hit: SelectionHit, button: MouseButton, host: ToolHost) {
        let document = host.document
        if let edit = document.shape {
            switch edit.stage {
            case .curveControl(let index):
                mode = .editing(saved: edit, action: .control(index))
                moveControl(index, to: point, document)
                return
            case .polygonOpen:
                let points = edit.shape.points
                let first = points[0]
                let near = abs(point.x - first.x) <= ShapeGeometry.polygonCloseDistance
                    && abs(point.y - first.y) <= ShapeGeometry.polygonCloseDistance
                if clickCount >= 2 || (points.count >= 3 && near) {
                    // The first click of a double click already placed the last vertex.
                    document.updateShape { $0.shape.isClosed = true; $0.stage = .complete }
                    mode = nil
                    return
                }
                mode = .editing(saved: edit, action: .vertex)
                let next = constrained(point, from: points[points.count - 1], box: false)
                document.updateShape { $0.shape.points.append(next) }
                return
            case .complete:
                switch hit {
                case .inside:
                    mode = .editing(saved: edit, action: .move(start: point))
                    return
                case .handle(let handle):
                    mode = .editing(saved: edit, action: .resize(handle))
                    return
                case .outside:
                    document.fixShape()
                }
            }
        }
        mode = .drawing(start: point, button: button)
    }

    func drag(to point: PixelPoint, host: ToolHost) {
        let document = host.document
        switch mode {
        case .drawing(let start, let button)?:
            let end = constrained(point, from: start, box: !kind.usesPoints)
            if document.shape == nil {
                // Nothing appears until the pointer leaves the pixel it was pressed on.
                guard end != start else { return }
                document.beginShape(makeShape(from: start, to: end), button: button, options: options)
            } else {
                let shape = makeShape(from: start, to: end)
                document.updateShape { $0.shape = shape }
            }
        case .editing(let saved, let action)?:
            switch action {
            case .move(let start):
                let shape = saved.shape.moved(point.x - start.x, point.y - start.y)
                document.updateShape { $0.shape = shape }
            case .resize(let handle):
                var rect = handle.resize(saved.shape.bounds, to: point)
                if constrain { rect = ShapeTool.proportional(rect, from: saved.shape.bounds, handle: handle) }
                let shape = saved.shape.resized(to: rect)
                document.updateShape { $0.shape = shape }
            case .control(let index):
                moveControl(index, to: point, document)
            case .vertex:
                let points = saved.shape.points
                let next = constrained(point, from: points[points.count - 1], box: false)
                document.updateShape { $0.shape.points[$0.shape.points.count - 1] = next }
            }
        case nil:
            break
        }
    }

    func release(at point: PixelPoint, host: ToolHost) {
        drag(to: point, host: host)
        let document = host.document
        switch mode {
        case .drawing?:
            if document.shape != nil {
                let stage: ShapeEdit.Stage = kind == .curve ? .curveControl(1) : kind == .polygon ? .polygonOpen : .complete
                document.updateShape { $0.stage = stage }
            }
        case .editing(_, .control(let index))?:
            document.updateShape { $0.stage = index == 1 ? .curveControl(2) : .complete }
        default:
            break
        }
        mode = nil
    }

    func cancel(host: ToolHost) {
        switch mode {
        case .drawing?: host.document.discardShape()
        case .editing(let saved, _)?: host.document.restoreShape(saved)
        case nil: break
        }
        mode = nil
    }

    /// The first control point bends the whole curve towards it; the second sets the other end's.
    private func moveControl(_ index: Int, to point: PixelPoint, _ document: PaintDocument) {
        document.updateShape { edit in
            guard edit.shape.points.count == 4 else { return }
            if index == 1 { edit.shape.points[1] = point }
            edit.shape.points[2] = point
        }
    }

    private func makeShape(from start: PixelPoint, to end: PixelPoint) -> DrawnShape {
        switch kind {
        case .line: return .points(.line, [start, end])
        case .curve: return .points(.curve, [start, start, end, end])
        case .polygon: return .points(.polygon, [start, end], closed: false)
        default:
            return .box(kind, PixelRect(x: min(start.x, end.x), y: min(start.y, end.y),
                                        width: abs(end.x - start.x) + 1, height: abs(end.y - start.y) + 1))
        }
    }

    /// With Shift: a square box, or a line at a multiple of 45°.
    private func constrained(_ point: PixelPoint, from start: PixelPoint, box: Bool) -> PixelPoint {
        guard constrain else { return point }
        return ShapeTool.constrain(point, from: start, square: box)
    }

    /// With Shift a corner handle keeps the proportions of the box, growing with the larger
    /// change and anchored at the opposite corner; side handles stretch freely (a conferir).
    static func proportional(_ rect: PixelRect, from original: PixelRect, handle: SelectionHandle) -> PixelRect {
        guard (handle.movesLeft || handle.movesRight) && (handle.movesTop || handle.movesBottom),
              original.width > 0, original.height > 0 else { return rect }
        let scale = max(Double(rect.width) / Double(original.width), Double(rect.height) / Double(original.height))
        let width = max(1, Int((Double(original.width) * scale).rounded()))
        let height = max(1, Int((Double(original.height) * scale).rounded()))
        return PixelRect(x: handle.movesLeft ? original.maxX - width : original.x,
                         y: handle.movesTop ? original.maxY - height : original.y, width: width, height: height)
    }

    static func constrain(_ point: PixelPoint, from start: PixelPoint, square: Bool) -> PixelPoint {
        let dx = point.x - start.x, dy = point.y - start.y
        let sx = dx < 0 ? -1 : 1, sy = dy < 0 ? -1 : 1
        if square {
            let side = max(abs(dx), abs(dy))
            return PixelPoint(x: start.x + sx * side, y: start.y + sy * side)
        }
        // tan(22.5°): below it the line is horizontal (or vertical), above it diagonal.
        let limit = 0.41421356
        if Double(abs(dy)) <= Double(abs(dx)) * limit { return PixelPoint(x: point.x, y: start.y) }
        if Double(abs(dx)) <= Double(abs(dy)) * limit { return PixelPoint(x: start.x, y: point.y) }
        let length = (abs(dx) + abs(dy) + 1) / 2
        return PixelPoint(x: start.x + sx * length, y: start.y + sy * length)
    }
}
