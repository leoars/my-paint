import Foundation

/// Whole-bitmap transforms used by Crop, Resize and Skew, Rotate and Flip and Invert Color.
/// They work on images and on selection masks alike (a mask word is 0 outside the selection).
extension Bitmap {
    /// The pixels of `rect`; parts of `rect` outside the image take `fill`.
    func cropped(to rect: PixelRect, fill: UInt32) -> Bitmap {
        var out = Bitmap(width: rect.width, height: rect.height, value: fill)
        let inside = rect.intersection(bounds)
        guard !inside.isEmpty else { return out }
        out.write(region(inside), to: PixelRect(x: inside.x - rect.x, y: inside.y - rect.y,
                                                width: inside.width, height: inside.height))
        return out
    }

    /// Builds a bitmap of the given size by reading each output pixel from `source(x, y)`.
    private static func mapped(width: Int, height: Int, _ source: (Int, Int) -> UInt32) -> Bitmap {
        var out = Bitmap(width: width, height: height, value: 0)
        out.withPixels { p in
            for y in 0..<height { for x in 0..<width { p[y * width + x] = source(x, y) } }
        }
        return out
    }

    /// 90° clockwise.
    func rotatedRight() -> Bitmap {
        let h = height
        return Bitmap.mapped(width: height, height: width) { x, y in self[y, h - 1 - x] }
    }

    /// 90° counterclockwise.
    func rotatedLeft() -> Bitmap {
        let w = width
        return Bitmap.mapped(width: height, height: width) { x, y in self[w - 1 - y, x] }
    }

    func rotated180() -> Bitmap {
        let w = width, h = height
        return Bitmap.mapped(width: w, height: h) { x, y in self[w - 1 - x, h - 1 - y] }
    }

    /// Top and bottom swap.
    func flippedVertically() -> Bitmap {
        let h = height
        return Bitmap.mapped(width: width, height: height) { x, y in self[x, h - 1 - y] }
    }

    /// Left and right swap.
    func flippedHorizontally() -> Bitmap {
        let w = width
        return Bitmap.mapped(width: width, height: height) { x, y in self[w - 1 - x, y] }
    }

    /// Nearest-neighbor stretch, with no smoothing (a conferir com o original).
    func scaled(toWidth newWidth: Int, height newHeight: Int) -> Bitmap {
        let w = width, h = height
        let nw = max(1, newWidth), nh = max(1, newHeight)
        if nw == w && nh == h { return self }
        return Bitmap.mapped(width: nw, height: nh) { x, y in self[x * w / nw, y * h / nh] }
    }

    /// Offsets of a skew by `degrees` along `count` rows (or columns), shifted to start at 0.
    static func skewOffsets(count: Int, degrees: Int) -> [Int] {
        let slope = tan(Double(degrees) * .pi / 180)
        let raw = (0..<count).map { Int((Double($0) * slope).rounded()) }
        let low = raw.min() ?? 0
        return raw.map { $0 - low }
    }

    /// Horizontal skew slides each row right by row × tan(angle); vertical skew slides each
    /// column down by column × tan(angle). The uncovered corners take `fill`.
    /// Direction of positive angles a conferir com o original.
    func skewed(horizontal: Int, vertical: Int, fill: UInt32) -> Bitmap {
        var result = self
        if horizontal != 0 {
            let source = result
            let offsets = Bitmap.skewOffsets(count: source.height, degrees: horizontal)
            let extra = offsets.max() ?? 0
            result = Bitmap.mapped(width: source.width + extra, height: source.height) { x, y in
                let sx = x - offsets[y]
                return sx >= 0 && sx < source.width ? source[sx, y] : fill
            }
        }
        if vertical != 0 {
            let source = result
            let offsets = Bitmap.skewOffsets(count: source.width, degrees: vertical)
            let extra = offsets.max() ?? 0
            result = Bitmap.mapped(width: source.width, height: source.height + extra) { x, y in
                let sy = y - offsets[x]
                return sy >= 0 && sy < source.height ? source[x, sy] : fill
            }
        }
        return result
    }

    /// Each color becomes its complement (255 − r, 255 − g, 255 − b).
    mutating func invert(in rect: PixelRect, mask: ((Int, Int) -> Bool)? = nil) {
        let clipped = rect.intersection(bounds)
        guard !clipped.isEmpty else { return }
        let w = width
        withPixels { p in
            for y in clipped.y..<(clipped.y + clipped.height) {
                for x in clipped.x..<(clipped.x + clipped.width) where mask?(x, y) ?? true {
                    p[y * w + x] ^= 0x00FF_FFFF
                }
            }
        }
    }
}
