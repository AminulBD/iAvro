//
//  AvroKeyboard
//
//  Copyright (c) 2012 OmicronLab. All rights reserved.
//

import Foundation

/// A rule set loaded from `data.json` / `regex.json`.
///
/// Patterns map a chunk of romanised input (`find`) to Bengali output (`replace`).
/// A pattern may carry context-sensitive `rules`; the first rule whose every `match`
/// condition holds wins, otherwise the pattern's default `replace` is used.
struct PhoneticRules: Decodable, Sendable {
    struct Match: Decodable {
        enum Position: String, Decodable { case prefix, suffix }
        enum Scope: String, Decodable { case punctuation, vowel, consonant, number, exact }

        let type: Position
        let scope: Scope
        let value: String?
        let negative: Bool

        private enum CodingKeys: String, CodingKey { case type, scope, value, negative }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            type = try container.decode(Position.self, forKey: .type)
            scope = try container.decode(Scope.self, forKey: .scope)
            value = try container.decodeIfPresent(String.self, forKey: .value)
            // The JSON stores "YES"/"NO"/"TRUE"/"FALSE"; use NSString's lenient parsing.
            negative = (try container.decodeIfPresent(String.self, forKey: .negative) as NSString?)?.boolValue ?? false
        }
    }

    struct Rule: Decodable {
        let matches: [Match]
        let replace: String
    }

    struct Pattern: Decodable {
        let find: String
        let replace: String
        let rules: [Rule]
    }

    let patterns: [Pattern]
    let vowel: String
    let consonant: String
    let casesensitive: String
    let number: String?

    static func load(resource name: String) -> PhoneticRules {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            fatalError("Missing bundle resource \(name).json")
        }
        do {
            return try JSONDecoder().decode(PhoneticRules.self, from: Data(contentsOf: url))
        } catch {
            fatalError("Could not load \(name).json: \(error)")
        }
    }
}

/// Longest-match, context-aware pattern substitution over romanised text.
///
/// This is the algorithm shared by `AvroParser` (produces Bengali text) and
/// `RegexParser` (produces a regular expression matching dictionary entries).
final class PhoneticEngine: Sendable {
    /// What to do with characters that are *not* in the rule set's `casesensitive` list.
    enum CaseSensitivePolicy {
        /// Keep them (lower-cased); case-sensitive ones are kept verbatim.
        case keep
        /// Drop case-sensitive characters from the input entirely.
        case drop
    }

    private let patterns: [String: PhoneticRules.Pattern]
    private let maxPatternLength: Int
    private let vowels: Set<Character>
    private let consonants: Set<Character>
    private let numbers: Set<Character>
    private let caseSensitive: Set<Character>
    private let replacementSuffix: String
    private let policy: CaseSensitivePolicy

    /// - Parameters:
    ///   - replacementSuffix: appended after every substituted chunk.
    ///   - policy: how case-sensitive characters are normalised before matching.
    init(rules: PhoneticRules, replacementSuffix: String = "", policy: CaseSensitivePolicy = .keep) {
        // Later duplicates win, which matches what the original binary search found.
        var table: [String: PhoneticRules.Pattern] = [:]
        for pattern in rules.patterns { table[pattern.find] = pattern }
        patterns = table
        maxPatternLength = rules.patterns.map { $0.find.count }.max() ?? 0
        vowels = Set(rules.vowel)
        consonants = Set(rules.consonant)
        numbers = Set(rules.number ?? "")
        caseSensitive = Set(rules.casesensitive)
        self.replacementSuffix = replacementSuffix
        self.policy = policy
    }

    // MARK: - Parsing

    func parse(_ input: String) -> String {
        guard !input.isEmpty else { return "" }

        let text = normalize(input)
        var output = ""
        var cursor = 0

        while cursor < text.count {
            let start = cursor
            var matched = false

            for chunkLength in stride(from: maxPatternLength, through: 1, by: -1) {
                let end = start + chunkLength
                guard end <= text.count, let pattern = patterns[String(text[start..<end])] else { continue }

                let rule = pattern.rules.first { rule in
                    rule.matches.allSatisfy { satisfies($0, in: text, start: start, end: end) }
                }
                output += (rule?.replace ?? pattern.replace) + replacementSuffix
                cursor = end
                matched = true
                break
            }

            if !matched {
                output.append(text[cursor])
                cursor += 1
            }
        }
        return output
    }

    /// Lower-cases everything except case-sensitive characters, which are kept or dropped per policy.
    func normalize(_ input: String) -> [Character] {
        var result: [Character] = []
        result.reserveCapacity(input.count)
        for character in input {
            if isCaseSensitive(character) {
                if policy == .keep { result.append(character) }
            } else {
                result.append(Self.asciiLowercased(character))
            }
        }
        return result
    }

    // MARK: - Match conditions

    private func satisfies(_ match: PhoneticRules.Match, in text: [Character], start: Int, end: Int) -> Bool {
        let isSuffix = match.type == .suffix
        let index = isSuffix ? end : start - 1
        let inBounds = isSuffix ? index < text.count : index >= 0

        let condition: Bool
        switch match.scope {
        case .punctuation:
            // The edges of the buffer count as punctuation.
            condition = !inBounds || isPunctuation(text[index])
        case .vowel:
            condition = inBounds && isVowel(text[index])
        case .consonant:
            condition = inBounds && isConsonant(text[index])
        case .number:
            condition = inBounds && isNumber(text[index])
        case .exact:
            let value = Array(match.value ?? "")
            let (from, to) = isSuffix ? (end, end + value.count) : (start - value.count, start)
            // Note: `to < text.count` (not `<=`) is inherited from the reference implementation:
            // an exact suffix match must be followed by at least one more character.
            condition = from >= 0 && to < text.count && Array(text[from..<to]) == value
        }
        return condition != match.negative
    }

    // MARK: - Character classes

    func isVowel(_ c: Character) -> Bool { vowels.contains(Self.asciiLowercased(c)) }
    func isConsonant(_ c: Character) -> Bool { consonants.contains(Self.asciiLowercased(c)) }
    func isNumber(_ c: Character) -> Bool { numbers.contains(Self.asciiLowercased(c)) }
    func isPunctuation(_ c: Character) -> Bool { !(isVowel(c) || isConsonant(c)) }
    func isCaseSensitive(_ c: Character) -> Bool { caseSensitive.contains(Self.asciiLowercased(c)) }

    /// Lower-cases ASCII letters only; everything else is returned unchanged.
    static func asciiLowercased(_ c: Character) -> Character {
        guard let ascii = c.asciiValue, ascii >= 65, ascii <= 90 else { return c }
        return Character(UnicodeScalar(ascii + 32))
    }
}
