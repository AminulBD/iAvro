//
//  AvroKeyboard
//
//  Copyright (c) 2012 OmicronLab. All rights reserved.
//

import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let shared = AppDelegate()

    /// Shown by the system under the input source menu.
    let menu: NSMenu = {
        let menu = NSMenu(title: "Menu")
        let preferences = NSMenuItem(title: "Preferences...", action: #selector(AvroKeyboardController.showPreferences(_:)), keyEquivalent: "")
        preferences.tag = 1
        menu.addItem(preferences)
        return menu
    }()

    private lazy var preferencesWindowController = PreferencesWindowController()

    private override init() {
        super.init()
    }

    /// Loads the heavy singletons up front so the first keystroke is not delayed.
    func warmUp() {
        if Preferences.includeDictionary {
            NSLog("Loading Dictionary...")
            _ = Database.shared
            _ = RegexParser.shared
            _ = CacheManager.shared
        }
        _ = AutoCorrect.shared
    }

    func showPreferences() {
        guard let window = preferencesWindowController.window else { return }
        window.hidesOnDeactivate = false
        window.level = .modalPanel
        window.makeKeyAndOrderFront(self)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if Preferences.includeDictionary {
            CacheManager.shared.persist()
        }
    }
}
