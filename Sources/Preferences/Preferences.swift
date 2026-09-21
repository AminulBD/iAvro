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
