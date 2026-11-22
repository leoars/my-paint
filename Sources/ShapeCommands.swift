import AppKit

/// Commands of the Shapes group: the gallery and the Outline and Fill drop-downs,
/// mirrored in the Shapes menu of the menu bar.
extension MainWindowController {
    /// A gallery shape: picks the Shapes tool. Another shape fixes the one being edited.
    @objc func chooseShape(_ sender: Any?) {
        guard let kind = GalleryShape(rawValue: senderTag(sender)) else { return }
        let toolbox = canvas.toolbox
        if kind != toolbox.shapeTool.kind { canvas.finishShape() }
        toolbox.shapeTool.kind = kind
        toolbox.select(.shape)
        syncInterface()
    }

    @objc func chooseOutline(_ sender: Any?) {
        guard let style = ShapeStyle(rawValue: senderTag(sender)) else { return }
        canvas.toolbox.shapeTool.outline = style
        canvas.shapeOptionsChanged()
        syncInterface()
    }

    @objc func chooseShapeFill(_ sender: Any?) {
        guard let style = ShapeStyle(rawValue: senderTag(sender)) else { return }
        canvas.toolbox.shapeTool.fill = style
        canvas.shapeOptionsChanged()
        syncInterface()
    }

    @objc func showOutlineMenu(_ sender: Any?) { showRibbonMenu(outlineMenuItems(), name: "menu.outline", under: sender) }
    @objc func showShapeFillMenu(_ sender: Any?) { showRibbonMenu(fillMenuItems(), name: "menu.shapeFill", under: sender) }

    func outlineMenuItems() -> [NSMenuItem] { styleItems(outline: true) }
    func fillMenuItems() -> [NSMenuItem] { styleItems(outline: false) }

    private func styleItems(outline: Bool) -> [NSMenuItem] {
        ShapeStyle.allCases.map { style in
            let item = NSMenuItem(title: L(style.nameKey(outline: outline)),
                                  action: outline ? #selector(chooseOutline(_:)) : #selector(chooseShapeFill(_:)), keyEquivalent: "")
            item.tag = style.rawValue
            item.target = self
            item.image = MainWindowController.styleSample(style, outline: outline)
            return item
        }
    }

    /// The Shapes menu of the menu bar: every gallery shape, then Outline and Fill.
    func makeShapesMenu() -> NSMenu {
        let menu = NSMenu(title: L("menu.shapes"))
        for shape in GalleryShape.allCases {
            let item = menu.addItem(withTitle: L(shape.nameKey), action: #selector(chooseShape(_:)), keyEquivalent: "")
            item.tag = shape.rawValue
            item.target = self
            item.image = shape.menuImage
        }
        menu.addItem(.separator())
        for (key, items) in [("ribbon.outline", outlineMenuItems()), ("ribbon.shapeFill", fillMenuItems())] {
            let parent = menu.addItem(withTitle: L(key), action: nil, keyEquivalent: "")
            parent.submenu = NSMenu()
            items.forEach(parent.submenu!.addItem)
        }
        return menu
    }

    /// A small square showing an outline or fill style, for the menus.
    static func styleSample(_ style: ShapeStyle, outline: Bool) -> NSImage {
        NSImage(size: NSSize(width: 16, height: 16), flipped: true) { _ in
            let box = NSRect(x: 2.5, y: 2.5, width: 11, height: 11)
            let dark = RibbonTheme.rgb(0x1E2C40)
            switch style {
            case .none:
                RibbonTheme.disabledTextColor.setStroke()
                let empty = NSBezierPath(rect: box)
                empty.setLineDash([2, 2], count: 2, phase: 0)
                empty.stroke()
            case .solid:
                if outline {
                    dark.setStroke()
                    let border = NSBezierPath(rect: box.insetBy(dx: 0.5, dy: 0.5))
                    border.lineWidth = 2
                    border.stroke()
                } else {
                    dark.setFill()
                    box.insetBy(dx: -0.5, dy: -0.5).fill()
                }
            default:
                // The brush texture itself, one point per texture pixel: a ring for Outline, the square for Fill.
                guard let texture = BrushKind(style: style) else { break }
                for y in 0..<12 {
                    for x in 0..<12 {
                        let ring = x < 2 || y < 2 || x > 9 || y > 9
                        guard !outline || ring else { continue }
                        let alpha = texture.grain(x: x * 3, y: y * 3) * texture.opacity
                        dark.withAlphaComponent(CGFloat(alpha)).setFill()
                        NSRect(x: 2 + CGFloat(x), y: 2 + CGFloat(y), width: 1, height: 1).fill()
                    }
                }
            }
            return true
        }
    }
}

extension GalleryShape {
    /// The gallery thumbnail as a 16-point image for menus.
    var menuImage: NSImage {
        NSImage(size: NSSize(width: 16, height: 16), flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            self.draw(IconPainter(context: context, enabled: true))
            return true
        }
    }
}
