import AppKit

/// Original line art for the ribbon, the application menu and the status bar.
/// Each icon is drawn on a 16 or 32 unit grid with y going down and scaled to its rectangle.
enum RibbonIcon {
    // Large (32 units)
    case paste, select, brushes, size, editColors, colors, shapes, zoomIn, zoomOut, actualSize
    case fullScreen, thumbnail, newFile, open, saveLarge, saveAs, print, wallpaper, properties, about, exit
    case picture, interfaceSize, printPreview, pageSetup, nextPage, previousPage, closePreview
    // The nine brushes (32 units), see BrushCommands.swift.
    case brushPlain, brushCalligraphy1, brushCalligraphy2, brushAirbrush, brushOil, brushCrayon, brushMarker
    case brushNaturalPencil, brushWatercolor
    // Small (16 units)
    case cut, copy, crop, resize, rotate, pencil, fill, text, eraser, colorPicker, magnifier
    case outline, shapeFill, save, undo, redo, rulers, gridlines
    case statusPointer, statusSelection, statusImage, statusDisk, application
    // Small, for the Select, Paste and Rotate menus and the Resize and Skew dialog.
    case selectRectangle, selectFreeForm, selectAll, invertSelection, deleteSelection, transparentSelection
    case pasteFrom, rotateRight, rotateLeft, rotate180, flipVertical, flipHorizontal
    case resizeHorizontal, resizeVertical, skewHorizontal, skewVertical, invertColor
    // Small, for the Text tab. The letters follow the language, as in the original.
    case bold, italic, underline, strikethrough, textOpaque, textTransparent

    var grid: CGFloat {
        switch self {
        case .paste, .select, .brushes, .size, .editColors, .colors, .shapes, .zoomIn, .zoomOut, .actualSize,
             .fullScreen, .thumbnail, .newFile, .open, .saveLarge, .saveAs, .print, .wallpaper, .properties,
             .about, .exit, .picture, .interfaceSize, .printPreview, .pageSetup, .nextPage, .previousPage, .closePreview, .brushPlain, .brushCalligraphy1, .brushCalligraphy2, .brushAirbrush, .brushOil,
             .brushCrayon, .brushMarker, .brushNaturalPencil, .brushWatercolor:
            return 32
        default:
            return 16
        }
    }

