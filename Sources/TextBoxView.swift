import AppKit

/// The text view laid over a text box on the canvas. It brings the caret, selection, input
/// methods (Japanese, Korean) and the usual editing keys; its bounds are the box in image
/// pixels, so it lays text out exactly as `TextLayout` draws it into the image.
final class TextBoxView: NSTextView {
    /// The app's pasteboard (`-PasteboardName` and the tests use their own).
    var pasteboardProvider: () -> NSPasteboard = { .general }
    /// Esc: the canvas fixes the box.
    var onEscape: (() -> Void)?

    init() {
        let storage = NSTextStorage()
        let manager = NSLayoutManager()
        storage.addLayoutManager(manager)
        let container = NSTextContainer(size: NSSize(width: 100, height: CGFloat.greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        container.widthTracksTextView = false
        container.heightTracksTextView = false
        manager.addTextContainer(container)
        super.init(frame: .zero, textContainer: container)
        textContainerInset = .zero
        isRichText = false
        importsGraphics = false
        allowsUndo = false
        usesFontPanel = false
        usesRuler = false
        usesFindBar = false
        drawsBackground = false
        isVerticallyResizable = false
        isHorizontallyResizable = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isContinuousSpellCheckingEnabled = false
        isGrammarCheckingEnabled = false
        smartInsertDeleteEnabled = false
        insertionPointColor = .black
        // Light like the rest of the canvas, whatever the Mac appearance.
        appearance = NSAppearance(named: .aqua)
        setAccessibilityIdentifier("canvas.text")
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private var pasteboard: NSPasteboard { pasteboardProvider() }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection([.control, .command, .option, .shift])
        // Esc fixes the box, unless an input method is composing (then it cancels the composition).
        if flags.isEmpty, event.keyCode == 53, !hasMarkedText() { onEscape?(); return }
        // Windows shortcuts (Ctrl+C, Ctrl+B…) before the Mac's Control text bindings.
        if flags.contains(.control), let window = window as? PaintWindow, window.performWindowsShortcut(event) { return }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) { onEscape?() }

    // MARK: Clipboard, on the app's pasteboard

    override func copy(_ sender: Any?) {
        let range = selectedRange()
        guard range.length > 0 else { return }
        pasteboard.clearContents()
        pasteboard.setString((string as NSString).substring(with: range), forType: .string)
    }

    override func cut(_ sender: Any?) {
        let range = selectedRange()
        guard range.length > 0 else { return }
        copy(sender)
        insertText("", replacementRange: range)
    }

    override func paste(_ sender: Any?) {
        guard let text = pasteboard.string(forType: .string) else { return }
        // Text from Windows may bring CR LF line ends.
        insertText(text.replacingOccurrences(of: "\r\n", with: "\n"), replacementRange: selectedRange())
    }

    override func pasteAsPlainText(_ sender: Any?) { paste(sender) }
    override func pasteAsRichText(_ sender: Any?) { paste(sender) }

    var canPaste: Bool { pasteboard.string(forType: .string) != nil }

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        switch item.action {
        case #selector(paste(_:)), #selector(pasteAsPlainText(_:)), #selector(pasteAsRichText(_:)): return canPaste
        case #selector(copy(_:)), #selector(cut(_:)): return selectedRange().length > 0
        default: return super.validateUserInterfaceItem(item)
        }
    }
}
