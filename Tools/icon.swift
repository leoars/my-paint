// Draws the original My Paint icon in code and writes the .icns family.
// A painter's palette in the My Suite style: one glossy object in three-quarter view with a
// thick blue rim, a cream surface with "My" in navy, dabs of paint and a blue brush with a
// silver ferrule, on a transparent background. The artwork fills the canvas edge to edge.
// Usage: swift Tools/icon.swift Resources/MyPaint.icns [preview.png]
import AppKit
import CoreText

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    FileHandle.standardError.write("usage: icon.swift output.icns [preview.png]\n".data(using: .utf8)!)
    exit(2)
}

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func fill(_ context: CGContext, _ path: CGPath, _ stops: [(UInt32, CGFloat, CGFloat)], from: CGPoint, to: CGPoint) {
    context.saveGState()
    context.addPath(path); context.clip()
    let gradient = CGGradient(colorsSpace: sRGB, colors: stops.map { rgb($0.0, $0.1) } as CFArray, locations: stops.map { $0.2 })!
    context.drawLinearGradient(gradient, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    context.restoreGState()
}

// Core Graphics shadows ignore the CTM, so they are scaled by hand for each output size.
var shadowScale: CGFloat = 1
func shadow(_ context: CGContext, x: CGFloat, y: CGFloat, blur: CGFloat, _ tint: CGColor) {
    context.setShadow(offset: CGSize(width: x * shadowScale, height: y * shadowScale), blur: blur * shadowScale, color: tint)
}

// The palette is drawn on a flat face (800 × 660, y down) and leaned back in three-quarter view,
// like the My Notepad pad and the My Explorer folder.
let lean = CGAffineTransform(a: 1, b: 0.10, c: -0.30, d: 1, tx: 0, ty: 0)
let edgeDepth = 26

/// The outline of the palette: a rounded, slightly lopsided oval.
func blob(inset: CGFloat = 0) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 40, y: 340))
    path.addCurve(to: CGPoint(x: 390, y: 30), control1: CGPoint(x: 40, y: 150), control2: CGPoint(x: 200, y: 30))
    path.addCurve(to: CGPoint(x: 770, y: 300), control1: CGPoint(x: 610, y: 30), control2: CGPoint(x: 770, y: 130))
    path.addCurve(to: CGPoint(x: 440, y: 630), control1: CGPoint(x: 770, y: 500), control2: CGPoint(x: 640, y: 630))
    path.addCurve(to: CGPoint(x: 40, y: 340), control1: CGPoint(x: 220, y: 630), control2: CGPoint(x: 40, y: 530))
    path.closeSubpath()
    guard inset > 0 else { return path }
    // Shrinks towards the middle of the shape; close enough to an inset for a rounded outline.
    let centre = CGPoint(x: 405, y: 330)
    let factor = (365 - inset) / 365
    var shrink = CGAffineTransform(translationX: centre.x, y: centre.y).scaledBy(x: factor, y: factor)
        .translatedBy(x: -centre.x, y: -centre.y)
    return path.copy(using: &shrink) ?? path
}

let thumbHole = CGRect(x: 548, y: 418, width: 118, height: 96)

func lettering(_ text: String, size: CGFloat, centre: CGFloat, baseline: CGFloat) -> CGPath {
    let font = NSFont.systemFont(ofSize: size, weight: .black)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font, .kern: -size * 0.02]))
    let path = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count), positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRange(), &glyphs); CTRunGetPositions(run, CFRange(), &positions)
        let runFont = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName as String] as! CTFont
        for index in 0..<count {
            // Glyph outlines are y-up; flip them into the y-down face.
            var flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: positions[index].x, ty: baseline)
            if let glyph = CTFontCreatePathForGlyph(runFont, glyphs[index], &flip) { path.addPath(glyph) }
        }
    }
    var move = CGAffineTransform(translationX: centre - path.boundingBoxOfPath.midX, y: 0)
    return path.copy(using: &move) ?? path
}

