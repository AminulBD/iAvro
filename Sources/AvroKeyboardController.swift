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
///
/// `IMKInputController` carries no actor annotation, so its overrides are `nonisolated`.
/// InputMethodKit always calls them on the main thread, and each one enters the main actor
/// with `MainActor.assumeIsolated`, which traps if that ever stops being true.
///
/// All of its own state is main-actor isolated, so sharing the reference is safe; it is
/// `@unchecked` only because the superclass is not `Sendable`.
@objc(AvroKeyboardController)
@MainActor
final class AvroKeyboardController: IMKInputController, @unchecked Sendable {
    private let composition = Composition()
    private var usedArrowKeys = false
    /// Text of a fixed layout's dead key, shown as marked text until the next key decides it.
    private var heldDeadKey: String?
    /// What the last key of a fixed layout typed, while typing goes on uninterrupted.
    private var lastFixedText: String?
    /// What each key of the current word typed, when a fixed layout outputs ANSI. Bijoy
    /// draws some vowel signs before their consonant, so the word is held as marked text
    /// and converted as a whole when it ends.
    private var ansiWord: [String] = []

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

    nonisolated override func candidates(_ sender: Any!) -> [Any]! {
        MainActor.assumeIsolated { composition.candidates }
    }

    nonisolated override func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
        guard let candidate = candidateString?.string else { return }
        MainActor.assumeIsolated { composition.selectionChanged(to: candidate) }
    }

    nonisolated override func candidateSelected(_ candidateString: NSAttributedString!) {
        let text = candidateString?.string ?? ""
        MainActor.assumeIsolated { commit(text) }
    }

    private func commit(_ text: String) {
        client()?.insertText(Preferences.outputAsANSI ? Bijoy.convert(text) : text, replacementRange: NSRange(location: NSNotFound, length: 0))

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
        commit(candidate)
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

    nonisolated override func commitComposition(_ sender: Any!) {
        MainActor.assumeIsolated { commitComposition() }
    }

    private func commitComposition() {
        lastFixedText = nil
        if heldDeadKey != nil || !ansiWord.isEmpty {
            releaseDeadKey()
            commitANSIWord()
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

    nonisolated override func inputText(_ string: String!, client sender: Any!) -> Bool {
        guard let string else { return false }
        return MainActor.assumeIsolated { input(string) }
    }

    private func input(_ string: String) -> Bool {
        if let layout = Preferences.keyboardLayout.fixedLayout {
            return inputFixed(string, layout: layout)
        }
        // The layout may have been switched back to phonetic mid-word.
        releaseDeadKey()
        commitANSIWord()
        lastFixedText = nil

        if string == " " {
            // Commit the highlighted candidate and let the space through to the client.
            commitSelectedCandidate()
            return false
        }

        composition.append(string)
        compositionDidChange()
        return true
    }

    nonisolated override func didCommand(by aSelector: Selector!, client sender: Any!) -> Bool {
        MainActor.assumeIsolated { handle(aSelector) }
    }

    private func handle(_ aSelector: Selector?) -> Bool {
        let lastFixedText = lastFixedText
        self.lastFixedText = nil
        if heldDeadKey != nil || !ansiWord.isEmpty {
            if aSelector == #selector(NSResponder.deleteBackward(_:)) {
                if heldDeadKey != nil {
                    heldDeadKey = nil
                    self.lastFixedText = lastFixedText
                } else {
                    ansiWord.removeLast()
                    self.lastFixedText = ansiWord.last
                }
                updateFixedMarkedText()
                return true
            }
            // Any other command types the dead key as is and ends the word, then goes to
            // the client.
            releaseDeadKey()
            commitANSIWord()
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
        // ANSI output may have been turned off mid-word.
        if !Preferences.outputAsANSI {
            commitANSIWord()
        }

        if heldDeadKey != nil, let text = layout.afterDeadKey[string] {
            heldDeadKey = nil
            insert(text)
            return true
        }
        releaseDeadKey()

        if let deadKey = layout.deadKey, string == deadKey.key {
            heldDeadKey = deadKey.text
            updateFixedMarkedText()
            return true
        }
        guard var text = layout.keys[string] else {
            lastFixedText = nil
            commitANSIWord()
            return false
        }
        if let previous = lastFixedText, let replacement = layout.afterText[previous]?[string] {
            text = replacement
        }
        insert(text)
        return true
    }

    /// Types the held dead key as it is.
    private func releaseDeadKey() {
        guard let text = heldDeadKey else { return }
        heldDeadKey = nil
        insert(text)
    }

    /// Types `text` into the client, or adds it to the ANSI word.
    private func insert(_ text: String) {
        lastFixedText = text
        if Preferences.outputAsANSI {
            ansiWord.append(text)
            updateFixedMarkedText()
        } else {
            client()?.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
        }
    }

    /// Shows the ANSI word and the held dead key as marked text.
    private func updateFixedMarkedText() {
        guard Preferences.outputAsANSI else {
            setMarkedText(heldDeadKey ?? "")
            return
        }
        var text = Bijoy.convert(ansiWord.joined())
        if let deadKey = heldDeadKey {
            // A lone hasanta has no glyph of its own in Bijoy, so show the visible one.
            text += Bijoy.convert(deadKey + "\u{200C}")
        }
        setMarkedText(text)
    }

    /// Commits the ANSI word, converted to Bijoy.
    private func commitANSIWord() {
        guard !ansiWord.isEmpty else { return }
        let text = Bijoy.convert(ansiWord.joined())
        ansiWord = []
        client()?.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    // MARK: - Input menu

    nonisolated override func menu() -> NSMenu! {
        // `NSMenu` is not `Sendable`, but it goes straight back to IMK on the main thread.
        nonisolated(unsafe) var menu: NSMenu?
        MainActor.assumeIsolated { menu = AppDelegate.shared.menu }
        return menu
    }

    nonisolated override func showPreferences(_ sender: Any!) {
        MainActor.assumeIsolated { AppDelegate.shared.showPreferences() }
    }
}
