import CoreGraphics
import Foundation

/// An opaque 24-bit color, as Paint stores them.
struct RGB: Equatable {
    var r: UInt8
    var g: UInt8
    var b: UInt8

    static let black = RGB(r: 0, g: 0, b: 0)
    static let white = RGB(r: 255, g: 255, b: 255)

    /// Memory layout R, G, B, X on little-endian hosts (arm64 and x86_64).
    var packed: UInt32 { UInt32(r) | UInt32(g) << 8 | UInt32(b) << 16 | 0xFF00_0000 }

    init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }

    init(packed: UInt32) {
        r = UInt8(packed & 0xFF)
        g = UInt8(packed >> 8 & 0xFF)
        b = UInt8(packed >> 16 & 0xFF)
    }
}

/// A rectangle in image pixels.
struct PixelRect: Equatable {
    var x: Int
    var y: Int
    var width: Int
    var height: Int

    var isEmpty: Bool { width <= 0 || height <= 0 }

    func union(_ other: PixelRect) -> PixelRect {
        if isEmpty { return other }
        if other.isEmpty { return self }
        let x0 = min(x, other.x), y0 = min(y, other.y)
        let x1 = max(x + width, other.x + other.width), y1 = max(y + height, other.y + other.height)
        return PixelRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }

    func intersection(_ other: PixelRect) -> PixelRect {
        let x0 = max(x, other.x), y0 = max(y, other.y)
        let x1 = min(x + width, other.x + other.width), y1 = min(y + height, other.y + other.height)
        return PixelRect(x: x0, y: y0, width: max(0, x1 - x0), height: max(0, y1 - y0))
    }
}

/// The image being edited: one 32-bit word per pixel, rows top to bottom.
/// Raster tools write pixels here directly, with no antialiasing.
struct Bitmap: Equatable {
    let width: Int
    let height: Int
    private(set) var pixels: [UInt32]

    var bounds: PixelRect { PixelRect(x: 0, y: 0, width: width, height: height) }

    init(width: Int, height: Int, fill: RGB = .white) {
        self.width = max(1, width)
        self.height = max(1, height)
        pixels = [UInt32](repeating: fill.packed, count: self.width * self.height)
    }

