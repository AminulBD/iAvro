//
//  AvroKeyboard
//
//  Copyright (c) 2012 OmicronLab. All rights reserved.
//

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
}
