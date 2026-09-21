//
//  AvroKeyboard
//
//  Copyright (c) 2012 OmicronLab. All rights reserved.
//

import Foundation

/// Three caches that make suggestions faster and smarter:
///
/// - **weight**: the candidate the user last picked for a term. Persisted to
///   `~/Library/Application Support/app.aminul.inputmethod.AvroKeyboard/weight.plist`.
/// - **phonetic**: the full suggestion list for a term, so it is computed once per session.
/// - **base**: for suffix-synthesised words, which (base term, base word) they came from,
///   so picking one also teaches the weight cache about the base.
final class CacheManager {
    static let shared = CacheManager()

    private var weightCache: [String: String]
    private var phoneticCache: [String: [String]] = [:]
    private var recentBaseCache: [String: (term: String, word: String)] = [:]

    private static let storageDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("app.aminul.inputmethod.AvroKeyboard")
    }()

    private static let weightFile = storageDirectory.appendingPathComponent("weight.plist")

    private init() {
        try? FileManager.default.createDirectory(at: Self.storageDirectory, withIntermediateDirectories: true)
        weightCache = (NSDictionary(contentsOf: Self.weightFile) as? [String: String]) ?? [:]
    }

    func persist() {
        (weightCache as NSDictionary).write(to: Self.weightFile, atomically: true)
    }

    // MARK: Weight (user selections)

    func string(forKey key: String) -> String? {
        weightCache[key]
    }

    func setString(_ string: String, forKey key: String) {
        weightCache[key] = string
    }

    func removeString(forKey key: String) {
        weightCache[key] = nil
    }

    // MARK: Phonetic (suggestion lists)

    func array(forKey key: String) -> [String]? {
        phoneticCache[key]
    }

    func setArray(_ array: [String], forKey key: String) {
        phoneticCache[key] = array
    }

    // MARK: Base (reverse suffix lookup)

    func removeAllBases() {
        recentBaseCache.removeAll()
    }

    func base(forKey key: String) -> (term: String, word: String)? {
        recentBaseCache[key]
    }

    func setBase(term: String, word: String, forKey key: String) {
        recentBaseCache[key] = (term, word)
    }
}
