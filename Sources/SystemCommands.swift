import AppKit

/// My Paint ▸ Settings…: the interface text size, the same choice as in the View tab.
final class SettingsWindow: NSObject {
    let window: NSWindow
    let sizePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let updatesButton = NSButton(checkboxWithTitle: L("updates.automatic"), target: nil, action: nil)
    var updates: UpdatePreferences { UpdatePreferences(defaults: AppSettings.defaults) }
    let checkNowButton = NSButton(title: L("updates.check_now"), target: nil, action: nil)
    let updateStatus = NSTextField(wrappingLabelWithString: L("updates.status.idle"))
    /// The app's updater, for Check now and the status line; none in the tests.
    var updater: PackageUpdater? { (NSApp.delegate as? AppDelegate)?.updater }
    private weak var controller: MainWindowController?

    init(controller: MainWindowController) {
        self.controller = controller
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 92), styleMask: [.titled, .closable],
                          backing: .buffered, defer: false)
        super.init()
        window.title = L("settings.title")
        window.isReleasedWhenClosed = false
        let content = FlippedView(frame: NSRect(x: 0, y: 0, width: 380, height: 92))
        let label = NSTextField(labelWithString: L("settings.interfaceSize"))
        label.sizeToFit()
        label.frame.origin = NSPoint(x: 20, y: 24)
        sizePopup.addItems(withTitles: InterfaceSize.allCases.map { L($0.nameKey) })
        for (item, size) in zip(sizePopup.itemArray, InterfaceSize.allCases) { item.tag = size.rawValue }
        sizePopup.sizeToFit()
        sizePopup.frame.origin = NSPoint(x: label.frame.maxX + 8, y: 19)
        sizePopup.target = controller
        sizePopup.action = #selector(MainWindowController.chooseInterfaceSize(_:))
        let note = NSTextField(wrappingLabelWithString: L("settings.interfaceSizeNote"))
        note.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        note.textColor = .secondaryLabelColor
        // As many lines as the note takes in the current language.
        let noteHeight = max(32, ceil(note.cell!.cellSize(forBounds: NSRect(x: 0, y: 0, width: 340, height: 1000)).height))
        note.frame = NSRect(x: 20, y: 52, width: 340, height: noteHeight)
        [label, sizePopup, note].forEach(content.addSubview)
        var width = max(380, sizePopup.frame.maxX + 20)
        var height = note.frame.maxY + 8
        // Only a copy installed from GitHub updates itself.
        if PackageUpdater.isAvailable {
            let heading = NSTextField(labelWithString: L("updates.heading"))
            heading.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
            heading.sizeToFit()
            heading.frame.origin = NSPoint(x: 20, y: height + 10)
            updatesButton.target = self
            updatesButton.action = #selector(toggleUpdates(_:))
            updatesButton.sizeToFit()
            updatesButton.frame.origin = NSPoint(x: 20, y: heading.frame.maxY + 8)
            // The option and Check now side by side, the status below, as in My Explorer's Options.
            checkNowButton.bezelStyle = .rounded
            checkNowButton.target = self
            checkNowButton.action = #selector(checkNow(_:))
            checkNowButton.sizeToFit()
            checkNowButton.frame.origin = NSPoint(x: updatesButton.frame.maxX + 12,
                                                  y: updatesButton.frame.midY - checkNowButton.frame.height / 2)
            updateStatus.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            updateStatus.textColor = .secondaryLabelColor
            // Room for two lines: the longest states take them in some languages.
            let lineHeight = ceil(updateStatus.font!.boundingRectForFont.height)
            updateStatus.frame = NSRect(x: 20, y: max(updatesButton.frame.maxY, checkNowButton.frame.maxY) + 6,
                                        width: 340, height: 2 * lineHeight + 2)
            [heading, updatesButton, checkNowButton, updateStatus].forEach(content.addSubview)
            width = max(width, checkNowButton.frame.maxX + 20)
            updateStatus.frame.size.width = width - 40
            height = updateStatus.frame.maxY + 14
        }
        content.frame.size = NSSize(width: width, height: height)
        window.setContentSize(NSSize(width: width, height: height))
        window.contentView = content
        sync()
    }

    func sync() {
        sizePopup.selectItem(withTag: controller?.interfaceSize.rawValue ?? InterfaceSize.normal.rawValue)
        updatesButton.state = updates.automatic ? .on : .off
        updateStatus.stringValue = L(updater?.status ?? "updates.status.idle")
        checkNowButton.isEnabled = updater?.canCheckNow ?? false
    }

    @objc func checkNow(_ sender: NSButton) { updater?.checkNow() }

    @objc func toggleUpdates(_ sender: NSButton) { updates.automatic = sender.state == .on }
}

/// Print, desktop background, properties, recent pictures, settings, and the File and View menus.
extension MainWindowController {
    @objc func openAppSettings(_ sender: Any?) {
        let settings = settingsWindow ?? SettingsWindow(controller: self)
        settingsWindow = settings
        settings.sync()
        if !settings.window.isVisible { centerDialog(settings.window) }
        settings.window.makeKeyAndOrderFront(nil)
    }

