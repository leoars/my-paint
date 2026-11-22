import Foundation

/// The two shapes of the Select button.
enum SelectionShape: Int {
    case rectangle = 0, freeForm = 1
}

/// A marked area of the image. Moving or changing it lifts its pixels: from then on they
/// float above `base` (the image without them) until the selection is fixed.
/// The document bitmap always shows the floating pixels already composited, so fixing a
/// selection, undoing or saving never needs an extra step.
struct Selection {
    /// Where the selection sits, in image pixels. A floating selection may hang off the image.
    var rect: PixelRect
    /// Selected pixels (non-zero words) at the source size; nil when the whole rectangle is selected.
    var mask: Bitmap?
    /// The lifted pixels at their own size; `rect` stretches them when it differs.
    var content: Bitmap?
    /// The image under the floating pixels.
    var base: Bitmap?

    var isFloating: Bool { content != nil }

    /// Whether image pixel (x, y) is selected, following any stretch of the selection.
    func contains(_ x: Int, _ y: Int) -> Bool {
        guard x >= rect.x, y >= rect.y, x < rect.x + rect.width, y < rect.y + rect.height else { return false }
        guard let mask = mask else { return true }
        return mask[(x - rect.x) * mask.width / rect.width, (y - rect.y) * mask.height / rect.height] != 0
    }

    /// Fills the selected pixels of a free-form outline: pixel centres inside the polygon
    /// (even-odd rule) plus every pixel the outline itself crosses. Points are image pixels.
    static func freeFormMask(_ points: [PixelPoint]) -> (rect: PixelRect, mask: Bitmap)? {
        guard let first = points.first else { return nil }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for point in points {
            minX = min(minX, point.x); maxX = max(maxX, point.x)
            minY = min(minY, point.y); maxY = max(maxY, point.y)
        }
        let rect = PixelRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        var mask = Bitmap(width: rect.width, height: rect.height, value: 0)
        let closed = points + [first]
        // Scanlines through pixel centres.
        for row in 0..<rect.height {
            let y = Double(minY + row) + 0.5
            var crossings: [Double] = []
            for index in 0..<(closed.count - 1) {
                let a = closed[index], b = closed[index + 1]
                let ay = Double(a.y) + 0.5, by = Double(b.y) + 0.5
                guard (ay <= y) != (by <= y) else { continue }
                let ax = Double(a.x) + 0.5, bx = Double(b.x) + 0.5
                crossings.append(ax + (y - ay) * (bx - ax) / (by - ay))
            }
            crossings.sort()
            var pair = 0
            while pair + 1 < crossings.count {
                let start = max(0, Int((crossings[pair] - 0.5).rounded(.up)) - minX)
                let end = min(rect.width - 1, Int((crossings[pair + 1] - 0.5).rounded(.down)) - minX)
                if start <= end { mask.fill(PixelRect(x: start, y: row, width: end - start + 1, height: 1), with: 1) }
                pair += 2
            }
        }
        for index in 0..<(closed.count - 1) {
            let a = closed[index], b = closed[index + 1]
            Bitmap.forEachLinePoint(fromX: a.x, y: a.y, toX: b.x, y: b.y) { x, y in mask.set(x: x - minX, y: y - minY, to: 1) }
        }
        return (rect, mask)
    }
}

extension PixelRect {
    var maxX: Int { x + width }
    var maxY: Int { y + height }

    func offsetBy(_ dx: Int, _ dy: Int) -> PixelRect { PixelRect(x: x + dx, y: y + dy, width: width, height: height) }
}

/// Selection editing. Every public operation is one undoable step; marking an area is not a step.
extension PaintDocument {
    private static let nothing = PixelRect(x: 0, y: 0, width: 0, height: 0)

    /// Runs `body` as one undoable step; `body` returns the area it changed.
    func step(_ body: () -> PixelRect) {
        // A shape or a text box still being edited becomes its own step first.
        fixShape()
        fixText()
        let before = bitmap
        let changed = body()
        commit(before: before, changed: changed)
    }

    /// Marks `rect` (clipped to the image), fixing any previous selection. An empty area marks nothing.
    func select(_ rect: PixelRect, mask: Bitmap? = nil) {
        fixShape()
        fixText()
        selection = nil
        let clipped = rect.intersection(bitmap.bounds)
        guard !clipped.isEmpty else { return }
        var kept = mask
        if let mask = mask, clipped != rect {
            kept = mask.cropped(to: PixelRect(x: clipped.x - rect.x, y: clipped.y - rect.y,
                                              width: clipped.width, height: clipped.height), fill: 0)
        }
        selection = Selection(rect: clipped, mask: kept)
    }

