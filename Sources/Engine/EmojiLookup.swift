//
//  AvroKeyboard
//
//  Copyright (c) 2012 OmicronLab. All rights reserved.
//

import Foundation

/// Emoji matching an English or Bangla keyword, from `emoji.json`: one entry per emoji with the
/// names and tags (English and Bangla, from Unicode CLDR via emojibase) that match it, in
/// standard emoji order.
final class EmojiLookup: Sendable {
    static let shared = EmojiLookup()

    private struct Entry: Decodable {
        let name: [String]
        let emoji: [String]
    }

    /// Keyword to emoji, built from the entries once at launch.
    private let index: [String: [String]]

    private init() {
        var index: [String: [String]] = [:]
        if let url = Bundle.main.url(forResource: "emoji", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let entries = try? JSONDecoder().decode([Entry].self, from: data) {
            for entry in entries {
                for name in entry.name {
                    index[name, default: []] += entry.emoji
                }
            }
        }
        self.index = index
    }

    /// Every emoji whose name or tags contain `term` as a word or whole tag.
    func find(_ term: String) -> [String] {
        index[term.lowercased()] ?? []
    }
}
