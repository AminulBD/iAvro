//
//  AvroKeyboard
//
//  Copyright (c) 2026 Saiful Islam. All rights reserved.
//
//  This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
//  If a copy of the MPL was not distributed with this file, You can obtain one at
//  https://mozilla.org/MPL/2.0/.
//
//  Based on clsGenericLayoutOld.pas in Avro Keyboard for Windows,
//  Copyright (C) OmicronLab.
//

import Foundation

/// Full old style (typewriter) typing for the fixed layouts: ি, ে and ৈ are typed before
/// their consonant and the reph after it, and this puts the text in Unicode order.
///
/// Unlike Windows, ো is only made from ে and া, so the ো key types ও (হও, যাও), and a vowel
/// sign with nothing to carry it makes the full vowel (খাই).
enum OldStyleTyping {
    /// The text `units` type, each unit being what one key typed. The word is replayed from
    /// the start whenever it changes, so Delete is simply one key fewer.
    ///
    /// A prebase sign still waiting for its consonant stays last, until `atWordEnd`.
    static func reorder(_ units: [String], atWordEnd: Bool = false) -> String {
        var word = Word()
        for unit in units {
            word.type(Array(unit.unicodeScalars))
        }
        if atWordEnd {
            word.settle()
        }
        var result = ""
        result.unicodeScalars.append(contentsOf: word.text + (word.waiting.map { [$0] } ?? []))
        return result
    }
}

private struct Word {
    var text: [Unicode.Scalar] = []
    /// A prebase sign waiting for the consonant it goes after.
    var waiting: Unicode.Scalar?

    mutating func type(_ typed: [Unicode.Scalar]) {
        let key = typed == [oKar] ? [letterO] : typed
        let sign = key.count == 1 ? key[0] : nil

        if let sign, let vowel = fullVowels[sign], text.last == hasanta {
            text.removeLast()
            release()
            text.append(vowel)
        } else if sign == hasanta {
            // A prebase sign moves on to the end of the conjunct.
            if waiting == nil, let last = text.last, prebase.contains(last) {
                waiting = text.removeLast()
            }
            text.append(hasanta)
        } else if key == reph {
            if !carriesVowelSign {
                settle()
            }
            insertReph()
            release()
        } else if let sign, prebase.contains(sign) {
            // The same sign twice types it on its own; another one replaces it.
            if sign == waiting {
                release()
            } else {
                waiting = sign
            }
        } else if waiting != nil, isConsonant(key[0]) || (isPhala(key) && carriesVowelSign) {
            text += key
            release()
        } else if let sign, sign == aaKar || sign == auKar {
            if waiting == eKar {
                release()
            } else {
                settle()
            }
            appendLengthMark(sign)
        } else {
            settle()
            if let sign, let vowel = fullVowels[sign], !carriesVowelSign {
                text.append(vowel)
            } else if isPhala(key), let last = text.last, kars.contains(last) {
                // ্র, ্য and র‍্য go before the vowel sign of their consonant.
                text.removeLast()
                text += key + [last]
            } else {
                text += key
            }
        }
    }

    /// Ends the wait of a prebase sign with no consonant coming: it stays on the consonant
    /// before it, dropping a hasanta left waiting for one, or makes the full vowel.
    mutating func settle() {
        guard let kar = waiting else { return }
        if text.last == hasanta {
            text.removeLast()
        }
        if !carriesVowelSign {
            waiting = fullVowels[kar]
        }
        release()
    }

    /// Adds the waiting sign as it is.
    private mutating func release() {
        if let waiting {
            text.append(waiting)
        }
        waiting = nil
    }

    /// Adds া or ৌ, joining it to a ে before it, across a chandrabindu too, to make ো or ৌ,
    /// and া to অ to make আ.
    private mutating func appendLengthMark(_ mark: Unicode.Scalar) {
        let joined = mark == aaKar ? oKar : auKar
        if text.last == eKar {
            text.removeLast()
            text.append(carriesVowelSign ? joined : fullVowels[joined]!)
        } else if text.count >= 2, text.last == chandrabindu, text[text.count - 2] == eKar {
            text[text.count - 2] = joined
        } else if mark == aaKar, text.last == letterA {
            text[text.count - 1] = letterAA
        } else {
            text.append(carriesVowelSign ? mark : fullVowels[mark]!)
        }
    }

