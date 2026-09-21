//
//  AvroKeyboard
//
//  Copyright (c) 2012 OmicronLab. All rights reserved.
//

import Foundation

/// Fixed spellings and emoticons from `autodict.plist`, keyed by romanised input.
final class AutoCorrect {
    static let shared = AutoCorrect()

    let entries: [String: String]

    private init() {
        if let url = Bundle.main.url(forResource: "autodict", withExtension: "plist"),
           let dictionary = NSDictionary(contentsOf: url) as? [String: String] {
            entries = dictionary
        } else {
            entries = [:]
        }
    }

    func find(_ term: String) -> String? {
        entries[AvroParser.shared.fix(term)]
    }
}