    func selectAll() {
        select(bitmap.bounds)
    }

    /// Leaves the floating pixels where they are and removes the selection.
    func fixSelection() {
        selection = nil
    }

    /// Size shown in the status bar.
    var selectionSize: (width: Int, height: Int)? {
        selection.map { ($0.rect.width, $0.rect.height) }
    }

    private func fillSelected(_ s: Selection, in target: inout Bitmap, with value: UInt32) {
        let area = s.rect.intersection(target.bounds)
        guard !area.isEmpty else { return }
        let w = target.width
        target.withPixels { p in
            for y in area.y..<area.maxY { for x in area.x..<area.maxX where s.contains(x, y) { p[y * w + x] = value } }
        }
    }

    /// Lifts the marked pixels so they can move or change; the hole takes Color 2 unless
    /// `copy`. Returns the area it changed (nothing when already floating).
    @discardableResult
    func liftSelection(copy: Bool) -> PixelRect {
        guard var s = selection, !s.isFloating else { return PaintDocument.nothing }
        s.content = bitmap.cropped(to: s.rect, fill: color2.packed)
        var base = bitmap
        if !copy { fillSelected(s, in: &base, with: color2.packed) }
        s.base = base
        selection = s
        composite(replacing: s.rect)
        return s.rect
    }

    /// Redraws the floating pixels over the base: `old` (the previous place) goes back to the
    /// base first. With Transparent selection, Color 2 pixels are skipped.
    func composite(replacing old: PixelRect) {
        guard let s = selection, let content = s.content, let base = s.base else { return }
        let key: UInt32? = transparentSelection ? color2.packed : nil
        draw { image in
            let restore = old.intersection(image.bounds)
            if !restore.isEmpty { image.write(base.region(restore), to: restore) }
            let area = s.rect.intersection(image.bounds)
            guard !area.isEmpty else { return }
            let w = image.width, cw = content.width, ch = content.height
            let mask = s.mask
            image.withPixels { p in
                for y in area.y..<area.maxY {
                    let sy = (y - s.rect.y) * ch / s.rect.height
                    for x in area.x..<area.maxX {
                        let sx = (x - s.rect.x) * cw / s.rect.width
                        if let mask = mask, mask[sx, sy] == 0 { continue }
                        let value = content[sx, sy]
                        if value == key { continue }
                        p[y * w + x] = value
                    }
                }
            }
        }
    }

    /// Moves a floating selection to `rect` (which may also change its size). Returns the area changed.
    @discardableResult
    func placeSelection(_ rect: PixelRect) -> PixelRect {
        guard var s = selection, s.isFloating else { return PaintDocument.nothing }
        let old = s.rect
        s.rect = rect
        selection = s
        composite(replacing: old)
        return old.union(rect)
    }

    /// The arrow keys: lifts the selection and moves it one pixel.
    func nudgeSelection(dx: Int, dy: Int) {
        guard selection != nil else { return }
        step {
            let lifted = liftSelection(copy: false)
            guard let rect = selection?.rect else { return lifted }
            return lifted.union(placeSelection(rect.offsetBy(dx, dy)))
        }
    }

    /// The selection as a picture of its own size, as Copy puts it on the clipboard and Crop keeps it.
    /// Unselected pixels inside the rectangle (free-form) take Color 2.
    func selectionImage() -> Bitmap? {
        guard let s = selection else { return nil }
        let fill = color2.packed
        var image: Bitmap
        if let content = s.content {
            image = content.scaled(toWidth: s.rect.width, height: s.rect.height)
        } else {
            image = bitmap.cropped(to: s.rect, fill: fill)
        }
        guard s.mask != nil else { return image }
        let w = image.width
        image.withPixels { p in
            for y in 0..<s.rect.height {
                for x in 0..<s.rect.width where !s.contains(s.rect.x + x, s.rect.y + y) { p[y * w + x] = fill }
            }
        }
        return image
    }

    /// Delete: the selected area takes Color 2 (a floating selection is simply dropped).
    func deleteSelection() {
        guard let s = selection else { return }
        step {
            selection = nil
            if let base = s.base {
                let area = s.rect.intersection(bitmap.bounds)
                if !area.isEmpty { draw { $0.write(base.region(area), to: area) } }
            } else {
                draw { fillSelected(s, in: &$0, with: color2.packed) }
            }
            return s.rect
        }
    }

