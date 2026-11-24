import AppKit

/// Updates: which installer is newer, what the person chose, and whose signature is trusted.
func runUpdateTests() {
    check(UpdateVersion.isNewer("1.0.1", than: "1.0") && UpdateVersion.isNewer("1.1", than: "1.0.9")
          && !UpdateVersion.isNewer("1.0.0", than: "1.0") && !UpdateVersion.isNewer("0.9", than: "1.0"),
          "versions compare number by number, and 1.0 is 1.0.0")
    func release(_ names: [String], draft: Bool = false, prerelease: Bool = false) -> [String: Any] {
        ["draft": draft, "prerelease": prerelease,
         "assets": names.enumerated().map { ["id": $0.offset + 1, "size": 3_000_000, "state": "uploaded", "name": $0.element] }]
    }
    let json = try! JSONSerialization.data(withJSONObject: [
        release(["My-Paint-1.2-arm64.pkg"], draft: true),
        release(["My-Paint-1.1.1-arm64.pkg"], prerelease: true),
        release(["My-Paint-1.1-arm64.pkg", "My-Paint-1.1-x86_64.pkg", "My-Notepad-1.9-arm64.pkg"]),
        release(["My-Paint-1.0-arm64.pkg", "My-Paint-1.0-x86_64.pkg"]),
    ])
    let releases = try! JSONDecoder().decode([UpdateRelease].self, from: json)
    check(UpdateVersion.newest(in: releases, prefix: "My-Paint", architecture: "arm64", after: "1.0")?.name == "My-Paint-1.1-arm64.pkg",
          "the newest installer of My Paint for this architecture is chosen, not a draft, a pre-release or another app")
    check(UpdateVersion.newest(in: releases, prefix: "My-Paint", architecture: "x86_64", after: "1.1") == nil,
          "with the newest version installed there is nothing to offer")

    let suite = "MyPaintUpdateTests-\(getpid())"
    let store = UserDefaults(suiteName: suite)!
    defer { store.removePersistentDomain(forName: suite) }
    let preferences = UpdatePreferences(defaults: store)
    let now = Date()
    check(preferences.automatic && preferences.isDue(at: now), "checking at launch is on and due at first")
    preferences.checked(at: now)
    check(!preferences.isDue(at: now.addingTimeInterval(3600)), "it runs at most once a day")
    preferences.remindLater(from: now.addingTimeInterval(21 * 3600))
    check(!preferences.isDue(at: now.addingTimeInterval(5 * 24 * 3600)) && preferences.isDue(at: now.addingTimeInterval(9 * 24 * 3600)),
          "Remind Me Later waits a week")
    preferences.skip("1.2")
    preferences.skip("1.1")
    check(preferences.skippedVersion == "1.2", "Skip This Version keeps the highest version skipped")

    let signed = """
        Package "My-Paint-1.0-arm64.pkg":
           Status: signed by a developer certificate issued by Apple for distribution
           Certificate Chain:
            1. Developer ID Installer: Leonardo Santos (GV4SHC87M4)
        """
    check(UpdatePackage.trusts(signature: signed), "an installer signed by the developer's team is trusted")
    check(!UpdatePackage.trusts(signature: signed.replacingOccurrences(of: "GV4SHC87M4", with: "AAAAAAAAAA")),
          "one signed by another team is not")

    // Settings shows and keeps the choice, in the defaults the tests use.
    let controller = MainWindowController()
    let settings = SettingsWindow(controller: controller)
    let before = settings.updates.automatic
    settings.updatesButton.state = .off
    settings.toggleUpdates(settings.updatesButton)
    check(!UpdatePreferences(defaults: AppSettings.defaults).automatic && settings.updatesButton.superview != nil,
          "Settings has the automatic check and turns it off")
    check(L("updates.automatic") == "Check for updates at startup" && settings.checkNowButton.title == "Check now"
          && settings.updateStatus.stringValue == "Checks GitHub at startup and asks before downloading."
          && abs(settings.checkNowButton.frame.midY - settings.updatesButton.frame.midY) < 1
          && settings.updateStatus.frame.minY > settings.updatesButton.frame.maxY,
          "Settings shows the option and Check now side by side, and the status below, with My Explorer's words")
    check(!settings.checkNowButton.isEnabled, "Check now waits for the app's updater")
    settings.updatesButton.state = before ? .on : .off
    settings.toggleUpdates(settings.updatesButton)
}
