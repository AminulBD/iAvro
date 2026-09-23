//
//  AvroKeyboard
//
//  Copyright (c) 2012 OmicronLab. All rights reserved.
//

import Cocoa
import InputMethodKit

/// One instance per client text field: routes keystrokes into a `Composition`, mirrors it
/// into the client as marked text, and drives the shared candidate window.
///
/// Space or Enter commits the highlighted candidate; arrow keys move through candidates.
@objc(AvroKeyboardController)
final class AvroKeyboardController: IMKInputController {
    private let composition = Composition()
    private var usedArrowKeys = false
    /// Text of a fixed layout's dead key, shown as marked text until the next key decides it.
    private var heldDeadKey: String?

    // MARK: - Candidate window

    private func updateCandidatesPanel() {
        guard !composition.candidates.isEmpty else {
            Candidates.shared?.hide()
            return
        }
        if Candidates.shared?.panelType() != Preferences.candidatePanelType {
            Candidates.reallocate()
        }
        guard let panel = Candidates.shared else { return }

        panel.update()
        panel.show(kIMKLocateCandidatesBelowHint)
        Candidates.raiseAboveOverlayPanels()

        // `selectCandidate(_:)` is unreliable, so step to the remembered choice instead.
        if composition.rememberedIndex > 0 {
            for _ in 0..<composition.rememberedIndex {
                switch panel.panelType() {
                case kIMKSingleColumnScrollingCandidatePanel: panel.moveDown(self)
                case kIMKSingleRowSteppingCandidatePanel: panel.moveRight(self)
                default: break
                }
            }
        }
    }

    override func candidates(_ sender: Any!) -> [Any]! {
        composition.candidates
    }

    override func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
        guard let candidate = candidateString?.string else { return }
        composition.selectionChanged(to: candidate)
    }

    override func candidateSelected(_ candidateString: NSAttributedString!) {
        client()?.insertText(candidateString, replacementRange: NSRange(location: NSNotFound, length: 0))

        composition.clear()
        updateCandidatesPanel()

        if usedArrowKeys {
            usedArrowKeys = false
            if Preferences.includeDictionary {
                CacheManager.shared.persist()
            }
        }
    }

    private func commitSelectedCandidate() {
        guard let candidate = composition.selectedCandidate else { return }
        candidateSelected(NSAttributedString(string: candidate))
    }

    // MARK: - Composition

    /// Mirrors the buffer into the client as marked text.
    private func updateMarkedText() {
        setMarkedText(composition.buffer)
    }

    /// Shows `text` in the client as marked text.
    ///
    /// This deliberately does not go through `updateComposition()`, which asks for the
    /// text back via `composedString(_:)`. On macOS 12 InputMethodKit invokes that
    /// selector without setting up its `sender` argument, so the register holds a stale
    /// pointer; Swift's @objc thunk retains every `id` argument before the body runs, and
    /// that retain faults. An Objective-C input method never notices because it simply
    /// ignores the unused argument. Writing the marked text straight to the client keeps
    /// `sender` out of Swift's hands and leaves `composedString(_:)` to IMK's own
    /// implementation.
    private func setMarkedText(_ text: String) {
        client()?.setMarkedText(NSAttributedString(string: text),
                                selectionRange: NSRange(location: text.utf16.count, length: 0),
                                replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
    }

    override func commitComposition(_ sender: Any!) {
        if heldDeadKey != nil {
            releaseDeadKey()
            return
        }
        client()?.insertText(composition.buffer, replacementRange: NSRange(location: NSNotFound, length: 0))
        composition.clear()
        updateCandidatesPanel()
    }

    private func compositionDidChange() {
        updateMarkedText()
        updateCandidatesPanel()
    }

    // MARK: - Input

    override func inputText(_ string: String!, client sender: Any!) -> Bool {
        guard let string else { return false }

        if let layout = Preferences.keyboardLayout.fixedLayout {
            return inputFixed(string, layout: layout)
        }
        // The layout may have been switched back to phonetic with a dead key held.
        releaseDeadKey()

        if string == " " {
            // Commit the highlighted candidate and let the space through to the client.
            commitSelectedCandidate()
            return false
        }

        composition.append(string)
        compositionDidChange()
        return true
    }

    override func didCommand(by aSelector: Selector!, client sender: Any!) -> Bool {
        if heldDeadKey != nil {
            if aSelector == #selector(NSResponder.deleteBackward(_:)) {
                heldDeadKey = nil
                setMarkedText("")
                return true
            }
            // Any other command types the dead key as is, then goes to the client.
            releaseDeadKey()
            return false
        }

        // Only intercept editing commands while something is being composed;
        // otherwise let the client application handle the key.
        guard !composition.isEmpty, let aSelector else { return false }

        switch aSelector {
        case #selector(NSResponder.deleteBackward(_:)):
            composition.deleteBackward()
            compositionDidChange()
        case #selector(NSResponder.insertTab(_:)):
            commitText("\t")
        case #selector(NSResponder.insertNewline(_:)):
            commitText(Preferences.commitNewLineOnEnter ? "\n" : "")
        case #selector(NSResponder.moveUp(_:)):
            moveInCandidates { $0.moveUp(self) }
        case #selector(NSResponder.moveDown(_:)):
            moveInCandidates { $0.moveDown(self) }
        case #selector(NSResponder.moveLeft(_:)):
            moveInCandidates { $0.moveLeft(self) }
        case #selector(NSResponder.moveRight(_:)):
            moveInCandidates { $0.moveRight(self) }
        default:
            return false
        }
        return true
    }

    private func moveInCandidates(_ move: (IMKCandidates) -> Void) {
        guard let panel = Candidates.shared, panel.isVisible() else { return }
        usedArrowKeys = true
        move(panel)
    }

    /// Commits the highlighted candidate followed by `string`.
    private func commitText(_ string: String) {
        guard composition.selectedCandidate != nil else {
            NSSound.beep()
            return
        }
        commitSelectedCandidate()
        client()?.insertText(string, replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    // MARK: - Fixed layouts

    /// Types `string` straight into the client using a fixed layout. Keys the layout does
    /// not map (space, for one) are left for the client.
    private func inputFixed(_ string: String, layout: FixedLayout) -> Bool {
        // The layout may have been switched away from phonetic mid-word.
        if !composition.isEmpty {
            commitSelectedCandidate()
        }

        if heldDeadKey != nil, let text = layout.afterDeadKey[string] {
            heldDeadKey = nil
            insert(text)
            return true
        }
        releaseDeadKey()

        if let deadKey = layout.deadKey, string == deadKey.key {
            heldDeadKey = deadKey.text
            setMarkedText(deadKey.text)
            return true
        }
        guard let text = layout.keys[string] else { return false }
        insert(text)
        return true
    }

    /// Types the held dead key as it is.
    private func releaseDeadKey() {
        guard let text = heldDeadKey else { return }
        heldDeadKey = nil
        insert(text)
    }

    private func insert(_ text: String) {
        client()?.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    // MARK: - Input menu

    override func menu() -> NSMenu! {
        AppDelegate.shared.menu
    }

    override func showPreferences(_ sender: Any!) {
        AppDelegate.shared.showPreferences()
    }
}
