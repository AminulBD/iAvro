//
//  AvroKeyboard
//
//  Copyright (c) 2026 Aminul Islam. All rights reserved.
//

import Foundation

/// A fixed (non-phonetic) Bengali keyboard layout, where every key types its Bengali text
/// directly instead of going through the suggestion engine.
///
/// Keys are identified by the character a US QWERTY keyboard produces for them, which is
/// what InputMethodKit hands to `inputText(_:client:)`. Text is typed in logical (Unicode)
/// order: a vowel sign follows its consonant even when it is drawn before it.
struct FixedLayout {
    /// The text each key types.
    let keys: [String: String]

    /// A key that is held back as marked text until the next key arrives, and the text it
    /// stands for when that key does not combine with it.
    let deadKey: (key: String, text: String)?

    /// What a key types right after `deadKey`, replacing the dead key's own text.
    let afterDeadKey: [String: String]

    /// Probhat, as shipped with Avro Keyboard for Windows (without the AltGr layer).
    static let probhat = FixedLayout(
        keys: [
            "`": "\u{200D}", "~": "~",
            "1": "১", "2": "২", "3": "৩", "4": "৪", "5": "৫",
            "6": "৬", "7": "৭", "8": "৮", "9": "৯", "0": "০",
            "$": "৳", "&": "ঞ", "*": "ৎ",

            "q": "দ", "Q": "ধ",
            "w": "ূ", "W": "ঊ",
            "e": "ী", "E": "ঈ",
            "r": "র", "R": "ড়",
            "t": "ট", "T": "ঠ",
            "y": "এ", "Y": "ঐ",
            "u": "ু", "U": "উ",
            "i": "ি", "I": "ই",
            "o": "ও", "O": "ঔ",
            "p": "প", "P": "ফ",
            "[": "ে", "{": "ৈ",
            "]": "ো", "}": "ৌ",
            "\\": "\u{200C}", "|": "॥",

            "a": "া", "A": "অ",
            "s": "স", "S": "ষ",
            "d": "ড", "D": "ঢ",
            "f": "ত", "F": "থ",
            "g": "গ", "G": "ঘ",
            "h": "হ", "H": "ঃ",
            "j": "জ", "J": "ঝ",
            "k": "ক", "K": "খ",
            "l": "ল", "L": "ং",

            "z": "য়", "Z": "য",
            "x": "শ", "X": "ঢ়",
            "c": "চ", "C": "ছ",
            "v": "আ", "V": "ঋ",
            "b": "ব", "B": "ভ",
            "n": "ন", "N": "ণ",
            "m": "ম", "M": "ঙ",
            "<": "ৃ",
            ".": "।", ">": "ঁ",
            "/": "্",
        ],
        deadKey: nil,
        afterDeadKey: [:]
    )

    /// Unijoy, following the m17n `bn-unijoy` table (without the Option layer).
    ///
    /// `g` is the hasanta (virama). Typed before a vowel-sign key it forms the independent
    /// vowel instead, so `g` `f` gives আ; `g` `g` gives a visible hasanta.
    static let unijoy = FixedLayout(
        keys: [
            "`": "‘", "~": "“",
            "1": "১", "2": "২", "3": "৩", "4": "৪", "5": "৫",
            "6": "৬", "7": "৭", "8": "৮", "9": "৯", "0": "০",
            "$": "৳", "&": "ঁ", "_": "—",

            "q": "ঙ", "Q": "ং",
            "w": "য", "W": "য়",
            "e": "ড", "E": "ঢ",
            "r": "প", "R": "ফ",
            "t": "ট", "T": "ঠ",
            "y": "চ", "Y": "ছ",
            "u": "জ", "U": "ঝ",
            "i": "হ", "I": "ঞ",
            "o": "গ", "O": "ঘ",
            "p": "ড়", "P": "ঢ়",
            "\\": "ৎ", "|": "ঃ",

            "a": "ৃ", "A": "র্",
            "s": "ু", "S": "ূ",
            "d": "ি", "D": "ী",
            "f": "া", "F": "অ",
            "G": "।",
            "h": "ব", "H": "ভ",
            "j": "ক", "J": "খ",
            "k": "ত", "K": "থ",
            "l": "দ", "L": "ধ",
            "'": "’", "\"": "”",

            "z": "্র", "Z": "্য",
            "x": "ো", "X": "ৌ",
            "c": "ে", "C": "ৈ",
            "v": "র", "V": "ল",
            "b": "ন", "B": "ণ",
            "n": "স", "N": "ষ",
            "m": "ম", "M": "শ",
        ],
        deadKey: (key: "g", text: "্"),
        afterDeadKey: [
            "f": "আ",
            "d": "ই", "D": "ঈ",
            "s": "উ", "S": "ঊ",
            "a": "ঋ",
            "c": "এ", "C": "ঐ",
            "x": "ও", "X": "ঔ",
            "g": "্\u{200C}",
            "G": "॥",
        ]
    )
}
