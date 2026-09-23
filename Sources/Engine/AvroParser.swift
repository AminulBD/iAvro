//
//  AvroKeyboard
//
//  Copyright (c) 2012 OmicronLab. All rights reserved.
//

import Foundation

/// Converts romanised (Avro Phonetic) input into Bengali text using `data.json`.
final class AvroParser: Sendable {
    static let shared = AvroParser()

    private let engine = PhoneticEngine(rules: .load(resource: "data"))

    private init() {}

    func parse(_ string: String) -> String {
        engine.parse(string)
    }

    /// Normalises letter case the same way `parse` does, without transliterating.
    func fix(_ string: String) -> String {
        String(engine.normalize(string))
    }
}
