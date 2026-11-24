import AppKit

// Updates of the copies installed from GitHub. The app looks for a newer installer of its own
// architecture among the releases, downloads it only when the person agrees, checks that it is
// signed by the developer and notarized, quits and hands it to the macOS Installer, which asks for
// the administrator password the folder Applications needs. The same file serves My Notepad,
// My Paint and My Calc. The App Store build leaves it out: the store updates that copy.

/// A release as the GitHub API lists it, with only what the updater reads.
struct UpdateRelease: Decodable {
  struct Asset: Decodable {
    let id: Int
    let name: String
    let size: Int
    let state: String
  }
  let draft: Bool
  let prerelease: Bool
  let assets: [Asset]
}

/// The installer chosen for this Mac.
struct UpdateCandidate: Equatable {
  let version: String
  let assetID: Int
  let name: String
  let size: Int
}

enum UpdateVersion {
  /// "1.0.4" as numbers; nil for anything that is not one to four groups of digits.
  static func parts(_ version: String) -> [Int]? {
    let pieces = version.split(separator: ".", omittingEmptySubsequences: false)
    guard (1...4).contains(pieces.count) else { return nil }
    var numbers: [Int] = []
    for piece in pieces {
      guard (1...6).contains(piece.count), piece.allSatisfy({ $0.isASCII && $0.isNumber }),
        let number = Int(piece) else { return nil }
      numbers.append(number)
    }
    return numbers
  }

  /// 1.0.10 is newer than 1.0.9, and 1.0 is the same as 1.0.0.
  static func isNewer(_ candidate: String, than current: String) -> Bool {
    guard let a = parts(candidate), let b = parts(current) else { return false }
    for index in 0..<max(a.count, b.count) {
      let x = index < a.count ? a[index] : 0
      let y = index < b.count ? b[index] : 0
      if x != y { return x > y }
    }
    return false
  }

  /// The newest published installer named `<prefix>-<version>-<architecture>.pkg` that is newer
  /// than `current`. Drafts, pre-releases and files not fully uploaded are left out.
  static func newest(in releases: [UpdateRelease], prefix: String, architecture: String,
                     after current: String) -> UpdateCandidate? {
    let head = prefix + "-"
    let tail = "-" + architecture + ".pkg"
    var best: UpdateCandidate?
    for release in releases where !release.draft && !release.prerelease {
      for asset in release.assets {
        guard asset.state == "uploaded", asset.id > 0, (1...536_870_912).contains(asset.size),
          asset.name.hasPrefix(head), asset.name.hasSuffix(tail),
          asset.name.count > head.count + tail.count else { continue }
        let version = String(asset.name.dropFirst(head.count).dropLast(tail.count))
        guard parts(version) != nil, isNewer(version, than: best?.version ?? current) else { continue }
        best = UpdateCandidate(version: version, assetID: asset.id, name: asset.name, size: asset.size)
      }
    }
    return best
  }
}

/// What the person chose about updates, kept in the app's settings.
struct UpdatePreferences {
  static let automaticKey = "updates.automatic"
  static let lastCheckKey = "updates.lastCheck"
  static let resumeKey = "updates.resumeAfter"
  static let skippedKey = "updates.skippedVersion"
  var defaults: UserDefaults

  /// On unless turned off in Settings.
  var automatic: Bool {
    get { defaults.object(forKey: Self.automaticKey) as? Bool ?? true }
    nonmutating set { defaults.set(newValue, forKey: Self.automaticKey) }
  }

  /// The automatic check runs at most once a day, and not while Remind Me Later lasts.
  func isDue(at now: Date) -> Bool {
    if let until = defaults.object(forKey: Self.resumeKey) as? Date, now < until { return false }
    if let last = defaults.object(forKey: Self.lastCheckKey) as? Date, last <= now,
      now.timeIntervalSince(last) < 20 * 60 * 60 { return false }
    return true
  }

  func isDeferred(at now: Date) -> Bool {
    guard let until = defaults.object(forKey: Self.resumeKey) as? Date else { return false }
    return now < until
  }

