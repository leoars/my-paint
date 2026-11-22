import AppKit

/// Builds the Home and View tabs. Controls with an action are synced from `commandState`;
/// controls without one belong to later phases and stay disabled.
extension MainWindowController {
    func makeRibbon() -> RibbonView {
        var controls: [String: RibbonControl] = [:]

        func command<T: RibbonControl>(_ name: String, _ control: T, _ action: Selector?, tag: Int = 0) -> T {
            control.target = self
            control.action = action
            control.tag = tag
            control.isEnabled = action != nil
            control.setAccessibilityIdentifier(name)
            controls[name] = control
            return control
        }
        func large(_ name: String, _ key: String, _ icon: RibbonIcon, _ action: Selector?, dropdown: Bool = false) -> RibbonButton {
            command(name, RibbonButton(.large, title: L(key), icon: icon, dropdown: dropdown), action)
        }
        func small(_ name: String, _ key: String, _ icon: RibbonIcon, _ action: Selector?, dropdown: Bool = false) -> RibbonButton {
            command(name, RibbonButton(.small, title: L(key), icon: icon, dropdown: dropdown), action)
        }
        /// Places `views` left to right; each entry is one view or a column of views.
        func content(_ columns: [[NSView]], top: [CGFloat] = []) -> FlippedView {
            let view = FlippedView()
            var x: CGFloat = 0
            for (index, column) in columns.enumerated() {
                var y: CGFloat = index < top.count ? top[index] : 1
                let width = column.map(\.frame.width).max() ?? 0
                for item in column {
                    item.frame.origin = NSPoint(x: x, y: y)
                    if item is RibbonButton, column.count > 1 { item.frame.size.width = width }
                    view.addSubview(item)
                    y += item.frame.height
                }
                x += width + (index < columns.count - 1 ? 2 : 0)
            }
            view.frame.size = NSSize(width: x, height: RibbonTheme.groupContentHeight)
            return view
        }
        func group(_ key: String, _ icon: RibbonIcon, _ view: FlippedView) -> RibbonGroupView {
            let group = RibbonGroupView(title: L(key), icon: icon, content: view)
            group.keyTip = MainWindowController.keyTipTable[key]
            return group
        }

        // Home: Clipboard
        // Paste and Select are split buttons: the icon runs the command, the label opens the menu.
        let paste = large("home.paste", "ribbon.paste", .paste, #selector(paste(_:)), dropdown: true)
        paste.menuAction = #selector(showPasteMenu(_:))
        let clipboard = group("group.clipboard", .paste, content([
            [paste],
            [small("home.cut", "ribbon.cut", .cut, #selector(cut(_:))), small("home.copy", "ribbon.copy", .copy, #selector(copy(_:)))],
        ], top: [1, 2]))

        // Image
        let select = command("home.select", RibbonButton(.large, title: L("ribbon.select"), icon: .select, dropdown: true),
                             #selector(chooseTool(_:)), tag: ToolKind.select.rawValue)
        select.menuAction = #selector(showSelectMenu(_:))
        let rotate = small("home.rotate", "ribbon.rotate", .rotate, #selector(showRotateMenu(_:)), dropdown: true)
        rotate.actsOnPress = true
        let image = group("group.image", .select, content([
            [select],
            [small("home.crop", "ribbon.crop", .crop, #selector(cropImage(_:))),
             small("home.resize", "ribbon.resize", .resize, #selector(showResizeDialog(_:))), rotate],
        ], top: [1, 2]))

        // Tools: two rows of three, as in the original.
        func tool(_ kind: ToolKind?, _ key: String, _ icon: RibbonIcon) -> RibbonButton {
            let name = kind.map { "tool.\($0)" } ?? "tool.text"
            return command(name, RibbonButton(.icon, title: L(key), icon: icon),
                           kind == nil ? nil : #selector(chooseTool(_:)), tag: kind?.rawValue ?? 0)
        }
        let toolsTop: CGFloat = 12
        let tools = group("group.tools", .pencil, content([
            [tool(.pencil, "tool.pencil", .pencil), tool(.eraser, "tool.eraser", .eraser)],
            [tool(.fill, "tool.fill", .fill), tool(.colorPicker, "tool.colorPicker", .colorPicker)],
            [tool(.text, "tool.text", .text), tool(.magnifier, "tool.magnifier", .magnifier)],
        ], top: [toolsTop, toolsTop, toolsTop]))

        // Brushes: a split button like Select. The icon picks the current brush, the label opens the nine.
        let brushButton = command("home.brushes", RibbonButton(.large, title: L("ribbon.brushes"), icon: BrushKind.brush.icon, dropdown: true),
                                  #selector(chooseTool(_:)), tag: ToolKind.brush.rawValue)
        brushButton.menuAction = #selector(showBrushMenu(_:))
        let brushes = group("group.brushes", .brushes, content([[brushButton]]))

        // Shapes
        let gallery = command("home.shapes", ShapeGalleryView(title: L("group.shapes")), #selector(chooseShape(_:)))
        gallery.shapeNames = GalleryShape.allCases.map { L($0.nameKey) }
        gallery.scrollNames = ["gallery.up", "gallery.down", "gallery.more"].map(L)
        let outline = small("home.outline", "ribbon.outline", .outline, #selector(showOutlineMenu(_:)), dropdown: true)
        let shapeFill = small("home.shapeFill", "ribbon.shapeFill", .shapeFill, #selector(showShapeFillMenu(_:)), dropdown: true)
        [outline, shapeFill].forEach { $0.actsOnPress = true }
        let shapes = group("group.shapes", .shapes, content([[gallery], [outline, shapeFill]], top: [4, 2]))
        shapes.setShrinkingGallery(gallery, columns: Array((RibbonTheme.shapeGalleryMinColumns...RibbonTheme.shapeGalleryColumns).reversed()))

        // Size
        let sizeButton = large("home.size", "ribbon.size", .size, #selector(showSizeMenu(_:)), dropdown: true)
        sizeButton.actsOnPress = true
        let size = group("group.size", .size, content([[sizeButton]]))

        // Colors
        let color1 = command("home.color1", ColorWellButton(title: L("ribbon.color1"), swatchSide: 30),
                             #selector(chooseColorSlot(_:)), tag: ColorSlot.color1.rawValue)
        let color2 = command("home.color2", ColorWellButton(title: L("ribbon.color2"), swatchSide: 22),
                             #selector(chooseColorSlot(_:)), tag: ColorSlot.color2.rawValue)
        let palette = command("home.palette", PaletteView(title: L("group.colors"), colors: paletteColors),
                              #selector(choosePaletteColor(_:)))
        palette.colorNames = Palette.colors.map { L($0.nameKey) } + (1...10).map { String(format: L("color.custom"), $0) }
        let colors = group("group.colors", .colors, content([
            [color1], [color2], [palette], [large("home.editColors", "ribbon.editColors", .editColors, #selector(showEditColors(_:)))],
        ], top: [1, 1, 3, 1]))

        var home = RibbonPage(title: L("ribbon.home"), groups: [clipboard, image, tools, brushes, shapes, size, colors],
                              steps: MainWindowController.homeLayoutSteps)
        home.keyTip = MainWindowController.keyTipTable["ribbon.home"]

        // View: Zoom
        let zoom = group("group.zoom", .zoomIn, content([
            [large("view.zoomIn", "ribbon.zoomIn", .zoomIn, #selector(zoomIn(_:)))],
            [large("view.zoomOut", "ribbon.zoomOut", .zoomOut, #selector(zoomOut(_:)))],
            [large("view.zoomActual", "ribbon.zoomActual", .actualSize, #selector(zoomActual(_:)))],
        ]))

        // Show or hide
        let checkTop: CGFloat = 3
        let rulers = command("view.rulers", RibbonCheckbox(title: L("ribbon.rulers")), #selector(toggleRulers(_:)))
        let gridlines = command("view.gridlines", RibbonCheckbox(title: L("ribbon.gridlines")), #selector(toggleGridlines(_:)))
        let statusBarBox = command("view.statusBar", RibbonCheckbox(title: L("ribbon.statusBar")), #selector(toggleStatusBar(_:)))
        let showHide = group("group.showHide", .gridlines, content([[rulers, gridlines, statusBarBox]], top: [checkTop]))

        // Display; the interface text size sits with them (proposta, seção 9).
        let interfaceSize = large("view.interfaceSize", "ribbon.interfaceSize", .interfaceSize, #selector(showInterfaceSizeMenu(_:)),
                                  dropdown: true)
        interfaceSize.actsOnPress = true
        let display = group("group.display", .fullScreen, content([
            [large("view.fullScreen", "ribbon.fullScreen", .fullScreen, #selector(viewFullScreen(_:)))],
            [large("view.thumbnail", "ribbon.thumbnail", .thumbnail, #selector(toggleThumbnail(_:)))],
            [interfaceSize],
        ]))

        var view = RibbonPage(title: L("ribbon.view"), groups: [zoom, showHide, display], collapseOrder: [2, 1, 0])
        view.keyTip = MainWindowController.keyTipTable["ribbon.view"]

        // Text (contextual): Clipboard, Font, Background and Colors, while a text box is open.
        let textClipboard = group("group.clipboard", .paste, content([
            [large("text.paste", "ribbon.paste", .paste, #selector(paste(_:)))],
            [small("text.cut", "ribbon.cut", .cut, #selector(cut(_:))), small("text.copy", "ribbon.copy", .copy, #selector(copy(_:)))],
        ], top: [1, 2]))
        let fontFamily = command("text.fontFamily", RibbonComboBox(title: L("text.fontFamily"), width: RibbonTheme.fontFamilyWidth,
                                                                   items: TextFormat.families), #selector(chooseTextFontFamily(_:)))
        let fontSize = command("text.fontSize", RibbonComboBox(title: L("text.fontSize"), width: RibbonTheme.fontSizeWidth,
                                                               items: TextFormat.sizes.map(String.init)), #selector(chooseTextFontSize(_:)))
        [fontFamily, fontSize].forEach { $0.combo.setAccessibilityIdentifier($0.accessibilityIdentifier()) }
        fontFamily.drawsFontList = true
        let styles = [("text.bold", RibbonIcon.bold, #selector(toggleTextBold(_:))),
                      ("text.italic", .italic, #selector(toggleTextItalic(_:))),
                      ("text.underline", .underline, #selector(toggleTextUnderline(_:))),
                      ("text.strikethrough", .strikethrough, #selector(toggleTextStrikethrough(_:)))].map { name, icon, action in
            command(name, RibbonButton(.icon, title: L(name), icon: icon), action)
        }
        // The two boxes on top, the four styles under them, as in the original.
        let fontView = FlippedView()
        fontFamily.frame.origin = NSPoint(x: 0, y: 8)
        fontSize.frame.origin = NSPoint(x: fontFamily.frame.maxX + 3, y: 8)
        var styleX: CGFloat = 0
        for button in styles {
            button.frame.origin = NSPoint(x: styleX, y: fontFamily.frame.maxY + 8)
            styleX += button.frame.width + 1
        }
        ([fontFamily, fontSize] + styles).forEach(fontView.addSubview)
        fontView.frame.size = NSSize(width: fontSize.frame.maxX, height: RibbonTheme.groupContentHeight)
        let font = group("group.font", .text, fontView)
        let backgrounds = TextBackground.allCases.map { background in
            command("text.\(background == .opaque ? "opaque" : "transparent")",
                    RibbonButton(.small, title: L(background.nameKey), icon: background.icon), #selector(chooseTextBackground(_:)),
                    tag: background.rawValue)
        }
        let background = group("group.background", .textOpaque, content([backgrounds], top: [8]))
        let textColor1 = command("text.color1", ColorWellButton(title: L("ribbon.color1"), swatchSide: 30),
                                 #selector(chooseColorSlot(_:)), tag: ColorSlot.color1.rawValue)
        let textColor2 = command("text.color2", ColorWellButton(title: L("ribbon.color2"), swatchSide: 22),
                                 #selector(chooseColorSlot(_:)), tag: ColorSlot.color2.rawValue)
        let textPalette = command("text.palette", PaletteView(title: L("group.colors"), colors: paletteColors),
                                  #selector(choosePaletteColor(_:)))
        textPalette.colorNames = Palette.colors.map { L($0.nameKey) } + (1...10).map { String(format: L("color.custom"), $0) }
        let textColors = group("group.colors", .colors, content([
            [textColor1], [textColor2], [textPalette], [large("text.editColors", "ribbon.editColors", .editColors, #selector(showEditColors(_:)))],
        ], top: [1, 1, 3, 1]))
        var text = RibbonPage(title: L("ribbon.text"), groups: [textClipboard, font, background, textColors],
                              collapseOrder: [3, 2, 1, 0], contextualTitle: L("ribbon.textTools"))
        text.keyTip = MainWindowController.keyTipTable["ribbon.text"]

        // Print preview: its own tab, the only one while the preview shows.
        let previewPrint = group("group.print", .print, content([
            [large("preview.print", "ribbon.previewPrint", .print, #selector(printFromPreview(_:)))],
            [large("preview.pageSetup", "ribbon.previewPageSetup", .pageSetup, #selector(pageSetupFromPreview(_:)))],
        ]))
        let previewZoom = group("group.zoom", .zoomIn, content([
            [large("preview.zoomIn", "ribbon.zoomIn", .zoomIn, #selector(zoomPreviewIn(_:)))],
            [large("preview.zoomOut", "ribbon.zoomOut", .zoomOut, #selector(zoomPreviewOut(_:)))],
        ]))
        let previewPages = group("group.preview", .nextPage, content([
            [large("preview.next", "ribbon.nextPage", .nextPage, #selector(showNextPreviewPage(_:)))],
            [large("preview.previous", "ribbon.previousPage", .previousPage, #selector(showPreviousPreviewPage(_:)))],
        ]))
        let previewClose = group("group.closePreview", .closePreview, content([
            [large("preview.close", "ribbon.closePreview", .closePreview, #selector(closePrintPreview(_:)))],
        ]))
        var printPreview = RibbonPage(title: L("preview.title"), groups: [previewPrint, previewZoom, previewPages, previewClose],
                                      collapseOrder: [2, 1, 0])
        printPreview.keyTip = MainWindowController.keyTipTable["printPreview"]
        printPreview.isPrintPreview = true

        // Quick access strip.
        let quick = [
            command("qat.save", RibbonButton(.icon, title: L("qat.save"), icon: .save), #selector(saveDocument(_:))),
            command("qat.undo", RibbonButton(.icon, title: L("qat.undo"), icon: .undo), #selector(undoEdit(_:))),
            command("qat.redo", RibbonButton(.icon, title: L("qat.redo"), icon: .redo), #selector(redoEdit(_:))),
        ]

        let application = ApplicationButton(title: L("ribbon.application"))
        application.setAccessibilityIdentifier("application")
        controls["application"] = application
        for (name, control) in controls { control.keyTip = MainWindowController.keyTipTable[name] }

        let ribbon = RibbonView(quickAccess: quick, applicationButton: application, pages: [home, view, text, printPreview], controls: controls)
        application.handler = { [weak self] _ in self?.showApplicationMenu() }
        for page in ribbon.pages {
            for group in page.groups {
                group.collapsedButton.handler = { [weak ribbon, weak group] _ in
                    if let group = group { ribbon?.openCollapsed(group) }
                }
            }
        }
        return ribbon
    }

    /// Home groups collapse from the right (a conferir com o original).
    static let homeCollapseOrder = [6, 5, 4, 3, 2, 1, 0]
    /// Colors collapses first (it gives back the most room); then the Shapes gallery loses
    /// columns, down to its narrowest, before the other groups collapse from the right, Shapes
    /// among them. Steps are not undone, as in the Windows ribbon (a conferir com o original).
    static let homeLayoutSteps: [RibbonLayout.Step] = [.collapse(6), .shrink(4)] + homeCollapseOrder.dropFirst().map(RibbonLayout.Step.collapse)

    /// The 20 standard colors followed by the 10 custom places, empty until Edit colors fills them.
    /// In black-and-white mode only black and white remain, in their places.
    var paletteColors: [RGB?] {
        guard !document.blackAndWhite else { return (0..<(Palette.colors.count + customColors.count)).map(paletteColor(at:)) }
        return Palette.colors.map { Optional($0.color) } + customColors
    }

    /// Brings every ribbon control in line with the current state.
    func syncRibbon() {
        for control in ribbon.controls.values {
            guard let action = control.action else { continue }
            let state = commandState(action, tag: control.tag)
            if let split = control as? RibbonButton, split.menuAction != nil {
                // The menu part stays usable when the command itself is not (Paste with an empty clipboard).
                control.isEnabled = true
                split.isMainEnabled = state.enabled
            } else {
                control.isEnabled = state.enabled
            }
            if let checked = state.checked, !(control is PaletteView), !(control is ShapeGalleryView) { control.isChecked = checked }
        }
        let toolbox = canvas.toolbox
        if let brushes = ribbon.control("home.brushes") as? RibbonButton, brushes.icon != toolbox.brushTool.kind.icon {
            brushes.icon = toolbox.brushTool.kind.icon
            brushes.needsDisplay = true
        }
        (ribbon.control("home.shapes") as? ShapeGalleryView)?.selected = toolbox.kind == .shape ? toolbox.shapeTool.kind : nil
        let colors = paletteColors
        for name in ["home.palette", "text.palette"] {
            guard let palette = ribbon.control(name) as? PaletteView else { continue }
            if palette.colors != colors { palette.colors = colors }
            if palette.showsEmptyPlaces == document.blackAndWhite { palette.showsEmptyPlaces = !document.blackAndWhite }
        }
        (ribbon.control("home.color1") as? ColorWellButton)?.color = document.color1
        (ribbon.control("home.color2") as? ColorWellButton)?.color = document.color2
        syncTextControls()
    }
}
