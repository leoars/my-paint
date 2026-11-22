import AppKit

/// Set as desktop background ▸ Fill, Tile, Center.
enum WallpaperStyle: Int, CaseIterable {
    case fill, tile, center

    var nameKey: String {
        switch self {
        case .fill: return "wallpaper.fill"
        case .tile: return "wallpaper.tile"
        case .center: return "wallpaper.center"
        }
    }
}

/// Puts a picture file on the desktop. Behind a protocol so the tests never touch the real desktop.
protocol DesktopPictureSetting {
    func setDesktopPicture(_ url: URL, style: WallpaperStyle) throws
}

/// The real desktop, on every screen. Tile arrives already tiled to the screen size, since the
/// Mac has no tiling of its own.
struct SystemDesktopPicture: DesktopPictureSetting {
    static func options(for style: WallpaperStyle) -> [NSWorkspace.DesktopImageOptionKey: Any] {
        switch style {
        case .fill:
            return [.imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue, .allowClipping: true]
        case .tile:
            return [.imageScaling: NSImageScaling.scaleAxesIndependently.rawValue, .allowClipping: true]
        case .center:
            return [.imageScaling: NSImageScaling.scaleNone.rawValue, .allowClipping: false]
        }
    }

    func setDesktopPicture(_ url: URL, style: WallpaperStyle) throws {
        for screen in NSScreen.screens {
            try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: SystemDesktopPicture.options(for: style))
        }
    }
}

extension MainWindowController {
    /// ~/Library/Application Support/My Paint
    static var defaultWallpaperFolder: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return support.appendingPathComponent("My Paint", isDirectory: true)
    }

    static let wallpaperPrefix = "Desktop background"

    /// Size in pixels of the screen the window is on, for Tile.
    var screenPixelSize: (width: Int, height: Int) {
        let screen = window.screen ?? NSScreen.main
        let size = screen?.frame.size ?? NSSize(width: 1440, height: 900)
        let scale = screen?.backingScaleFactor ?? 1
        return (Int(size.width * scale), Int(size.height * scale))
    }

    /// The picture as it goes to the desktop: as it is, or tiled over a screen for Tile.
    static func wallpaperBitmap(_ bitmap: Bitmap, style: WallpaperStyle, screen: (width: Int, height: Int)) -> Bitmap {
        guard style == .tile else { return bitmap }
        let width = max(1, screen.width), height = max(1, screen.height)
        var tiled = Bitmap(width: width, height: height)
        tiled.withPixels { pixels in
            for y in 0..<height {
                for x in 0..<width { pixels[y * width + x] = bitmap[x % bitmap.width, y % bitmap.height] }
            }
        }
        return tiled
    }

    /// Writes the picture to the app's folder (a new name each time, so the desktop takes the
    /// change) and puts it on the desktop. Returns the file written.
    @discardableResult
    func setWallpaper(_ style: WallpaperStyle) throws -> URL {
        canvas.finishEditing()
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: wallpaperFolder, withIntermediateDirectories: true)
        let old = (try? fileManager.contentsOfDirectory(at: wallpaperFolder, includingPropertiesForKeys: nil)) ?? []
        let url = wallpaperFolder.appendingPathComponent("\(MainWindowController.wallpaperPrefix) \(UUID().uuidString.prefix(8)).png")
        let picture = MainWindowController.wallpaperBitmap(document.bitmap, style: style, screen: screenPixelSize)
        try ImageFile.write(picture, to: url, format: .png)
        try desktopPicture.setDesktopPicture(url, style: style)
        for file in old where file.lastPathComponent.hasPrefix(MainWindowController.wallpaperPrefix) {
            try? fileManager.removeItem(at: file)
        }
        return url
    }

    /// Set as desktop background ▸ Fill, Tile or Center (the tag).
    @objc func setDesktopBackground(_ sender: Any?) {
        let style = WallpaperStyle(rawValue: senderTag(sender)) ?? .fill
        do {
            try setWallpaper(style)
        } catch {
            _ = runAlert(NSAlert(error: error))
        }
    }

    func wallpaperMenuItems() -> [NSMenuItem] {
        WallpaperStyle.allCases.map { style in
            let item = NSMenuItem(title: L(style.nameKey), action: #selector(setDesktopBackground(_:)), keyEquivalent: "")
            item.tag = style.rawValue
            item.target = self
            return item
        }
    }
}
