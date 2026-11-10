//
//  AvroKeyboard
//
//  Copyright (c) 2012 OmicronLab. All rights reserved.
//

import Foundation

/// One of the user's own auto-correct entries, like a macOS text replacement: typing
/// `shortcut` offers `phrase` first.
///
/// Saved in the same format as the `Text Substitutions.plist` that macOS exports, an
/// array of `shortcut`/`phrase` dictionaries.
struct Replacement: Codable, Equatable, Sendable {
    var shortcut: String
    var phrase: String
}

/// Auto-correct entries, keyed by romanised input: the user's own replacements, then the
/// fixed spellings and emoticons from `autodict.plist`.
@MainActor
final class AutoCorrect {
    static let shared = AutoCorrect()

    /// The built-in entries from `autodict.plist`.
    let entries: [String: String]

    /// The user's own entries, in the order they are listed in Preferences.
    private(set) var replacements: [Replacement]
    /// `replacements` keyed by normalised shortcut.
    private var replacementLookup: [String: String] = [:]

    private static let replacementsFile = Storage.file("replacements.plist")

    private init() {
        if let url = Bundle.main.url(forResource: "autodict", withExtension: "plist"),
           let dictionary = NSDictionary(contentsOf: url) as? [String: String] {
            entries = dictionary
        } else {
            entries = [:]
        }
        replacements = Self.loadReplacements()
        rebuildLookup()
    }

    /// The user's replacement for `term`, else the built-in entry when `includeBuiltIn` is set.
    func find(_ term: String, includeBuiltIn: Bool = true) -> String? {
        let key = Self.key(for: term)
        if let phrase = replacementLookup[key] {
            return phrase
        }
        return includeBuiltIn ? entries[key] : nil
    }

    /// The built-in entry that `shortcut` would hide, if any.
    func builtInEntry(for shortcut: String) -> String? {
        entries[Self.key(for: shortcut)]
    }

    /// Shortcuts match the way typed text does: letters whose case means nothing in Avro
    /// Phonetic are lower-cased, so `Addr` and `addr` are the same shortcut.
    static func key(for shortcut: String) -> String {
        AvroParser.shared.fix(shortcut)
    }

    // MARK: - Editing

    /// Replaces the user's entries and saves them. Lists already worked out for the old
    /// entries are forgotten, as is any earlier pick for a shortcut that changed, so the
    /// new phrase is offered first straight away.
    func setReplacements(_ newReplacements: [Replacement]) throws {
        let old = Dictionary(replacements.map { (Self.key(for: $0.shortcut), $0.phrase) }, uniquingKeysWith: { first, _ in first })
        replacements = newReplacements
        rebuildLookup()
        try save()

        let cache = CacheManager.shared
        cache.removeAllArrays()
        for (key, phrase) in replacementLookup where old[key] != phrase {
            cache.removeString(forKey: key)
        }
        for replacement in newReplacements {
            cache.removeString(forKey: replacement.shortcut)
        }
    }

    /// Why `shortcut` can't be used, or nil if it can. `others` are the remaining entries,
    /// which it must not repeat.
    static func problem(withShortcut shortcut: String, others: [Replacement]) -> String? {
        if shortcut.isEmpty {
            return "Type a shortcut."
        }
        if shortcut.contains(where: { $0.isWhitespace || $0.isNewline }) {
            return "A shortcut can't contain spaces."
        }
        if let digit = Composition.digitPickingCandidate(in: shortcut) {
            return "A shortcut can't have \(digit) right after a letter: the number picks a suggestion."
        }
        let key = key(for: shortcut)
        if others.contains(where: { Self.key(for: $0.shortcut) == key }) {
            return "“\(shortcut)” is already a shortcut."
        }
        return nil
    }

    // MARK: - Storage

    private func rebuildLookup() {
        replacementLookup = [:]
        for replacement in replacements where !replacement.shortcut.isEmpty && !replacement.phrase.isEmpty {
            let key = Self.key(for: replacement.shortcut)
            if replacementLookup[key] == nil {
                replacementLookup[key] = replacement.phrase
            }
        }
    }

    private static func loadReplacements() -> [Replacement] {
        guard let data = try? Data(contentsOf: replacementsFile) else { return [] }
        do {
            return try PropertyListDecoder().decode([Replacement].self, from: data)
        } catch {
            NSLog("Could not read \(replacementsFile.path): \(error)")
            return []
        }
    }

    private func save() throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        try encoder.encode(replacements).write(to: Self.replacementsFile, options: .atomic)
    }
}