    /// Invert selection: everything that was not selected becomes the selection.
    func invertSelection() {
        guard let s = selection else { return }
        let bounds = bitmap.bounds
        var mask = Bitmap(width: bounds.width, height: bounds.height, value: 1)
        var any = false
        mask.withPixels { p in
            for y in 0..<bounds.height {
                for x in 0..<bounds.width {
                    if s.contains(x, y) { p[y * bounds.width + x] = 0 } else { any = true }
                }
            }
        }
        selection = nil
        if any { selection = Selection(rect: bounds, mask: mask) }
    }

    /// Crop: the image becomes the selection.
    func cropToSelection() {
        guard let image = selectionImage() else { return }
        step {
            selection = nil
            draw { $0 = image }
            return image.bounds
        }
    }

    /// Applies `transform` to the selection, or to the whole image when nothing is selected.
    /// `transform` gets the bitmap and the color for areas it uncovers (Color 2, or 0 for masks).
    func transform(_ transform: (Bitmap, UInt32) -> Bitmap) {
        guard selection != nil else {
            step {
                draw { $0 = transform($0, color2.packed) }
                return bitmap.bounds
            }
            return
        }
        step {
            let lifted = liftSelection(copy: false)
            guard var s = selection, let content = s.content else { return lifted }
            let old = s.rect
            let stretched = content.scaled(toWidth: old.width, height: old.height)
            let mask = (s.mask ?? Bitmap(width: content.width, height: content.height, value: 1))
                .scaled(toWidth: old.width, height: old.height)
            let newContent = transform(stretched, color2.packed)
            let newMask = transform(mask, 0)
            s.content = newContent
            s.mask = newMask.pixels.contains(0) ? newMask : nil
            s.rect = PixelRect(x: old.x, y: old.y, width: newContent.width, height: newContent.height)
            selection = s
            composite(replacing: old)
            return lifted.union(old).union(s.rect)
        }
    }

    /// Invert color, on the selection or the whole image.
    func invertColors() {
        guard let s = selection else {
            step {
                draw { $0.invert(in: $0.bounds) }
                return bitmap.bounds
            }
            return
        }
        step {
            if var content = s.content {
                content.invert(in: content.bounds)
                var floating = s
                floating.content = content
                selection = floating
                composite(replacing: s.rect)
            } else {
                draw { $0.invert(in: s.rect, mask: s.contains) }
            }
            return s.rect
        }
    }

    /// Turns Transparent selection on or off; a floating selection is redrawn at once.
    func setTransparentSelection(_ on: Bool) {
        guard on != transparentSelection else { return }
        transparentSelection = on
        guard let s = selection, s.isFloating else { return }
        step {
            composite(replacing: s.rect)
            return s.rect
        }
    }

    /// The canvas handles: a new image size, keeping the top-left corner. New area takes Color 2.
    func resizeCanvas(width: Int, height: Int) {
        let width = max(1, width), height = max(1, height)
        guard width != bitmap.width || height != bitmap.height else { return }
        selection = nil
        step {
            let resized = bitmap.cropped(to: PixelRect(x: 0, y: 0, width: width, height: height), fill: color2.packed)
            draw { $0 = resized }
            return resized.bounds
        }
    }

    /// Pastes `image` as a floating selection at `origin`. With `enlarge`, an image larger than
    /// the canvas first grows the canvas (new area in Color 2) and is pasted at the top-left corner.
    func paste(_ image: Bitmap, at origin: PixelPoint, enlarge: Bool = false) {
        selection = nil
        step {
            var origin = origin
            if enlarge && (image.width > bitmap.width || image.height > bitmap.height) {
                let grown = bitmap.cropped(to: PixelRect(x: 0, y: 0, width: max(bitmap.width, image.width),
                                                         height: max(bitmap.height, image.height)), fill: color2.packed)
                draw { $0 = grown }
                origin = PixelPoint(x: 0, y: 0)
            }
            let rect = PixelRect(x: origin.x, y: origin.y, width: image.width, height: image.height)
            selection = Selection(rect: rect, mask: nil, content: image, base: bitmap)
            composite(replacing: PaintDocument.nothing)
            return rect
        }
    }
}
