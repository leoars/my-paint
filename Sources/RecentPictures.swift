import AppKit

/// The recent pictures, kept in the app's own settings rather than in `NSDocumentController`,
/// whose list size follows a system setting. Pinned pictures come first, in the order they were
/// pinned, and stay when new ones arrive; the others follow, most recent first.
final class RecentPictures {
    /// As many as the application menu shows (a conferir com o original).
    static let limit = 9

    private(set) var urls: [URL]
    /// The pinned pictures, standardized; always the first `pinnedCount` of `urls`.
    private(set) var pinned: [URL]

    init() {
        let paths = AppSettings.defaults.stringArray(forKey: AppSettings.recentKey) ?? []
        let stored = paths.map { URL(fileURLWithPath: $0).standardizedFileURL }
        let pins = (AppSettings.defaults.stringArray(forKey: AppSettings.recentPinnedKey) ?? [])
            .map { URL(fileURLWithPath: $0).standardizedFileURL }
        var unique: [URL] = []
        for url in stored where !unique.contains(url) { unique.append(url) }
        pinned = Array(pins.filter(unique.contains).prefix(RecentPictures.limit))
        urls = pinned + Array(unique.filter { !pins.contains($0) }.prefix(RecentPictures.limit - pinned.count))
    }

    var pinnedCount: Int { pinned.count }

    func isPinned(_ url: URL) -> Bool { pinned.contains(url.standardizedFileURL) }

    /// Puts `url` first among the pictures that are not pinned, once; a pinned picture keeps its
    /// place. When the list is full the oldest picture that is not pinned leaves; when all nine
    /// are pinned, the new picture is not listed.
    func add(_ url: URL) {
        let file = url.standardizedFileURL
        guard !pinned.contains(file) else { return }
        urls.removeAll { $0 == file }
        guard pinned.count < RecentPictures.limit else { return save() }
        urls.insert(file, at: pinned.count)
        if urls.count > RecentPictures.limit { urls.removeLast(urls.count - RecentPictures.limit) }
        save()
    }

    /// Pins or unpins a listed picture. A new pin goes last among the pinned ones; an unpinned
    /// picture goes first among the others.
    func setPinned(_ url: URL, _ pin: Bool) {
        let file = url.standardizedFileURL
        guard urls.contains(file), pin != pinned.contains(file) else { return }
        urls.removeAll { $0 == file }
        if pin {
            pinned.append(file)
            urls.insert(file, at: pinned.count - 1)
        } else {
            pinned.removeAll { $0 == file }
            urls.insert(file, at: pinned.count)
        }
        save()
    }

    func togglePin(_ url: URL) { setPinned(url, !isPinned(url)) }

    /// Takes a picture off the list (and off the pins): one that can no longer be read.
    func remove(_ url: URL) {
        let file = url.standardizedFileURL
        urls.removeAll { $0.standardizedFileURL == file }
        pinned.removeAll { $0 == file }
        save()
    }

    /// Clear Menu: the pictures that are not pinned leave; the pinned ones stay.
    func clear() {
        urls = pinned
        save()
    }

    /// Whether Clear Menu has anything to take away.
    var canClear: Bool { urls.count > pinned.count }

    private func save() {
        AppSettings.defaults.set(urls.map(\.path), forKey: AppSettings.recentKey)
        AppSettings.defaults.set(pinned.map(\.path), forKey: AppSettings.recentPinnedKey)
    }
}

extension MainWindowController {
    func noteRecent(_ url: URL) {
        recentPictures.add(url)
        // The Dock menu and Finder's recent items still hear about it.
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }

    /// Opens the recent picture at the sender's tag, after asking about unsaved changes.
    @objc func openRecentPicture(_ sender: Any?) {
        let urls = recentPictures.urls
        let index = senderTag(sender)
        guard urls.indices.contains(index) else { return }
        open(urls[index])
    }

    @objc func clearRecentPictures(_ sender: Any?) { recentPictures.clear() }

    /// The pin of the recent picture at `index` in the application menu.
    func toggleRecentPin(at index: Int) {
        let urls = recentPictures.urls
        guard urls.indices.contains(index) else { return }
        recentPictures.togglePin(urls[index])
    }

    /// "1 name.png", as the application menu numbers them.
    static func recentTitle(_ url: URL, index: Int) -> String { "\(index + 1)  \(url.lastPathComponent)" }

    /// The items of File > Open Recent, rebuilt each time it opens.
    func recentMenuItems() -> [NSMenuItem] {
        var items = recentPictures.urls.enumerated().map { index, url -> NSMenuItem in
            let item = NSMenuItem(title: url.lastPathComponent, action: #selector(openRecentPicture(_:)), keyEquivalent: "")
            item.tag = index
            item.target = self
            item.toolTip = url.path
            return item
        }
        if !items.isEmpty { items.append(.separator()) }
        let clear = NSMenuItem(title: L("menu.clearRecent"), action: #selector(clearRecentPictures(_:)), keyEquivalent: "")
        clear.target = self
        items.append(clear)
        return items
    }
}
