import Foundation

enum ColorSlot: Int {
    case color1 = 1, color2 = 2
}

/// The 20 standard colors of Paint, two rows of ten, left to right.
/// The well-known values of the Windows 7 palette, checked again in the fidelity pass (phase 8).
enum Palette {
    struct Entry {
        let color: RGB
        let nameKey: String
    }

    /// The places of black and white, the only colors of black-and-white mode.
    static let blackAndWhiteIndices: Set<Int> = [0, 10]

    static let colors: [Entry] = [
        Entry(color: RGB(r: 0, g: 0, b: 0), nameKey: "color.black"),
        Entry(color: RGB(r: 127, g: 127, b: 127), nameKey: "color.gray50"),
        Entry(color: RGB(r: 136, g: 0, b: 21), nameKey: "color.darkRed"),
        Entry(color: RGB(r: 237, g: 28, b: 36), nameKey: "color.red"),
        Entry(color: RGB(r: 255, g: 127, b: 39), nameKey: "color.orange"),
        Entry(color: RGB(r: 255, g: 242, b: 0), nameKey: "color.yellow"),
        Entry(color: RGB(r: 34, g: 177, b: 76), nameKey: "color.green"),
        Entry(color: RGB(r: 0, g: 162, b: 232), nameKey: "color.turquoise"),
        Entry(color: RGB(r: 63, g: 72, b: 204), nameKey: "color.indigo"),
        Entry(color: RGB(r: 163, g: 73, b: 164), nameKey: "color.purple"),
        Entry(color: RGB(r: 255, g: 255, b: 255), nameKey: "color.white"),
        Entry(color: RGB(r: 195, g: 195, b: 195), nameKey: "color.gray25"),
        Entry(color: RGB(r: 185, g: 122, b: 87), nameKey: "color.brown"),
        Entry(color: RGB(r: 255, g: 174, b: 201), nameKey: "color.rose"),
        Entry(color: RGB(r: 255, g: 201, b: 14), nameKey: "color.gold"),
        Entry(color: RGB(r: 239, g: 228, b: 176), nameKey: "color.lightYellow"),
        Entry(color: RGB(r: 181, g: 230, b: 29), nameKey: "color.lime"),
        Entry(color: RGB(r: 153, g: 217, b: 234), nameKey: "color.lightTurquoise"),
        Entry(color: RGB(r: 112, g: 146, b: 190), nameKey: "color.blueGray"),
        Entry(color: RGB(r: 200, g: 191, b: 231), nameKey: "color.lavender"),
    ]
}
