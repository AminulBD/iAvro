//
//  AvroKeyboard
//
//  This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
//  If a copy of the MPL was not distributed with this file, You can obtain one at
//  https://mozilla.org/MPL/2.0/.
//
//  Ported from clsUnicodeToBijoy2000.pas in Avro Keyboard for Windows,
//  Copyright (C) OmicronLab.
//

import Foundation

/// Converts Unicode Bengali to Bijoy ANSI, the encoding used by SutonnyMJ and other Bijoy
/// fonts, where each code point names a glyph rather than a character.
///
/// Bijoy stores glyphs in the order they are drawn, so pre-base vowel signs (ি ে ৈ) move
/// ahead of their consonant cluster, reph moves after it, and conjuncts become precomposed
/// or half-form glyphs. The passes below follow Avro Keyboard for Windows step by step;
/// their order matters, as later passes look at what earlier ones produced.
enum Bijoy {
    static func convert(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        var converter = Converter(text)
        converter.deNormalize()
        converter.rearrangeKars()
        converter.rearrangeReph()
        converter.replaceKarsAndVowels()
        converter.convertFolasAndHasanta()
        converter.replaceFullForms()
        converter.firstHalfForms()
        converter.secondHalfForms()
        converter.consonants()
        converter.finalTouch()
        return converter.text
    }
}

private let hasanta: Unicode.Scalar = "\u{9CD}"
private let zwj: Unicode.Scalar = "\u{200D}"
private let zwnj: Unicode.Scalar = "\u{200C}"
private let joiners: Set<Unicode.Scalar> = [hasanta, zwj, zwnj]

private let pureConsonants: Set<Unicode.Scalar> = [
    "ক", "খ", "গ", "ঘ", "ঙ", "চ", "ছ", "জ", "ঝ", "ঞ", "ট", "ঠ", "ড", "ঢ", "ণ",
    "ত", "থ", "দ", "ধ", "ন", "প", "ফ", "ব", "ভ", "ম", "য", "র", "ল", "শ", "ষ", "স", "হ",
    "\u{9DC}", "\u{9DD}", "\u{9DF}", "ৎ", "ৰ", "ৱ",
]

/// Consonants whose right edge sits on the baseline, which picks the shape of a following
/// u-kar, uu-kar, ri-kar or la-phala.
private let baseLineRight: Set<Unicode.Scalar> = [
    "খ", "গ", "ঘ", "ণ", "থ", "দ", "ধ", "ন", "প", "ব", "ম", "য", "র", "ল", "শ", "ষ", "স", "হ", "\u{9DF}",
]

private struct Converter {
    private var s: [Unicode.Scalar]

    init(_ text: String) {
        s = Array(text.unicodeScalars)
    }

    var text: String {
        var view = String.UnicodeScalarView()
        view.append(contentsOf: s)
        return String(view)
    }

    // MARK: - Helpers

    private func at(_ i: Int) -> Unicode.Scalar? {
        s.indices.contains(i) ? s[i] : nil
    }

    /// Whether `pattern` occurs at `i`.
    private func matches(_ pattern: String, at i: Int) -> Bool {
        let p = Array(pattern.unicodeScalars)
        guard i >= 0, i + p.count <= s.count else { return false }
        return s[i..<i + p.count].elementsEqual(p)
    }

    private func firstIndex(of pattern: String) -> Int? {
        let count = pattern.unicodeScalars.count
        guard count > 0, s.count >= count else { return nil }
        return (0...s.count - count).first { matches(pattern, at: $0) }
    }

    private mutating func splice(_ i: Int, _ length: Int, _ replacement: String) {
        s.replaceSubrange(i..<i + length, with: replacement.unicodeScalars)
    }

    /// Replaces every occurrence of `pattern`, left to right.
    private mutating func replace(_ pattern: String, _ replacement: String) {
        let count = pattern.unicodeScalars.count
        var i = 0
        while i + count <= s.count {
            if matches(pattern, at: i) {
                splice(i, count, replacement)
                i += replacement.unicodeScalars.count
            } else {
                i += 1
            }
        }
    }

    /// Repeatedly finds the first `pattern` and lets `body` rewrite it, looking at its
    /// surroundings. `body` must remove the pattern, or this never ends.
    private mutating func rewriteEach(_ pattern: String, _ body: (inout Converter, Int) -> Void) {
        while let i = firstIndex(of: pattern) {
            body(&self, i)
        }
    }

