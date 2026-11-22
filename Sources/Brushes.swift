import CoreGraphics
import Foundation

/// The nine brushes of the Brushes drop-down, in the order of the original gallery.
/// Sizes, opacities and textures are our own approximations (a conferir com o original).
enum BrushKind: Int, CaseIterable {
    case brush, calligraphy1, calligraphy2, airbrush, oil, crayon, marker, naturalPencil, watercolor

    var nameKey: String { "brush.\(self)" }

    /// Sizes of the Size group, smallest first (a conferir com o original).
    var sizes: [Int] {
        switch self {
        case .brush: return [1, 3, 5, 8]
        case .calligraphy1, .calligraphy2: return [4, 8, 12, 16]
        case .airbrush: return [9, 16, 24, 32]
        case .oil, .crayon, .watercolor: return [8, 16, 30, 40]
        case .marker: return [10, 20, 30, 40]
        case .naturalPencil: return [2, 4, 6, 8]
        }
    }

    /// The size a brush starts with: the second one offered (a conferir com o original).
    var defaultSize: Int { sizes[1] }

    /// How much of the color one stroke lays down at full coverage. Within a stroke
    /// coverage never adds up, so a marker passing twice over a spot stays as light.
    var opacity: Double {
        switch self {
        case .marker: return 0.5
        case .watercolor: return 0.45
        case .naturalPencil: return 0.85
        default: return 1
        }
    }

    /// The texture as a function of the image pixel, from 0 (no paint) to 1. The textured
    /// outlines and fills of the Shapes group use the same function.
    func grain(x: Int, y: Int) -> Double {
        switch self {
        case .brush, .calligraphy1, .calligraphy2, .airbrush, .marker:
            return 1
        case .crayon:
            // Wax catches the raised grain of the paper and skips the hollows.
            let n = BrushNoise.smooth(Double(x) / 2.2, Double(y) / 2.2, salt: 11) * 0.6 + BrushNoise.hash(x, y, salt: 12) * 0.4
            return n < 0.32 ? 0.1 : n < 0.42 ? 0.6 : 1
        case .oil:
            // Streaks of thicker and thinner paint.
            return 0.6 + 0.4 * BrushNoise.smooth(Double(x) / 6, Double(y) / 1.3, salt: 21)
        case .naturalPencil:
            // Fine graphite grain.
            let n = BrushNoise.hash(x, y, salt: 31)
            return n < 0.3 ? 0.2 : 0.55 + 0.45 * n
        case .watercolor:
            // Pigment pooling unevenly.
            return 0.7 + 0.3 * BrushNoise.smooth(Double(x) / 4, Double(y) / 4, salt: 41)
        }
    }

    /// The texture an Outline or Fill style shares with a brush.
    init?(style: ShapeStyle) {
        switch style {
        case .crayon: self = .crayon
        case .marker: self = .marker
        case .oil: self = .oil
        case .naturalPencil: self = .naturalPencil
        case .watercolor: self = .watercolor
        case .none, .solid: return nil
        }
    }

    /// Distance in pixels between dabs along the path.
    func spacing(for size: Int) -> Double {
        switch self {
        case .calligraphy1, .calligraphy2: return 0.5
        default: return max(0.5, Double(size) / 8)
        }
    }
}

/// Deterministic noise for the textures: the same pixel always gets the same value.
enum BrushNoise {
    /// A value in 0..<1 for an integer lattice point.
    static func hash(_ x: Int, _ y: Int, salt: UInt64) -> Double {
        var z = UInt64(bitPattern: Int64(x)) &* 0x9E37_79B9_7F4A_7C15
        z ^= UInt64(bitPattern: Int64(y)) &* 0xC2B2_AE3D_27D4_EB4F
        z ^= salt &* 0x1656_67B1_9E37_79F9
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / 9_007_199_254_740_992
    }

    /// Smoothly interpolated lattice noise in 0..<1.
    static func smooth(_ x: Double, _ y: Double, salt: UInt64) -> Double {
        let x0 = Int(floor(x)), y0 = Int(floor(y))
        var fx = x - Double(x0), fy = y - Double(y0)
        fx = fx * fx * (3 - 2 * fx)
        fy = fy * fy * (3 - 2 * fy)
        let a = hash(x0, y0, salt: salt), b = hash(x0 + 1, y0, salt: salt)
        let c = hash(x0, y0 + 1, salt: salt), d = hash(x0 + 1, y0 + 1, salt: salt)
        return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fy
    }
}