/// One dab of paint: a glossy blob with a darker underside.
func dab(_ context: CGContext, at centre: CGPoint, radius: CGFloat, light: UInt32, base: UInt32, dark: UInt32) {
    let rect = CGRect(x: centre.x - radius, y: centre.y - radius * 0.86, width: radius * 2, height: radius * 1.72)
    let path = CGPath(ellipseIn: rect, transform: nil)
    context.saveGState()
    shadow(context, x: 4, y: -8, blur: 12, rgb(0x3A2A10, 0.38))
    context.addPath(path); context.setFillColor(rgb(base)); context.fillPath()
    context.restoreGState()
    fill(context, path, [(light, 1, 0), (base, 1, 0.5), (dark, 1, 1)], from: CGPoint(x: rect.minX, y: rect.minY), to: CGPoint(x: rect.maxX, y: rect.maxY))
    let gloss = CGPath(ellipseIn: CGRect(x: centre.x - radius * 0.55, y: centre.y - radius * 0.62, width: radius * 0.8, height: radius * 0.42), transform: nil)
    context.addPath(gloss); context.setFillColor(rgb(0xFFFFFF, 0.55)); context.fillPath()
}

func drawPalette(_ context: CGContext, detail: Bool) {
    let rim = blob()
    let hole = CGPath(ellipseIn: thumbHole, transform: nil)
    let holeRim = CGPath(ellipseIn: thumbHole.insetBy(dx: -20, dy: -20), transform: nil)

    // Rim, with the thumb hole cut through it.
    context.saveGState()
    context.addPath(rim); context.addPath(hole); context.clip(using: .evenOdd)
    fill(context, rim, [(0x5B97FF, 1, 0), (0x2468EC, 1, 0.45), (0x1243B4, 1, 1)], from: CGPoint(x: 150, y: 30), to: CGPoint(x: 600, y: 630))
    context.restoreGState()

    // Cream surface, sunk a little into the rim.
    let surface = blob(inset: 46)
    context.saveGState()
    context.addPath(surface); context.addPath(holeRim); context.clip(using: .evenOdd)
    fill(context, surface, [(0xFFFBF0, 1, 0), (0xF6EEDB, 1, 0.6), (0xE9DDC2, 1, 1)], from: CGPoint(x: 200, y: 80), to: CGPoint(x: 560, y: 600))
    // The rim's shade along the top and left of the surface.
    context.setLineWidth(22)
    context.setStrokeColor(rgb(0x0A1E5C, 0.20))
    context.addPath(surface); context.strokePath()
    context.restoreGState()

    // A light line along the outer edge of the rim.
    context.saveGState()
    context.addPath(rim); context.addPath(hole); context.clip(using: .evenOdd)
    context.setLineWidth(12)
    context.setStrokeColor(rgb(0xBFD6FF, 0.75))
    context.addPath(rim); context.strokePath()
    context.restoreGState()

    // "My", as on the other icons of the suite.
    context.addPath(lettering("My", size: 232, centre: 330, baseline: 470))
    context.setFillColor(rgb(0x0B1E5B)); context.fillPath()

    // Paint along the top of the palette.
    let dabs: [(CGPoint, UInt32, UInt32, UInt32)] = [
        (CGPoint(x: 178, y: 226), 0xFF8A8A, 0xE5322E, 0xA8161A),
        (CGPoint(x: 296, y: 148), 0xFFE08A, 0xFFB01F, 0xC97A08),
        (CGPoint(x: 432, y: 122), 0x9BE7A4, 0x2FB34C, 0x177A30),
        (CGPoint(x: 566, y: 158), 0x9CCBFF, 0x2A86F0, 0x1250B8),
        (CGPoint(x: 660, y: 256), 0xD3A6FF, 0x8E48DC, 0x5B229E),
    ]
    for (centre, light, base, dark) in dabs {
        dab(context, at: centre, radius: detail ? 50 : 58, light: light, base: base, dark: dark)
    }
}

