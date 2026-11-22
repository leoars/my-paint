import CoreGraphics
import Foundation

/// Outline and Fill choices of the Shapes group, in the order of their menus.
/// The textures share their look with the brushes (`BrushKind(style:)`).
enum ShapeStyle: Int, CaseIterable {
    case none, solid, crayon, marker, oil, naturalPencil, watercolor

    var isTexture: Bool { rawValue >= ShapeStyle.crayon.rawValue }

    /// "No outline" and "No fill" differ; the other names are shared.
    func nameKey(outline: Bool) -> String {
        switch self {
        case .none: return outline ? "outline.none" : "fill.none"
        case .solid: return "style.solid"
        case .crayon: return "style.crayon"
        case .marker: return "style.marker"
        case .oil: return "style.oil"
        case .naturalPencil: return "style.naturalPencil"
        case .watercolor: return "style.watercolor"
        }
    }
}

/// Everything besides the geometry that decides how a shape is drawn.
struct ShapeOptions: Equatable {
    var outline = ShapeStyle.solid
    var fill = ShapeStyle.none
    /// Outline width in pixels.
    var width = 1
}

extension GalleryShape {
    var nameKey: String { "shape.\(self)" }
    /// Line, curve and polygon are defined by points; the others fill a box.
    var usesPoints: Bool { self == .line || self == .curve || self == .polygon }
    /// Line and curve have no inside, so Fill does not apply to them.
    var canFill: Bool { self != .line && self != .curve }
}

/// A shape as drawn: a box for most shapes, points for line, curve and polygon.
struct DrawnShape: Equatable {
    var kind: GalleryShape
    /// Box shapes: the pixels the shape covers, outline included.
    var box: PixelRect
    /// Line: start and end. Curve: start, control 1, control 2, end. Polygon: the vertices.
    var points: [PixelPoint]
    /// A polygon being built is open: drawn as lines and never filled.
    var isClosed: Bool

    static func box(_ kind: GalleryShape, _ rect: PixelRect) -> DrawnShape {
        DrawnShape(kind: kind, box: rect, points: [], isClosed: true)
    }

    static func points(_ kind: GalleryShape, _ points: [PixelPoint], closed: Bool = true) -> DrawnShape {
        DrawnShape(kind: kind, box: DrawnShape.boundingBox(points), points: points, isClosed: closed)
    }

    /// Whether the shape has an inside that Fill paints.
    var canFill: Bool { kind.canFill && isClosed }

    /// The box with the handles: the box itself, or the pixels spanned by the points.
    var bounds: PixelRect { kind.usesPoints ? DrawnShape.boundingBox(points) : box }

    static func boundingBox(_ points: [PixelPoint]) -> PixelRect {
        guard let first = points.first else { return PixelRect(x: 0, y: 0, width: 0, height: 0) }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for point in points {
            minX = min(minX, point.x); maxX = max(maxX, point.x)
            minY = min(minY, point.y); maxY = max(maxY, point.y)
        }
        return PixelRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    func moved(_ dx: Int, _ dy: Int) -> DrawnShape {
        var shape = self
        shape.box = box.offsetBy(dx, dy)
        shape.points = points.map { PixelPoint(x: $0.x + dx, y: $0.y + dy) }
        return shape
    }

    /// The shape stretched so its bounds become `rect`; points keep their place relative to the box.
    func resized(to rect: PixelRect) -> DrawnShape {
        var shape = self
        guard kind.usesPoints else { shape.box = rect; return shape }
        let old = bounds
        func map(_ value: Int, _ from: Int, _ fromSize: Int, _ to: Int, _ toSize: Int) -> Int {
            guard fromSize > 1 else { return to }
            return to + Int((Double(value - from) * Double(toSize - 1) / Double(fromSize - 1)).rounded())
        }
        shape.points = points.map {
            PixelPoint(x: map($0.x, old.x, old.width, rect.x, rect.width), y: map($0.y, old.y, old.height, rect.y, rect.height))
        }
        shape.box = DrawnShape.boundingBox(shape.points)
        return shape
    }
}

/// The outline of every shape as a pure function of its box or points, in image pixel
/// coordinates with y going down. Proportions are our own drawings (a conferir com o original).
enum ShapeGeometry {
    /// Corner radius of the rounded rectangle and the rounded callout, as a share of the shorter side.
    static let cornerRatio: CGFloat = 0.2
    /// Share of the height taken by the body of a callout; the tail uses the rest.
    static let calloutBody: CGFloat = 0.72
    /// A click this close (in pixels) to the first vertex closes a polygon.
    static let polygonCloseDistance = 3

