//
//  AvroKeyboard
//
//  Copyright (c) 2012 OmicronLab. All rights reserved.
//

import Cocoa
import InputMethodKit

/// The single candidate window shared by every input session.
///
/// `IMKCandidates` fixes its panel type at creation (changing it later has no effect
/// since Mojave), so switching orientation in Preferences requires rebuilding the window.
enum Candidates {
    private static var server: IMKServer?
    private(set) static var shared: IMKCandidates?

    static func allocate(server: IMKServer) {
        self.server = server
        let candidates = IMKCandidates(server: server, panelType: Preferences.candidatePanelType)
        candidates?.setAttributes([IMKCandidatesSendServerKeyEventFirst: true])
        candidates?.setDismissesAutomatically(false)
        shared = candidates
    }

    /// Recreates the window with the orientation currently in Preferences.
    static func reallocate() {
        guard let server else { return }
        shared?.hide()
        allocate(server: server)
    }

    /// IMK parks the candidate panel at window level 20, so overlays like Spotlight — which
    /// float near `CGShieldingWindowLevel()`, the level Apple's own input-source HUD uses —
    /// cover the list while it is being typed into. IMK reapplies its own level on every
    /// `show(_:)`, so this has to run after each one.
    static func raiseAboveOverlayPanels() {
        let level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        for window in NSApp.windows where window is NSPanel && window.level != level {
            // `IMKCandidateWindow` on older systems, `IMKUIPanel` on current ones.
            guard NSStringFromClass(type(of: window)).hasPrefix("IMK") else { continue }
            window.level = level
        }
    }
}
