//
//  AvroKeyboard
//
//  Copyright (c) 2012 OmicronLab. All rights reserved.
//

import Foundation

/// The text being composed and the candidates it produces. Independent of InputMethodKit.
///
/// The buffer holds raw romanised text. Leading and trailing punctuation are transliterated
/// directly (`prefix`/`suffix`); the middle (`term`) goes through the suggestion engine and
/// each suggestion is re-wrapped in the prefix and suffix.
final class Composition {
    /// Splits a buffer into (leading punctuation, term, trailing punctuation). A run of two or
    /// more commas inside the term is kept with the term so `,,` (hasanta) keeps working.
    private static let splitter: NSRegularExpression = {
        let punctuation = #"(?::`|\.`|[-\]\\~!@#&*()_=+\[{}'";<>/?|.,])"#
        let pattern = "(^\(punctuation)*?(?=(?:,{2,}))|^\(punctuation)*)(.*?(?:,,)*)(\(punctuation)*$)"
        return try! NSRegularExpression(pattern: pattern)
    }()

    private(set) var buffer = ""
    private(set) var candidates: [String] = []
    /// The candidate highlighted in the candidate window.
    private(set) var selectedIndex = 0
    /// Index of the candidate the user picked the last time this term came up, or -1.
    private(set) var rememberedIndex = -1

    private(set) var prefix = ""
    private(set) var term = ""
    private(set) var suffix = ""

    var isEmpty: Bool { buffer.isEmpty }

    var selectedCandidate: String? {
        candidates.indices.contains(selectedIndex) ? candidates[selectedIndex] : nil
    }

    // MARK: - Editing

    func append(_ string: String) {
        buffer += string
        refreshCandidates()
    }

    func deleteBackward() {
        guard !buffer.isEmpty else { return }
        buffer.removeLast()
        refreshCandidates()
    }

    func clear() {
        buffer = ""
        candidates = []
        selectedIndex = 0
        rememberedIndex = -1
    }

    // MARK: - Selection

    /// Records that `candidate` is now highlighted. A choice other than the default is
    /// remembered so it is offered first the next time the same term is typed.
    func selectionChanged(to candidate: String) {
        guard let index = candidates.firstIndex(of: candidate) else { return }
        selectedIndex = index

        guard Preferences.includeDictionary, !term.isEmpty, !(index == 0 && rememberedIndex == -1) else { return }

        let cache = CacheManager.shared
        let word = Self.stripping(prefix: prefix, suffix: suffix, from: candidate)
        cache.setString(word, forKey: term)

        // A suffixed word also teaches us which base word the user prefers.
        if let base = cache.base(forKey: word) {
            cache.setString(base.word, forKey: base.term)
        }
    }

    /// Removes the transliterated punctuation around a candidate, measured in UTF-16 units so
    /// that a leading vowel sign is never merged into the prefix.
    private static func stripping(prefix: String, suffix: String, from candidate: String) -> String {
        let candidate = candidate as NSString
        let length = candidate.length - prefix.utf16.count - suffix.utf16.count
        guard length > 0 else { return "" }
        return candidate.substring(with: NSRange(location: prefix.utf16.count, length: length))
    }

    // MARK: - Candidates

    private func refreshCandidates() {
        candidates = []
        selectedIndex = 0
        rememberedIndex = -1
        guard !buffer.isEmpty else { return }

        let text = buffer as NSString
        guard let match = Self.splitter.firstMatch(in: buffer, range: NSRange(location: 0, length: text.length)) else {
            return
        }
        prefix = AvroParser.shared.parse(text.substring(with: match.range(at: 1)))
        term = text.substring(with: match.range(at: 2))
        suffix = AvroParser.shared.parse(text.substring(with: match.range(at: 3)))

        let suggestions = Suggestion.shared.list(for: term)
        guard !suggestions.isEmpty else {
            candidates = [prefix]
            return
        }

        if Preferences.includeDictionary, let remembered = CacheManager.shared.string(forKey: term) {
            rememberedIndex = suggestions.firstIndex(of: remembered) ?? -1
        }
        candidates = suggestions.map { prefix + $0 + suffix }

        // Emoticons and other auto-correct entries that include the punctuation itself.
        if Preferences.includeDictionary, buffer != term, let smiley = AutoCorrect.shared.find(buffer) {
            candidates.insert(smiley, at: 0)
            if rememberedIndex >= 0 { rememberedIndex += 1 }
        }
    }
}