    /// Path of a box shape filling `rect`. Point shapes get a simple stand-in (a diagonal, a rectangle).
    static func path(for kind: GalleryShape, in r: CGRect) -> CGPath {
        let path = CGMutablePath()
        switch kind {
        case .line, .curve:
            path.move(to: CGPoint(x: r.minX, y: r.maxY))
            path.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        case .rectangle, .polygon:
            path.addRect(r)
        case .oval:
            path.addEllipse(in: r)
        case .roundedRectangle:
            let radius = min(r.width, r.height) * cornerRatio
            path.addRoundedRect(in: r, cornerWidth: radius, cornerHeight: radius)
        case .triangle:
            return fitted(unit: [(0.5, 0), (1, 1), (0, 1)], in: r)
        case .rightTriangle:
            return fitted(unit: [(0, 0), (1, 1), (0, 1)], in: r)
        case .diamond:
            return fitted(unit: [(0.5, 0), (1, 0.5), (0.5, 1), (0, 0.5)], in: r)
        case .pentagon:
            return fitted(unit: regular(5), in: r)
        case .hexagon:
            return fitted(unit: [(0.25, 0), (0.75, 0), (1, 0.5), (0.75, 1), (0.25, 1), (0, 0.5)], in: r)
        case .rightArrow, .leftArrow, .upArrow, .downArrow:
            // A right arrow in the unit square, turned for the other directions.
            let right: [(CGFloat, CGFloat)] = [(0, 0.25), (0.5, 0.25), (0.5, 0), (1, 0.5), (0.5, 1), (0.5, 0.75), (0, 0.75)]
            let turned: [(CGFloat, CGFloat)]
            switch kind {
            case .leftArrow: turned = right.map { (1 - $0.0, $0.1) }
            case .upArrow: turned = right.map { ($0.1, 1 - $0.0) }
            case .downArrow: turned = right.map { ($0.1, $0.0) }
            default: turned = right
            }
            return fitted(unit: turned, in: r)
        case .star4: return fitted(unit: star(4, inner: 0.38), in: r)
        case .star5: return fitted(unit: star(5, inner: 0.4), in: r)
        case .star6: return fitted(unit: star(6, inner: 0.55), in: r)
        case .roundedCallout:
            return roundedCallout(in: r)
        case .ovalCallout:
            return ovalCallout(in: r)
        case .cloudCallout:
            return fitted(cloud(), in: r)
        case .heart:
            let heart = CGMutablePath()
            heart.move(to: CGPoint(x: 0.5, y: 1))
            heart.addCurve(to: CGPoint(x: 0, y: 0.3), control1: CGPoint(x: 0.35, y: 0.85), control2: CGPoint(x: 0, y: 0.6))
            heart.addCurve(to: CGPoint(x: 0.5, y: 0.2), control1: CGPoint(x: 0, y: 0.02), control2: CGPoint(x: 0.4, y: -0.02))
            heart.addCurve(to: CGPoint(x: 1, y: 0.3), control1: CGPoint(x: 0.6, y: -0.02), control2: CGPoint(x: 1, y: 0.02))
            heart.addCurve(to: CGPoint(x: 0.5, y: 1), control1: CGPoint(x: 1, y: 0.6), control2: CGPoint(x: 0.65, y: 0.85))
            heart.closeSubpath()
            return fitted(heart, in: r)
        case .lightning:
            return fitted(unit: [(0.36, 0), (0.7, 0), (0.53, 0.35), (0.8, 0.35), (0.25, 1), (0.42, 0.55), (0.18, 0.55)], in: r)
        }
        return path
    }

