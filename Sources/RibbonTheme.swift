import AppKit

/// Every measure and color of the ribbon, the status bar and the workspace, in one place
/// for the fidelity pass. Values are from memory of the Windows 7 Paint; the ones marked
/// "a conferir com o original" are the least certain.
enum RibbonTheme {
    static func rgb(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }

    /// View > Interface text size. The ribbon, the status bar, the rulers, the application menu,
    /// the panels and the app's own dialogs keep their layout in these units and are drawn this
    /// many times larger (see `setScaledFrame`), so icons and measures follow the text.
    static var scale: CGFloat = 1

    // MARK: Text

    /// Segoe UI 9 pt is 12 px at 96 dpi; the system font is wider, so 11 pt keeps the same widths.
    /// A conferir com o original; replaced by Selawik later.
    static let font = NSFont.systemFont(ofSize: 11)
    static let textColor = rgb(0x1E1E1E)
    static let disabledTextColor = rgb(0x8D8D8D)
    /// Group names under each group. A conferir com o original.
    static let groupLabelColor = rgb(0x4C5A6E)

    static func attributes(_ enabled: Bool = true, color: NSColor? = nil) -> [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: enabled ? (color ?? textColor) : disabledTextColor]
    }

    static func textWidth(_ text: String) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    // MARK: Heights (a conferir com o original)

    /// Strip for Save, Undo and Redo above the tabs (in Windows it sits in the title bar).
    static let quickAccessHeight: CGFloat = 25
    static let tabRowHeight: CGFloat = 24
    static let bodyHeight: CGFloat = 93
    static var ribbonHeight: CGFloat { quickAccessHeight + tabRowHeight + bodyHeight }

    /// Room for controls inside a group, starting `groupTop` below the top of the body.
    static let groupTop: CGFloat = 3
    static let groupContentHeight: CGFloat = 70
    static let groupLabelHeight: CGFloat = 17
    /// Horizontal room between a group's content and its separators.
    static let groupPadding: CGFloat = 4
    /// Left margin of the first group.
    static let bodyMargin: CGFloat = 3

    static let largeButtonHeight: CGFloat = 68
    static let largeButtonMinWidth: CGFloat = 42
    static let largeIcon: CGFloat = 32
    static let smallButtonHeight: CGFloat = 22
    static let smallIcon: CGFloat = 16
    /// Icon-only buttons of the Tools group.
    static let iconButtonWidth: CGFloat = 23

    // MARK: Tabs

    static let applicationButtonWidth: CGFloat = 56
    static let applicationButtonHeight: CGFloat = 22
    static let tabHeight: CGFloat = 23
    static let tabPadding: CGFloat = 13
    static let tabSpacing: CGFloat = 1
    /// Left edge of the application button.
    static let tabRowMargin: CGFloat = 1

    // MARK: Colors (a conferir com o original)

    /// Behind the quick access strip and the tabs.
    static let frameTop = rgb(0xE2EBF6)
    static let frameBottom = rgb(0xD7E3F2)
    static let bodyTop = rgb(0xFDFEFF)
    static let bodyMiddle = rgb(0xF2F6FB)
    static let bodyBottom = rgb(0xDCE6F4)
    static let bodyBorder = rgb(0xB1C2D7)
    static let bodyBottomBorder = rgb(0x9FB2CA)
    static let separatorDark = rgb(0xC5D2E3)
    static let separatorLight = rgb(0xFFFFFF, alpha: 0.85)

    static let tabBorder = rgb(0xB1C2D7)
    static let tabHoverTop = rgb(0xF5F9FE, alpha: 0.9)
    static let tabHoverBottom = rgb(0xE6EEF8, alpha: 0.9)
    static let tabHoverBorder = rgb(0xC3D3E7)

    static let applicationTop = rgb(0x4A84D0)
    static let applicationBottom = rgb(0x1D56A8)
    static let applicationBorder = rgb(0x1B4887)
    static let applicationHoverTop = rgb(0x5E97E0)
    static let applicationHoverBottom = rgb(0x2866BB)
    static let applicationPressedTop = rgb(0x2E66B2)
    static let applicationPressedBottom = rgb(0x184A92)

    /// Button backgrounds: hover, pressed and checked (the selected tool).
    static let hoverTop = rgb(0xF4F9FF)
    static let hoverBottom = rgb(0xDCEBFC)
    static let hoverBorder = rgb(0xA8C8EC)
    static let pressedTop = rgb(0xCFE2F8)
    static let pressedBottom = rgb(0xB4D1F4)
    static let pressedBorder = rgb(0x7EA3CF)
    static let checkedTop = rgb(0xE2EEFC)
    static let checkedBottom = rgb(0xC7DDF8)
    static let checkedBorder = rgb(0x8EAFD8)
    static let checkedHoverTop = rgb(0xD8E8FB)
    static let checkedHoverBottom = rgb(0xBCD6F6)

    /// Line between the two parts of a split button under the pointer.
    static let splitLine = rgb(0xA8C8EC)

    static let checkboxBorder = rgb(0x8E8F8F)
    static let checkboxTop = rgb(0xF4F4F4)
    static let checkboxBottom = rgb(0xDADADA)
    static let checkmark = rgb(0x21344E)

    static let swatchBorder = rgb(0xA0A0A0)
    static let swatchHoverBorder = rgb(0xE5C365)
    static let customSwatchBorder = rgb(0xC9D1DC)

    static let popupBackground = rgb(0xF5F8FC)
    static let popupBorder = rgb(0x8BA0BC)

    /// Area around the image. A conferir com o original.
    static let workspace = rgb(0xC9D3E2)
    /// Canvas resize handles.
    static let handleFill = rgb(0xFFFFFF)
    static let handleBorder = rgb(0x55606E)
    static let handleSize: CGFloat = 5

    // MARK: Selection (a conferir com o original)

    /// Dashed outline of a selection: dark dashes over a light line, 4 px each.
    static let selectionDashDark = rgb(0x000000)
    static let selectionDashLight = rgb(0xFFFFFF)
    static let selectionDash: [CGFloat] = [4, 4]
    /// The eight selection handles, centred on the outline.
    static let selectionHandleSize: CGFloat = 5
    static let selectionHandleFill = rgb(0xFFFFFF)
    static let selectionHandleBorder = rgb(0x000000)
    /// Dotted outline of the new size while dragging a canvas handle.
    static let canvasResizeDash: [CGFloat] = [1, 1]
    static let canvasResizeColor = rgb(0x000000)
    /// Extra room around the small handles that still counts as a hit.
    static let handleHitSlop: CGFloat = 2

    /// Band along the edge of a text box, inside and outside, that moves the box.
    static let textBorderBand: CGFloat = 3

    // MARK: Diagonal resize cursors (a conferir com o original)

    /// Side of the drawn ↖↘ and ↗↙ cursors, and the length of each arrowhead along the diagonal.
    static let diagonalCursorSize: CGFloat = 20
    static let diagonalCursorHead: CGFloat = 6

    // MARK: Contextual tab (a conferir com o original)

    /// "Text Tools": a tinted header above the tab and a light tint behind it.
    static let contextualHeaderTop = rgb(0xFCEFC2)
    static let contextualHeaderBottom = rgb(0xF6D77C)
    static let contextualHeaderBorder = rgb(0xD8B24E)
    static let contextualHeaderText = rgb(0x5A4512)
    static let contextualTabTint = rgb(0xFBE7A6, alpha: 0.55)
    /// Gap between the normal tabs and the contextual ones.
    static let contextualGap: CGFloat = 6
    /// Font family and size boxes of the Text tab.
    static let fontFamilyWidth: CGFloat = 140
    static let fontSizeWidth: CGFloat = 58
    static let comboHeight: CGFloat = 22

    // MARK: Status bar (a conferir com o original)

    static let statusBarHeight: CGFloat = 24
    static let statusTop = rgb(0xEEF3FA)
    static let statusBottom = rgb(0xDDE6F2)
    static let statusBorder = rgb(0xB9C6D6)
    /// Sections are at least this wide (a conferir com o original)…
    static let statusSectionMinimum: CGFloat = 140
    /// …and wider when the longest value they show needs it in the current language.
    static var statusSectionWidth: CGFloat {
        let longest = [StatusText.position(PixelPoint(x: 9999, y: 9999)), StatusText.imageSize(width: 9999, height: 9999),
                       StatusText.diskSize(1000 * 1024), StatusText.diskSize(999)].map(textWidth).max() ?? 0
        return max(statusSectionMinimum, ceil(longest) + 30)
    }
    static let zoomLabelWidth: CGFloat = 42
    static let zoomSliderWidth: CGFloat = 110
    static let zoomTrack = rgb(0x8496AE)
    static let zoomThumbTop = rgb(0xF7FAFD)
    static let zoomThumbBottom = rgb(0xC4D4E8)
    static let zoomThumbBorder = rgb(0x5D7699)

    // MARK: Application menu (a conferir com o original)

    static let menuItemHeight: CGFloat = 38
    /// Items on the right: a bold title over two lines of detail, or a single line.
    static let menuPaneItemHeight: CGFloat = 50
    static let menuPaneDetailHeight: CGFloat = 29
    static let menuPaneLineHeight: CGFloat = 26
    static let menuLeftWidth: CGFloat = 250
    static let menuRightWidth: CGFloat = 270
    static let menuFrame = rgb(0xC6D6EA)
    static let menuLeftBackground = rgb(0xFBFCFE)
    static let menuRightBackground = rgb(0xEEF3F9)
    static let menuHeaderColor = rgb(0x1E395B)
    /// The pin at the right of each recent picture: its column, and the colors of the drawing.
    static let menuPinWidth: CGFloat = 24
    static let menuPinOutline = rgb(0x4C5A6E)
    static let menuPinFill = rgb(0xFFFFFF)
    static let menuPinPinnedFill = rgb(0x8FB3DE)

    // MARK: Drop-down menus (a conferir com o original)

    /// The drawn drop-downs of the ribbon and the canvas (Size, Outline, Fill, Brushes, Paste,
    /// Select, Rotate, Text size, the context menu): a light background, a strip for the icons
    /// on the left with a line beside it, bold section headers and rounded blue highlights.
    static let dropdownBackground = rgb(0xFCFCFD)
    static let dropdownGutter = rgb(0xF0F3F7)
    static let dropdownGutterLine = rgb(0xDDE3EA)
    static let dropdownHeaderBackground = rgb(0xE6ECF3)
    static let dropdownHeaderLine = rgb(0xC5D2E3)
    static let dropdownHeaderText = menuHeaderColor
    static let dropdownSeparator = rgb(0xD5DCE5)
    static let dropdownSample = rgb(0x1E1E1E)
    static let dropdownHeaderFont = NSFont.boldSystemFont(ofSize: 11)
    /// Room around the items, inside the panel's border.
    static let dropdownPadding: CGFloat = 2
    static let dropdownItemHeight: CGFloat = 22
    static let dropdownHeaderHeight: CGFloat = 22
    static let dropdownSeparatorHeight: CGFloat = 7
    /// Width of the icon strip; the text starts `dropdownTextGap` after it.
    static let dropdownGutterWidth: CGFloat = 28
    static let dropdownTextGap: CGFloat = 8
    /// After the text: room for the submenu triangle.
    static let dropdownTrailing: CGFloat = 24
    static let dropdownMinWidth: CGFloat = 120
    static let dropdownIcon: CGFloat = 16
    /// Size: lines of each thickness, at most this thick, in rows this wide.
    static let sizeSampleMaxThickness: CGFloat = 14
    static let sizeSampleWidth: CGFloat = 150
    static let sizeSampleMinHeight: CGFloat = 22
    /// Brushes: a gallery of large icons.
    static let brushGalleryColumns = 3
    static let brushGalleryCell: CGFloat = 46
    static let brushGalleryIcon: CGFloat = 32

    // MARK: Shapes gallery (a conferir com o original)

    /// Columns of the Shapes gallery with room to spare, and the fewest it shows before the
    /// Shapes group collapses; it loses one column at a time in between.
    static let shapeGalleryColumns = 7
    static let shapeGalleryMinColumns = 3

    // MARK: Key tips and the minimized ribbon (a conferir com o original)

    /// The small labels shown over the tabs and the controls after Option (Alt) or F10.
    static let keyTipFont = NSFont.systemFont(ofSize: 10)
    static let keyTipHeight: CGFloat = 15
    static let keyTipPadding: CGFloat = 4
    static let keyTipMinWidth: CGFloat = 15
    static let keyTipTop = rgb(0xFFFFFF)
    static let keyTipBottom = rgb(0xE3E8EF)
    static let keyTipBorder = rgb(0x767F8B)
    static let keyTipText = rgb(0x1E1E1E)
    /// Key tips of disabled controls.
    static let keyTipDisabledText = rgb(0x9AA2AD)
    /// Height of the ribbon reduced to the quick access strip and the tabs, with a border line under them.
    static var minimizedRibbonHeight: CGFloat { quickAccessHeight + tabRowHeight + 2 }

    // MARK: Font list (a conferir com o original)

    /// The drop-down of the Font box: each family written in itself, 16 rows, a scroll bar.
    static let fontListRowHeight: CGFloat = 24
    static let fontListNameSize: CGFloat = 13
    /// Room kept above and below the text of a row; taller fonts are drawn smaller.
    static let fontListTextMargin: CGFloat = 2
    static let fontListTextInset: CGFloat = 8
    static let fontListVisibleRows = 16
    static let fontListScrollBarWidth: CGFloat = 14
    static let fontListThumbMinimum: CGFloat = 18
    static let fontListTrack = rgb(0xEEF1F5)
    /// Symbol fonts show their name in the interface font and this sample in the font.
    static let fontListSample = "AaBbYyZz"
    static let fontListSampleGap: CGFloat = 12
    /// The arrow part of the Font box, from its right edge, that opens the drawn list.
    static let comboButtonWidth: CGFloat = 20

    // MARK: Rulers and gridlines (a conferir com o original)

    static let rulerThickness: CGFloat = 18
    static let rulerBackground = rgb(0xEEF2F8)
    /// The stretch of the ruler over the image.
    static let rulerImage = rgb(0xFFFFFF)
    static let rulerBorder = rgb(0xA7B6CA)
    static let rulerTick = rgb(0x5C6E86)
    static let rulerText = rgb(0x3B4B60)
    static let rulerFont = NSFont.systemFont(ofSize: 9)
    /// The line marking the pointer.
    static let rulerPointer = rgb(0x1E1E1E)
    /// Labelled ticks are at least this far apart.
    static let rulerLabelSpacing: CGFloat = 50
    /// Pixel gridlines, drawn between image pixels from this zoom up.
    static let gridMinimumZoom: CGFloat = 4
    static let gridColor = rgb(0x808080, alpha: 0.55)

    // MARK: Full screen and thumbnail (a conferir com o original)

    static let fullScreenBackground = rgb(0x000000)
    static let thumbnailSize = NSSize(width: 200, height: 150)
    static let thumbnailBackground = workspace
    static let thumbnailVisibleArea = rgb(0x1D56A8)

    // MARK: Print preview (a conferir com o original)

    static let previewBackground = rgb(0xABABAB)
    static let previewMargin = rgb(0x9DB0C8)
    static let previewLabel = rgb(0x1E1E1E)
    /// Room around the page, and under it for the page number.
    static let previewRoom: CGFloat = 14
    static let previewLabelHeight: CGFloat = 20

    // MARK: Drawing helpers

    enum Look {
        case normal, hover, pressed, checked, checkedHover
    }

    /// The rounded background of a ribbon button in the given look; nothing in `.normal`.
    static func drawButton(_ rect: NSRect, _ look: Look, radius: CGFloat = 2.5) {
        let colors: (NSColor, NSColor, NSColor)
        switch look {
        case .normal: return
        case .hover: colors = (hoverTop, hoverBottom, hoverBorder)
        case .pressed: colors = (pressedTop, pressedBottom, pressedBorder)
        case .checked: colors = (checkedTop, checkedBottom, checkedBorder)
        case .checkedHover: colors = (checkedHoverTop, checkedHoverBottom, pressedBorder)
        }
        let box = rect.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: box, xRadius: radius, yRadius: radius)
        NSGradient(starting: colors.0, ending: colors.1)?.draw(in: path, angle: 90)
        colors.2.setStroke()
        path.stroke()
        // Inner highlight.
        rgb(0xFFFFFF, alpha: look == .pressed ? 0.25 : 0.6).setStroke()
        NSBezierPath(roundedRect: box.insetBy(dx: 1, dy: 1), xRadius: radius - 1, yRadius: radius - 1).stroke()
    }

    /// Only the border of a hovered button, around a split button whose other part is lit.
    static func drawButtonFrame(_ rect: NSRect, radius: CGFloat = 2.5) {
        hoverBorder.setStroke()
        NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: radius, yRadius: radius).stroke()
    }

    /// A vertical gradient that works in flipped views: `top` is drawn at the top edge.
    static func fillVertical(_ rect: NSRect, top: NSColor, bottom: NSColor, flipped: Bool = true) {
        NSGradient(starting: top, ending: bottom)?.draw(in: rect, angle: flipped ? 90 : -90)
    }

    /// The small downward triangle of drop-down buttons, centred on `center`.
    static func drawArrow(center: NSPoint, enabled: Bool, color: NSColor? = nil) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: center.x - 3, y: center.y - 1.5))
        path.line(to: NSPoint(x: center.x + 3, y: center.y - 1.5))
        path.line(to: NSPoint(x: center.x, y: center.y + 1.5))
        path.close()
        (enabled ? (color ?? rgb(0x2C3E55)) : disabledTextColor).setFill()
        path.fill()
    }
}