    /// Draws the icon into `rect` of the current graphics context (a flipped view).
    func draw(in rect: NSRect, enabled: Bool = true) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: rect.width / grid, y: rect.height / grid)
        let painter = IconPainter(context: context, enabled: enabled)
        paint(painter)
        context.restoreGState()
    }

    private func paint(_ p: IconPainter) {
        if let brush = BrushKind.allCases.first(where: { $0.icon == self }) { return p.brushIcon(brush) }
        switch self {
        case .paste:
            p.roundRect(5, 5, 18, 23, 2, fill: 0xC08A4A, stroke: 0x7A5228)
            p.roundRect(9, 2, 10, 6, 1.5, fill: 0xD4D8DE, stroke: 0x6D7480)
            p.rect(13, 12, 15, 18, fill: 0xFFFFFF, stroke: 0x6E7C91)
            for y in stride(from: 16.0, through: 26.0, by: 3) { p.line(15.5, y, 25.5, y, 0x9AB0CC, 1) }
        case .select:
            p.dashedRect(3.5, 5.5, 22, 18, 0x2D4B73)
            p.pointer(at: 17, 15, scale: 1.1)
        case .brushes:
            p.path(fill: 0x9C6B3A, stroke: 0x5E3D1E, 1) { $0.move(to: CGPoint(x: 25, y: 3)); $0.addLine(to: CGPoint(x: 29, y: 7))
                $0.addLine(to: CGPoint(x: 16, y: 20)); $0.addLine(to: CGPoint(x: 12, y: 16)); $0.closeSubpath() }
            p.path(fill: 0xB8BEC8, stroke: 0x5F6670, 1) { $0.move(to: CGPoint(x: 12, y: 16)); $0.addLine(to: CGPoint(x: 16, y: 20))
                $0.addLine(to: CGPoint(x: 13, y: 23)); $0.addLine(to: CGPoint(x: 9, y: 19)); $0.closeSubpath() }
            p.path(fill: 0x2E6BC6, stroke: 0x1C437C, 1) { $0.move(to: CGPoint(x: 9, y: 19)); $0.addLine(to: CGPoint(x: 13, y: 23))
                $0.addCurve(to: CGPoint(x: 3, y: 29), control1: CGPoint(x: 11, y: 28), control2: CGPoint(x: 6, y: 29))
                $0.addCurve(to: CGPoint(x: 9, y: 19), control1: CGPoint(x: 5, y: 26), control2: CGPoint(x: 5, y: 21)) }
        case .size:
            for (index, width) in [1.0, 2, 4, 6].enumerated() {
                let y = 7 + Double(index) * 6.5
                p.context.setFillColor(p.cg(0x1E1E1E))
                p.context.fill(CGRect(x: 5, y: y - width / 2, width: 22, height: width))
            }
        case .editColors:
            let hues: [UInt32] = [0xED1C24, 0xFF7F27, 0xFFF200, 0x22B14C, 0x00A2E8, 0x3F48CC, 0xA349A4]
            for (index, hue) in hues.enumerated() {
                let start = CGFloat(index) / CGFloat(hues.count) * 2 * .pi
                let end = CGFloat(index + 1) / CGFloat(hues.count) * 2 * .pi
                p.path(fill: hue, stroke: nil, 0) {
                    $0.move(to: CGPoint(x: 16, y: 15))
                    $0.addArc(center: CGPoint(x: 16, y: 15), radius: 12, startAngle: start, endAngle: end, clockwise: false)
                    $0.closeSubpath()
                }
            }
            p.ellipse(4, 3, 24, 24, fill: nil, stroke: 0x5A5A5A)
            p.ellipse(11, 10, 10, 10, fill: 0xFFFFFF, stroke: 0x8A8A8A)
            p.rect(20, 21, 9, 9, fill: 0xFFFFFF, stroke: 0x5A5A5A)
            p.rect(22, 23, 5, 5, fill: 0x22B14C, stroke: nil)
        case .colors:
            p.path(fill: 0xE9D9B8, stroke: 0x8A6A3C, 1) {
                $0.addEllipse(in: CGRect(x: 3, y: 5, width: 26, height: 21))
            }
            p.ellipse(9, 15, 6, 6, fill: 0xFFFFFF, stroke: 0x8A6A3C)
            for (x, y, c) in [(8.0, 8.0, 0xED1C24), (14, 7, 0xFFF200), (20, 8, 0x22B14C), (23, 14, 0x3F48CC)] as [(Double, Double, UInt32)] {
                p.ellipse(x, y, 4.5, 4.5, fill: c, stroke: nil)
            }
        case .shapes:
            p.ellipse(3, 4, 16, 13, fill: 0xFFFFFF, stroke: 0x2D4B73)
            p.rect(13, 13, 15, 14, fill: 0x9CC3EE, stroke: 0x2D4B73)
            p.line(4, 28, 12, 20, 0x2D4B73, 1.5)
        case .zoomIn, .zoomOut, .actualSize:
            p.line(19, 19, 28, 28, 0x5D4529, 4)
            p.ellipse(3, 3, 19, 19, fill: 0xE8F2FC, stroke: 0x3E5878, width: 2)
            switch self {
            case .zoomIn:
                p.line(8, 12.5, 17, 12.5, 0x2D4B73, 2.2)
                p.line(12.5, 8, 12.5, 17, 0x2D4B73, 2.2)
            case .zoomOut:
                p.line(8, 12.5, 17, 12.5, 0x2D4B73, 2.2)
            default:
                p.text("1:1", in: CGRect(x: 4, y: 7, width: 17, height: 11), size: 8, color: 0x2D4B73)
            }
        case .fullScreen:
            p.rect(3, 5, 26, 18, fill: 0x2F6EBE, stroke: 0x34465E)
            p.rect(5, 7, 22, 14, fill: 0xBFDCF7, stroke: nil)
            p.rect(13, 23, 6, 3, fill: 0x8A98AA, stroke: nil)
            p.rect(9, 26, 14, 2, fill: 0x5F6E82, stroke: nil)
            for (a, b) in [((7.0, 9.0), (11.0, 13.0)), ((25, 9), (21, 13)), ((7, 19), (11, 15)), ((25, 19), (21, 15))] {
                p.line(a.0, a.1, b.0, b.1, 0x1E395B, 1.5)
            }
        case .interfaceSize:
            // A small and a large letter, the text getting bigger.
            p.text("A", in: CGRect(x: 1, y: 12, width: 12, height: 14), size: 11, color: 0x34465E)
            p.text("A", in: CGRect(x: 10, y: 3, width: 21, height: 26), size: 22, color: 0x1E395B, bold: true)
        case .printPreview:
            p.page(5, 3, 18, 24)
            p.ellipse(15, 15, 11, 11, fill: 0xDCEBFC, stroke: 0x34465E, width: 1.5)
            p.line(24, 24, 29, 29, 0x34465E, 2.5)
        case .pageSetup:
            p.page(5, 3, 20, 26)
            p.dashedRect(8.5, 7.5, 14, 18, 0x2E7AD6)
        case .nextPage, .previousPage:
            // A page with a green arrow pointing to the next or the previous one.
            p.page(8, 3, 18, 24)
            let next = self == .nextPage
            let (tail, head): (CGFloat, CGFloat) = next ? (4, 22) : (28, 10)
            p.line(tail, 22, head + (next ? -4 : 4), 22, 0x2E8B2E, 3)
            p.path(fill: 0x2E8B2E, stroke: 0x1F6A1F, 1) {
                $0.move(to: CGPoint(x: head, y: 16)); $0.addLine(to: CGPoint(x: head + (next ? 7 : -7), y: 22))
                $0.addLine(to: CGPoint(x: head, y: 28)); $0.closeSubpath()
            }
        case .closePreview:
            p.page(4, 3, 18, 24)
            p.ellipse(15, 15, 14, 14, fill: 0xD9473A, stroke: 0x8E2A20, width: 1)
            p.line(18.5, 18.5, 25.5, 25.5, 0xFFFFFF, 2)
            p.line(25.5, 18.5, 18.5, 25.5, 0xFFFFFF, 2)
        case .thumbnail:
            p.rect(3, 4, 26, 22, fill: 0xFFFFFF, stroke: 0x4A5A70)
            p.rect(3, 4, 26, 4, fill: 0x8FB4E3, stroke: 0x4A5A70)
            p.rect(7, 12, 12, 10, fill: 0xC9E4C5, stroke: 0x5E8A57)
            p.ellipse(9, 14, 4, 4, fill: 0xFFE680, stroke: nil)
        case .newFile:
            p.page(7, 3, 19, 26)
        case .open:
            p.path(fill: 0xE7C46A, stroke: 0x9A7428, 1) { $0.move(to: CGPoint(x: 3, y: 8)); $0.addLine(to: CGPoint(x: 11, y: 8))
                $0.addLine(to: CGPoint(x: 13, y: 10)); $0.addLine(to: CGPoint(x: 27, y: 10)); $0.addLine(to: CGPoint(x: 27, y: 26))
                $0.addLine(to: CGPoint(x: 3, y: 26)); $0.closeSubpath() }
            p.path(fill: 0xF6DC8E, stroke: 0x9A7428, 1) { $0.move(to: CGPoint(x: 7, y: 15)); $0.addLine(to: CGPoint(x: 30, y: 15))
                $0.addLine(to: CGPoint(x: 27, y: 26)); $0.addLine(to: CGPoint(x: 3, y: 26)); $0.closeSubpath() }
        case .saveLarge:
            p.floppy(4, 4, 24)
        case .saveAs:
            p.floppy(3, 3, 20)
            p.path(fill: 0xF3D36B, stroke: 0x8A6A1C, 1) { $0.move(to: CGPoint(x: 28, y: 16)); $0.addLine(to: CGPoint(x: 30, y: 18))
                $0.addLine(to: CGPoint(x: 21, y: 27)); $0.addLine(to: CGPoint(x: 18, y: 28)); $0.addLine(to: CGPoint(x: 19, y: 25)); $0.closeSubpath() }
        case .print:
            p.rect(9, 3, 14, 9, fill: 0xFFFFFF, stroke: 0x6A7584)
            p.roundRect(3, 11, 26, 12, 2, fill: 0xB9C2CE, stroke: 0x56606E)
            p.rect(9, 19, 14, 10, fill: 0xFFFFFF, stroke: 0x6A7584)
            p.ellipse(24, 14, 3, 3, fill: 0x45B649, stroke: nil)
        case .wallpaper:
            p.rect(3, 4, 26, 19, fill: 0x2B6CC4, stroke: 0x34465E)
            p.path(fill: 0x6FB45E, stroke: nil, 0) { $0.move(to: CGPoint(x: 4, y: 22)); $0.addLine(to: CGPoint(x: 12, y: 13))
                $0.addLine(to: CGPoint(x: 18, y: 18)); $0.addLine(to: CGPoint(x: 22, y: 15)); $0.addLine(to: CGPoint(x: 28, y: 22)); $0.closeSubpath() }
            p.rect(13, 23, 6, 3, fill: 0x8A98AA, stroke: nil)
            p.rect(9, 26, 14, 2, fill: 0x5F6E82, stroke: nil)
        case .properties:
            p.page(6, 3, 18, 24)
            p.check(14, 24, 0x2E8B2E)
        case .about:
            p.ellipse(4, 4, 24, 24, fill: 0x3C7FD3, stroke: 0x1E4E8C)
            p.rect(14.5, 14, 3, 9, fill: 0xFFFFFF, stroke: nil)
            p.ellipse(14, 8, 4, 4, fill: 0xFFFFFF, stroke: nil)
        case .exit:
            p.rect(5, 4, 14, 24, fill: 0xD8DEE6, stroke: 0x56606E)
            p.line(14, 16, 28, 16, 0xC0392B, 3)
            p.path(fill: 0xC0392B, stroke: nil, 0) { $0.move(to: CGPoint(x: 23, y: 10)); $0.addLine(to: CGPoint(x: 30, y: 16))
                $0.addLine(to: CGPoint(x: 23, y: 22)); $0.closeSubpath() }
        case .picture:
            p.rect(3, 6, 26, 20, fill: 0xFFFFFF, stroke: 0x4A5A70)
            p.rect(5, 8, 22, 16, fill: 0xBFDCF7, stroke: nil)
            p.path(fill: 0x5FA350, stroke: nil, 0) { $0.move(to: CGPoint(x: 5, y: 24)); $0.addLine(to: CGPoint(x: 13, y: 15))
                $0.addLine(to: CGPoint(x: 19, y: 20)); $0.addLine(to: CGPoint(x: 22, y: 17)); $0.addLine(to: CGPoint(x: 27, y: 24)); $0.closeSubpath() }
            p.ellipse(20, 10, 4, 4, fill: 0xFFD94A, stroke: nil)

        // MARK: Small
        case .cut:
            p.line(5, 2, 10, 11, 0x5A6470, 1.3)
            p.line(11, 2, 6, 11, 0x5A6470, 1.3)
            p.ellipse(2.5, 10.5, 4.5, 4.5, fill: nil, stroke: 0xB0352B, width: 1.4)
            p.ellipse(9, 10.5, 4.5, 4.5, fill: nil, stroke: 0xB0352B, width: 1.4)
        case .copy:
            p.page(2, 1, 8, 10, small: true)
            p.page(6, 5, 8, 10, small: true)
        case .crop:
            p.line(4.5, 1, 4.5, 11.5, 0x2D4B73, 1.6)
            p.line(4, 11.5, 15, 11.5, 0x2D4B73, 1.6)
            p.line(1, 4.5, 11.5, 4.5, 0x2D4B73, 1.6)
            p.line(11.5, 4, 11.5, 15, 0x2D4B73, 1.6)
        case .resize:
            p.rect(1.5, 1.5, 9, 9, fill: 0xFFFFFF, stroke: 0x5A6A80)
            p.rect(1.5, 1.5, 13, 13, fill: nil, stroke: 0x2D4B73, dashed: true)
            p.line(8, 8, 13, 13, 0x2D4B73, 1.2)
            p.path(fill: 0x2D4B73, stroke: nil, 0) { $0.move(to: CGPoint(x: 14, y: 14)); $0.addLine(to: CGPoint(x: 9, y: 14)); $0.addLine(to: CGPoint(x: 14, y: 9)); $0.closeSubpath() }
        case .rotate:
            p.rect(5.5, 5.5, 9, 9, fill: 0xFFFFFF, stroke: 0x5A6A80)
            p.path(fill: nil, stroke: 0x2B7A2B, 1.5) { $0.addArc(center: CGPoint(x: 6, y: 8), radius: 4.5, startAngle: .pi, endAngle: 1.6 * .pi, clockwise: false) }
            p.path(fill: 0x2B7A2B, stroke: nil, 0) { $0.move(to: CGPoint(x: 6, y: 1.5)); $0.addLine(to: CGPoint(x: 10, y: 3.8)); $0.addLine(to: CGPoint(x: 6, y: 6)); $0.closeSubpath() }
        case .pencil:
            p.path(fill: 0xF2C14E, stroke: 0x6E5214, 1) { $0.move(to: CGPoint(x: 12, y: 1.5)); $0.addLine(to: CGPoint(x: 14.5, y: 4))
                $0.addLine(to: CGPoint(x: 5, y: 13.5)); $0.addLine(to: CGPoint(x: 2.5, y: 11)); $0.closeSubpath() }
            p.path(fill: 0xF1D6B0, stroke: 0x6E5214, 1) { $0.move(to: CGPoint(x: 2.5, y: 11)); $0.addLine(to: CGPoint(x: 5, y: 13.5))
                $0.addLine(to: CGPoint(x: 1.5, y: 14.5)); $0.closeSubpath() }
            p.line(11, 2.5, 13.5, 5, 0xE07A8A, 1.5)
        case .fill:
            p.path(fill: 0xDDE3EA, stroke: 0x4D5866, 1) { $0.move(to: CGPoint(x: 6, y: 2.5)); $0.addLine(to: CGPoint(x: 12.5, y: 9))
                $0.addLine(to: CGPoint(x: 8, y: 13.5)); $0.addLine(to: CGPoint(x: 1.5, y: 7)); $0.closeSubpath() }
            p.path(fill: 0x2E7AD6, stroke: 0x1A4F94, 0.8) { $0.move(to: CGPoint(x: 12.5, y: 9)); $0.addCurve(to: CGPoint(x: 14, y: 13.5), control1: CGPoint(x: 14.5, y: 10.5), control2: CGPoint(x: 15.5, y: 13.5))
                $0.addCurve(to: CGPoint(x: 12.5, y: 9), control1: CGPoint(x: 12.5, y: 13.5), control2: CGPoint(x: 12, y: 11)) }
        case .text:
            p.text("A", in: CGRect(x: 1, y: 0, width: 14, height: 16), size: 13, color: 0x1E1E1E, bold: true)
        case .eraser:
            p.path(fill: 0xF0A1B4, stroke: 0x8A4458, 1) { $0.move(to: CGPoint(x: 9, y: 2.5)); $0.addLine(to: CGPoint(x: 14.5, y: 8))
                $0.addLine(to: CGPoint(x: 10, y: 12.5)); $0.addLine(to: CGPoint(x: 4.5, y: 7)); $0.closeSubpath() }
            p.path(fill: 0xFFFFFF, stroke: 0x8A4458, 1) { $0.move(to: CGPoint(x: 4.5, y: 7)); $0.addLine(to: CGPoint(x: 10, y: 12.5))
                $0.addLine(to: CGPoint(x: 8, y: 14.5)); $0.addLine(to: CGPoint(x: 4.5, y: 14.5)); $0.addLine(to: CGPoint(x: 1.5, y: 11.5)); $0.addLine(to: CGPoint(x: 1.5, y: 10)); $0.closeSubpath() }
        case .colorPicker:
            p.line(3, 13, 10, 6, 0x6E7884, 2.2)
            p.path(fill: 0x3F4A57, stroke: nil, 0) { $0.move(to: CGPoint(x: 9, y: 4)); $0.addLine(to: CGPoint(x: 12, y: 1.5)); $0.addLine(to: CGPoint(x: 14.5, y: 4))
                $0.addLine(to: CGPoint(x: 12, y: 7)); $0.addLine(to: CGPoint(x: 12.5, y: 8.5)); $0.addLine(to: CGPoint(x: 11.5, y: 9.5)); $0.addLine(to: CGPoint(x: 6.5, y: 4.5)); $0.addLine(to: CGPoint(x: 7.5, y: 3.5)); $0.closeSubpath() }
            p.line(2, 14, 3.2, 12.8, 0x2E7AD6, 1.8)
        case .magnifier:
            p.line(9.5, 9.5, 14.5, 14.5, 0x5D4529, 2.4)
            p.ellipse(1.5, 1.5, 9.5, 9.5, fill: 0xE8F2FC, stroke: 0x3E5878, width: 1.4)
        case .outline:
            p.ellipse(2, 3, 12, 10, fill: nil, stroke: 0x2D4B73, width: 1.4)
            p.line(1, 15, 15, 15, 0x1E1E1E, 2)
        case .shapeFill:
            p.ellipse(2, 3, 12, 10, fill: 0x9CC3EE, stroke: 0x2D4B73, width: 1)
            p.line(1, 15, 15, 15, 0x1E1E1E, 2)
        case .save:
            p.floppy(1.5, 1.5, 13)
        case .undo, .redo:
            p.context.saveGState()
            if self == .redo { p.context.translateBy(x: 16, y: 0); p.context.scaleBy(x: -1, y: 1) }
            p.path(fill: nil, stroke: 0x2C5D9E, 2) { $0.move(to: CGPoint(x: 4, y: 7)); $0.addLine(to: CGPoint(x: 10, y: 7))
                $0.addCurve(to: CGPoint(x: 10, y: 14), control1: CGPoint(x: 15, y: 7), control2: CGPoint(x: 15, y: 14)) ; $0.addLine(to: CGPoint(x: 7, y: 14)) }
            p.path(fill: 0x2C5D9E, stroke: nil, 0) { $0.move(to: CGPoint(x: 1, y: 7)); $0.addLine(to: CGPoint(x: 6, y: 2.5)); $0.addLine(to: CGPoint(x: 6, y: 11.5)); $0.closeSubpath() }
            p.context.restoreGState()
        case .rulers:
            p.rect(1.5, 1.5, 13, 4, fill: 0xF6E7A8, stroke: 0x7A6A2A)
            p.rect(1.5, 1.5, 4, 13, fill: 0xF6E7A8, stroke: 0x7A6A2A)
        case .gridlines:
            for v in [1.5, 6.5, 11.5] as [CGFloat] { p.line(v, 1, v, 15, 0x7D8CA2, 1); p.line(1, v, 15, v, 0x7D8CA2, 1) }
        case .statusPointer:
            p.pointer(at: 4, 1, scale: 0.75)
            p.line(1, 14, 7, 14, 0x6A7584, 1)
        case .statusSelection:
            p.dashedRect(1.5, 3.5, 12, 9, 0x4A5A70)
        case .statusImage:
            p.rect(2.5, 2.5, 11, 11, fill: 0xFFFFFF, stroke: 0x4A5A70)
            p.line(0.5, 15.5, 15.5, 15.5, 0x8A98AA, 1)
        case .statusDisk:
            p.floppy(1.5, 1.5, 13)
        case .selectRectangle:
            p.dashedRect(1.5, 3.5, 13, 9, 0x2D4B73)
        case .selectFreeForm:
            p.context.saveGState()
            p.context.setLineDash(phase: 0, lengths: [2, 2])
            p.path(fill: nil, stroke: 0x2D4B73, 1) { $0.move(to: CGPoint(x: 3, y: 4)); $0.addCurve(to: CGPoint(x: 13, y: 5), control1: CGPoint(x: 6, y: 0), control2: CGPoint(x: 11, y: 1))
                $0.addCurve(to: CGPoint(x: 8, y: 14), control1: CGPoint(x: 16, y: 10), control2: CGPoint(x: 11, y: 13))
                $0.addCurve(to: CGPoint(x: 3, y: 4), control1: CGPoint(x: 3, y: 15), control2: CGPoint(x: 0, y: 8)) }
            p.context.restoreGState()
        case .selectAll:
            p.rect(2.5, 2.5, 11, 11, fill: 0xBFDCF7, stroke: nil)
            p.dashedRect(1.5, 1.5, 13, 13, 0x2D4B73)
        case .invertSelection:
            p.rect(1.5, 1.5, 13, 13, fill: 0xBFDCF7, stroke: nil)
            p.rect(5.5, 5.5, 5, 5, fill: 0xFFFFFF, stroke: nil)
            p.dashedRect(5.5, 5.5, 5, 5, 0x2D4B73)
        case .deleteSelection:
            p.dashedRect(1.5, 1.5, 13, 13, 0x2D4B73)
            p.line(4.5, 4.5, 11.5, 11.5, 0xC0392B, 2)
            p.line(11.5, 4.5, 4.5, 11.5, 0xC0392B, 2)
        case .bold:
            p.text(L("icon.bold"), in: CGRect(x: 0, y: 0, width: 16, height: 16), size: 13, color: 0x1E1E1E, bold: true)
        case .italic:
            // Slanted by hand, so it does not depend on an italic system font.
            p.context.saveGState()
            p.context.concatenate(CGAffineTransform(a: 1, b: 0, c: -0.25, d: 1, tx: 2, ty: 0))
            p.text(L("icon.italic"), in: CGRect(x: 0, y: 0, width: 16, height: 16), size: 13, color: 0x1E1E1E)
            p.context.restoreGState()
        case .underline:
            p.text(L("icon.underline"), in: CGRect(x: 0, y: -1, width: 16, height: 15), size: 12, color: 0x1E1E1E)
            p.line(3.5, 14.5, 12.5, 14.5, 0x1E1E1E, 1)
        case .strikethrough:
            p.text("abc", in: CGRect(x: -1, y: 0, width: 18, height: 16), size: 9, color: 0x1E1E1E)
            p.line(1, 8.5, 15, 8.5, 0xC0282D, 1.2)
        case .textOpaque:
            p.rect(1.5, 2.5, 13, 11, fill: 0x9CC2EC, stroke: 0x46638A)
            p.text("A", in: CGRect(x: 1, y: 2, width: 14, height: 12), size: 10, color: 0x1E1E1E, bold: true)
        case .textTransparent:
            for row in 0..<4 { for column in 0..<4 where (row + column) % 2 == 0 {
                p.rect(2 + CGFloat(column) * 3, 3 + CGFloat(row) * 2.5, 3, 2.5, fill: 0xC8CED6, stroke: nil) } }
            p.rect(1.5, 2.5, 13, 11, fill: nil, stroke: 0x46638A, dashed: true)
            p.text("A", in: CGRect(x: 1, y: 2, width: 14, height: 12), size: 10, color: 0x1E1E1E, bold: true)
        case .transparentSelection:
            for row in 0..<4 { for column in 0..<4 where (row + column) % 2 == 0 {
                p.rect(2 + CGFloat(column) * 3, 2 + CGFloat(row) * 3, 3, 3, fill: 0xC8CED6, stroke: nil) } }
            p.dashedRect(1.5, 1.5, 13, 13, 0x2D4B73)
        case .pasteFrom:
            p.roundRect(1.5, 2.5, 9, 12, 1.5, fill: 0xC08A4A, stroke: 0x7A5228)
            p.path(fill: 0xF4D27A, stroke: 0x9A7A2A, 1) { $0.move(to: CGPoint(x: 6.5, y: 7.5)); $0.addLine(to: CGPoint(x: 10, y: 7.5)); $0.addLine(to: CGPoint(x: 11, y: 6.5))
                $0.addLine(to: CGPoint(x: 14.5, y: 6.5)); $0.addLine(to: CGPoint(x: 14.5, y: 14.5)); $0.addLine(to: CGPoint(x: 6.5, y: 14.5)); $0.closeSubpath() }
        case .rotateRight, .rotateLeft:
            p.context.saveGState()
            if self == .rotateLeft { p.context.translateBy(x: 16, y: 0); p.context.scaleBy(x: -1, y: 1) }
            p.rect(1.5, 6.5, 8, 8, fill: 0xFFFFFF, stroke: 0x5A6A80)
            p.path(fill: nil, stroke: 0x2B7A2B, 1.5) { $0.addArc(center: CGPoint(x: 9, y: 9), radius: 5, startAngle: 1.05 * .pi, endAngle: 1.75 * .pi, clockwise: false) }
            p.path(fill: 0x2B7A2B, stroke: nil, 0) { $0.move(to: CGPoint(x: 15, y: 3)); $0.addLine(to: CGPoint(x: 14.5, y: 8)); $0.addLine(to: CGPoint(x: 10.5, y: 4.5)); $0.closeSubpath() }
            p.context.restoreGState()
        case .rotate180:
            p.rect(4.5, 4.5, 7, 7, fill: 0xFFFFFF, stroke: 0x5A6A80)
            p.path(fill: nil, stroke: 0x2B7A2B, 1.5) { $0.addArc(center: CGPoint(x: 8, y: 8), radius: 6, startAngle: 0.6 * .pi, endAngle: 1.9 * .pi, clockwise: false) }
            p.path(fill: 0x2B7A2B, stroke: nil, 0) { $0.move(to: CGPoint(x: 15.5, y: 5)); $0.addLine(to: CGPoint(x: 15, y: 10)); $0.addLine(to: CGPoint(x: 11, y: 7)); $0.closeSubpath() }
        case .flipVertical:
            p.path(fill: 0x9CC3EE, stroke: 0x2D4B73, 1) { $0.move(to: CGPoint(x: 3, y: 6.5)); $0.addLine(to: CGPoint(x: 13, y: 6.5)); $0.addLine(to: CGPoint(x: 8, y: 1.5)); $0.closeSubpath() }
            p.path(fill: 0xFFFFFF, stroke: 0x2D4B73, 1) { $0.move(to: CGPoint(x: 3, y: 9.5)); $0.addLine(to: CGPoint(x: 13, y: 9.5)); $0.addLine(to: CGPoint(x: 8, y: 14.5)); $0.closeSubpath() }
        case .flipHorizontal:
            p.path(fill: 0x9CC3EE, stroke: 0x2D4B73, 1) { $0.move(to: CGPoint(x: 6.5, y: 3)); $0.addLine(to: CGPoint(x: 6.5, y: 13)); $0.addLine(to: CGPoint(x: 1.5, y: 8)); $0.closeSubpath() }
            p.path(fill: 0xFFFFFF, stroke: 0x2D4B73, 1) { $0.move(to: CGPoint(x: 9.5, y: 3)); $0.addLine(to: CGPoint(x: 9.5, y: 13)); $0.addLine(to: CGPoint(x: 14.5, y: 8)); $0.closeSubpath() }
        case .resizeHorizontal, .resizeVertical:
            p.context.saveGState()
            if self == .resizeVertical { p.context.translateBy(x: 16, y: 0); p.context.rotate(by: .pi / 2) }
            p.rect(4.5, 4.5, 7, 7, fill: 0xFFFFFF, stroke: 0x5A6A80)
            p.line(0.5, 8, 15.5, 8, 0x2D4B73, 1)
            p.path(fill: 0x2D4B73, stroke: nil, 0) { $0.move(to: CGPoint(x: 0, y: 8)); $0.addLine(to: CGPoint(x: 3, y: 5)); $0.addLine(to: CGPoint(x: 3, y: 11)); $0.closeSubpath()
                $0.move(to: CGPoint(x: 16, y: 8)); $0.addLine(to: CGPoint(x: 13, y: 5)); $0.addLine(to: CGPoint(x: 13, y: 11)); $0.closeSubpath() }
            p.context.restoreGState()
        case .skewHorizontal:
            p.path(fill: 0xFFFFFF, stroke: 0x5A6A80, 1) { $0.move(to: CGPoint(x: 5.5, y: 3.5)); $0.addLine(to: CGPoint(x: 14.5, y: 3.5)); $0.addLine(to: CGPoint(x: 10.5, y: 12.5)); $0.addLine(to: CGPoint(x: 1.5, y: 12.5)); $0.closeSubpath() }
            p.line(1, 15, 15, 15, 0x2D4B73, 1)
        case .skewVertical:
            p.path(fill: 0xFFFFFF, stroke: 0x5A6A80, 1) { $0.move(to: CGPoint(x: 3.5, y: 1.5)); $0.addLine(to: CGPoint(x: 12.5, y: 5.5)); $0.addLine(to: CGPoint(x: 12.5, y: 14.5)); $0.addLine(to: CGPoint(x: 3.5, y: 10.5)); $0.closeSubpath() }
            p.line(1, 1, 1, 15, 0x2D4B73, 1)
        case .invertColor:
            p.rect(1.5, 2.5, 13, 11, fill: 0xFFFFFF, stroke: 0x4A5A70)
            p.rect(8, 3, 6, 10, fill: 0x1E1E1E, stroke: nil)
            p.ellipse(4, 5, 6, 6, fill: 0x2E7AD6, stroke: nil)
            p.ellipse(8, 5, 6, 6, fill: 0xD18529, stroke: nil)
        case .application:
            p.rect(2.5, 2.5, 11, 11, fill: 0xFFFFFF, stroke: 0xFFFFFF)
            p.rect(2.5, 2.5, 11, 3, fill: 0x9CC3EE, stroke: 0xFFFFFF)
            p.line(4.5, 8.5, 11.5, 8.5, 0x5C86C0, 1)
            p.line(4.5, 11, 9.5, 11, 0x5C86C0, 1)
        case .brushPlain, .brushCalligraphy1, .brushCalligraphy2, .brushAirbrush, .brushOil, .brushCrayon, .brushMarker,
             .brushNaturalPencil, .brushWatercolor:
            break
        }
    }
}