/// The brush lies across the right of the palette, its tip in the paint.
func drawBrush(_ context: CGContext, detail: Bool) {
    let tip = CGPoint(x: 470, y: 268), end = CGPoint(x: 930, y: 700)
    let length = hypot(end.x - tip.x, end.y - tip.y)
    context.saveGState()
    context.translateBy(x: tip.x, y: tip.y)
    context.rotate(by: atan2(end.y - tip.y, end.x - tip.x))
    let half: CGFloat = 30

    // Handle, tapering to a rounded end.
    let handle = CGMutablePath()
    handle.move(to: CGPoint(x: 200, y: -half))
    handle.addLine(to: CGPoint(x: length - 40, y: -half * 0.55))
    handle.addQuadCurve(to: CGPoint(x: length - 40, y: half * 0.55), control: CGPoint(x: length + 4, y: 0))
    handle.addLine(to: CGPoint(x: 200, y: half))
    handle.closeSubpath()
    context.saveGState()
    shadow(context, x: 8, y: -14, blur: 16, rgb(0x061340, 0.45))
    context.addPath(handle); context.setFillColor(rgb(0x1A56D6)); context.fillPath()
    context.restoreGState()
    fill(context, handle, [(0x6AA2FF, 1, 0), (0x1F5BDB, 1, 0.45), (0x0C3190, 1, 1)], from: CGPoint(x: 0, y: -half), to: CGPoint(x: 0, y: half))
    if detail {
        context.setStrokeColor(rgb(0xFFFFFF, 0.5)); context.setLineWidth(5); context.setLineCap(.round)
        context.move(to: CGPoint(x: 230, y: -half * 0.5)); context.addLine(to: CGPoint(x: length - 90, y: -half * 0.3))
        context.strokePath()
    }

    // Silver ferrule.
    let ferrule = CGPath(roundedRect: CGRect(x: 104, y: -half - 3, width: 104, height: half * 2 + 6), cornerWidth: 9, cornerHeight: 9, transform: nil)
    context.saveGState()
    shadow(context, x: 8, y: -14, blur: 16, rgb(0x061340, 0.4))
    context.addPath(ferrule); context.setFillColor(rgb(0xB9C0CC)); context.fillPath()
    context.restoreGState()
    fill(context, ferrule, [(0xFAFBFD, 1, 0), (0xC4CAD4, 1, 0.4), (0x7B8494, 1, 1)], from: CGPoint(x: 0, y: -half), to: CGPoint(x: 0, y: half))
    if detail {
        context.setStrokeColor(rgb(0x6B7483, 0.8)); context.setLineWidth(4)
        for x in [CGFloat(130), 182] {
            context.move(to: CGPoint(x: x, y: -half - 2)); context.addLine(to: CGPoint(x: x, y: half + 2))
        }
        context.strokePath()
    }

    // Bristles, loaded with red paint at the tip.
    let bristles = CGMutablePath()
    bristles.move(to: CGPoint(x: 108, y: -half + 2))
    bristles.addCurve(to: CGPoint(x: 0, y: 0), control1: CGPoint(x: 60, y: -half - 4), control2: CGPoint(x: 26, y: -12))
    bristles.addCurve(to: CGPoint(x: 108, y: half - 2), control1: CGPoint(x: 26, y: 12), control2: CGPoint(x: 60, y: half + 4))
    bristles.closeSubpath()
    context.saveGState()
    shadow(context, x: 6, y: -10, blur: 12, rgb(0x3A2A10, 0.4))
    context.addPath(bristles); context.setFillColor(rgb(0xD9A866)); context.fillPath()
    context.restoreGState()
    fill(context, bristles, [(0xF3D29A, 1, 0), (0xD29A52, 1, 0.6), (0x9A6A2E, 1, 1)], from: CGPoint(x: 0, y: -half), to: CGPoint(x: 0, y: half))
    context.saveGState()
    context.addPath(bristles); context.clip()
    fill(context, CGPath(rect: CGRect(x: -4, y: -half - 6, width: 62, height: half * 2 + 12), transform: nil),
         [(0xFF7A70, 1, 0), (0xE5322E, 1, 0.5), (0xA8161A, 1, 1)], from: CGPoint(x: 0, y: -half), to: CGPoint(x: 0, y: half))
    context.restoreGState()
    context.restoreGState()
}

