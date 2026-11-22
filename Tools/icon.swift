// Draws the original My Paint icon in code and writes the .icns family.
// Same visual family as My Notepad: one glossy object in three-quarter view, a thick blue frame,
// a cream surface with "My" in navy and silver metal details, on a transparent background.
// Usage: swift Tools/icon.swift Resources/MyPaint.icns [preview.png]
import AppKit

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    FileHandle.standardError.write("usage: icon.swift output.icns [preview.png]\n".data(using: .utf8)!)
    exit(2)
}

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

let navy = rgb(0.04, 0.10, 0.33)
let blueLight = rgb(0.24, 0.52, 0.98)
let blue = rgb(0.11, 0.38, 0.90)
let blueDark = rgb(0.05, 0.22, 0.66)
let blueSide = rgb(0.04, 0.17, 0.52)
let creamLight = rgb(0.995, 0.985, 0.955)
let cream = rgb(0.96, 0.93, 0.85)
let creamDark = rgb(0.88, 0.84, 0.74)
let stroke = [rgb(0.90, 0.16, 0.20), rgb(1.00, 0.70, 0.08), rgb(0.20, 0.70, 0.32), rgb(0.13, 0.50, 0.96)]

// The canvas board is drawn on a flat face of W × H points, then leaned back in three-quarter
// view by an affine map, like the notepad's front cover.
let faceWidth: CGFloat = 690, faceHeight: CGFloat = 690
let faceMap = CGAffineTransform(a: 0.95, b: 0.10, c: -0.34, d: 0.95, tx: 292, ty: 112)
/// Where the brush tip touches the end of the paint stroke, on the flat face.
let strokeEnd = CGPoint(x: faceWidth - 54 - 30, y: 54 + 452)

