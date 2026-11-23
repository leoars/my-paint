import AppKit

/// The About window of the suite: name, version, what the application is, who makes it, the
/// licence, where the code lives and the other applications of the My suite. Same model as
/// My Notepad's.
private final class AboutPanel: NSPanel {
    override func close() {
        if NSApp.modalWindow === self { NSApp.stopModal() }
        super.close()
    }

    @objc func dismissPanel() { close() }

    /// A web address opens in the browser; anything else is a file of the bundle (the licence,
    /// the notices) and opens in TextEdit.
    @objc func openLink(_ sender: NSButton) {
        guard let destination = sender.identifier?.rawValue else { return }
        if destination.hasPrefix("https://"), let url = URL(string: destination) {
            NSWorkspace.shared.open(url)
        } else if let url = Bundle.main.resourceURL?.appendingPathComponent(destination),
                  let viewer = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.TextEdit") {
            NSWorkspace.shared.open([url], withApplicationAt: viewer, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
        }
    }
}

extension MainWindowController {
    @objc func showAboutPanel(_ sender: Any?) {
        let panel = AboutPanel(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = L("menu.about")
        panel.isReleasedWhenClosed = false
        func text(_ value: String, size: CGFloat = 13, weight: NSFont.Weight = .regular) -> NSTextField {
            let label = NSTextField(wrappingLabelWithString: value)
            label.font = .systemFont(ofSize: size, weight: weight)
            return label
        }
        func link(_ title: String, _ destination: String) -> NSButton {
            let button = NSButton(title: title, target: panel, action: #selector(AboutPanel.openLink(_:)))
            button.bezelStyle = .inline
            button.isBordered = false
            button.contentTintColor = .linkColor
            button.identifier = .init(destination)
            button.setAccessibilityRole(.link)
            return button
        }
        func column(_ views: [NSView], spacing: CGFloat) -> NSStackView {
            let stack = NSStackView(views: views)
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = spacing
            return stack
        }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let versionLabel = text(String(format: L("about.version"), version))
        versionLabel.textColor = .secondaryLabelColor
        let summary = text(L("about.description"))
        summary.preferredMaxLayoutWidth = 355
        summary.widthAnchor.constraint(equalToConstant: 355).isActive = true
        let author = text(L("about.author"), size: 14, weight: .semibold)
        let github = "https://github.com/leoars"
        let linkedin = "https://www.linkedin.com/in/leonardoars/"
        let details = column([text("My Paint", size: 25, weight: .semibold), versionLabel,
                              summary, author, link(github, github), link(linkedin, linkedin)], spacing: 4)
        details.setCustomSpacing(14, after: versionLabel)
        details.setCustomSpacing(14, after: summary)
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        NSLayoutConstraint.activate([icon.widthAnchor.constraint(equalToConstant: 80),
                                     icon.heightAnchor.constraint(equalToConstant: 80)])
        let header = NSStackView(views: [icon, details])
        header.alignment = .top
        header.spacing = 20
        let suite = NSStackView(views: [text(L("about.suite")), link("My Explorer", github + "/my-explorer"), text("·"),
                                        link("My Notepad", github + "/My-Notepad")])
        let legalLinks = NSStackView(views: [link(L("about.license"), "LICENSE"), text("·"),
                                             link(L("about.notices"), "THIRD_PARTY_NOTICES.md")])
        let repo = github + "/my-paint"
        let close = NSButton(title: L("about.close"), target: panel, action: #selector(AboutPanel.dismissPanel))
        close.keyEquivalent = "\r"
        let footer = NSStackView(views: [link(L("about.repository"), repo), text("·"),
                                         link(L("about.issues"), repo + "/issues"), NSView(), close])
        let rule = NSBox()
        rule.boxType = .separator
        let content = column([header, rule, suite, text("© 2026 Leonardo Santos  ·  Apache License 2.0"),
                              legalLinks, footer], spacing: 6)
        content.setCustomSpacing(18, after: header)
        content.setCustomSpacing(14, after: rule)
        content.setCustomSpacing(12, after: suite)
        content.setCustomSpacing(16, after: legalLinks)
        footer.widthAnchor.constraint(equalTo: header.widthAnchor).isActive = true
        rule.widthAnchor.constraint(equalTo: header.widthAnchor).isActive = true
        // The margins are constraints of a container, not insets of the stack: with insets the
        // fitting size came out narrower than the rows, and the Close button, the only thing
        // aligned to the right, ended up against the edge of the window.
        let container = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 22),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -22),
            content.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -18),
            footer.trailingAnchor.constraint(equalTo: header.trailingAnchor),
        ])
        panel.contentView = container
        panel.setContentSize(container.fittingSize)
        panel.isFloatingPanel = false
        _ = runDialog(panel)
    }
}