    // MARK: - Passes

    mutating func deNormalize() {
        replace("\u{9AF}\u{9BC}", "\u{9DF}")
        replace("\u{9A1}\u{9BC}", "\u{9DC}")
        replace("\u{9A2}\u{9BC}", "\u{9DD}")
    }

    /// Splits o-kar and ou-kar, then moves i-kar, e-kar and oi-kar ahead of their
    /// consonant cluster.
    mutating func rearrangeKars() {
        replace("\u{9CB}", "\u{9C7}\u{9BE}")
        replace("\u{9CC}", "\u{9C7}\u{9D7}")

        let movable: Set<Unicode.Scalar> = ["\u{9C7}", "\u{9BF}", "\u{9C8}"]
        var result: [Unicode.Scalar] = []
        var pendingKar: Unicode.Scalar?
        for i in s.indices.reversed() {
            let c = s[i]
            if movable.contains(c) {
                pendingKar = c
                continue
            }
            guard let kar = pendingKar else {
                result.insert(c, at: 0)
                continue
            }
            if i == 0 {
                result.insert(contentsOf: [kar, c], at: 0)
                pendingKar = nil
            } else if !pureConsonants.contains(c) && !joiners.contains(c) {
                result.insert(contentsOf: [c, kar], at: 0)
                pendingKar = nil
            } else if joiners.contains(c) {
                result.insert(c, at: 0)
            } else if joiners.contains(s[i - 1]) {
                result.insert(c, at: 0)
            } else {
                result.insert(contentsOf: [kar, c], at: 0)
                pendingKar = nil
            }
        }
        // A kar typed before any consonant stays where it is.
        if let kar = pendingKar {
            result.insert(kar, at: 0)
        }
        s = result

        replace("“", "Ò")
        replace("”", "Ó")
        replace("‘", "Ô")
        replace("’", "Õ")
    }

    /// Moves reph (র্) after the consonant cluster it sits on.
    mutating func rearrangeReph() {
        guard s.count >= 3 else { return }
        let reph: Unicode.Scalar = "©"
        var result: [Unicode.Scalar] = []
        var pending = false
        var i = 0
        while i < s.count {
            let c = s[i]
            let movable = i + 2 < s.count && c == "র" && s[i + 1] == hasanta && s[i + 2] != zwj && s[i + 2] != zwnj
            if movable {
                pending = true
                i += 2
                continue
            }
            if !pending {
                result.append(c)
            } else if !pureConsonants.contains(c) && !joiners.contains(c) {
                result.append(contentsOf: [reph, c])
                pending = false
            } else if i + 1 >= s.count {
                result.append(contentsOf: [c, reph])
                pending = false
            } else if joiners.contains(c) {
                result.append(c)
            } else if joiners.contains(s[i + 1]) {
                result.append(c)
            } else {
                result.append(contentsOf: [c, reph])
                pending = false
            }
            i += 1
        }
        s = result
    }