/// Small drawing vocabulary for the icons. A disabled painter draws everything in light grays.
struct IconPainter {
    let context: CGContext
    let enabled: Bool

    func cg(_ hex: UInt32) -> CGColor {
        let r = CGFloat(hex >> 16 & 0xFF) / 255, g = CGFloat(hex >> 8 & 0xFF) / 255, b = CGFloat(hex & 0xFF) / 255
        guard !enabled else { return CGColor(srgbRed: r, green: g, blue: b, alpha: 1) }
        let gray = 0.62 + 0.38 * (0.3 * r + 0.59 * g + 0.11 * b)
        return CGColor(srgbRed: gray, green: gray, blue: gray, alpha: 1)
    }

    func path(fill: UInt32?, stroke: UInt32?, _ width: CGFloat, _ build: (CGMutablePath) -> Void) {
        let path = CGMutablePath()
        build(path)
        if let fill = fill {
            context.addPath(path)
            context.setFillColor(cg(fill))
            context.fillPath()
        }
        if let stroke = stroke, width > 0 {
            context.addPath(path)
            context.setStrokeColor(cg(stroke))
            context.setLineWidth(width)
            context.setLineJoin(.round)
            context.setLineCap(.round)
            context.strokePath()
        }
    }

    func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, fill: UInt32?, stroke: UInt32?, dashed: Bool = false) {
        let box = CGRect(x: x, y: y, width: w, height: h)
        if let fill = fill { context.setFillColor(cg(fill)); context.fill(box) }
        if let stroke = stroke {
            context.saveGState()
            if dashed { context.setLineDash(phase: 0, lengths: [1.5, 1.5]) }
            context.setStrokeColor(cg(stroke))
            context.setLineWidth(1)
            context.stroke(box)
            context.restoreGState()
        }
    }

    func roundRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, fill: UInt32, stroke: UInt32) {
        path(fill: fill, stroke: stroke, 1) { $0.addRoundedRect(in: CGRect(x: x + 0.5, y: y + 0.5, width: w - 1, height: h - 1), cornerWidth: r, cornerHeight: r) }
    }

    func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, fill: UInt32?, stroke: UInt32?, width: CGFloat = 1) {
        path(fill: fill, stroke: stroke, width) { $0.addEllipse(in: CGRect(x: x, y: y, width: w, height: h)) }
    }

    func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ color: UInt32, _ width: CGFloat) {
        path(fill: nil, stroke: color, width) { $0.move(to: CGPoint(x: x1, y: y1)); $0.addLine(to: CGPoint(x: x2, y: y2)) }
    }

    func dashedRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: UInt32) {
        context.saveGState()
        context.setLineDash(phase: 0, lengths: [2, 2])
        context.setStrokeColor(cg(color))
        context.setLineWidth(1)
        context.stroke(CGRect(x: x, y: y, width: w, height: h))
        context.restoreGState()
    }

    /// An arrow pointer with its tip at (x, y).
    func pointer(at x: CGFloat, _ y: CGFloat, scale s: CGFloat) {
        path(fill: 0xFFFFFF, stroke: 0x1E1E1E, 1) {
            $0.move(to: CGPoint(x: x, y: y))
            $0.addLine(to: CGPoint(x: x, y: y + 13 * s))
            $0.addLine(to: CGPoint(x: x + 3.2 * s, y: y + 10 * s))
            $0.addLine(to: CGPoint(x: x + 5.5 * s, y: y + 14.5 * s))
            $0.addLine(to: CGPoint(x: x + 7.5 * s, y: y + 13.5 * s))
            $0.addLine(to: CGPoint(x: x + 5.2 * s, y: y + 9.2 * s))
            $0.addLine(to: CGPoint(x: x + 9.3 * s, y: y + 9.2 * s))
            $0.closeSubpath()
        }
    }

    /// A sheet of paper with a folded corner.
    func page(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, small: Bool = false) {
        let fold: CGFloat = small ? 3 : 6
        path(fill: 0xFFFFFF, stroke: 0x6E7C91, 1) {
            $0.move(to: CGPoint(x: x + 0.5, y: y + 0.5))
            $0.addLine(to: CGPoint(x: x + w - fold, y: y + 0.5))
            $0.addLine(to: CGPoint(x: x + w - 0.5, y: y + fold))
            $0.addLine(to: CGPoint(x: x + w - 0.5, y: y + h - 0.5))
            $0.addLine(to: CGPoint(x: x + 0.5, y: y + h - 0.5))
            $0.closeSubpath()
        }
        path(fill: 0xDCE5F0, stroke: 0x6E7C91, 1) {
            $0.move(to: CGPoint(x: x + w - fold, y: y + 0.5))
            $0.addLine(to: CGPoint(x: x + w - fold, y: y + fold))
            $0.addLine(to: CGPoint(x: x + w - 0.5, y: y + fold))
        }
    }

    /// A diskette of side `s`.
    func floppy(_ x: CGFloat, _ y: CGFloat, _ s: CGFloat) {
        path(fill: 0x3A6EB5, stroke: 0x1E3F70, 1) {
            $0.move(to: CGPoint(x: x, y: y)); $0.addLine(to: CGPoint(x: x + s * 0.85, y: y))
            $0.addLine(to: CGPoint(x: x + s, y: y + s * 0.15)); $0.addLine(to: CGPoint(x: x + s, y: y + s))
            $0.addLine(to: CGPoint(x: x, y: y + s)); $0.closeSubpath()
        }
        rect(x + s * 0.22, y + 0.5, s * 0.52, s * 0.34, fill: 0xE4E9F0, stroke: nil)
        rect(x + s * 0.56, y + s * 0.06, s * 0.1, s * 0.22, fill: 0x3A6EB5, stroke: nil)
        rect(x + s * 0.16, y + s * 0.55, s * 0.68, s * 0.45, fill: 0xFFFFFF, stroke: nil)
    }

    func check(_ x: CGFloat, _ y: CGFloat, _ color: UInt32) {
        path(fill: nil, stroke: color, 2.5) {
            $0.move(to: CGPoint(x: x - 5, y: y - 4)); $0.addLine(to: CGPoint(x: x - 1, y: y)); $0.addLine(to: CGPoint(x: x + 7, y: y - 9))
        }
    }

    func text(_ string: String, in box: CGRect, size: CGFloat, color: UInt32, bold: Bool = false) {
        let font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: NSColor(cgColor: cg(color)) ?? .black, .paragraphStyle: style,
        ]
        // The current context is the flipped view's, already scaled to the icon grid.
        let height = (string as NSString).size(withAttributes: attributes).height
        (string as NSString).draw(in: CGRect(x: box.minX, y: box.midY - height / 2, width: box.width, height: height),
                                  withAttributes: attributes)
    }
}

