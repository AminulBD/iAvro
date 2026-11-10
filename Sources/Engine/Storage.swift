//
//  AvroKeyboard
//
//  Copyright (c) 2012 OmicronLab. All rights reserved.
//

import Foundation

/// Where per-user data is kept:
/// `~/Library/Application Support/app.aminul.inputmethod.AvroKeyboard`.
enum Storage {
    static let directory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("app.aminul.inputmethod.AvroKeyboard")
    }()

    /// The file `name` in the storage directory, creating the directory if needed.
    static func file(_ name: String) -> URL {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(name)
    }
}