    mutating func replaceKarsAndVowels() {
        let wordStart: Set<Unicode.Scalar> = [" ", "\r", "\n", "\t"]
        rewriteEach("\u{9C7}") { c, i in
            c.s[i] = i == 0 || wordStart.contains(c.s[i - 1]) ? "†" : "‡"
        }
        rewriteEach("\u{9C8}") { c, i in
            c.s[i] = i == 0 || wordStart.contains(c.s[i - 1]) ? "ˆ" : "‰"
        }

        // U-kar
        replace("গু", "¸")
        replace("শু", "ï")
        replace("হু", "û")
        replace("্তু", "্‘")
        let rPhalaBelowU = ["শ্র", "দ্র", "গ্র", "ত্র", "জ্র", "থ্র", "ধ্র", "প্র", "ব্র", "ভ্র", "ম্র", "স্র"]
        let rPhalaBelowULong = ["ন্দ্র", "ম্প্র", "ষ্প্র", "স্প্র"]
        let lPhalaBelowU = ["গ্ল", "প্ল", "ব্ল", "শ্ল", "স্ল"]
        let lPhalaBelowULong = ["স্প্ল"]
        func follows(_ c: Converter, _ i: Int, _ short: [String], _ long: [String]) -> Bool {
            short.contains { c.matches($0, at: i - 3) } || long.contains { c.matches($0, at: i - 5) }
        }
        rewriteEach("\u{9C1}") { c, i in
            guard i >= 1 else { c.s[i] = "z"; return }
            let previous = c.s[i - 1]
            if baseLineRight.contains(previous) {
                if previous == "র" {
                    c.s[i] = follows(c, i, rPhalaBelowU, rPhalaBelowULong) || c.at(i - 2) != hasanta ? "“" : "y"
                } else if previous == "ল" {
                    c.s[i] = follows(c, i, lPhalaBelowU, lPhalaBelowULong) ? "“" : "y"
                } else {
                    c.s[i] = "y"
                }
                if c.matches("ষ্ণ", at: i - 3) {
                    c.s[i] = "z"
                }
            } else {
                c.s[i] = previous == "\u{9DC}" || previous == "\u{9DD}" ? "–" : "z"
            }
        }

        // UU-kar
        rewriteEach("\u{9C2}") { c, i in
            guard i >= 1 else { c.s[i] = "‚"; return }
            let previous = c.s[i - 1]
            if baseLineRight.contains(previous) {
                if previous == "র" {
                    c.s[i] = follows(c, i, rPhalaBelowU, rPhalaBelowULong) || c.at(i - 2) != hasanta ? "ƒ" : "~"
                } else if previous == "ল" {
                    c.s[i] = follows(c, i, lPhalaBelowU, lPhalaBelowULong) ? "ƒ" : "~"
                } else {
                    c.s[i] = "~"
                }
            } else {
                c.s[i] = "‚"
            }
        }

        // Ri-kar
        replace("হৃ", "ü")
        rewriteEach("\u{9C3}") { c, i in
            c.s[i] = i >= 1 && baseLineRight.contains(c.s[i - 1]) ? "„" : "…"
        }

        replace("\u{9BE}", "v")
        replace("\u{9BF}", "w")
        replace("\u{9C0}", "x")
        replace("\u{9D7}", "Š")

        replace("অ", "A")
        replace("আ", "Av")
        replace("ই", "B")
        replace("ঈ", "C")
        replace("উ", "D")
        replace("ঊ", "E")
        replace("ঋ", "F")
        replace("এ", "G")
        replace("ঐ", "H")
        replace("ও", "I")
        replace("ঔ", "J")
    }

    mutating func convertFolasAndHasanta() {
        replace("্য", "¨")
        replace("্\u{200C}", "&")

        rewriteEach("্র") { c, i in
            switch c.at(i - 1) {
            case "প", "গ":
                c.splice(i, 2, "Ö")
            case "ভ":
                if c.at(i - 2) == hasanta {
                    c.splice(i - 1, 3, "£")
                } else {
                    c.splice(i - 1, 3, "å")
                }
            case "ক":
                if c.at(i - 2) == hasanta {
                    c.splice(i - 1, 3, "Œ")
                } else {
                    c.splice(i - 1, 3, "µ")
                }
            case "ত":
                if c.at(i - 2) == hasanta {
                    if c.at(i - 3) == "ক" || c.at(i - 3) == "ত" {
                        c.splice(i, 2, "«")
                    } else {
                        c.splice(i - 1, 3, "¿")
                    }
                } else {
                    c.splice(i - 1, 3, "Î")
                }
            case "ফ":
                c.splice(i, 2, "«")
            default:
                c.splice(i, 2, "ª")
            }
        }
    }

    mutating func replaceFullForms() {
        for (digit, ascii) in zip("০১২৩৪৫৬৭৮৯", "0123456789") {
            replace(String(digit), String(ascii))
        }

        replace("৳", "$")
        replace("।", "|")
        replace("॥", "\\")

        replace("ৎ", "r")
        replace("ং", "s")
        replace("ঃ", "t")
        replace("ঁ", "u")

        let fullForms: KeyValuePairs<String, String> = [
            "ক্ক": "°", "ক্ট": "±", "ক্ষ্ম": "²", "ক্ত": "³", "ক্ম": "´", "ক্ষ": "¶", "ক্স": "·",
            "গ্গ": "¹", "গ্দ": "º", "গ্ধ": "»",
            "ঙ্ক": "¼", "ঙ্গ": "½",
            "জ্জ": "¾", "জ্ঝ": "À", "জ্ঞ": "Á",
            "ঞ্চ": "Â", "ঞ্ছ": "Ã", "ঞ্জ": "Ä", "ঞ্ঝ": "Å",
            "ট্ট": "Æ", "ড্ড": "Ç",
            "ণ্ট": "È", "ণ্ঠ": "É", "ণ্ড": "Ê",
            "ত্ত": "Ë", "ত্থ": "Ì", "ত্ম": "Í",
            "দ্দ": "Ï", "দ্ধ": "×", "দ্ব": "Ø", "দ্ম": "Ù",
            "ন্ঠ": "Ú", "ন্ড": "Û", "ন্ধ": "Ü", "ন্স": "Ý",
            "প্ট": "Þ", "প্ত": "ß", "প্প": "à", "প্স": "á",
            "ব্জ": "â", "ব্দ": "ã", "ব্ধ": "ä",
            "ম্ন": "æ", "ম্ফ": "ç",
            "ল্ক": "é", "ল্গ": "ê", "ল্ট": "ë", "ল্ড": "ì", "ল্প": "í", "ল্ফ": "î",
            "শ্চ": "ð", "শ্ছ": "ñ",
            "ষ্ণ": "ò", "ষ্ট": "ó", "ষ্ঠ": "ô", "ষ্ফ": "õ",
            "স্খ": "ö", "স্ট": "÷", "স্ন": "ø", "স্ফ": "ù",
            "হ্ন": "ý", "হ্ম": "þ",
            "\u{9DC}্গ": "ÿ",
        ]
        for (conjunct, glyph) in fullForms {
            replace(conjunct, glyph)
        }
    }