    /// Path of a point shape through the centers of its pixels.
    static func path(through points: [PixelPoint], kind: GalleryShape, closed: Bool) -> CGPath {
        let path = CGMutablePath()
        let centers = points.map { CGPoint(x: CGFloat($0.x) + 0.5, y: CGFloat($0.y) + 0.5) }
        guard let first = centers.first else { return path }
        path.move(to: first)
        if kind == .curve, centers.count == 4 {
            path.addCurve(to: centers[3], control1: centers[1], control2: centers[2])
        } else {
            centers.dropFirst().forEach { path.addLine(to: $0) }
            if closed && kind == .polygon { path.closeSubpath() }
        }
        return path
    }

    /// The path a drawn shape is filled and stroked along. Box shapes move `inset` pixels in from
    /// the box, so an outline of twice that width stays inside it; point shapes ignore it.
    static func path(for shape: DrawnShape, inset: CGFloat) -> CGPath {
        if shape.kind.usesPoints { return path(through: shape.points, kind: shape.kind, closed: shape.isClosed) }
        let box = shape.box
        let dx = min(inset, CGFloat(box.width) / 2), dy = min(inset, CGFloat(box.height) / 2)
        let rect = CGRect(x: box.x, y: box.y, width: box.width, height: box.height).insetBy(dx: dx, dy: dy)
        return path(for: shape.kind, in: rect)
    }

    // MARK: Building blocks

    private static func polygon(_ points: [(CGFloat, CGFloat)]) -> CGMutablePath {
        let path = CGMutablePath()
        path.addLines(between: points.map { CGPoint(x: $0.0, y: $0.1) })
        path.closeSubpath()
        return path
    }

    private static func fitted(unit points: [(CGFloat, CGFloat)], in rect: CGRect) -> CGPath {
        fitted(polygon(points), in: rect)
    }

    /// Stretches `path` so its exact bounds become `rect`.
    static func fitted(_ path: CGPath, in rect: CGRect) -> CGPath {
        let bounds = path.boundingBoxOfPath
        guard bounds.width > 0, bounds.height > 0 else { return path }
        var transform = CGAffineTransform(translationX: rect.minX, y: rect.minY)
            .scaledBy(x: rect.width / bounds.width, y: rect.height / bounds.height)
            .translatedBy(x: -bounds.minX, y: -bounds.minY)
        return path.copy(using: &transform) ?? path
    }

    /// A regular polygon with a vertex at the top.
    private static func regular(_ count: Int) -> [(CGFloat, CGFloat)] {
        (0..<count).map { index in
            let angle = -CGFloat.pi / 2 + CGFloat(index) * 2 * .pi / CGFloat(count)
            return (cos(angle), sin(angle))
        }
    }

    /// A star with `count` points, the first at the top; `inner` is the radius of the notches.
    private static func star(_ count: Int, inner: CGFloat) -> [(CGFloat, CGFloat)] {
        (0..<(count * 2)).map { index in
            let angle = -CGFloat.pi / 2 + CGFloat(index) * .pi / CGFloat(count)
            let radius = index % 2 == 0 ? 1 : inner
            return (cos(angle) * radius, sin(angle) * radius)
        }
    }