    /// Wraps existing pixels; `pixels` must hold `width * height` words.
    init(width: Int, height: Int, pixels: [UInt32]) {
        precondition(width > 0 && height > 0 && pixels.count == width * height)
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    /// A bitmap where every word is `value`; also used for selection masks.
    init(width: Int, height: Int, value: UInt32) {
        self.width = max(1, width)
        self.height = max(1, height)
        pixels = [UInt32](repeating: value, count: self.width * self.height)
    }

    subscript(x: Int, y: Int) -> UInt32 { pixels[y * width + x] }

    /// Fast in-place access to every pixel, rows top to bottom.
    mutating func withPixels<T>(_ body: (UnsafeMutableBufferPointer<UInt32>) -> T) -> T {
        pixels.withUnsafeMutableBufferPointer { body($0) }
    }

    /// Writes one pixel; coordinates outside the image are ignored.
    mutating func set(x: Int, y: Int, to value: UInt32) {
        guard x >= 0, y >= 0, x < width, y < height else { return }
        pixels[y * width + x] = value
    }

    /// Visits every pixel of a one-pixel Bresenham line, both end points included.
    static func forEachLinePoint(fromX x0: Int, y y0: Int, toX x1: Int, y y1: Int, _ body: (Int, Int) -> Void) {
        var x = x0, y = y0
        let dx = abs(x1 - x0), dy = -abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1
        var error = dx + dy
        while true {
            body(x, y)
            if x == x1 && y == y1 { break }
            let doubled = 2 * error
            if doubled >= dy { error += dy; x += sx }
            if doubled <= dx { error += dx; y += sy }
        }
    }

    /// One-pixel Bresenham line including both end points.
    mutating func line(fromX x0: Int, y y0: Int, toX x1: Int, y y1: Int, value: UInt32) {
        Bitmap.forEachLinePoint(fromX: x0, y: y0, toX: x1, y: y1) { set(x: $0, y: $1, to: value) }
    }

    /// The square a tool of `size` pixels covers when the pointer is on (x, y).
    /// Even sizes extend one pixel further up and left (a conferir com o original).
    static func square(atX x: Int, y: Int, size: Int) -> PixelRect {
        PixelRect(x: x - size / 2, y: y - size / 2, width: size, height: size)
    }

    /// Fills `rect`, clipped to the image.
    mutating func fill(_ rect: PixelRect, with value: UInt32) {
        let clipped = rect.intersection(bounds)
        guard !clipped.isEmpty else { return }
        let w = width
        pixels.withUnsafeMutableBufferPointer { p in
            for row in clipped.y..<(clipped.y + clipped.height) {
                let start = row * w + clipped.x
                for index in start..<(start + clipped.width) { p[index] = value }
            }
        }
    }

    /// Inside `rect`, changes only the pixels equal to `old` into `new`.
    mutating func replace(_ old: UInt32, with new: UInt32, in rect: PixelRect) {
        let clipped = rect.intersection(bounds)
        guard !clipped.isEmpty, old != new else { return }
        let w = width
        pixels.withUnsafeMutableBufferPointer { p in
            for row in clipped.y..<(clipped.y + clipped.height) {
                let start = row * w + clipped.x
                for index in start..<(start + clipped.width) where p[index] == old { p[index] = new }
            }
        }
    }

    /// 4-connected flood fill of the exact color under (x, y), as Paint's bucket does.
    /// Scanline fill with an explicit stack, so large areas need neither recursion nor
    /// one stack entry per pixel. Returns the bounding box of the changed pixels.
    @discardableResult
    mutating func floodFill(x: Int, y: Int, with value: UInt32) -> PixelRect {
        let empty = PixelRect(x: 0, y: 0, width: 0, height: 0)
        guard x >= 0, y >= 0, x < width, y < height else { return empty }
        let target = self[x, y]
        guard target != value else { return empty }
        let w = width, h = height
        var minX = x, maxX = x, minY = y, maxY = y
        var stack = [(x: x, y: y)]
        pixels.withUnsafeMutableBufferPointer { p in
            while let seed = stack.popLast() {
                let row = seed.y * w
                guard p[row + seed.x] == target else { continue }
                var left = seed.x, right = seed.x
                while left > 0 && p[row + left - 1] == target { left -= 1 }
                while right < w - 1 && p[row + right + 1] == target { right += 1 }
                for index in (row + left)...(row + right) { p[index] = value }
                minX = min(minX, left); maxX = max(maxX, right)
                minY = min(minY, seed.y); maxY = max(maxY, seed.y)
                // Queue one seed per run of matching pixels on the rows above and below.
                for next in [seed.y - 1, seed.y + 1] where next >= 0 && next < h {
                    let nextRow = next * w
                    var column = left
                    while column <= right {
                        if p[nextRow + column] == target {
                            stack.append((x: column, y: next))
                            while column <= right && p[nextRow + column] == target { column += 1 }
                        } else {
                            column += 1
                        }
                    }
                }
            }
        }
        return PixelRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// Copies out the pixels of `rect`, which must lie inside the image.
    func region(_ rect: PixelRect) -> [UInt32] {
        var out = [UInt32]()
        out.reserveCapacity(rect.width * rect.height)
        for row in rect.y..<(rect.y + rect.height) {
            let start = row * width + rect.x
            out.append(contentsOf: pixels[start..<(start + rect.width)])
        }
        return out
    }

    /// Writes back pixels previously taken with `region(_:)`.
    mutating func write(_ data: [UInt32], to rect: PixelRect) {
        for row in 0..<rect.height {
            let source = row * rect.width
            let target = (rect.y + row) * width + rect.x
            pixels.replaceSubrange(target..<(target + rect.width), with: data[source..<(source + rect.width)])
        }
    }

    private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private static let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue

    func makeImage() -> CGImage? {
        let data = pixels.withUnsafeBufferPointer { Data(buffer: $0) }
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: Bitmap.colorSpace, bitmapInfo: CGBitmapInfo(rawValue: Bitmap.bitmapInfo),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    /// Flattens any image onto white, since the document has no transparency.
    init?(image: CGImage) {
        let w = image.width, h = image.height
        guard w > 0, h > 0 else { return nil }
        var buffer = [UInt32](repeating: RGB.white.packed, count: w * h)
        let drawn = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                space: Bitmap.colorSpace, bitmapInfo: Bitmap.bitmapInfo) else { return false }
            let rect = CGRect(x: 0, y: 0, width: w, height: h)
            context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
            context.fill(rect)
            context.interpolationQuality = .none
            context.draw(image, in: rect)
            return true
        }
        guard drawn else { return nil }
        for index in buffer.indices { buffer[index] |= 0xFF00_0000 }
        width = w
        height = h
        pixels = buffer
    }
}
