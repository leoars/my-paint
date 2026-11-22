import Foundation

enum MouseButton {
    /// Draws with Color 1.
    case left
    /// Draws with Color 2; Control-click counts as this button.
    case right
}

/// A pixel position in image coordinates. It may lie outside the image while dragging.
struct PixelPoint: Equatable {
    var x: Int
    var y: Int
}

/// What a tool may use from the canvas that runs it.
protocol ToolHost: AnyObject {
    var document: PaintDocument { get }
    /// Goes back to the tool that was selected before the current one.
    func returnToPreviousTool()
    /// Moves the zoom one level in `direction` and keeps `point` in the middle of the view.
    func stepZoom(_ direction: Int, centeredOn point: PixelPoint)
}

/// One gesture: press, any number of drags, then release or cancel.
/// The canvas only starts a gesture when the press lands on the image.
protocol Tool: AnyObject {
    /// Sizes offered for this tool, smallest first; empty when it has no size.
    var sizes: [Int] { get }
    var size: Int { get set }
    func press(at point: PixelPoint, button: MouseButton, host: ToolHost)
    func drag(to point: PixelPoint, host: ToolHost)
    func release(at point: PixelPoint, host: ToolHost)
    /// Undoes whatever the gesture did so far, as when the other button is pressed.
    func cancel(host: ToolHost)
}

/// The tools. Select lives in the Image group, Shapes and Brushes in their own groups.
/// Later tools come last so the earlier tags stay the same.
enum ToolKind: Int, CaseIterable {
    case pencil, fill, eraser, colorPicker, magnifier, select, shape, brush, text

    /// The order of the Tools menu, as in the Tools group: Text after Fill.
    static let menuOrder: [ToolKind] = [.pencil, .fill, .text, .eraser, .colorPicker, .magnifier, .select]

    var nameKey: String {
        switch self {
        case .pencil: return "tool.pencil"
        case .fill: return "tool.fill"
        case .eraser: return "tool.eraser"
        case .colorPicker: return "tool.colorPicker"
        case .magnifier: return "tool.magnifier"
        case .select: return "tool.select"
        case .shape: return "tool.shape"
        case .brush: return "tool.brush"
        case .text: return "tool.text"
        }
    }

    func makeTool() -> Tool {
        switch self {
        case .pencil: return PencilTool()
        case .fill: return FillTool()
        case .eraser: return EraserTool()
        case .colorPicker: return ColorPickerTool()
        case .magnifier: return MagnifierTool()
        case .select: return SelectionTool()
        case .shape: return ShapeTool()
        case .brush: return BrushTool()
        case .text: return TextTool()
        }
    }
}

/// The selected tool and the one before it. Each tool keeps its own size.
final class ToolBox {
    private(set) var kind: ToolKind = .pencil
    private(set) var previousKind: ToolKind = .pencil
    private let tools: [ToolKind: Tool]
    /// Called when the selected tool or its size changes.
    var onChange: (() -> Void)?

    init() {
        var tools = [ToolKind: Tool]()
        for kind in ToolKind.allCases { tools[kind] = kind.makeTool() }
        self.tools = tools
    }

    var current: Tool { tools[kind]! }
    var selectionTool: SelectionTool { tools[.select] as! SelectionTool }
    var shapeTool: ShapeTool { tools[.shape] as! ShapeTool }
    var brushTool: BrushTool { tools[.brush] as! BrushTool }
    var textTool: TextTool { tools[.text] as! TextTool }
    func tool(_ kind: ToolKind) -> Tool { tools[kind]! }

    func select(_ newKind: ToolKind) {
        guard newKind != kind else { return }
        previousKind = kind
        kind = newKind
        onChange?()
    }

    /// Something about the current tool changed besides the kind, such as the chosen brush.
    func toolDidChange() { onChange?() }

    /// Used by the color picker, which hands control back after one pick.
    func returnToPrevious() {
        let back = previousKind
        previousKind = kind
        kind = back
        onChange?()
    }

    func canStepSize(_ direction: Int) -> Bool { steppedSize(direction) != nil }

    /// Ctrl++ and Ctrl+- move through the sizes the tool offers.
    func stepSize(_ direction: Int) {
        guard let size = steppedSize(direction) else { return }
        current.size = size
        onChange?()
    }

    func setSize(_ size: Int) {
        guard current.sizes.contains(size), current.size != size else { return }
        current.size = size
        onChange?()
    }

    private func steppedSize(_ direction: Int) -> Int? {
        let sizes = current.sizes
        guard let index = sizes.firstIndex(of: current.size) else { return nil }
        let next = index + direction
        return sizes.indices.contains(next) ? sizes[next] : nil
    }
}

/// Bookkeeping shared by the tools that paint along the mouse path.
/// Each mouse position stamps a square of `size` pixels, joined by Bresenham lines.
class StrokeTool: Tool {
    let sizes: [Int]
    var size: Int
    private var before: Bitmap?
    private var changed = PixelRect(x: 0, y: 0, width: 0, height: 0)
    private var last = PixelPoint(x: 0, y: 0)
    private var button = MouseButton.left

    init(sizes: [Int], size: Int) {
        self.sizes = sizes
        self.size = size
    }

    /// Paints one stamp. Subclasses decide what the stamp does.
    func stamp(_ rect: PixelRect, button: MouseButton, color1: UInt32, color2: UInt32, on bitmap: inout Bitmap) {}

    func press(at point: PixelPoint, button: MouseButton, host: ToolHost) {
        before = host.document.bitmap
        changed = PixelRect(x: 0, y: 0, width: 0, height: 0)
        self.button = button
        paint(from: point, to: point, document: host.document)
        last = point
    }

    func drag(to point: PixelPoint, host: ToolHost) {
        guard before != nil else { return }
        paint(from: last, to: point, document: host.document)
        last = point
    }

    func release(at point: PixelPoint, host: ToolHost) {
        guard let before = before else { return }
        self.before = nil
        host.document.commit(before: before, changed: changed)
    }

    func cancel(host: ToolHost) {
        guard let before = before else { return }
        self.before = nil
        host.document.revert(to: before)
    }

    private func paint(from a: PixelPoint, to b: PixelPoint, document: PaintDocument) {
        let size = self.size, button = self.button
        let color1 = document.color1.packed, color2 = document.color2.packed
        var touched = changed
        document.draw { bitmap in
            Bitmap.forEachLinePoint(fromX: a.x, y: a.y, toX: b.x, y: b.y) { x, y in
                let rect = Bitmap.square(atX: x, y: y, size: size)
                stamp(rect, button: button, color1: color1, color2: color2, on: &bitmap)
                touched = touched.union(rect)
            }
        }
        changed = touched
    }
}
