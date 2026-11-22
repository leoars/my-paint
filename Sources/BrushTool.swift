import Foundation

/// Fires the airbrush while the button is held; tests drive a manual one.
protocol BrushClock: AnyObject {
    func start(_ tick: @escaping () -> Void)
    func stop()
}

/// The real clock: a run loop timer, also running while menus or drags track the mouse.
final class TimerBrushClock: BrushClock {
    /// Seconds between airbrush bursts (a conferir com o original).
    static let interval: TimeInterval = 0.03
    private var timer: Timer?

    func start(_ tick: @escaping () -> Void) {
        stop()
        let timer = Timer(timeInterval: TimerBrushClock.interval, repeats: true) { _ in tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

/// The Brushes tool: paints with the brush chosen in the Brushes drop-down. Each brush keeps
/// its own size. The left button paints Color 1, the right button Color 2; a stroke is one
/// undoable step and the other button (or Esc) cancels it.
final class BrushTool: Tool {
    var kind = BrushKind.brush
    private var sizesByKind: [BrushKind: Int] = Dictionary(uniqueKeysWithValues: BrushKind.allCases.map { ($0, $0.defaultSize) })
    /// Fixed seed for the airbrush dots; nil draws a new one for every stroke.
    var seed: UInt64?
    var clock: BrushClock = TimerBrushClock()
    /// Called after the airbrush timer paints, so the canvas can redraw.
    var onSpray: (() -> Void)?
    private var stroke: BrushStroke?
    private weak var host: ToolHost?

    var sizes: [Int] { kind.sizes }
    var size: Int {
        get { sizesByKind[kind] ?? kind.defaultSize }
        set { sizesByKind[kind] = newValue }
    }

    func size(of brush: BrushKind) -> Int { sizesByKind[brush] ?? brush.defaultSize }

    var isPainting: Bool { stroke != nil }

    func press(at point: PixelPoint, button: MouseButton, host: ToolHost) {
        let document = host.document
        let stroke = BrushStroke(kind: kind, size: size, color: button == .left ? document.color1 : document.color2,
                                 before: document.bitmap, seed: seed ?? UInt64.random(in: 0...UInt64.max))
        self.stroke = stroke
        self.host = host
        document.draw { stroke.begin(at: point, on: &$0) }
        if kind == .airbrush {
            clock.start { [weak self] in self?.tick() }
        }
    }

    func drag(to point: PixelPoint, host: ToolHost) {
        guard let stroke = stroke else { return }
        host.document.draw { stroke.move(to: point, on: &$0) }
    }

    func release(at point: PixelPoint, host: ToolHost) {
        guard let stroke = stroke else { return }
        clock.stop()
        self.stroke = nil
        self.host = nil
        host.document.commit(before: stroke.before, changed: stroke.changed)
    }

    func cancel(host: ToolHost) {
        guard let stroke = stroke else { return }
        clock.stop()
        self.stroke = nil
        self.host = nil
        host.document.revert(to: stroke.before)
    }

    /// One airbrush burst where the pointer rests.
    func tick() {
        guard let stroke = stroke, let host = host else { return }
        host.document.draw { stroke.spray(on: &$0) }
        onSpray?()
    }
}