func gradient(_ colors: [CGColor], _ locations: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: locations)!
}

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func fill(_ context: CGContext, _ path: CGPath, _ colors: [CGColor], from: CGPoint, to: CGPoint,
          _ locations: [CGFloat]? = nil) {
    context.saveGState()
    context.addPath(path)
    context.clip()
    context.drawLinearGradient(gradient(colors, locations), start: from, end: to,
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    context.restoreGState()
}

// MARK: Canvas board

func drawStand(_ context: CGContext) {
    // The back leg that keeps the board standing, seen behind its right edge.
    let leg = CGMutablePath()
    leg.move(to: CGPoint(x: 880, y: 200))
    leg.addLine(to: CGPoint(x: 950, y: 222))
    leg.addQuadCurve(to: CGPoint(x: 968, y: 246), control: CGPoint(x: 966, y: 226))
    leg.addLine(to: CGPoint(x: 1000, y: 820))
    leg.addQuadCurve(to: CGPoint(x: 980, y: 846), control: CGPoint(x: 1003, y: 842))
    leg.addLine(to: CGPoint(x: 860, y: 868))
    leg.closeSubpath()
    fill(context, leg, [blueDark, blueSide], from: CGPoint(x: 900, y: 0), to: CGPoint(x: 1004, y: 0))
}

func drawBoard(_ context: CGContext, detail: Bool) {
    let face = CGRect(x: 0, y: 0, width: faceWidth, height: faceHeight)
    let frame = rounded(face, 62)

    // Depth: the same outline stacked towards the lower right, darker the deeper it goes.
    let depth = 32
    for step in stride(from: depth, through: 1, by: -1) {
        context.saveGState()
        context.translateBy(x: CGFloat(step) * 0.90, y: CGFloat(step) * 0.42)
        context.concatenate(faceMap)
        context.addPath(frame)
        let shade = 0.80 + 0.20 * CGFloat(depth - step) / CGFloat(depth)
        context.setFillColor(rgb(0.04 * shade, 0.18 * shade, 0.55 * shade))
        context.fillPath()
        context.restoreGState()
    }

    context.saveGState()
    context.concatenate(faceMap)

    // Blue plastic frame, lit from the upper left.
    fill(context, frame, [blueLight, blue, blueDark], from: CGPoint(x: 0, y: 0),
         to: CGPoint(x: faceWidth * 0.55, y: faceHeight), [0, 0.45, 1])
    if detail {
        context.saveGState()
        context.addPath(rounded(face.insetBy(dx: 7, dy: 7), 56))
        context.setStrokeColor(rgb(1, 1, 1, 0.30))
        context.setLineWidth(6)
        context.strokePath()
        context.restoreGState()
    }

    // Cream canvas set into the frame, with a soft inner shadow along its top and left.
    let surfaceRect = face.insetBy(dx: 54, dy: 54)
    let surface = rounded(surfaceRect, 30)
    fill(context, surface, [creamLight, cream, creamDark], from: surfaceRect.origin,
         to: CGPoint(x: surfaceRect.maxX, y: surfaceRect.maxY), [0, 0.55, 1])
    if detail {
        context.saveGState()
        context.addPath(surface)
        context.clip()
        context.setShadow(offset: CGSize(width: 6, height: 8), blur: 18, color: rgb(0.10, 0.12, 0.25, 0.45))
        context.addRect(surfaceRect.insetBy(dx: -60, dy: -60))
        context.addPath(surface)
        context.setFillColor(rgb(0, 0, 0, 1))
        context.fillPath(using: .evenOdd)
        context.restoreGState()
    }

    drawPaintStroke(context, in: surfaceRect, detail: detail)
    drawLettering(context, in: surfaceRect)
    context.restoreGState()
}

/// A wide rainbow brush stroke under the lettering, where the notepad has its ruled lines.
func drawPaintStroke(_ context: CGContext, in rect: CGRect, detail: Bool) {
    // One ribbon of four colours: each band is drawn a little wider than its spacing, from the
    // bottom up, so they touch like a single loaded brush stroke.
    let band: CGFloat = 27
    let start = CGPoint(x: rect.minX + 40, y: strokeEnd.y - 30)
    for (index, color) in stroke.enumerated().reversed() {
        let offset = CGFloat(index - stroke.count + 1) * band
        let path = CGMutablePath()
        path.move(to: CGPoint(x: start.x, y: start.y + offset))
        path.addCurve(to: CGPoint(x: strokeEnd.x, y: strokeEnd.y + offset),
                      control1: CGPoint(x: rect.minX + 210, y: start.y + offset - 80),
                      control2: CGPoint(x: rect.minX + 360, y: strokeEnd.y + offset + 70))
        context.saveGState()
        context.addPath(path)
        context.setLineWidth(band + 5)
        context.setLineCap(.round)
        context.setStrokeColor(color)
        context.strokePath()
        if detail {
            context.translateBy(x: 0, y: -7)
            context.addPath(path)
            context.setLineWidth(3)
            context.setStrokeColor(rgb(1, 1, 1, 0.28))
            context.strokePath()
        }
        context.restoreGState()
    }
}

func drawLettering(_ context: CGContext, in rect: CGRect) {
    let font = NSFont.systemFont(ofSize: 250, weight: .black)
    let text = NSAttributedString(string: "My", attributes: [
        .font: font,
        .foregroundColor: NSColor(cgColor: navy)!,
        .kern: -6,
    ])
    let size = text.size()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    text.draw(at: NSPoint(x: rect.midX - size.width / 2 - 6, y: rect.minY + 28))
    NSGraphicsContext.restoreGraphicsState()
}

// MARK: Brush

/// The brush lies across the lower right corner with its tip at the end of the stroke, the way the
/// notepad's page curl breaks that corner.
func drawBrush(_ context: CGContext, detail: Bool) {
    let tip = CGPoint(x: strokeEnd.x, y: strokeEnd.y - 40).applying(faceMap)
    let angle = atan2(0.78, 0.62)
    let length: CGFloat = 400
    context.saveGState()
    context.translateBy(x: tip.x, y: tip.y)
    context.rotate(by: angle)
    context.scaleBy(x: 1.12, y: 1.12)
    context.setShadow(offset: CGSize(width: 10, height: 14), blur: 22, color: rgb(0.02, 0.05, 0.20, 0.40))
    context.beginTransparencyLayer(auxiliaryInfo: nil)

    // Handle: glossy navy lacquer, tapering towards a rounded end.
    let handle = CGMutablePath()
    handle.move(to: CGPoint(x: 160, y: -27))
    handle.addLine(to: CGPoint(x: length - 18, y: -19))
    handle.addQuadCurve(to: CGPoint(x: length - 18, y: 19), control: CGPoint(x: length + 10, y: 0))
    handle.addLine(to: CGPoint(x: 160, y: 27))
    handle.closeSubpath()
    fill(context, handle, [rgb(0.03, 0.07, 0.24), rgb(0.20, 0.32, 0.70), rgb(0.08, 0.16, 0.45), rgb(0.02, 0.05, 0.18)],
         from: CGPoint(x: 0, y: -27), to: CGPoint(x: 0, y: 27), [0, 0.30, 0.65, 1])
    if detail {
        context.saveGState()
        context.setStrokeColor(rgb(1, 1, 1, 0.45))
        context.setLineWidth(5)
        context.setLineCap(.round)
        context.move(to: CGPoint(x: 180, y: -12))
        context.addLine(to: CGPoint(x: length - 40, y: -8))
        context.strokePath()
        context.restoreGState()
    }

    // Ferrule: polished metal like the notepad's rings, with two crimp grooves.
    let ferrule = rounded(CGRect(x: 84, y: -30, width: 84, height: 60), 8)
    let metal = [rgb(0.42, 0.44, 0.48), rgb(0.95, 0.96, 0.98), rgb(0.70, 0.72, 0.76), rgb(0.86, 0.87, 0.90), rgb(0.36, 0.38, 0.42)]
    fill(context, ferrule, metal, from: CGPoint(x: 0, y: -30), to: CGPoint(x: 0, y: 30), [0, 0.28, 0.55, 0.75, 1])
    if detail {
        for x in [122.0, 140.0] {
            let groove = CGRect(x: x, y: -30, width: 5, height: 60)
            fill(context, CGPath(rect: groove, transform: nil), [rgb(0.30, 0.32, 0.36), rgb(0.62, 0.64, 0.68), rgb(0.28, 0.30, 0.34)],
                 from: CGPoint(x: 0, y: -30), to: CGPoint(x: 0, y: 30), [0, 0.35, 1])
        }
    }

    // Bristles: a full tuft narrowing to a point, dipped in the stroke's red.
    let tuft = CGMutablePath()
    tuft.move(to: CGPoint(x: 90, y: -27))
    tuft.addCurve(to: CGPoint(x: 0, y: 0), control1: CGPoint(x: 52, y: -34), control2: CGPoint(x: 14, y: -14))
    tuft.addCurve(to: CGPoint(x: 90, y: 27), control1: CGPoint(x: 14, y: 14), control2: CGPoint(x: 52, y: 34))
    tuft.closeSubpath()
    fill(context, tuft, [rgb(0.62, 0.45, 0.28), rgb(0.93, 0.80, 0.58), rgb(0.56, 0.40, 0.24)],
         from: CGPoint(x: 0, y: -30), to: CGPoint(x: 0, y: 30), [0, 0.4, 1])
    context.saveGState()
    context.addPath(tuft)
    context.clip()
    let paint = CGMutablePath()
    paint.move(to: CGPoint(x: -4, y: -40))
    paint.addCurve(to: CGPoint(x: 58, y: 40), control1: CGPoint(x: 62, y: -30), control2: CGPoint(x: 30, y: 10))
    paint.addLine(to: CGPoint(x: -4, y: 40))
    paint.closeSubpath()
    fill(context, paint, [rgb(0.62, 0.06, 0.10), rgb(0.98, 0.28, 0.30), rgb(0.70, 0.08, 0.12)],
         from: CGPoint(x: 0, y: -30), to: CGPoint(x: 0, y: 30), [0, 0.4, 1])
    if detail {
        context.setStrokeColor(rgb(0.30, 0.18, 0.08, 0.30))
        context.setLineWidth(1.6)
        for y in stride(from: -20.0, through: 20.0, by: 8.0) {
            context.move(to: CGPoint(x: 88, y: y))
            context.addLine(to: CGPoint(x: 10, y: y * 0.25))
        }
        context.strokePath()
    }
    context.restoreGState()

    context.endTransparencyLayer()
    context.restoreGState()
}

// MARK: Output

func render(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    let context = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    context.interpolationQuality = .high
    // Top-left origin, in 1024-point units.
    let scale = CGFloat(pixels) / 1024
    context.translateBy(x: 0, y: CGFloat(pixels))
    context.scaleBy(x: scale, y: -scale)
    let detail = pixels >= 64
    drawStand(context)
    drawBoard(context, detail: detail)
    drawBrush(context, detail: detail)
    return rep.representation(using: .png, properties: [:])!
}

let output = URL(fileURLWithPath: arguments[1])
let iconset = FileManager.default.temporaryDirectory
    .appendingPathComponent("MyPaint-\(ProcessInfo.processInfo.globallyUniqueString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconset) }
for points in [16, 32, 128, 256, 512] {
    try render(points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try render(points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { exit(1) }
if arguments.count >= 3 {
    try render(1024).write(to: URL(fileURLWithPath: arguments[2]))
}
