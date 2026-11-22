import Foundation

/// Stands in for the canvas so each tool can be driven alone.
final class FakeHost: ToolHost {
    let document: PaintDocument
    var returned = 0
    var zooms: [(Int, PixelPoint)] = []

    init(width: Int = 40, height: Int = 30) {
        document = PaintDocument(bitmap: Bitmap(width: width, height: height))
    }

    func returnToPreviousTool() { returned += 1 }
    func stepZoom(_ direction: Int, centeredOn point: PixelPoint) { zooms.append((direction, point)) }
}

/// Every pixel of `bitmap` that equals `value`.
func pixels(of bitmap: Bitmap, equalTo value: UInt32) -> Set<[Int]> {
    var found = Set<[Int]>()
    for y in 0..<bitmap.height { for x in 0..<bitmap.width where bitmap[x, y] == value { found.insert([x, y]) } }
    return found
}

func square(_ x: Int, _ y: Int, _ width: Int, _ height: Int) -> Set<[Int]> {
    var set = Set<[Int]>()
    for row in y..<(y + height) { for column in x..<(x + width) { set.insert([column, row]) } }
    return set
}

func stroke(_ tool: Tool, _ host: ToolHost, _ points: [(Int, Int)], button: MouseButton = .left) {
    let first = PixelPoint(x: points[0].0, y: points[0].1)
    tool.press(at: first, button: button, host: host)
    for point in points.dropFirst() { tool.drag(to: PixelPoint(x: point.0, y: point.1), host: host) }
    let last = points.last!
    tool.release(at: PixelPoint(x: last.0, y: last.1), host: host)
}