/// SplitMix64: small, fast and reproducible, so tests can fix the airbrush's dots.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A value in 0..<1.
    mutating func unit() -> Double { Double(next() >> 11) / 9_007_199_254_740_992 }
}

/// One brush stroke over the image it started on. Each dab raises a coverage mask (never
/// adding up), and the pixels are the starting image blended towards the color by that
/// coverage, so a stroke can be cancelled, is deterministic and never darkens over itself.
final class BrushStroke {
    let kind: BrushKind
    let size: Int
    let color: RGB
    let before: Bitmap
    /// Pixels the stroke may have changed so far.
    private(set) var changed = PixelRect(x: 0, y: 0, width: 0, height: 0)
    private var mask: [UInt8]
    private var random: SeededRandom
    private var last = CGPoint.zero
    /// Unit vector of the last movement; the oil brush lays its bristles across it.
    private var direction = CGVector(dx: 1, dy: 0)
    private var travelled = 0.0

    /// Airbrush dots per burst (a conferir com o original).
    var dotsPerBurst: Int { max(2, size * size / 12) }

    init(kind: BrushKind, size: Int, color: RGB, before: Bitmap, seed: UInt64) {
        self.kind = kind
        self.size = max(1, size)
        self.color = color
        self.before = before
        mask = [UInt8](repeating: 0, count: before.width * before.height)
        random = SeededRandom(seed: seed)
    }

    private static func center(_ point: PixelPoint) -> CGPoint { CGPoint(x: Double(point.x) + 0.5, y: Double(point.y) + 0.5) }

    func begin(at point: PixelPoint, on bitmap: inout Bitmap) {
        last = BrushStroke.center(point)
        var dirty = PixelRect(x: 0, y: 0, width: 0, height: 0)
        if kind == .airbrush { burst(&dirty) } else { dab(at: last, &dirty) }
        finish(dirty, on: &bitmap)
    }

    func move(to point: PixelPoint, on bitmap: inout Bitmap) {
        let target = BrushStroke.center(point)
        let dx = Double(target.x - last.x), dy = Double(target.y - last.y)
        let length = (dx * dx + dy * dy).squareRoot()
        var dirty = PixelRect(x: 0, y: 0, width: 0, height: 0)
        if kind == .airbrush {
            // The airbrush sprays where the pointer is, leaving gaps when it moves fast, as in Paint.
            last = target
            burst(&dirty)
        } else {
            if length > 0 { direction = CGVector(dx: dx / length, dy: dy / length) }
            let step = kind.spacing(for: size)
            var t = step
            let start = last
            while t < length {
                dab(at: CGPoint(x: Double(start.x) + dx * t / length, y: Double(start.y) + dy * t / length), &dirty)
                t += step
            }
            travelled += length
            last = target
            dab(at: target, &dirty)
        }
        finish(dirty, on: &bitmap)
    }

    /// One more burst of airbrush dots where the pointer rests, from the timer.
    func spray(on bitmap: inout Bitmap) {
        guard kind == .airbrush else { return }
        var dirty = PixelRect(x: 0, y: 0, width: 0, height: 0)
        burst(&dirty)
        finish(dirty, on: &bitmap)
    }

    // MARK: Dabs

    private func burst(_ dirty: inout PixelRect) {
        let radius = Double(size) / 2
        let w = before.width, h = before.height
        for _ in 0..<dotsPerBurst {
            let angle = random.unit() * 2 * .pi
            let distance = radius * random.unit().squareRoot()
            let x = Int(floor(Double(last.x) + cos(angle) * distance))
            let y = Int(floor(Double(last.y) + sin(angle) * distance))
            guard x >= 0, y >= 0, x < w, y < h else { continue }
            mask[y * w + x] = 255
            dirty = dirty.union(PixelRect(x: x, y: y, width: 1, height: 1))
        }
    }

