//
//  AvroKeyboard
//
//  Copyright (c) 2012 OmicronLab. All rights reserved.
//

import Foundation

/// Builds the ordered candidate list for a romanised term.
///
/// With dictionary suggestions enabled the list is: auto-correct entry, dictionary
/// matches (closest spelling first), words synthesised from a known base + suffix,
/// and finally the plain phonetic transliteration. Otherwise it is just the transliteration.
final class Suggestion {
    static let shared = Suggestion()

    /// Independent vowels and vowel signs (kars).
    private static let vowels: Set<Unicode.Scalar> = Set("\u{0985}\u{0986}\u{0987}\u{0988}\u{0989}\u{098A}\u{098B}\u{098F}\u{0990}\u{0993}\u{0994}\u{098C}\u{09E1}\u{09BE}\u{09BF}\u{09C0}\u{09C1}\u{09C2}\u{09C3}\u{09C7}\u{09C8}\u{09CB}\u{09CC}".unicodeScalars)
    /// Vowel signs (kars) only.
    private static let kars: Set<Unicode.Scalar> = Set("\u{09BE}\u{09BF}\u{09C0}\u{09C1}\u{09C2}\u{09C3}\u{09C7}\u{09C8}\u{09CB}\u{09CC}\u{09C4}".unicodeScalars)

    private init() {}

    func list(for term: String) -> [String] {
        guard !term.isEmpty else { return [] }

        let parsed = AvroParser.shared.parse(term)
        var suggestions: [String] = []

        if Preferences.includeDictionary {
            let cache = CacheManager.shared

            if let cached = cache.array(forKey: term), !cached.isEmpty {
                suggestions = cached
            } else {
                let autoCorrect = AutoCorrect.shared.find(term)
                let dictionary = Database.shared.find(term)

                // Prefer the dictionary's own copy of a word over the auto-correct entry.
                if let autoCorrect, !dictionary.contains(autoCorrect) {
                    suggestions.append(autoCorrect)
                }
                let distances = Dictionary(uniqueKeysWithValues: dictionary.map { ($0, parsed.levenshteinDistance(to: $0)) })
                suggestions += dictionary.sorted { distances[$0]! < distances[$1]! }

                cache.setArray(suggestions, forKey: term)
            }

            suggestions += suffixedWords(for: term, existing: suggestions)
        }

        if !suggestions.contains(parsed) {
            suggestions.append(parsed)
        }
        return suggestions
    }

    /// Words formed by splitting `term` into a known base + a known suffix, e.g. `bhalo` + `bashar`.
    private func suffixedWords(for term: String, existing: [String]) -> [String] {
        let cache = CacheManager.shared
        let characters = Array(term)
        var words: [String] = []
        var alreadySelected = false

        cache.removeAllBases()

        for split in stride(from: characters.count - 1, through: 1, by: -1) {
            let romanSuffix = String(characters[split...]).lowercased()
            guard let suffix = Database.shared.banglaForSuffix(romanSuffix),
                  let suffixHead = suffix.unicodeScalars.first else { continue }

            let base = String(characters[..<split])
            let selected = alreadySelected ? nil : cache.string(forKey: base)

            for item in cache.array(forKey: base) ?? [] {
                // Skip the auto-correct entry that echoes the English input.
                if item == base { continue }

                let word = join(item, with: suffix, suffixHead: suffixHead)
                cache.setBase(term: base, word: item, forKey: word)

                guard !existing.contains(word), !words.contains(word) else { continue }

                // If the user previously picked this base, pre-select the suffixed form too.
                if !alreadySelected, let selected, item == selected {
                    if cache.string(forKey: term) == nil {
                        cache.setString(word, forKey: term)
                    }
                    alreadySelected = true
                }
                words.append(word)
            }
        }
        return words
    }

    /// Joins a base word and a suffix, applying Bengali sandhi at the boundary.
    private func join(_ item: String, with suffix: String, suffixHead: Unicode.Scalar) -> String {
        guard let itemTail = item.unicodeScalars.last else { return item + suffix }
        let stem = String(String.UnicodeScalarView(item.unicodeScalars.dropLast()))

        if Self.vowels.contains(itemTail) && Self.kars.contains(suffixHead) {
            return item + "\u{09DF}" + suffix              // vowel + kar → insert য়
        }
        switch itemTail {
        case "\u{09CE}": return stem + "\u{09A4}" + suffix  // ৎ → ত
        case "\u{0982}": return stem + "\u{0999}" + suffix  // ং → ঙ
        default:         return item + suffix
        }
    }
}
