import Foundation

// Line by line, so a crash still shows the checks before it.
setvbuf(stdout, nil, _IOLBF, 0)

var failures = 0

// Settings go to a suite of their own, removed at the end, never to the app's.
let settingsSuite = "mypaint-tests-\(UUID().uuidString)"
AppSettings.defaults = UserDefaults(suiteName: settingsSuite)!

func check(_ condition: Bool, _ name: String) {
    print(condition ? "ok    \(name)" : "FAIL  \(name)")
    if !condition { failures += 1 }
}

/// A picture with every kind of content a lossless format must keep.
func sample() -> Bitmap {
    var bitmap = Bitmap(width: 37, height: 23)
    for y in 0..<bitmap.height {
        for x in 0..<bitmap.width {
            let color = RGB(r: UInt8(x * 255 / 36), g: UInt8(y * 255 / 22), b: UInt8((x * 7 + y * 13) % 256))
            bitmap.set(x: x, y: y, to: color.packed)
        }
    }
    return bitmap
}

// Bitmap
do {
    var bitmap = Bitmap(width: 10, height: 10)
    let black = RGB.black.packed, white = RGB.white.packed
    bitmap.line(fromX: 1, y: 1, toX: 6, y: 3, value: black)
    let expected: Set<[Int]> = [[1, 1], [2, 1], [3, 2], [4, 2], [5, 3], [6, 3]]
    var drawn = Set<[Int]>()
    for y in 0..<10 { for x in 0..<10 where bitmap[x, y] == black { drawn.insert([x, y]) } }
    check(drawn == expected, "line covers the Bresenham pixels")

    var clipped = Bitmap(width: 4, height: 4)
    clipped.line(fromX: -5, y: -5, toX: 8, y: 8, value: black)
    check((0..<4).allSatisfy { clipped[$0, $0] == black }, "line is clipped to the image")

    let rect = PixelRect(x: 2, y: 1, width: 3, height: 2)
    let saved = bitmap.region(rect)
    var copy = bitmap
    copy.write([UInt32](repeating: white, count: 6), to: rect)
    copy.write(saved, to: rect)
    check(copy == bitmap, "region and write are inverses")
}

// Undo
do {
    let document = PaintDocument(bitmap: Bitmap(width: 20, height: 20))
    let blank = document.bitmap
    var states = [blank]
    for step in 0..<60 {
        let before = document.bitmap
        document.draw { $0.set(x: step % 20, y: step / 20, to: RGB.black.packed) }
        document.commit(before: before, changed: PixelRect(x: step % 20, y: step / 20, width: 1, height: 1))
        states.append(document.bitmap)
    }
    check(document.isDirty, "drawing marks the document as changed")
    var undone = 0
    while document.undo() { undone += 1 }
    check(undone == 50, "undo keeps 50 levels")
    check(document.bitmap == states[10], "undo restores the oldest kept state")
    var redone = 0
    while document.redo() { redone += 1 }
    check(redone == 50 && document.bitmap == states[60], "redo restores the newest state")

    document.undo()
    let before = document.bitmap
    document.draw { $0.set(x: 19, y: 19, to: RGB.black.packed) }
    document.commit(before: before, changed: PixelRect(x: 19, y: 19, width: 1, height: 1))
    check(!document.canRedo, "a new edit clears redo")

    let unchanged = document.bitmap
    document.draw { $0.set(x: 5, y: 5, to: RGB.black.packed) }
    document.revert(to: unchanged)
    check(document.bitmap == unchanged, "revert discards a cancelled stroke")
}

// Files
do {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("mypaint-tests-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let original = sample()
    for format in [ImageFormat.png, .bmp, .tiff] {
        let url = folder.appendingPathComponent("sample.\(format.fileExtension)")
        do {
            try ImageFile.write(original, to: url, format: format)
            let loaded = try ImageFile.read(url)
            check(loaded == original, "\(format.fileExtension) round trip is lossless")
        } catch {
            check(false, "\(format.fileExtension) round trip: \(error.localizedDescription)")
        }
    }
    for format in [ImageFormat.jpeg, .gif] {
        let url = folder.appendingPathComponent("sample.\(format.fileExtension)")
        do {
            try ImageFile.write(original, to: url, format: format)
            let loaded = try ImageFile.read(url)
            check(loaded.width == original.width && loaded.height == original.height,
                  "\(format.fileExtension) keeps the image size")
        } catch {
            check(false, "\(format.fileExtension) write and read: \(error.localizedDescription)")
        }
    }
    check(ImageFormat(url: URL(fileURLWithPath: "/tmp/A.JPEG")) == .jpeg, "format is recognised by extension")
    let bogus = folder.appendingPathComponent("bogus.png")
    try! Data("not an image".utf8).write(to: bogus)
    check((try? ImageFile.read(bogus)) == nil, "an invalid file is rejected")
}

runToolTests()
runWindowTests()
runRibbonTests()
runSelectionTests()
runShapeTests()
runBrushTests()
runTextTests()
runSystemTests()
runLocalizationTests()
runFidelityTests()
runMenuTests()
runMenuStripTests()
runGalleryTests()
runKeyTipTests()
runPreviewTests()
runCanvasTests()
runRecentPinTests()
runBlackAndWhiteTests()
runFontListTests()
runUpdateTests()

AppSettings.defaults.removePersistentDomain(forName: settingsSuite)

print(failures == 0 ? "All tests passed." : "\(failures) test(s) failed.")
exit(failures == 0 ? 0 : 1)
