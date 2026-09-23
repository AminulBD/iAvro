//
//  AvroKeyboard
//
//  Copyright (c) 2012 OmicronLab. All rights reserved.
//

import Cocoa
import Carbon.HIToolbox

/// Offers to copy the app into `~/Library/Input Methods` when it is launched from
/// somewhere else (the DMG, Downloads, ...). This is how a user "installs" from the
/// disk image: double-click the app and accept the prompt.
@MainActor
enum Installer {
    private static let folderName = "Input Methods"

    private static var userFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/\(folderName)")
    }

    /// True when the bundle already lives in a folder macOS scans for input methods.
    static var isInstalled: Bool {
        let parent = Bundle.main.bundleURL.deletingLastPathComponent().resolvingSymlinksInPath().path
        return [userFolder, URL(fileURLWithPath: "/Library/\(folderName)")]
            .contains { $0.resolvingSymlinksInPath().path == parent }
    }

    /// Prompts to install if the app is not already in an Input Methods folder. Returns
    /// only if the app should carry on starting as an input method; otherwise exits.
    static func offerIfNeeded() {
        #if DEBUG
        // Xcode runs debug builds from DerivedData; do not nag on every launch.
        return
        #else
        guard !isInstalled else { return }

        let destination = userFolder.appendingPathComponent(Bundle.main.bundleURL.lastPathComponent)
        let replacing = FileManager.default.fileExists(atPath: destination.path)

        // Input methods are background-only, so the app has to be made activatable
        // before a modal alert can come to the front.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = replacing ? "Update Avro Keyboard?" : "Install Avro Keyboard?"
        alert.informativeText = "Avro Keyboard needs to live in your Input Methods folder before macOS can use it.\n\n"
            + (replacing
               ? "The copy already in ~/Library/Input Methods will be replaced with this one."
               : "It will be copied to ~/Library/Input Methods, for your user only.")
        alert.addButton(withTitle: replacing ? "Update" : "Install")
        alert.addButton(withTitle: "Quit")
        guard alert.runModal() == .alertFirstButtonReturn else { exit(0) }

        do {
            try install(to: destination)
        } catch {
            let failure = NSAlert(error: error)
            failure.messageText = "Avro Keyboard could not be installed"
            failure.informativeText = error.localizedDescription
                + "\n\nYou can install it by hand: copy Avro Keyboard into ~/Library/Input Methods, then log out and back in."
            failure.runModal()
            exit(1)
        }

        let done = NSAlert()
        done.messageText = replacing ? "Avro Keyboard was updated" : "Avro Keyboard was installed"
        done.informativeText = replacing
            ? "Log out and back in so macOS starts using the new version."
            : "It has been added to your input sources. Switch to it from the input menu in the menu bar.\n\n"
              + "If it is missing there, log out and back in, then add it under System Settings > Keyboard > Input Sources."
        done.runModal()
        exit(0)
        #endif
    }

    private static func install(to destination: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: userFolder, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        // ditto keeps the bundle intact (signature, resource forks) and --noqtn leaves the
        // quarantine flag behind so the installed copy is not app-translocated on launch.
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["--noqtn", Bundle.main.bundlePath, destination.path]
        try ditto.run()
        ditto.waitUntilExit()
        guard ditto.terminationStatus == 0 else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError, userInfo: [
                NSLocalizedDescriptionKey: "Copying the app failed (ditto exited with \(ditto.terminationStatus)).",
            ])
        }

        // Tell Text Input Sources about the new bundle right away, so it shows up
        // without logging out, and enable it for the current user.
        guard TISRegisterInputSource(destination as CFURL) == noErr else {
            NSLog("TISRegisterInputSource failed for \(destination.path); it will be picked up at next login")
            return
        }
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
        let filter = [kTISPropertyInputSourceID as String: bundleIdentifier] as CFDictionary
        if let sources = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource],
           let source = sources.first {
            let status = TISEnableInputSource(source)
            if status != noErr {
                NSLog("TISEnableInputSource failed (\(status)); add it manually under Input Sources")
            }
        }
    }
}