    /// য়, ড় and ঢ় end in a nukta. A hasanta, a chandrabindu or a joiner counts too, as a
    /// sign after one was typed on purpose.
    private var carriesVowelSign: Bool {
        guard let last = text.last else { return false }
        return isConsonant(last) || [nukta, hasanta, chandrabindu, zwj, zwnj].contains(last)
    }

    /// Puts a reph before the conjunct it was typed after, past any vowel sign and
    /// chandrabindu, or adds it as it is with no consonant to carry it.
    private mutating func insertReph() {
        var index = text.count - 1
        if index >= 0, text[index] == chandrabindu {
            index -= 1
        }
        if index >= 0, kars.contains(text[index]) {
            index -= 1
        }
        guard var start = consonantStart(endingAt: index) else {
            text += reph
            return
        }
        while start >= 2, text[start - 1] == hasanta, let previous = consonantStart(endingAt: start - 2) {
            start = previous
        }
        text.insert(contentsOf: reph, at: start)
    }

    /// Where the consonant ending at `index` starts: at `index`, or before its nukta.
    private func consonantStart(endingAt index: Int) -> Int? {
        guard index >= 0 else { return nil }
        if text[index] == nukta {
            return index >= 1 && isConsonant(text[index - 1]) ? index - 1 : nil
        }
        return isConsonant(text[index]) ? index : nil
    }
}

// MARK: - Characters

private let hasanta: Unicode.Scalar = "\u{09CD}"
private let reph: [Unicode.Scalar] = ["\u{09B0}", hasanta]
private let chandrabindu: Unicode.Scalar = "\u{0981}"
private let nukta: Unicode.Scalar = "\u{09BC}"
private let letterA: Unicode.Scalar = "\u{0985}"
private let letterAA: Unicode.Scalar = "\u{0986}"
private let letterO: Unicode.Scalar = "\u{0993}"
private let aaKar: Unicode.Scalar = "\u{09BE}"
private let eKar: Unicode.Scalar = "\u{09C7}"
private let oKar: Unicode.Scalar = "\u{09CB}"
private let auKar: Unicode.Scalar = "\u{09CC}"
private let zwj: Unicode.Scalar = "\u{200D}"
private let zwnj: Unicode.Scalar = "\u{200C}"

/// ি, ে and ৈ.
private let prebase: Set<Unicode.Scalar> = ["\u{09BF}", "\u{09C7}", "\u{09C8}"]

/// The full vowel of each vowel sign.
private let fullVowels: [Unicode.Scalar: Unicode.Scalar] = [
    "\u{09BE}": "\u{0986}", "\u{09BF}": "\u{0987}", "\u{09C0}": "\u{0988}",
    "\u{09C1}": "\u{0989}", "\u{09C2}": "\u{098A}", "\u{09C3}": "\u{098B}",
    "\u{09C7}": "\u{098F}", "\u{09C8}": "\u{0990}", "\u{09CB}": "\u{0993}",
    "\u{09CC}": "\u{0994}",
]

private let kars = Set(fullVowels.keys)

/// ক to হ, ড় ঢ় য়, and khanda ta.
private func isConsonant(_ scalar: Unicode.Scalar) -> Bool {
    (0x0995...0x09B9).contains(scalar.value) || [0x09CE, 0x09DC, 0x09DD, 0x09DF].contains(scalar.value)
}

/// A hasanta and a consonant typed by one key, like ্র and ্য, or র‍্য's with its joiner.
private func isPhala(_ key: [Unicode.Scalar]) -> Bool {
    let rest = key.first == zwj ? Array(key.dropFirst()) : key
    return rest.count >= 2 && rest[0] == hasanta && isConsonant(rest[1])
}
