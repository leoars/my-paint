import Foundation

enum Localization {
    /// Where the texts come from; the tests point it at each `.lproj` in turn.
    static var bundle = Bundle.main
}

func L(_ key: String) -> String {
    Localization.bundle.localizedString(forKey: key, value: nil, table: nil)
}
