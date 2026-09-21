//
//  AvroKeyboard
//
//  Copyright (c) 2012 OmicronLab. All rights reserved.
//

import Cocoa
import InputMethodKit

// Must match `InputMethodConnectionName` in Info.plist; periods and spaces are not allowed.
let connectionName = "Avro_Keyboard_Connection"

Preferences.registerDefaults()

guard let server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier) else {
    fatalError("Could not start the input method server")
}
Candidates.allocate(server: server)

let app = NSApplication.shared
app.delegate = AppDelegate.shared
AppDelegate.shared.warmUp()
app.run()
