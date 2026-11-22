import Foundation

/// The eight handles around a selection, clockwise from the top-left corner.
enum SelectionHandle: Int, CaseIterable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

    var movesLeft: Bool { self == .topLeft || self == .left || self == .bottomLeft }
    var movesRight: Bool { self == .topRight || self == .right || self == .bottomRight }
    var movesTop: Bool { self == .topLeft || self == .top || self == .topRight }
    var movesBottom: Bool { self == .bottomLeft || self == .bottom || self == .bottomRight }

    /// `rect` with the handle's edges moved to `point`, never smaller than one pixel.
    func resize(_ rect: PixelRect, to point: PixelPoint) -> PixelRect {
        var left = rect.x, top = rect.y, right = rect.maxX, bottom = rect.maxY
        if movesLeft { left = min(point.x, right - 1) }
        if movesRight { right = max(point.x, left + 1) }
        if movesTop { top = min(point.y, bottom - 1) }
        if movesBottom { bottom = max(point.y, top + 1) }
        return PixelRect(x: left, y: top, width: right - left, height: bottom - top)
    }
}

/// Where a press lands relative to the current selection.
enum SelectionHit: Equatable {
    case outside, inside, handle(SelectionHandle)
}

/// Rectangular and free-form selection. Pressing outside the selection fixes it and marks a
/// new area; pressing inside moves it (Ctrl copies, Shift leaves a trail); the handles stretch it.
/// Moving and stretching are one undoable step each; marking is not a step.
final class SelectionTool: Tool {
    let sizes: [Int] = []
    var size = 0
    var shape = SelectionShape.rectangle

    /// The rectangle being marked, for the canvas to outline.
    private(set) var markingRect: PixelRect?
    /// The free-form outline being drawn.
    private(set) var path: [PixelPoint] = []

    private enum Mode {
        case marking(start: PixelPoint)
        case freeForm
        case moving(start: PixelPoint, from: PixelRect, copy: Bool, stamp: Bool)
        case resizing(SelectionHandle, from: PixelRect)
    }
    private var mode: Mode?
    private var before: Bitmap?
    private var saved: Selection?
    private var changed = PixelRect(x: 0, y: 0, width: 0, height: 0)

    var isMarking: Bool { markingRect != nil || !path.isEmpty }

    static func hit(_ point: PixelPoint, selection: Selection?) -> SelectionHit {
        guard let rect = selection?.rect else { return .outside }
        let inside = point.x >= rect.x && point.y >= rect.y && point.x < rect.maxX && point.y < rect.maxY
        return inside ? .inside : .outside
    }

    func press(at point: PixelPoint, button: MouseButton, host: ToolHost) {
        begin(at: point, hit: SelectionTool.hit(point, selection: host.document.selection), copy: false, stamp: false, host: host)
    }

    /// A press with what the canvas knows: where it landed and the Ctrl and Shift keys.
    func begin(at point: PixelPoint, hit: SelectionHit, copy: Bool, stamp: Bool, host: ToolHost) {
        let document = host.document
        changed = PixelRect(x: 0, y: 0, width: 0, height: 0)
        switch hit {
        case .inside:
            guard let rect = document.selection?.rect else { return }
            before = document.bitmap
            saved = document.selection
            mode = .moving(start: point, from: rect, copy: copy, stamp: stamp)
        case .handle(let handle):
            guard let rect = document.selection?.rect else { return }
            before = document.bitmap
            saved = document.selection
            mode = .resizing(handle, from: rect)
        case .outside:
            saved = document.selection
            document.fixSelection()
            switch shape {
            case .rectangle:
                let start = clampedCorner(point, document)
                mode = .marking(start: start)
                markingRect = PixelRect(x: start.x, y: start.y, width: 0, height: 0)
            case .freeForm:
                mode = .freeForm
                path = [clampedPixel(point, document)]
            }
        }
    }

    func drag(to point: PixelPoint, host: ToolHost) {
        let document = host.document
        switch mode {
        case .marking(let start)?:
            let end = clampedCorner(point, document)
            markingRect = PixelRect(x: min(start.x, end.x), y: min(start.y, end.y),
                                    width: abs(end.x - start.x), height: abs(end.y - start.y))
        case .freeForm?:
            let next = clampedPixel(point, document)
            if path.last != next { path.append(next) }
        case .moving(let start, let from, let copy, let stamp)?:
            let dx = point.x - start.x, dy = point.y - start.y
            guard let current = document.selection else { return }
            if !current.isFloating {
                guard dx != 0 || dy != 0 else { return }
                changed = changed.union(document.liftSelection(copy: copy))
            }
            // Shift: the pixels stay behind at every position they pass.
            if stamp { document.selection?.base = document.bitmap }
            changed = changed.union(document.placeSelection(from.offsetBy(dx, dy)))
        case .resizing(let handle, let from)?:
            let target = handle.resize(from, to: point)
            guard target != document.selection?.rect else { return }
            changed = changed.union(document.liftSelection(copy: false))
            changed = changed.union(document.placeSelection(target))
        case nil:
            break
        }
    }

    func release(at point: PixelPoint, host: ToolHost) {
        drag(to: point, host: host)
        let document = host.document
        switch mode {
        case .marking?:
            if let rect = markingRect { document.select(rect) }
        case .freeForm?:
            if path.count > 1, let area = Selection.freeFormMask(path), area.rect.width > 1 || area.rect.height > 1 {
                document.select(area.rect, mask: area.mask)
            }
        case .moving?, .resizing?:
            if let before = before { document.commit(before: before, changed: changed) }
        case nil:
            break
        }
        finish()
    }

    func cancel(host: ToolHost) {
        guard let _ = mode else { return }
        if let before = before { host.document.revert(to: before) }
        host.document.selection = saved
        finish()
    }

    private func finish() {
        mode = nil
        before = nil
        saved = nil
        markingRect = nil
        path = []
    }

    /// Corners run from 0 to the image size, so a drag to the far edge selects the last pixel.
    private func clampedCorner(_ point: PixelPoint, _ document: PaintDocument) -> PixelPoint {
        PixelPoint(x: max(0, min(document.bitmap.width, point.x)), y: max(0, min(document.bitmap.height, point.y)))
    }

    private func clampedPixel(_ point: PixelPoint, _ document: PaintDocument) -> PixelPoint {
        PixelPoint(x: max(0, min(document.bitmap.width - 1, point.x)), y: max(0, min(document.bitmap.height - 1, point.y)))
    }
}