  func checked(at now: Date) { defaults.set(now, forKey: Self.lastCheckKey) }

  func remindLater(from now: Date) {
    defaults.set(now.addingTimeInterval(7 * 24 * 60 * 60), forKey: Self.resumeKey)
  }

  var skippedVersion: String? { defaults.string(forKey: Self.skippedKey) }

  func skip(_ version: String) {
    if let skipped = skippedVersion, !UpdateVersion.isNewer(version, than: skipped) { return }
    defaults.set(version, forKey: Self.skippedKey)
  }
}

enum UpdateError: Error { case invalid, untrusted, access }

#if APP_STORE

/// The App Store copy is updated by the store.
final class PackageUpdater {
  static let isAvailable = false
  var preferences = UpdatePreferences(defaults: .standard)
  var automatic = false
  let status = "updates.status.idle"
  let canCheckNow = false
  var changed: (() -> Void)?
  init(appName: String, repository: String, prefix: String, window: @escaping () -> NSWindow?) {}
  func startAutomatically() {}
  func checkNow() {}
}

#else

/// Checks a downloaded installer before anything opens it.
enum UpdatePackage {
  static let team = "GV4SHC87M4"

  /// `pkgutil --check-signature` must report a Developer ID Installer certificate of the
  /// developer's team, issued by Apple for distribution.
  static func trusts(signature output: String, team: String = team) -> Bool {
    let lines = output.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
    return lines.contains("Status: signed by a developer certificate issued by Apple for distribution")
      && lines.contains { $0.hasPrefix("1. Developer ID Installer: ") && $0.hasSuffix("(\(team))") }
  }

  static func run(_ tool: String, _ arguments: [String]) throws -> (status: Int32, output: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: tool)
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    process.standardInput = FileHandle.nullDevice
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return (process.terminationStatus, String(decoding: data, as: UTF8.self))
  }

  /// The signature of the developer's team, then the verdict of Gatekeeper, which also requires
  /// Apple's notarization.
  static func verify(_ package: URL) throws {
    let signature = try run("/usr/sbin/pkgutil", ["--check-signature", package.path])
    guard signature.status == 0, trusts(signature: signature.output) else { throw UpdateError.untrusted }
    guard try run("/usr/sbin/spctl", ["--assess", "--type", "install", package.path]).status == 0
    else { throw UpdateError.untrusted }
  }
}

/// Only to GitHub's own download hosts, over HTTPS, without carrying headers along.
private final class UpdateRedirects: NSObject, URLSessionTaskDelegate {
  func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                  newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
    guard let url = request.url, url.scheme == "https", let host = url.host,
      host.hasSuffix(".githubusercontent.com") else { completionHandler(nil); return }
    var stripped = URLRequest(url: url)
    stripped.httpMethod = "GET"
    completionHandler(stripped)
  }
}