func drawIcon(_ context: CGContext, detail: Bool) {
    // Dark copies stepped along the depth direction fake the extruded edge of the palette.
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    for step in stride(from: edgeDepth, through: 1, by: -1) {
        context.saveGState()
        context.translateBy(x: CGFloat(step) * 0.55, y: CGFloat(step))
        context.concatenate(lean)
        context.addPath(blob()); context.addPath(CGPath(ellipseIn: thumbHole, transform: nil))
        context.setFillColor(rgb(0x0B2F8A)); context.fillPath(using: .evenOdd)
        context.restoreGState()
    }
    context.endTransparencyLayer()

    context.saveGState()
    context.concatenate(lean)
    drawPalette(context, detail: detail)
    drawBrush(context, detail: detail)
    context.restoreGState()
}

// MARK: Output

func bitmap(_ pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    return rep
}

/// Renders the artwork with `fit` mapping face space onto a y-down square of `pixels`.
func render(_ pixels: Int, fit: CGAffineTransform) -> NSBitmapImageRep {
    let rep = bitmap(pixels)
    let context = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    context.interpolationQuality = .high
    context.translateBy(x: 0, y: CGFloat(pixels))
    context.scaleBy(x: 1, y: -1)
    context.concatenate(fit)
    shadowScale = fit.a
    drawIcon(context, detail: pixels >= 64)
    return rep
}

// Measure the opaque bounds once, then scale the artwork edge to edge at every size.
let probeScale: CGFloat = 0.5, probeOffset: CGFloat = 500
let probe = render(1024, fit: CGAffineTransform(a: probeScale, b: 0, c: 0, d: probeScale, tx: probeOffset * probeScale, ty: probeOffset * probeScale))
var minX = 1024, minY = 1024, maxX = -1, maxY = -1
let data = probe.bitmapData!, rowBytes = probe.bytesPerRow
for y in 0..<1024 {
    for x in 0..<1024 where data[y * rowBytes + x * 4 + 3] > 24 {
        minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
    }
}
guard maxX >= 0 else { fatalError("Icon artwork rendered empty") }
let bounds = CGRect(x: CGFloat(minX) / probeScale - probeOffset, y: CGFloat(minY) / probeScale - probeOffset,
                    width: CGFloat(maxX - minX + 1) / probeScale, height: CGFloat(maxY - minY + 1) / probeScale)

func png(_ pixels: Int) -> Data {
    let side = CGFloat(pixels), margin = side * 0.012
    let factor = (side - margin * 2) / max(bounds.width, bounds.height)
    let fit = CGAffineTransform(a: factor, b: 0, c: 0, d: factor,
                                tx: (side - bounds.width * factor) / 2 - bounds.minX * factor,
                                ty: (side - bounds.height * factor) / 2 - bounds.minY * factor)
    return render(pixels, fit: fit).representation(using: .png, properties: [:])!
}

let output = URL(fileURLWithPath: arguments[1])
let iconset = FileManager.default.temporaryDirectory
    .appendingPathComponent("MyPaint-\(ProcessInfo.processInfo.globallyUniqueString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconset) }
for points in [16, 32, 128, 256, 512] {
    try png(points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try png(points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { exit(1) }
if arguments.count >= 3 {
    try png(1024).write(to: URL(fileURLWithPath: arguments[2]))
}