func runToolTests() {
    let black = RGB.black.packed, white = RGB.white.packed
    let red = RGB(r: 237, g: 28, b: 36), blue = RGB(r: 63, g: 72, b: 204)

    // Pencil
    do {
        let expected: [Int: Set<[Int]>] = [
            1: square(10, 10, 1, 1), 2: square(9, 9, 2, 2), 3: square(9, 9, 3, 3), 4: square(8, 8, 4, 4),
        ]
        for size in [1, 2, 3, 4] {
            let host = FakeHost(), pencil = PencilTool()
            pencil.size = size
            stroke(pencil, host, [(10, 10)])
            check(pixels(of: host.document.bitmap, equalTo: black) == expected[size]!, "pencil \(size) px paints a \(size)×\(size) square")
        }

        let host = FakeHost(), pencil = PencilTool()
        pencil.size = 2
        stroke(pencil, host, [(5, 5), (15, 5)])
        check(pixels(of: host.document.bitmap, equalTo: black) == square(4, 4, 12, 2), "pencil 2 px drag paints a 2 px band")

        pencil.size = 1
        stroke(pencil, host, [(2, 20), (7, 22)])
        var line = Bitmap(width: 40, height: 30)
        line.line(fromX: 2, y: 20, toX: 7, y: 22, value: black)
        check(pixels(of: host.document.bitmap, equalTo: black).isSuperset(of: pixels(of: line, equalTo: black)),
              "pencil 1 px drag follows the Bresenham line")

        host.document.color2 = red
        pencil.size = 3
        stroke(pencil, host, [(30, 20)], button: .right)
        check(pixels(of: host.document.bitmap, equalTo: red.packed) == square(29, 19, 3, 3), "pencil right button uses Color 2")

        let edge = FakeHost(width: 5, height: 5)
        pencil.size = 4
        stroke(pencil, edge, [(0, 0), (-3, -3)])
        check(pixels(of: edge.document.bitmap, equalTo: black) == square(0, 0, 2, 2), "pencil is clipped at the image edge")

        let before = host.document.bitmap
        host.document.undo()
        check(host.document.bitmap[30, 20] == white && host.document.bitmap[2, 20] == black, "undo removes the last pencil stroke only")
        host.document.redo()
        check(host.document.bitmap == before, "redo brings the pencil stroke back")

        let cancelled = host.document.bitmap
        pencil.press(at: PixelPoint(x: 20, y: 25), button: .left, host: host)
        pencil.drag(to: PixelPoint(x: 25, y: 25), host: host)
        pencil.cancel(host: host)
        check(host.document.bitmap == cancelled, "cancel discards the pencil stroke")
    }

    // Eraser
    do {
        check(EraserTool().sizes == [4, 6, 8, 10], "eraser offers 4, 6, 8 and 10 px")
        for size in [4, 6, 8, 10] {
            let host = FakeHost(), eraser = EraserTool()
            host.document.draw { $0.fill($0.bounds, with: black) }
            host.document.color2 = red
            eraser.size = size
            stroke(eraser, host, [(20, 15)])
            check(pixels(of: host.document.bitmap, equalTo: red.packed) == square(20 - size / 2, 15 - size / 2, size, size),
                  "eraser \(size) px paints a \(size)×\(size) square of Color 2")
        }

        let host = FakeHost(), eraser = EraserTool()
        eraser.size = 4
        host.document.color1 = blue
        host.document.color2 = red
        // Left half blue (Color 1), right half black.
        host.document.draw { $0.fill(PixelRect(x: 0, y: 0, width: 20, height: 30), with: blue.packed) }
        host.document.draw { $0.fill(PixelRect(x: 20, y: 0, width: 20, height: 30), with: black) }
        let start = host.document.bitmap
        stroke(eraser, host, [(10, 10), (30, 10)], button: .right)
        let bitmap = host.document.bitmap
        check(pixels(of: bitmap, equalTo: red.packed) == square(8, 8, 12, 4), "right eraser changes only Color 1 pixels")
        check(bitmap[25, 10] == black, "right eraser leaves other colors alone")

        host.document.undo()
        check(host.document.bitmap == start, "undo restores the pixels the eraser changed")

        stroke(eraser, host, [(5, 25), (35, 25)])
        check(pixels(of: host.document.bitmap, equalTo: red.packed) == square(3, 23, 34, 4), "left eraser covers every color")
        host.document.undo()
        check(host.document.bitmap == start, "undo removes the left eraser stroke")
    }

    // Fill
    do {
        let host = FakeHost(width: 20, height: 20), bucket = FillTool()
        host.document.color1 = red
        host.document.color2 = blue
        // A closed black square outline from (5,5) to (14,14), with a diagonal gap pixel at a corner outside it.
        host.document.draw { bitmap in
            bitmap.line(fromX: 5, y: 5, toX: 14, y: 5, value: black)
            bitmap.line(fromX: 5, y: 14, toX: 14, y: 14, value: black)
            bitmap.line(fromX: 5, y: 5, toX: 5, y: 14, value: black)
            bitmap.line(fromX: 14, y: 5, toX: 14, y: 14, value: black)
        }
        let start = host.document.bitmap
        stroke(bucket, host, [(9, 9)])
        let inside = square(6, 6, 8, 8)
        check(pixels(of: host.document.bitmap, equalTo: red.packed) == inside, "fill stays inside a closed outline")

        stroke(bucket, host, [(0, 0)], button: .right)
        let bitmap = host.document.bitmap
        check(pixels(of: bitmap, equalTo: blue.packed).count == 400 - 100, "right fill uses Color 2 and covers the outside")
        check(bitmap[0, 0] == blue.packed && bitmap[19, 19] == blue.packed && bitmap[0, 19] == blue.packed,
              "fill reaches the image corners")

        // A diagonal of two pixels does not connect: 4-connectivity.
        let diagonal = FakeHost(width: 3, height: 3)
        diagonal.document.draw { bitmap in
            bitmap.set(x: 1, y: 0, to: black); bitmap.set(x: 0, y: 1, to: black)
        }
        diagonal.document.color1 = red
        stroke(bucket, diagonal, [(0, 0)])
        check(pixels(of: diagonal.document.bitmap, equalTo: red.packed) == [[0, 0]], "fill is 4-connected, not 8-connected")

        // Exact color: a slightly different white stops the fill.
        let exact = FakeHost(width: 4, height: 1)
        exact.document.draw { $0.set(x: 2, y: 0, to: RGB(r: 254, g: 255, b: 255).packed) }
        exact.document.color1 = red
        stroke(bucket, exact, [(0, 0)])
        check(pixels(of: exact.document.bitmap, equalTo: red.packed) == [[0, 0], [1, 0]], "fill matches the exact color only")

        let same = FakeHost(width: 4, height: 4)
        same.document.color1 = .white
        stroke(bucket, same, [(1, 1)])
        check(!same.document.canUndo, "filling with the same color records no step")

        host.document.undo()
        check(pixels(of: host.document.bitmap, equalTo: blue.packed).isEmpty, "undo removes the last fill")
        host.document.undo()
        check(host.document.bitmap == start, "undo removes the first fill")

        // A large image with a maze-like pattern of stripes, filled in one go.
        let big = FakeHost(width: 3000, height: 3000)
        big.document.draw { bitmap in
            for x in stride(from: 10, to: 3000, by: 20) {
                // Vertical walls with a gap alternately at the top and the bottom.
                let gapAtTop = (x / 20) % 2 == 0
                bitmap.fill(PixelRect(x: x, y: gapAtTop ? 1 : 0, width: 1, height: 2999), with: black)
            }
        }
        big.document.color1 = red
        let started = Date()
        stroke(bucket, big, [(0, 1500)])
        let seconds = Date().timeIntervalSince(started)
        let filled = big.document.bitmap
        check(filled[2999, 2999] == red.packed && filled[0, 0] == red.packed && filled[15, 1500] == red.packed,
              "fill crosses a 3000×3000 serpentine")
        check(filled[10, 1500] == black, "fill leaves the walls")
        check(seconds < 10, String(format: "fill of 9 million pixels is fast (%.2f s, unoptimized build)", seconds))
    }

    // Color picker
    do {
        let host = FakeHost(), picker = ColorPickerTool()
        host.document.draw { $0.set(x: 3, y: 4, to: red.packed); $0.set(x: 7, y: 8, to: blue.packed) }
        stroke(picker, host, [(3, 4)])
        check(host.document.color1 == red && host.returned == 1, "left pick sets Color 1 and returns to the previous tool")
        stroke(picker, host, [(7, 8)], button: .right)
        check(host.document.color2 == blue && host.document.color1 == red && host.returned == 2, "right pick sets Color 2")
        stroke(picker, host, [(1, 1), (-5, -5)])
        check(host.document.color1 == red && host.returned == 2, "releasing outside the image picks nothing")
        picker.press(at: PixelPoint(x: 3, y: 4), button: .left, host: host)
        picker.cancel(host: host)
        picker.release(at: PixelPoint(x: 7, y: 8), host: host)
        check(host.document.color1 == red && host.returned == 2, "a cancelled pick changes nothing")
        check(!host.document.canUndo && !host.document.isDirty, "picking a color is not an image change")
    }

    // Magnifier
    do {
        let host = FakeHost(), lens = MagnifierTool()
        stroke(lens, host, [(12, 7)])
        stroke(lens, host, [(3, 4)], button: .right)
        check(host.zooms.count == 2 && host.zooms[0].0 == 1 && host.zooms[0].1 == PixelPoint(x: 12, y: 7)
              && host.zooms[1].0 == -1 && host.zooms[1].1 == PixelPoint(x: 3, y: 4),
              "magnifier: left zooms in, right zooms out, around the clicked pixel")
        check(!host.document.canUndo, "zooming is not an image change")
    }

    // Tool box
    do {
        let box = ToolBox()
        check(box.kind == .pencil && box.current.size == 1, "pencil 1 px is selected at start")
        box.stepSize(1); box.stepSize(1)
        check(box.current.size == 3, "Ctrl++ steps the pencil to 3 px")
        box.stepSize(1); box.stepSize(1)
        check(box.current.size == 4 && !box.canStepSize(1), "pencil size stops at 4 px")
        box.select(.eraser)
        check(box.current.size == 8, "each tool keeps its own size")
        box.stepSize(-1)
        check(box.current.size == 6, "Ctrl+- steps the eraser down")
        for _ in 0..<5 { box.stepSize(-1) }
        check(box.current.size == 4 && !box.canStepSize(-1), "eraser size stops at 4 px")
        box.select(.fill)
        check(!box.canStepSize(1) && !box.canStepSize(-1), "the bucket has no size")
        box.select(.colorPicker)
        box.returnToPrevious()
        check(box.kind == .fill, "returning from the color picker selects the tool used before")
        box.select(.pencil)
        check(box.current.size == 4, "the pencil size is remembered")
    }
}