/// The 23 shapes of the Shapes gallery, in gallery order. Drawn only as gallery thumbnails for now.
enum GalleryShape: Int, CaseIterable {
    case line, curve, oval, rectangle, roundedRectangle, polygon, triangle, rightTriangle, diamond, pentagon
    case hexagon, rightArrow, leftArrow, upArrow, downArrow, star4, star5, star6
    case roundedCallout, ovalCallout, cloudCallout, heart, lightning

    /// Draws the thumbnail on a 16 unit grid; the caller places and scales it.
    func draw(_ p: IconPainter) {
        let c: UInt32 = 0x1E2C40
        func poly(_ points: [(CGFloat, CGFloat)]) {
            p.path(fill: nil, stroke: c, 1) { path in
                path.move(to: CGPoint(x: points[0].0, y: points[0].1))
                for point in points.dropFirst() { path.addLine(to: CGPoint(x: point.0, y: point.1)) }
                path.closeSubpath()
            }
        }
        func star(_ count: Int, inner: CGFloat) {
            var points: [(CGFloat, CGFloat)] = []
            for index in 0..<(count * 2) {
                let angle = -CGFloat.pi / 2 + CGFloat(index) * .pi / CGFloat(count)
                let radius: CGFloat = index % 2 == 0 ? 7 : inner
                points.append((8 + cos(angle) * radius, 8.5 + sin(angle) * radius))
            }
            poly(points)
        }
        switch self {
        case .line: p.line(2, 14, 14, 2, c, 1)
        case .curve: p.path(fill: nil, stroke: c, 1) { $0.move(to: CGPoint(x: 2, y: 13)); $0.addCurve(to: CGPoint(x: 14, y: 3), control1: CGPoint(x: 4, y: 0), control2: CGPoint(x: 12, y: 17)) }
        case .oval: p.ellipse(1.5, 3.5, 13, 9, fill: nil, stroke: c)
        case .rectangle: p.rect(1.5, 3.5, 13, 9, fill: nil, stroke: c)
        case .roundedRectangle: p.path(fill: nil, stroke: c, 1) { $0.addRoundedRect(in: CGRect(x: 1.5, y: 3.5, width: 13, height: 9), cornerWidth: 3, cornerHeight: 3) }
        case .polygon: poly([(2, 14), (4, 4), (10, 2), (14, 8), (9, 9), (11, 14)])
        case .triangle: poly([(8, 2), (14.5, 14), (1.5, 14)])
        case .rightTriangle: poly([(2, 2), (14, 14), (2, 14)])
        case .diamond: poly([(8, 1.5), (14.5, 8), (8, 14.5), (1.5, 8)])
        case .pentagon: poly([(8, 1.5), (14.5, 6.5), (12, 14.5), (4, 14.5), (1.5, 6.5)])
        case .hexagon: poly([(4.5, 2), (11.5, 2), (15, 8), (11.5, 14), (4.5, 14), (1, 8)])
        case .rightArrow: poly([(1.5, 5.5), (9, 5.5), (9, 2), (14.5, 8), (9, 14), (9, 10.5), (1.5, 10.5)])
        case .leftArrow: poly([(14.5, 5.5), (7, 5.5), (7, 2), (1.5, 8), (7, 14), (7, 10.5), (14.5, 10.5)])
        case .upArrow: poly([(5.5, 14.5), (5.5, 7), (2, 7), (8, 1.5), (14, 7), (10.5, 7), (10.5, 14.5)])
        case .downArrow: poly([(5.5, 1.5), (5.5, 9), (2, 9), (8, 14.5), (14, 9), (10.5, 9), (10.5, 1.5)])
        case .star4: star(4, inner: 2.5)
        case .star5: star(5, inner: 3)
        case .star6: star(6, inner: 3.8)
        case .roundedCallout:
            p.path(fill: nil, stroke: c, 1) { $0.addRoundedRect(in: CGRect(x: 1.5, y: 2.5, width: 13, height: 8), cornerWidth: 2.5, cornerHeight: 2.5)
                $0.move(to: CGPoint(x: 4, y: 10.5)); $0.addLine(to: CGPoint(x: 3, y: 14.5)); $0.addLine(to: CGPoint(x: 7, y: 10.5)) }
        case .ovalCallout:
            p.ellipse(1.5, 2, 13, 9, fill: nil, stroke: c)
            p.line(4.5, 10, 3, 14.5, c, 1)
        case .cloudCallout:
            for (x, y, s) in [(2.0, 5.0, 6.0), (5, 2.5, 6.5), (9, 3.5, 6), (6, 6.5, 6)] as [(CGFloat, CGFloat, CGFloat)] { p.ellipse(x, y, s, s, fill: nil, stroke: c) }
            p.ellipse(2.5, 13, 2, 2, fill: nil, stroke: c)
        case .heart:
            p.path(fill: nil, stroke: c, 1) { $0.move(to: CGPoint(x: 8, y: 14.5)); $0.addCurve(to: CGPoint(x: 8, y: 4.5), control1: CGPoint(x: -2, y: 8), control2: CGPoint(x: 3, y: -1))
                $0.addCurve(to: CGPoint(x: 8, y: 14.5), control1: CGPoint(x: 13, y: -1), control2: CGPoint(x: 18, y: 8)) }
        case .lightning: poly([(6, 1.5), (11, 1.5), (8.5, 6.5), (12.5, 6.5), (5, 14.5), (7, 9), (3.5, 9)])
        }
    }
}
