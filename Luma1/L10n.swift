//
//  L10n.swift
//  Luma
//
//  Created by Codex on 3/19/26.
//

import Foundation
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case chineseSimplified = "zh-Hans"

    static let userDefaultsKey = "luma.app.language"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .english:
            return Locale(identifier: "en_US")
        case .chineseSimplified:
            return Locale(identifier: "zh_Hans_CN")
        }
    }

    static var deviceDefault: AppLanguage {
        resolve(from: Locale.preferredLanguages.first) ?? .english
    }

    static func resolve(from rawValue: String?) -> AppLanguage? {
        guard let rawValue else {
            return nil
        }

        let normalized = rawValue.lowercased()
        if normalized.hasPrefix("zh") {
            return .chineseSimplified
        }
        if normalized.hasPrefix("en") {
            return .english
        }
        return nil
    }
}

@MainActor
final class LanguageStore: ObservableObject {
    @Published var currentLanguage: AppLanguage {
        didSet {
            guard oldValue != currentLanguage else { return }
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: AppLanguage.userDefaultsKey)
            L10n.setLanguage(currentLanguage)
        }
    }

    init() {
        let stored = AppLanguage.resolve(
            from: UserDefaults.standard.string(forKey: AppLanguage.userDefaultsKey)
        )
        let language = stored ?? AppLanguage.deviceDefault
        currentLanguage = language
        L10n.setLanguage(language)
    }
}

enum L10n {
    private static let enBundle: Bundle = localizedBundle(for: "en")
    private static let zhHansBundle: Bundle = localizedBundle(for: "zh-Hans")
    private static var selectedLanguage: AppLanguage = {
        AppLanguage.resolve(from: UserDefaults.standard.string(forKey: AppLanguage.userDefaultsKey))
        ?? AppLanguage.deviceDefault
    }()

    private static func localizedBundle(for languageCode: String) -> Bundle {
        guard
            let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return .main
        }
        return bundle
    }

    private static func localizedValue(for key: String, in bundle: Bundle) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }

    private static var activeBundle: Bundle {
        switch selectedLanguage {
        case .english:
            return enBundle
        case .chineseSimplified:
            return zhHansBundle
        }
    }

    private static var activeLocale: Locale {
        selectedLanguage.locale
    }

    static func setLanguage(_ language: AppLanguage) {
        selectedLanguage = language
    }

    static func tr(_ key: String) -> String {
        localizedValue(for: key, in: activeBundle)
    }

    static func format(_ key: String, _ args: CVarArg...) -> String {
        let format = localizedValue(for: key, in: activeBundle)
        return String(format: format, locale: activeLocale, arguments: args)
    }
}
