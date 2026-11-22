import Foundation

/// Square pencil, 1 to 4 pixels: left button paints Color 1, right button Color 2.
final class PencilTool: StrokeTool {
    init() { super.init(sizes: [1, 2, 3, 4], size: 1) }

    override func stamp(_ rect: PixelRect, button: MouseButton, color1: UInt32, color2: UInt32, on bitmap: inout Bitmap) {
        bitmap.fill(rect, with: button == .left ? color1 : color2)
    }
}

/// Square eraser. The left button paints Color 2 over everything;
/// the right button turns only the Color 1 pixels into Color 2.
final class EraserTool: StrokeTool {
    // Default size a conferir com o original.
    init() { super.init(sizes: [4, 6, 8, 10], size: 8) }

    override func stamp(_ rect: PixelRect, button: MouseButton, color1: UInt32, color2: UInt32, on bitmap: inout Bitmap) {
        switch button {
        case .left: bitmap.fill(rect, with: color2)
        case .right: bitmap.replace(color1, with: color2, in: rect)
        }
    }
}

/// Bucket: fills the 4-connected area of exactly the clicked color.
/// It fills on press, so there is nothing left to cancel (a conferir com o original).
final class FillTool: Tool {
    let sizes: [Int] = []
    var size = 0

    func press(at point: PixelPoint, button: MouseButton, host: ToolHost) {
        let document = host.document
        let value = (button == .left ? document.color1 : document.color2).packed
        let before = document.bitmap
        var changed = PixelRect(x: 0, y: 0, width: 0, height: 0)
        document.draw { changed = $0.floodFill(x: point.x, y: point.y, with: value) }
        document.commit(before: before, changed: changed)
    }

    func drag(to point: PixelPoint, host: ToolHost) {}
    func release(at point: PixelPoint, host: ToolHost) {}
    func cancel(host: ToolHost) {}
}

/// Takes the color under the pointer on release, then returns to the previous tool.
final class ColorPickerTool: Tool {
    let sizes: [Int] = []
    var size = 0
    private var button: MouseButton?

    func press(at point: PixelPoint, button: MouseButton, host: ToolHost) { self.button = button }
    func drag(to point: PixelPoint, host: ToolHost) {}

    func release(at point: PixelPoint, host: ToolHost) {
        guard let button = button else { return }
        self.button = nil
        let document = host.document, bitmap = document.bitmap
        // Releasing outside the image picks nothing and keeps the tool.
        guard point.x >= 0, point.y >= 0, point.x < bitmap.width, point.y < bitmap.height else { return }
        let color = RGB(packed: bitmap[point.x, point.y])
        switch button {
        case .left: document.color1 = color
        case .right: document.color2 = color
        }
        host.returnToPreviousTool()
    }

    func cancel(host: ToolHost) { button = nil }
}

/// Left click zooms in one level around the clicked pixel, right click zooms out.
final class MagnifierTool: Tool {
    let sizes: [Int] = []
    var size = 0

    func press(at point: PixelPoint, button: MouseButton, host: ToolHost) {
        host.stepZoom(button == .left ? 1 : -1, centeredOn: point)
    }

    func drag(to point: PixelPoint, host: ToolHost) {}
    func release(at point: PixelPoint, host: ToolHost) {}
    func cancel(host: ToolHost) {}
}
