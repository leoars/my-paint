import AppKit

/// Width of a row of push buttons (OK, Cancel…): at least `minimum`, and wide enough for the
/// longest title, measured, so every language fits.
func dialogButtonWidth(_ buttons: [NSButton], minimum: CGFloat = 82) -> CGFloat {
    let widest = buttons.map { ($0.title as NSString).size(withAttributes: [.font: $0.font ?? NSFont.systemFont(ofSize: 13)]).width }.max() ?? 0
    return max(minimum, ceil(widest) + 24)
}

/// Dialogs open centred on the main window, not on the screen, as in the other My apps.
extension MainWindowController {
    func centerDialog(_ dialog: NSWindow) {
        guard window !== dialog else { return }
        let frame = window.frame
        let size = dialog.frame.size
        var origin = NSPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2)
        if let visible = window.screen?.visibleFrame {
            origin.x = max(visible.minX, min(origin.x, visible.maxX - size.width))
            origin.y = max(visible.minY, min(origin.y, visible.maxY - size.height))
        }
        if dialog.frame.origin != origin { dialog.setFrameOrigin(origin) }
    }

    /// AppKit creates some panels lazily and picks a screen location while presenting,
    /// so the dialog is re-centred whenever it becomes key or changes size during `present`.
    func presentingDialog<Result>(_ expected: NSWindow? = nil, _ present: () -> Result) -> Result {
        let notifications = NotificationCenter.default
        let observers = [NSWindow.didBecomeKeyNotification, NSWindow.didResizeNotification].map { name in
            notifications.addObserver(forName: name, object: expected, queue: nil) { [weak self] note in
                guard let self = self, let dialog = note.object as? NSWindow,
                      dialog !== self.window, expected != nil || dialog.isKeyWindow,
                      dialog.sheetParent == nil else { return }
                self.centerDialog(dialog)
            }
        }
        defer { observers.forEach(notifications.removeObserver) }
        // A modal run centres the window on the screen as it shows it, and while the app is in
        // the background the dialog never becomes key to be centred again, so it is centred once
        // more from inside the modal loop.
        if let expected = expected, expected.sheetParent == nil {
            RunLoop.main.perform(inModes: [.modalPanel]) { [weak self, weak expected] in
                if let dialog = expected, dialog.sheetParent == nil { self?.centerDialog(dialog) }
            }
        }
        return present()
    }

    func runAlert(_ alert: NSAlert) -> NSApplication.ModalResponse {
        presentingDialog(alert.window) { alert.runModal() }
    }

    func runPanel(_ panel: NSSavePanel) -> NSApplication.ModalResponse {
        presentingDialog(panel) { panel.runModal() }
    }

    /// Runs one of the app's own dialogs modally, centred on the main window.
    func runDialog(_ dialog: NSWindow) -> NSApplication.ModalResponse {
        presentingDialog(dialog) {
            centerDialog(dialog)
            let response = NSApp.runModal(for: dialog)
            dialog.orderOut(nil)
            return response
        }
    }
}
