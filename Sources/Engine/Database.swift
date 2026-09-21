//
//  AvroKeyboard
//
//  Copyright (c) 2012 OmicronLab. All rights reserved.
//

import Foundation
import SQLite3

/// The bundled Bengali word list (`database.db3`), loaded into memory once.
///
/// Words are grouped into tables by their leading sound (e.g. `KH`, `NGA`); a lookup
/// scans only the tables that could start with the typed letter.
final class Database {
    static let shared = Database()

    private static let wordTables = [
        "A", "AA", "B", "BH", "C", "CH", "D", "Dd", "Ddh", "Dh", "E", "G", "Gh", "H", "I", "II",
        "J", "JH", "K", "KH", "Khandatta", "L", "M", "N", "NGA", "NN", "NYA", "O", "OI", "OU",
        "P", "PH", "R", "RR", "RRH", "RRI", "S", "SH", "SS", "T", "TH", "TT", "TTH", "U", "UU", "Y", "Z",
    ]

    /// Which word tables to search for a given (lower-cased) leading letter.
    private static let tablesForLeadingLetter: [Character: [String]] = [
        "a": ["a", "aa", "e", "oi", "o", "nya", "y"],
        "b": ["b", "bh"],
        "c": ["c", "ch", "k"],
        "d": ["d", "dh", "dd", "ddh"],
        "e": ["i", "ii", "e", "y"],
        "f": ["ph"],
        "g": ["g", "gh", "j"],
        "h": ["h"],
        "i": ["i", "ii", "y"],
        "j": ["j", "jh", "z"],
        "k": ["k", "kh"],
        "l": ["l"],
        "m": ["h", "m"],
        "n": ["n", "nya", "nga", "nn"],
        "o": ["a", "u", "uu", "oi", "o", "ou", "y"],
        "p": ["p", "ph"],
        "q": ["k"],
        "r": ["rri", "h", "r", "rr", "rrh"],
        "s": ["s", "sh", "ss"],
        "t": ["t", "th", "tt", "tth", "khandatta"],
        "u": ["u", "uu", "y"],
        "v": ["bh"],
        "w": ["o"],
        "x": ["e", "k"],
        "y": ["i", "y"],
        "z": ["h", "j", "jh", "z"],
    ]

    /// Words keyed by lower-cased table name. Stored as `NSString` so that
    /// `NSRegularExpression` can scan them without re-bridging on every keystroke.
    private var words: [String: [NSString]] = [:]
    private var suffixes: [String: String] = [:]

    private init() {
        guard let path = Bundle.main.path(forResource: "database", ofType: "db3") else {
            fatalError("Missing bundle resource database.db3")
        }
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            fatalError("Could not open database.db3: \(String(cString: sqlite3_errmsg(db)))")
        }
        defer { sqlite3_close(db) }

        for table in Self.wordTables {
            words[table.lowercased()] = query(db, "SELECT Words FROM \(table)").map { $0[0] as NSString }
        }
        for row in query(db, "SELECT English, Bangla FROM Suffix") {
            suffixes[row[0]] = row[1]
        }
    }

    private func query(_ db: OpaquePointer, _ sql: String) -> [[String]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            fatalError("Bad query '\(sql)': \(String(cString: sqlite3_errmsg(db)))")
        }
        defer { sqlite3_finalize(statement) }

        let columnCount = Int(sqlite3_column_count(statement))
        var rows: [[String]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append((0..<columnCount).map { column in
                sqlite3_column_text(statement, Int32(column)).map { String(cString: $0) } ?? ""
            })
        }
        return rows
    }

    /// Dictionary words that the romanised `term` could spell, in table order, without duplicates.
    func find(_ term: String) -> [String] {
        guard let leading = term.lowercased().first, let tables = Self.tablesForLeadingLetter[leading] else {
            return []
        }
        let pattern = "^" + RegexParser.shared.parse(term) + "$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        var seen = Set<String>()
        var matches: [String] = []
        for table in tables {
            for word in words[table] ?? [] {
                let range = NSRange(location: 0, length: word.length)
                guard regex.firstMatch(in: word as String, range: range) != nil else { continue }
                let string = word as String
                if seen.insert(string).inserted { matches.append(string) }
            }
        }
        return matches
    }

    /// The Bengali form of a romanised suffix (e.g. `"er"` → `"ের"`), if it is a known suffix.
    func banglaForSuffix(_ suffix: String) -> String? {
        suffixes[suffix]
    }
}