    /// State of the commands of this phase, or nil for the others.
    func systemCommandState(_ action: Selector, tag: Int) -> (enabled: Bool, checked: Bool?)? {
        switch action {
        case #selector(toggleRulers(_:)): return (true, showsRulers)
        case #selector(toggleGridlines(_:)): return (true, showsGridlines)
        case #selector(toggleThumbnail(_:)): return (true, showsThumbnail)
        case #selector(viewFullScreen(_:)): return (true, nil)
        case #selector(chooseInterfaceSize(_:)): return (true, interfaceSize.rawValue == tag)
        case #selector(showInterfaceSizeMenu(_:)), #selector(openAppSettings(_:)), #selector(toggleKeyTips(_:)): return (true, nil)
        case #selector(toggleRibbonMinimized(_:)): return (!isShowingPrintPreview, isRibbonMinimized)
        case #selector(openRecentPicture(_:)): return (recentPictures.urls.indices.contains(tag), nil)
        case #selector(clearRecentPictures(_:)): return (recentPictures.canClear, nil)
        case #selector(printImage(_:)), #selector(showPageSetup(_:)), #selector(showPrintPreview(_:)),
             #selector(setDesktopBackground(_:)), #selector(showImageProperties(_:)), #selector(showEditColors(_:)):
            return (true, nil)
        default: return nil
        }
    }

    static let recentMenuTitle = "recent"

    /// File menu of the menu bar, with the commands of the application menu.
    func makeFileMenu() -> NSMenu {
        let file = NSMenu(title: L("menu.file"))
        file.addItem(withTitle: L("menu.new"), action: #selector(newDocument(_:)), keyEquivalent: "n")
        file.addItem(withTitle: L("menu.open"), action: #selector(openDocument(_:)), keyEquivalent: "o")
        let recent = file.addItem(withTitle: L("menu.openRecent"), action: nil, keyEquivalent: "")
        let recentMenu = NSMenu(title: MainWindowController.recentMenuTitle)
        recentMenu.delegate = self
        recentMenuItems().forEach(recentMenu.addItem)
        recent.submenu = recentMenu
        file.addItem(.separator())
        file.addItem(withTitle: L("menu.save"), action: #selector(saveDocument(_:)), keyEquivalent: "s")
        file.addItem(withTitle: L("menu.saveAs"), action: #selector(saveDocumentAs(_:)), keyEquivalent: "S")
        file.addItem(.separator())
        file.addItem(withTitle: L("menu.print"), action: #selector(printImage(_:)), keyEquivalent: "p")
        file.addItem(withTitle: L("menu.pageSetup"), action: #selector(showPageSetup(_:)), keyEquivalent: "P")
        file.addItem(withTitle: L("menu.printPreview"), action: #selector(showPrintPreview(_:)), keyEquivalent: "")
        file.addItem(.separator())
        let wallpaper = file.addItem(withTitle: L("menu.wallpaper"), action: nil, keyEquivalent: "")
        wallpaper.submenu = NSMenu(title: L("menu.wallpaper"))
        wallpaperMenuItems().forEach(wallpaper.submenu!.addItem)
        file.addItem(withTitle: L("menu.properties"), action: #selector(showImageProperties(_:)), keyEquivalent: "e")
        for item in file.items where item.action != nil { item.target = self }
        return file
    }

    /// View menu of the menu bar, mirroring the View tab.
    func makeViewMenu() -> NSMenu {
        let view = NSMenu(title: L("menu.view"))
        view.addItem(withTitle: L("menu.zoomIn"), action: #selector(zoomIn(_:)), keyEquivalent: "+")
        view.addItem(withTitle: L("menu.zoomOut"), action: #selector(zoomOut(_:)), keyEquivalent: "-")
        view.addItem(withTitle: L("menu.zoomActual"), action: #selector(zoomActual(_:)), keyEquivalent: "0")
        view.addItem(.separator())
        view.addItem(withTitle: L("menu.rulers"), action: #selector(toggleRulers(_:)), keyEquivalent: "r")
        view.addItem(withTitle: L("menu.gridlines"), action: #selector(toggleGridlines(_:)), keyEquivalent: "g")
        view.addItem(withTitle: L("menu.statusBar"), action: #selector(toggleStatusBar(_:)), keyEquivalent: "")
        view.addItem(.separator())
        let full = view.addItem(withTitle: L("menu.fullScreen"), action: #selector(viewFullScreen(_:)),
                                keyEquivalent: String(UnicodeScalar(NSF11FunctionKey)!))
        full.keyEquivalentModifierMask = []
        view.addItem(withTitle: L("menu.thumbnail"), action: #selector(toggleThumbnail(_:)), keyEquivalent: "")
        let minimize = view.addItem(withTitle: L("menu.minimizeRibbon"), action: #selector(toggleRibbonMinimized(_:)),
                                    keyEquivalent: String(UnicodeScalar(NSF1FunctionKey)!))
        minimize.keyEquivalentModifierMask = .command
        view.addItem(.separator())
        let size = view.addItem(withTitle: L("menu.interfaceSize"), action: nil, keyEquivalent: "")
        size.submenu = NSMenu(title: L("menu.interfaceSize"))
        interfaceSizeMenuItems().forEach(size.submenu!.addItem)
        for item in view.items where item.action != nil { item.target = self }
        return view
    }
}
