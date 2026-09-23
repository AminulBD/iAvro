//
//  AvroKeyboard
//
//  Copyright (c) 2012 OmicronLab. All rights reserved.
//

import Foundation

/// Converts romanised input into a regular expression that matches every Bengali
/// spelling the input could stand for, using `regex.json`. Used for dictionary lookup.
final class RegexParser: Sendable {
    static let shared = RegexParser()

    /// Allows an optional য-ফলা/ব-ফলা/ম-ফলা, hasanta, and visarga/chandrabindu after each unit.
    private static let optionalMarks = "(্[যবম])?(্?)([ঃঁ]?)"

    private let engine = PhoneticEngine(rules: .load(resource: "regex"),
                                        replacementSuffix: RegexParser.optionalMarks,
                                        policy: .drop)

    private init() {}

    func parse(_ string: String) -> String {
        engine.parse(string)
    }
}
