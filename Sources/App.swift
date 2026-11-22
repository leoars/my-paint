import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: MainWindowController!
    private var closingConfirmed = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The Dock shows the free-form icon itself, without the grey plate macOS adds to it.
        if let url = Bundle.main.url(forResource: "MyPaint", withExtension: "icns"), let icon = NSImage(contentsOf: url) {
            let view = NSImageView(image: icon)
            view.imageScaling = .scaleProportionallyUpOrDown
            NSApp.dockTile.contentView = view
            NSApp.dockTile.display()
        }
        controller = MainWindowController()
        NSApp.mainMenu = makeMainMenu()
        // Image, Tools, Shapes, Text and Colors mirror the ribbon groups in the menu bar, with the same commands.
        if let main = NSApp.mainMenu {
            for menu in [controller.makeImageMenu(), controller.makeToolsMenu(), controller.makeShapesMenu(), controller.makeTextMenu(), controller.makeColorsMenu()] { add(menu, titled: menu.title, to: main) }
        }
        if let url = pendingURL { pendingURL = nil; controller.open(url) }
        controller.window.makeKeyAndOrderFront(nil)
        controller.syncThumbnailPanel()
        NSApp.activate(ignoringOtherApps: true)
    }

    private var pendingURL: URL?

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        if controller == nil { pendingURL = url } else { controller.open(url) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // The window already asked about unsaved changes before closing.
        closingConfirmed = true
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if closingConfirmed { return .terminateNow }
        return controller.confirmDiscardingChanges() ? .terminateNow : .terminateCancel
    }

    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let app = NSMenu()
        app.addItem(withTitle: L("menu.about"), action: #selector(MainWindowController.showAboutPanel(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: L("menu.settings"), action: #selector(MainWindowController.openAppSettings(_:)), keyEquivalent: ",")
        app.addItem(.separator())
        app.addItem(withTitle: L("menu.hide"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let others = app.addItem(withTitle: L("menu.hideOthers"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        others.keyEquivalentModifierMask = [.command, .option]
        app.addItem(withTitle: L("menu.showAll"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: L("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        add(app, titled: "My Paint", to: main)

        add(controller.makeFileMenu(), titled: L("menu.file"), to: main)

        let edit = NSMenu(title: L("menu.edit"))
        edit.addItem(withTitle: L("menu.undo"), action: #selector(MainWindowController.undoEdit(_:)), keyEquivalent: "z")
        edit.addItem(withTitle: L("menu.redo"), action: #selector(MainWindowController.redoEdit(_:)), keyEquivalent: "Z")
        edit.addItem(.separator())
        // Standard selectors, so text fields of panels and dialogs keep their own Cut, Copy and Paste.
        edit.addItem(withTitle: L("menu.cut"), action: #selector(MainWindowController.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: L("menu.copy"), action: #selector(MainWindowController.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: L("menu.paste"), action: #selector(MainWindowController.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: L("menu.pasteFrom"), action: #selector(MainWindowController.pasteFromFile(_:)), keyEquivalent: "")
        // No key equivalent: the canvas takes the Delete keys itself, and a menu Delete would reach text fields too.
        edit.addItem(withTitle: L("menu.delete"), action: #selector(MainWindowController.delete(_:)), keyEquivalent: "")
        edit.addItem(.separator())
        edit.addItem(withTitle: L("menu.selectAll"), action: #selector(MainWindowController.selectAll(_:)), keyEquivalent: "a")
        edit.addItem(withTitle: L("menu.invertSelection"), action: #selector(MainWindowController.invertSelection(_:)), keyEquivalent: "")
        add(edit, titled: edit.title, to: main)

        add(controller.makeViewMenu(), titled: L("menu.view"), to: main)

        return main
    }

    private func add(_ menu: NSMenu, titled title: String, to main: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = menu
        main.addItem(item)
    }
}
