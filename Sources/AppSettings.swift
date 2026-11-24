import AppKit

/// What the app keeps between launches. The tests point `defaults` at a suite of their own.
enum AppSettings {
    static var defaults = UserDefaults.standard

    static let rulersKey = "ShowRulers"
    static let gridlinesKey = "ShowGridlines"
    static let thumbnailKey = "ShowThumbnail"
    static let interfaceSizeKey = "InterfaceSize"
    static let customColorsKey = "CustomColors"
    static let nextCustomColorKey = "NextCustomColor"
    static let dialogColorsKey = "EditColorsCustomColors"
    static let recentKey = "RecentPictures"
    static let ribbonMinimizedKey = "MinimizeRibbon"
    static let recentPinnedKey = "RecentPicturesPinned"
    static let recentBookmarksKey = "RecentPicturesBookmarks"

    static func bool(_ key: String, default value: Bool) -> Bool {
        defaults.object(forKey: key) == nil ? value : defaults.bool(forKey: key)
    }

    /// Colors stored as "RRGGBB" strings, an empty string for an empty place.
    static func colors(_ key: String, count: Int) -> [RGB?] {
        let stored = defaults.stringArray(forKey: key) ?? []
        return (0..<count).map { index in
            guard stored.indices.contains(index), let value = UInt32(stored[index], radix: 16) else { return nil }
            return RGB(r: UInt8(value >> 16 & 0xFF), g: UInt8(value >> 8 & 0xFF), b: UInt8(value & 0xFF))
        }
    }

    static func setColors(_ colors: [RGB?], forKey key: String) {
        defaults.set(colors.map { $0.map { String(format: "%02X%02X%02X", $0.r, $0.g, $0.b) } ?? "" }, forKey: key)
    }
}

/// View > Interface text size: one factor for every measure, font and icon of the ribbon,
/// the application menu, the status bar, the rulers and the app's own dialogs.
enum InterfaceSize: Int, CaseIterable {
    case small, normal, large, extraLarge

    /// A conferir: the levels are ours, the Mac has no per-app DPI setting to copy.
    var factor: CGFloat {
        switch self {
        case .small: return 0.9
        case .normal: return 1
        case .large: return 1.25
        case .extraLarge: return 1.5
        }
    }

    var nameKey: String {
        switch self {
        case .small: return "interfaceSize.small"
        case .normal: return "interfaceSize.normal"
        case .large: return "interfaceSize.large"
        case .extraLarge: return "interfaceSize.extraLarge"
        }
    }

    static var saved: InterfaceSize {
        InterfaceSize(rawValue: AppSettings.defaults.object(forKey: AppSettings.interfaceSizeKey) as? Int ?? 1) ?? .normal
    }
}

extension NSView {
    /// Places the view at `frame` (window points) and draws it `scale` times larger than its own
    /// layout, which keeps working in the original units: bounds are the frame divided by the scale.
    func setScaledFrame(_ frame: NSRect, scale: CGFloat) {
        let old = bounds.size
        self.frame = frame
        let logical = NSRect(x: 0, y: 0, width: frame.width / scale, height: frame.height / scale)
        if bounds != logical { bounds = logical }
        resizeSubviews(withOldSize: old)
    }
}

/// A window content that shows a fixed-size layout scaled by the interface factor, for the
/// app's own dialogs.
final class ScaledContentView: NSView {
    let content: FlippedView

    init(content: FlippedView, scale: CGFloat = RibbonTheme.scale) {
        self.content = content
        let size = content.frame.size
        super.init(frame: NSRect(x: 0, y: 0, width: ceil(size.width * scale), height: ceil(size.height * scale)))
        addSubview(content)
        content.frame = bounds
        content.bounds = NSRect(origin: .zero, size: size)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Puts `content` in `window`, which takes its scaled size.
    static func install(_ content: FlippedView, in window: NSWindow) {
        let host = ScaledContentView(content: content)
        window.setContentSize(host.frame.size)
        window.contentView = host
    }
}