    /// Rounded rectangle with a tail from its bottom edge to the bottom-left of the box.
    private static func roundedCallout(in r: CGRect) -> CGPath {
        let bottom = r.minY + r.height * calloutBody
        let radius = min(r.width, bottom - r.minY) * cornerRatio
        let path = CGMutablePath()
        path.move(to: CGPoint(x: r.minX + radius, y: r.minY))
        path.addArc(tangent1End: CGPoint(x: r.maxX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: bottom), radius: radius)
        path.addArc(tangent1End: CGPoint(x: r.maxX, y: bottom), tangent2End: CGPoint(x: r.minX, y: bottom), radius: radius)
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.42, y: bottom))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.16, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.24, y: bottom))
        path.addArc(tangent1End: CGPoint(x: r.minX, y: bottom), tangent2End: CGPoint(x: r.minX, y: r.minY), radius: radius)
        path.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.minY), radius: radius)
        path.closeSubpath()
        return path
    }

    /// Ellipse with a tail going down to the bottom-left of the box.
    private static func ovalCallout(in r: CGRect) -> CGPath {
        let body = CGRect(x: r.minX, y: r.minY, width: r.width, height: r.height * calloutBody)
        let tip = CGPoint(x: r.minX + r.width * 0.16, y: r.maxY)
        let path = CGMutablePath()
        guard body.width > 0, body.height > 0 else {
            path.addRect(r)
            return path
        }
        // Angles grow from +x towards +y, which points down here: 90° is the bottom of the ellipse.
        let from = 100 * CGFloat.pi / 180, to = 125 * CGFloat.pi / 180
        let transform = CGAffineTransform(translationX: body.midX, y: body.midY).scaledBy(x: body.width / 2, y: body.height / 2)
        path.move(to: tip)
        path.addLine(to: CGPoint(x: cos(to), y: sin(to)).applying(transform))
        path.addRelativeArc(center: .zero, radius: 1, startAngle: to, delta: 2 * .pi - (to - from), transform: transform)
        path.closeSubpath()
        return path
    }

    /// A scalloped cloud with two small bubbles under it, in unit space (fitted later).
    private static func cloud() -> CGPath {
        let path = CGMutablePath()
        let center = CGPoint(x: 0.5, y: 0.36), radius = CGSize(width: 0.4, height: 0.27)
        let bumps = 9
        func point(_ angle: CGFloat, _ scale: CGFloat) -> CGPoint {
            CGPoint(x: center.x + cos(angle) * radius.width * scale, y: center.y + sin(angle) * radius.height * scale)
        }
        for index in 0..<bumps {
            let a = -CGFloat.pi / 2 + CGFloat(index) * 2 * .pi / CGFloat(bumps)
            let b = a + 2 * .pi / CGFloat(bumps)
            if index == 0 { path.move(to: point(a, 1)) }
            path.addQuadCurve(to: point(b, 1), control: point((a + b) / 2, 1.55))
        }
        path.closeSubpath()
        path.addEllipse(in: CGRect(x: 0.15, y: 0.8, width: 0.11, height: 0.09))
        path.addEllipse(in: CGRect(x: 0.05, y: 0.93, width: 0.07, height: 0.07))
        return path
    }
}

/// Draws shapes onto a bitmap with Core Graphics, antialiased, as Paint does for shapes.
enum ShapeRenderer {
    private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    /// The pixels drawing `shape` with an outline of `width` may change.
    static func area(of shape: DrawnShape, width: Int) -> PixelRect {
        let bounds = shape.bounds
        let margin = shape.kind.usesPoints ? (width + 1) / 2 + 2 : 1
        return PixelRect(x: bounds.x - margin, y: bounds.y - margin, width: bounds.width + 2 * margin, height: bounds.height + 2 * margin)
    }

