//
//  AvroKeyboard
//
//  Copyright (c) 2012 OmicronLab. All rights reserved.
//

import Foundation
import InputMethodKit

/// Typed access to the user defaults declared in `preferences.plist`.
enum Preferences {
    enum Key {
        static let keyboardLayout = "KeyboardLayout"
        static let candidatePanelType = "CandidatePanelType"
        static let includeDictionary = "IncludeDictionary"
        static let commitNewLineOnEnter = "CommitNewLineOnEnter"
    }

    /// Registers the defaults shipped in `preferences.plist`, for both `UserDefaults`
    /// and the bindings-facing `NSUserDefaultsController`.
    static func registerDefaults() {
        guard let url = Bundle.main.url(forResource: "preferences", withExtension: "plist"),
              let defaults = NSDictionary(contentsOf: url) as? [String: Any] else { return }
        UserDefaults.standard.register(defaults: defaults)
        NSUserDefaultsController.shared.initialValues = defaults
    }

    /// How keystrokes become Bengali text. Stored as the raw value so the Preferences
    /// pop-up can bind to it by tag.
    enum KeyboardLayout: Int, CaseIterable {
        case phonetic = 0
        case probhat = 1
        case unijoy = 2

        var title: String {
            switch self {
            case .phonetic: return "Avro Phonetic"
            case .probhat: return "Probhat"
            case .unijoy: return "Unijoy"
            }
        }

        /// The key map for a fixed layout, or nil for phonetic typing.
        var fixedLayout: FixedLayout? {
            switch self {
            case .phonetic: return nil
            case .probhat: return .probhat
            case .unijoy: return .unijoy
            }
        }
    }

    static var keyboardLayout: KeyboardLayout {
        KeyboardLayout(rawValue: UserDefaults.standard.integer(forKey: Key.keyboardLayout)) ?? .phonetic
    }

    /// Orientation of the candidate window. Defaults to `kIMKSingleRowSteppingCandidatePanel`
    /// (the native macOS transliteration bar: a horizontal 9-column row placed below the caret);
    /// `kIMKSingleColumnScrollingCandidatePanel` gives the vertical column instead.
    static var candidatePanelType: IMKCandidatePanelType {
        IMKCandidatePanelType(UserDefaults.standard.integer(forKey: Key.candidatePanelType))
    }

    static var includeDictionary: Bool {
        UserDefaults.standard.bool(forKey: Key.includeDictionary)
    }

    static var commitNewLineOnEnter: Bool {
        UserDefaults.standard.bool(forKey: Key.commitNewLineOnEnter)
    }
}
