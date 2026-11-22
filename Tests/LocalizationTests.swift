import AppKit

/// The format specifiers of a text (`%@`, `%d`, `%1$@`…), in order, without the literal `%%`.
func formatSpecifiers(_ text: String) -> [String] {
    let pattern = #"%(\d+\$)?[-+ #0']*(\d+|\*)?(\.(\d+|\*))?(hh|h|ll|l|q|z|t|j)?[@dDiuUxXoOfFeEgGcCsSp%]"#
    let regex = try! NSRegularExpression(pattern: pattern)
    let range = NSRange(text.startIndex..., in: text)
    return regex.matches(in: text, range: range).map { String(text[Range($0.range, in: text)!]) }.filter { $0 != "%%" }
}

/// The table of one `.strings` file, read on its own (not through the bundle's language choice).
func stringsTable(_ path: String) -> [String: String]? {
    NSDictionary(contentsOfFile: path) as? [String: String]
}

func runLocalizationTests() {
    // The eight languages of the My line, each loaded from its own folder next to the tests.
    let expected = ["de", "en", "es", "fr", "it", "ja", "ko", "pt-BR"]
    let folders = Bundle.main.paths(forResourcesOfType: "lproj", inDirectory: nil).sorted()
    let names = folders.map { (($0 as NSString).lastPathComponent as NSString).deletingPathExtension }
    check(names == expected, "the eight languages are in Resources: " + names.joined(separator: ", "))
    guard let english = folders.first(where: { $0.hasSuffix("/en.lproj") }) else { return }
    let tables = ((try? FileManager.default.contentsOfDirectory(atPath: english)) ?? []).filter { $0.hasSuffix(".strings") }.sorted()
    check(tables.contains("Localizable.strings"), "English has Localizable.strings")

    check(formatSpecifiers("%1$@ is %d, %.2f%% and %ld") == ["%1$@", "%d", "%.2f", "%ld"], "format specifiers are found")
    check(formatSpecifiers("100 %").isEmpty && formatSpecifiers("Gray 50 %").isEmpty, "a lone percent sign is not a specifier")

    for table in tables {
        guard let reference = stringsTable((english as NSString).appendingPathComponent(table)) else {
            check(false, "en/\(table) can be read")
            continue
        }
        check(reference.count > 0, "en/\(table) has keys")
        for folder in folders where folder != english {
            let language = (folder as NSString).lastPathComponent
            guard let texts = stringsTable((folder as NSString).appendingPathComponent(table)) else {
                check(false, "\(language)/\(table) exists and can be read")
                continue
            }
            let missing = Set(reference.keys).subtracting(texts.keys).sorted()
            let extra = Set(texts.keys).subtracting(reference.keys).sorted()
            check(missing.isEmpty, "\(language)/\(table): every English key is there" + (missing.isEmpty ? "" : " — missing " + missing.joined(separator: ", ")))
            check(extra.isEmpty, "\(language)/\(table): no keys left over" + (extra.isEmpty ? "" : " — " + extra.joined(separator: ", ")))
            let wrong = reference.keys.sorted().filter { key in
                guard let text = texts[key] else { return false }
                return formatSpecifiers(text).sorted() != formatSpecifiers(reference[key]!).sorted()
            }
            check(wrong.isEmpty, "\(language)/\(table): same format specifiers as English" + (wrong.isEmpty ? "" : " — " + wrong.joined(separator: ", ")))
            let empty = texts.filter { $0.value.trimmingCharacters(in: .whitespaces).isEmpty }.keys.sorted()
            check(empty.isEmpty, "\(language)/\(table): no empty texts" + (empty.isEmpty ? "" : " — " + empty.joined(separator: ", ")))
            // A translation, not a copy: most texts differ from English (names like PNG or Zoom may not).
            let translated = reference.keys.filter { texts[$0] != reference[$0] }.count
            check(language == "en.lproj" || Double(translated) > Double(reference.count) * 0.6, "\(language)/\(table): translated (\(translated) of \(reference.count))")
        }
    }

    // Through the app's own lookup, each language gives its texts and formats them without trouble.
    for folder in folders {
        guard let bundle = Bundle(path: folder) else { continue }
        let language = (folder as NSString).lastPathComponent
        Localization.bundle = bundle
        let samples = [String(format: L("window.title"), "a.png"), String(format: L("status.position"), 12, 34),
                       String(format: L("resize.range"), 1, 500), String(format: L("preview.page"), 1, 2),
                       String(format: L("properties.disk"), "1 KB"), String(format: L("color.custom"), 3)]
        check(samples.allSatisfy { !$0.isEmpty && !$0.contains("%") } && L("ribbon.home") != "ribbon.home",
              "\(language): texts are found and formatted")
        check(samples[1].contains("12") && samples[1].contains("34") && samples[2].contains("500"), "\(language): numbers land in the texts")
        // No trademark of the original in any language.
        let all = (stringsTable((folder as NSString).appendingPathComponent("Localizable.strings")) ?? [:]).values
        check(!all.contains { $0.localizedCaseInsensitiveContains("windows") || $0.localizedCaseInsensitiveContains("microsoft") },
              "\(language): no Microsoft or Windows names")
    }
    Localization.bundle = .main
    // The tests themselves run in English, so the expected texts stay stable.
    check(L("ribbon.home") == "Home", "the tests run with the English texts")
}