final class PackageUpdater: NSObject {
  /// A sandboxed copy cannot hand an installer over; it came from the store.
  static var isAvailable: Bool { ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] == nil }

  let appName: String
  let repository: String
  let prefix: String
  let window: () -> NSWindow?
  var preferences = UpdatePreferences(defaults: .standard)
  var currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
  var architecture: String = {
    #if arch(arm64)
      return "arm64"
    #else
      return "x86_64"
    #endif
  }()
  private lazy var session: URLSession = {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpShouldSetCookies = false
    configuration.urlCredentialStorage = nil
    configuration.timeoutIntervalForResource = 600
    return URLSession(configuration: configuration, delegate: UpdateRedirects(), delegateQueue: nil)
  }()
  private var task: Task<Void, Never>?
  private var staged: URL?
  private var progress: NSPanel?
  private var installing = false
  /// The line Settings shows under the option, as a localization key, as in My Explorer.
  private(set) var status = "updates.status.idle" { didSet { changed?() } }
  var changed: (() -> Void)?
  var canCheckNow: Bool { task == nil }

  var automatic: Bool {
    get { preferences.automatic }
    set { preferences.automatic = newValue }
  }

  init(appName: String, repository: String, prefix: String, window: @escaping () -> NSWindow?) {
    self.appName = appName
    self.repository = repository
    self.prefix = prefix
    self.window = window
    super.init()
    NotificationCenter.default.addObserver(
      self, selector: #selector(applicationWillTerminate(_:)), name: NSApplication.willTerminateNotification, object: nil)
  }

  /// A few seconds after launch, when turned on and due.
  func startAutomatically() {
    guard Self.isAvailable, preferences.automatic else { return }
    if preferences.isDeferred(at: Date()) { status = "updates.status.deferred"; return }
    guard preferences.isDue(at: Date()) else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in self?.check(manual: false) }
  }

  /// Check for Updates…: also offers a version skipped before, and says when there is none.
  func checkNow() { check(manual: true) }

  private func check(manual: Bool) {
    guard Self.isAvailable, task == nil else { return }
    status = "updates.status.checking"
    task = Task { @MainActor [weak self] in
      await self?.run(manual: manual)
      self?.task = nil
      self?.changed?()
    }
  }

  @MainActor private func run(manual: Bool) async {
    do {
      var floor = currentVersion
      if !manual, let skipped = preferences.skippedVersion, UpdateVersion.isNewer(skipped, than: floor) {
        floor = skipped
      }
      let candidate = try await newest(after: floor)
      preferences.checked(at: Date())
      guard let candidate else {
        status = "updates.status.current"
        if manual {
          inform(L("updates.current"), String(format: L("updates.current.detail"), appName, currentVersion))
        }
        return
      }
      guard let owner = window(), owner.isVisible else { status = "updates.status.idle"; return }
      switch await offer(candidate, on: owner, manual: manual) {
      case .alertFirstButtonReturn:
        try await install(candidate, on: owner)
        status = "updates.status.idle"
      case .alertSecondButtonReturn where !manual:
        preferences.remindLater(from: Date())
        status = "updates.status.deferred"
      case .alertThirdButtonReturn where !manual:
        preferences.skip(candidate.version)
        status = "updates.status.skipped"
      default: status = "updates.status.idle"
      }
    } catch is CancellationError {
      dismissProgress()
      status = "updates.status.idle"
    } catch {
      dismissProgress()
      status = (error as? UpdateError) == .access ? "updates.status.access" : "updates.status.failed"
      // A check that runs by itself fails quietly; one the person asked for, or a download, says so.
      if manual || installing {
        let detail = (error as? UpdateError) == .untrusted ? "updates.untrusted.detail" : "updates.failed.detail"
        inform(L("updates.failed"), L(detail))
      }
    }
    installing = false
  }

  @MainActor private func newest(after version: String) async throws -> UpdateCandidate? {
    var best: UpdateCandidate?
    for page in 1...10 {
      var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repository)/releases?per_page=100&page=\(page)")!)
      request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
      let (data, response) = try await session.data(for: request)
      let code = (response as? HTTPURLResponse)?.statusCode
      if [401, 403, 404].contains(code) { throw UpdateError.access }
      guard code == 200 else { throw UpdateError.invalid }
      let releases = try JSONDecoder().decode([UpdateRelease].self, from: data)
      if let found = UpdateVersion.newest(in: releases, prefix: prefix, architecture: architecture,
                                          after: best?.version ?? version) { best = found }
      if releases.count < 100 { break }
    }
    return best
  }

  @MainActor private func offer(_ candidate: UpdateCandidate, on owner: NSWindow, manual: Bool) async -> NSApplication.ModalResponse {
    let alert = NSAlert()
    alert.messageText = String(format: L("updates.offer"), appName, candidate.version)
    alert.informativeText = String(format: L("updates.offer.detail"), currentVersion, appName)
    alert.addButton(withTitle: L("updates.install"))
    if manual {
      alert.addButton(withTitle: L("updates.cancel")).keyEquivalent = "\u{1b}"
    } else {
      alert.addButton(withTitle: L("updates.later")).keyEquivalent = "\u{1b}"
      alert.addButton(withTitle: L("updates.skip"))
    }
    if owner.attachedSheet != nil || NSApp.modalWindow != nil { return alert.runModal() }
    return await withCheckedContinuation { continuation in
      alert.beginSheetModal(for: owner) { continuation.resume(returning: $0) }
    }
  }

  @MainActor private func install(_ candidate: UpdateCandidate, on owner: NSWindow) async throws {
    installing = true
    showProgress(on: owner, String(format: L("updates.downloading"), appName, candidate.version))
    var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repository)/releases/assets/\(candidate.assetID)")!)
    request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
    let (file, response) = try await session.download(for: request)
    defer { try? FileManager.default.removeItem(at: file) }
    try Task.checkCancellation()
    guard (response as? HTTPURLResponse)?.statusCode == 200,
      try file.resourceValues(forKeys: [.fileSizeKey]).fileSize == candidate.size else { throw UpdateError.invalid }
    let manager = FileManager.default
    let folder = manager.temporaryDirectory.appendingPathComponent("\(prefix)-Update-\(UUID().uuidString)")
    try manager.createDirectory(at: folder, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    let package = folder.appendingPathComponent(candidate.name)
    do {
      try manager.moveItem(at: file, to: package)
      try await Task.detached { try UpdatePackage.verify(package) }.value
      try Task.checkCancellation()
    } catch {
      try? manager.removeItem(at: folder)
      throw error
    }
    dismissProgress()
    staged = package
    NSApp.terminate(nil)
    // Still running: quitting was cancelled, for a document the person chose to keep open.
    try? manager.removeItem(at: folder)
    staged = nil
  }

  /// After the app has gone, the Installer opens the package; when it closes, the app opens again.
  @objc private func applicationWillTerminate(_ notification: Notification) {
    guard let staged else { return }
    let helper = Process()
    helper.executableURL = URL(fileURLWithPath: "/bin/sh")
    helper.arguments = [
      "-c",
      #"while kill -0 "$1" 2>/dev/null; do sleep 0.2; done; /usr/bin/open -W "$2"; /bin/rm -rf "$3"; [ -n "$4" ] && exec /usr/bin/open -b "$4""#,
      "update", String(ProcessInfo.processInfo.processIdentifier), staged.path,
      staged.deletingLastPathComponent().path, Bundle.main.bundleIdentifier ?? "",
    ]
    try? helper.run()
  }

  @MainActor private func showProgress(on owner: NSWindow, _ text: String) {
    let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 110), styleMask: [.titled], backing: .buffered, defer: true)
    let label = NSTextField(labelWithString: text)
    let bar = NSProgressIndicator()
    bar.isIndeterminate = true
    bar.style = .bar
    bar.startAnimation(nil)
    let cancel = NSButton(title: L("updates.cancel"), target: self, action: #selector(cancelDownload))
    cancel.keyEquivalent = "\u{1b}"
    let stack = NSStackView(views: [label, bar, cancel])
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 12
    stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 18, right: 20)
    bar.widthAnchor.constraint(equalToConstant: 320).isActive = true
    cancel.trailingAnchor.constraint(equalTo: bar.trailingAnchor).isActive = true
    panel.contentView = stack
    panel.setContentSize(stack.fittingSize)
    progress = panel
    owner.beginSheet(panel)
  }

  @objc private func cancelDownload() { task?.cancel() }

  private func dismissProgress() {
    guard let progress else { return }
    progress.sheetParent?.endSheet(progress)
    progress.orderOut(nil)
    self.progress = nil
  }

  @MainActor private func inform(_ title: String, _ detail: String) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = detail
    alert.addButton(withTitle: L("updates.ok"))
    if let owner = window(), owner.isVisible, owner.attachedSheet == nil {
      alert.beginSheetModal(for: owner, completionHandler: nil)
    } else {
      _ = alert.runModal()
    }
  }
}

#endif
