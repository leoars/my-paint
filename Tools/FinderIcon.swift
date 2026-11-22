// Gives the app bundle a custom Finder icon, or removes it. Usage: swift Tools/FinderIcon.swift apply|clear "My Paint.app"
// macOS puts free-form icons on a grey plate unless the bundle has a custom Finder icon. That icon
// cannot be part of a signed bundle, so build.sh clears it before signing and adds it only to the
// ad hoc build here; installed copies get it from the installer's postinstall script.
import AppKit

let bundle = URL(fileURLWithPath: CommandLine.arguments[2]).standardizedFileURL
let workspace = NSWorkspace.shared
if CommandLine.arguments[1] == "clear" {
    let metadata = bundle.appendingPathComponent("Icon\r")
    if FileManager.default.fileExists(atPath: metadata.path) {
        guard workspace.setIcon(nil, forFile: bundle.path) else { exit(1) }
    }
} else {
    let url = bundle.appendingPathComponent("Contents/Resources/MyPaint.icns")
    guard let icon = NSImage(contentsOf: url),
          workspace.setIcon(icon, forFile: bundle.path) else { exit(1) }
}
