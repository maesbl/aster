import Foundation
import SwiftUI

enum AsterLanguage: String, CaseIterable {
    case spanish = "es", english = "en", catalan = "ca"
    var name: String { switch self { case .spanish: return "Español"; case .english: return "English"; case .catalan: return "Català" } }
}
private enum TranslationCatalog {
    static let values: [String: [String: String]] = {
        var catalogs: [String: [String: String]] = [:]
        for code in ["en", "ca"] {
            if let url = Bundle.main.url(forResource: code, withExtension: "json", subdirectory: "Localization"), let data = try? Data(contentsOf: url), let catalog = try? JSONDecoder().decode([String: String].self, from: data) { catalogs[code] = catalog }
        }
        return catalogs
    }()
}
func L(_ key: String, language: String? = nil) -> String {
    let language = language ?? UserDefaults.standard.string(forKey: "AsterLanguage") ?? "es"
    return TranslationCatalog.values[language]?[key] ?? key
}
func LF(_ key: String, _ arguments: CVarArg...) -> String { String(format: L(key), locale: Locale(identifier: UserDefaults.standard.string(forKey: "AsterLanguage") ?? "es"), arguments: arguments) }