    /// Draws `shape` over what `bitmap` holds and returns the area it may have changed.
    /// The outline takes `outline`, the inside `fill`. Line and curve, and a polygon still being
    /// built, are always stroked. Textured styles use the brushes' textures (see Brushes.swift).
    @discardableResult
    static func draw(_ shape: DrawnShape, options: ShapeOptions, outline: RGB, fill: RGB, on bitmap: inout Bitmap) -> PixelRect {
        let width = CGFloat(max(1, options.width))
        let strokes = options.outline != .none || !shape.canFill
        let fills = shape.canFill && options.fill != .none
        let area = ShapeRenderer.area(of: shape, width: options.width).intersection(bitmap.bounds)
        guard strokes || fills, !area.isEmpty else { return PixelRect(x: 0, y: 0, width: 0, height: 0) }
        let outlineTexture = BrushKind(style: options.outline)
        let fillTexture = BrushKind(style: options.fill)
        let antialias = shape.kind != .rectangle
        let fillPath = fills ? ShapeGeometry.path(for: shape, inset: strokes ? width / 2 : 0) : nil
        // The outline is filled as an area: Core Graphics strokes 1 px lines unevenly from
        // left to right, which would break the symmetry of the shapes.
        // Square corners where they stay inside the box; round joins keep star points in it.
        let outlinePath = strokes ? ShapeGeometry.path(for: shape, inset: width / 2)
            .copy(strokingWithWidth: width, lineCap: .round, lineJoin: shape.kind == .rectangle ? .miter : .round, miterLimit: 10) : nil
        if let path = fillPath, let texture = fillTexture {
            textured(path, texture, color: fill, area: area, antialias: antialias, on: &bitmap)
        }
        let w = bitmap.width, h = bitmap.height
        let solidFill = fillTexture == nil ? fillPath : nil, solidOutline = outlineTexture == nil ? outlinePath : nil
        if solidFill != nil || solidOutline != nil {
            bitmap.withPixels { pixels in
                guard let context = CGContext(
                    data: pixels.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                    space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return }
                // Image coordinates: y goes down and pixel (x, y) covers x...x+1, y...y+1.
                context.translateBy(x: 0, y: CGFloat(h))
                context.scaleBy(x: 1, y: -1)
                context.clip(to: CGRect(x: area.x, y: area.y, width: area.width, height: area.height))
                // A rectangle always lies on whole pixels, so it is drawn crisp.
                context.setShouldAntialias(antialias)
                if let path = solidFill {
                    context.addPath(path)
                    context.setFillColor(fill.cgColor)
                    context.fillPath()
                }
                if let path = solidOutline {
                    context.addPath(path)
                    context.setFillColor(outline.cgColor)
                    context.fillPath()
                }
                // Core Graphics leaves the unused byte undefined; the document keeps it opaque.
                for y in area.y..<area.maxY {
                    for index in (y * w + area.x)..<(y * w + area.maxX) { pixels[index] |= 0xFF00_0000 }
                }
            }
        }
        if let path = outlinePath, let texture = outlineTexture {
            textured(path, texture, color: outline, area: area, antialias: antialias, on: &bitmap)
        }
        return area
    }

    /// Paints the inside of `path` with a brush texture: its coverage, times the texture's grain
    /// and opacity, blends the color over what is there. Watercolor gets softened edges.
    private static func textured(_ path: CGPath, _ texture: BrushKind, color: RGB, area: PixelRect, antialias: Bool, on bitmap: inout Bitmap) {
        let aw = area.width, ah = area.height
        var gray = [UInt8](repeating: 0, count: aw * ah)
        gray.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress, width: aw, height: ah, bitsPerComponent: 8, bytesPerRow: aw,
                                          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
            context.translateBy(x: 0, y: CGFloat(ah))
            context.scaleBy(x: 1, y: -1)
            context.translateBy(x: CGFloat(-area.x), y: CGFloat(-area.y))
            context.setShouldAntialias(antialias)
            context.addPath(path)
            context.setFillColor(gray: 1, alpha: 1)
            context.fillPath()
        }
        if texture == .watercolor { gray = softened(gray, width: aw, height: ah) }
        // Coverage over the whole image, as the brush blend expects.
        var coverage = [UInt8](repeating: 0, count: bitmap.width * bitmap.height)
        for y in 0..<ah {
            for x in 0..<aw where gray[y * aw + x] > 0 {
                let ix = area.x + x, iy = area.y + y
                let value = Double(gray[y * aw + x]) * texture.grain(x: ix, y: iy)
                coverage[iy * bitmap.width + ix] = UInt8(min(255, value.rounded()))
            }
        }
        let base = bitmap
        BrushStroke.blend(area, color: color, opacity: texture.opacity, base: base, coverage: coverage, on: &bitmap)
    }

    /// A 3 × 3 box blur, for the soft edges of watercolor.
    private static func softened(_ values: [UInt8], width: Int, height: Int) -> [UInt8] {
        var result = values
        for y in 0..<height {
            for x in 0..<width {
                var sum = 0, count = 0
                for dy in -1...1 {
                    for dx in -1...1 {
                        let sx = x + dx, sy = y + dy
                        guard sx >= 0, sy >= 0, sx < width, sy < height else { continue }
                        sum += Int(values[sy * width + sx])
                        count += 1
                    }
                }
                result[y * width + x] = UInt8(sum / count)
            }
        }
        return result
    }
}

extension RGB {
    var cgColor: CGColor { CGColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1) }
}