    /// Consonants that take a special shape when they start a conjunct.
    mutating func firstHalfForms() {
        replace("ম্", "¤্")
        replace("ষ্", "®্")
        replace("চ্", "”্")
        replace("ঙ্", "•্")
        replace("স্", "¯্")

        rewriteEach("দ্") { c, i in
            c.s[i] = c.at(i + 2) == "গ" ? "˜" : "™"
        }
        rewriteEach("ন্") { c, i in
            switch c.at(i + 2) {
            case "ত", "থ", "ল", "ব", "¿", "‘": c.s[i] = "š"
            case "ম", "ন": c.s[i] = "b"
            default: c.s[i] = "›"
            }
        }
    }

    /// Consonants that take a special shape when they end a conjunct.
    mutating func secondHalfForms() {
        replace("্ভ", "¢")
        replace("্ত", "—")
        replace("্থ", "’")
        replace("্ক", "‹")

        rewriteEach("্ব") { c, i in
            switch c.at(i - 1) {
            case "স", "ষ", "ম", "ন", "দ", "¤", "®", "¯", "š", "™": c.splice(i, 2, "^")
            case "ধ", "ব", "হ": c.splice(i, 2, "Ÿ")
            case "শ", "গ", "প": c.splice(i, 2, "¦")
            default: c.splice(i, 2, "¡")
            }
        }
        rewriteEach("্ম") { c, i in
            switch c.at(i - 1) {
            case "¤", "®", "”", "¯", "™", "š", "›": c.splice(i, 2, "§")
            case "•": c.splice(i, 2, "g")
            default: c.splice(i, 2, "¥")
            }
        }
        rewriteEach("্ল") { c, i in
            c.splice(i, 2, c.at(i - 1).map(baseLineRight.contains) == true ? "−" : "¬")
        }

        replace("্ণ", "è")
        replace("্ন", "œ")
    }

    mutating func consonants() {
        let map: KeyValuePairs<Unicode.Scalar, Unicode.Scalar> = [
            "ক": "K", "খ": "L", "গ": "M", "ঘ": "N", "ঙ": "O",
            "চ": "P", "ছ": "Q", "জ": "R", "ঝ": "S", "ঞ": "T",
            "ট": "U", "ঠ": "V", "ড": "W", "ঢ": "X", "ণ": "Y",
            "ত": "Z", "থ": "_", "দ": "`", "ধ": "a", "ন": "b",
            "প": "c", "ফ": "d", "ব": "e", "ভ": "f", "ম": "g",
            "য": "h", "র": "i", "ল": "j", "শ": "k", "ষ": "l", "স": "m", "হ": "n",
            "\u{9DF}": "q", "\u{9DC}": "o", "\u{9DD}": "p",
        ]
        let lookup = Dictionary(uniqueKeysWithValues: map.map { ($0.key, $0.value) })
        s = s.map { lookup[$0] ?? $0 }
    }

    mutating func finalTouch() {
        s.removeAll { joiners.contains($0) }
        replace("nè", "nœ")
        replace("Kœ", "Kè")
        replace("¶y", "¶z")
        replace("Rz", "Ry")
        replace("R‚", "R~")
        replace("R…", "R„")
    }
}