    private func dab(at c: CGPoint, _ dirty: inout PixelRect) {
        let radius = Double(size) / 2
        // The calligraphy nib's thickness reaches past the radius.
        let reach = radius + Double(size) / 10 + 1.5
        let cx = Double(c.x), cy = Double(c.y)
        let area = PixelRect(x: Int(floor(cx - reach)), y: Int(floor(cy - reach)),
                             width: Int(ceil(2 * reach)) + 1, height: Int(ceil(2 * reach)) + 1).intersection(before.bounds)
        guard !area.isEmpty else { return }
        let w = before.width
        for y in area.y..<area.maxY {
            for x in area.x..<area.maxX {
                let a = coverage(Double(x) + 0.5 - cx, Double(y) + 0.5 - cy, x, y, radius)
                guard a > 0 else { continue }
                let value = UInt8(min(255, (a * 255).rounded()))
                let index = y * w + x
                if value > mask[index] { mask[index] = value }
            }
        }
        dirty = dirty.union(area)
    }

    /// How much one dab centered `(px, py)` away covers pixel (x, y), from 0 to 1.
    private func coverage(_ px: Double, _ py: Double, _ x: Int, _ y: Int, _ radius: Double) -> Double {
        func clamp(_ v: Double) -> Double { min(1, max(0, v)) }
        let distance = (px * px + py * py).squareRoot()
        // A disk with a one-pixel antialiased edge; size 1 covers exactly its pixel.
        let disk = clamp(radius - distance + 0.5)
        switch kind {
        case .brush, .marker:
            return disk
        case .calligraphy1, .calligraphy2:
            // A flat nib at 45°: rising to the right for brush 1, falling for brush 2.
            let s = 0.5.squareRoot()
            let nx = s, ny = kind == .calligraphy1 ? -s : s
            let half = max(0, radius - 0.5), thickness = max(0.5, Double(size) / 10)
            let along = min(half, max(-half, px * nx + py * ny))
            let ex = px - along * nx, ey = py - along * ny
            return clamp(thickness - (ex * ex + ey * ey).squareRoot() + 0.5)
        case .airbrush:
            return 0
        case .oil:
            guard disk > 0 else { return 0 }
            // Bristles across the direction of the stroke leave streaks; the paint runs out slowly.
            let across = -px * Double(direction.dy) + py * Double(direction.dx)
            let width = max(1, Double(size) / 7)
            let bristle = 0.45 + 0.55 * BrushNoise.hash(Int(floor((across + radius) / width)), 0, salt: 51)
            let paint = max(0.5, 1 - travelled / (Double(size) * 80))
            return disk * bristle * (0.8 + 0.2 * kind.grain(x: x, y: y)) * paint
        case .crayon, .naturalPencil:
            guard disk > 0 else { return 0 }
            return disk * kind.grain(x: x, y: y)
        case .watercolor:
            // Soft edge over the outer 70% of the radius.
            let t = clamp((radius + 0.5 - distance) / max(1, radius * 0.7))
            guard t > 0 else { return 0 }
            return t * t * (3 - 2 * t) * kind.grain(x: x, y: y)
        }
    }

    /// Blends `rect` again from the starting image and the coverage.
    private func finish(_ rect: PixelRect, on bitmap: inout Bitmap) {
        let area = rect.intersection(bitmap.bounds)
        guard !area.isEmpty else { return }
        changed = changed.union(area)
        BrushStroke.blend(area, color: color, opacity: kind.opacity, base: before, coverage: mask, on: &bitmap)
    }

    /// Pixels of `area` become `base` moved towards `color` by coverage × opacity.
    static func blend(_ area: PixelRect, color: RGB, opacity: Double, base: Bitmap, coverage: [UInt8], on bitmap: inout Bitmap) {
        let w = bitmap.width
        let cr = Double(color.r), cg = Double(color.g), cb = Double(color.b)
        bitmap.withPixels { pixels in
            for y in area.y..<area.maxY {
                for x in area.x..<area.maxX {
                    let index = y * w + x
                    let value = coverage[index]
                    let old = base[x, y]
                    guard value > 0 else { pixels[index] = old; continue }
                    let a = Double(value) / 255 * opacity
                    let p = RGB(packed: old)
                    func mix(_ from: UInt8, _ to: Double) -> UInt8 { UInt8((Double(from) + (to - Double(from)) * a).rounded()) }
                    pixels[index] = RGB(r: mix(p.r, cr), g: mix(p.g, cg), b: mix(p.b, cb)).packed
                }
            }
        }
    }
}
