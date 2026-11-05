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
/// Space or Enter commits the highlighted candidate; arrow keys move through candidates,
/// and a number key commits the candidate shown with that number.
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
    /// Whether the user picked a candidate by hand, so the choice is saved on commit.
    private var pickedCandidate = false
    /// Index of the candidate the panel shows with the number 1.
    private var firstVisibleCandidate = 0
    /// Text of a fixed layout's dead key, shown as marked text until the next key decides it.
    private var heldDeadKey: String?
    /// What the last key of a fixed layout typed, while typing goes on uninterrupted.
    private var lastFixedText: String?
    /// What each key of the current word typed, while a fixed layout holds the word as
    /// marked text: ANSI output converts a word as a whole, and in old style typing a later
    /// key can move a vowel sign or reph.
    private var heldWord: [String] = []

    /// Whether a fixed layout holds the current word as marked text.
    private var holdsWord: Bool {
        Preferences.outputAsANSI || Preferences.oldStyleTyping
    }

    // MARK: - Candidate window

    private func updateCandidatesPanel() {
        firstVisibleCandidate = 0
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
        MainActor.assumeIsolated {
            composition.selectionChanged(to: candidate)
            updateFirstVisibleCandidate()
            if !composition.isEmpty { updateMarkedText() }
        }
    }

    /// Follows the panel as the selection moves: the row steps a page at a time, the
    /// column scrolls just far enough. The panel's own line lookups can't be used for
    /// this, as `candidateIdentifier(atLineNumber:)` returns 0 for every line.
    private func updateFirstVisibleCandidate() {
        let index = composition.selectedIndex
        if Candidates.shared?.panelType() == kIMKSingleRowSteppingCandidatePanel {
            firstVisibleCandidate = index / Candidates.visibleCount * Candidates.visibleCount
        } else if index < firstVisibleCandidate {
            firstVisibleCandidate = index
        } else if index >= firstVisibleCandidate + Candidates.visibleCount {
            firstVisibleCandidate = index - Candidates.visibleCount + 1
        }
    }

    nonisolated override func candidateSelected(_ candidateString: NSAttributedString!) {
        let text = candidateString?.string ?? ""
        MainActor.assumeIsolated { commit(text) }
    }

    private func commit(_ text: String) {
        client()?.insertText(Preferences.outputAsANSI ? Bijoy.convert(text) : text, replacementRange: NSRange(location: NSNotFound, length: 0))

        composition.clear()
        updateCandidatesPanel()

        if pickedCandidate {
            pickedCandidate = false
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

    /// The text shown, and committed on a focus change: the highlighted candidate, or the
    /// raw buffer when there is none.
    private var composedText: String {
        let text = composition.selectedCandidate ?? composition.buffer
        return Preferences.outputAsANSI ? Bijoy.convert(text) : text
    }

    /// Mirrors the highlighted candidate into the client as marked text, so the Bangla
    /// shows live while typing.
    private func updateMarkedText() {
        setMarkedText(composedText)
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
        if heldDeadKey != nil || !heldWord.isEmpty {
            releaseDeadKey()
            commitHeldWord()
            return
        }
        client()?.insertText(composedText, replacementRange: NSRange(location: NSNotFound, length: 0))
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
        commitHeldWord()
        lastFixedText = nil

        if string == " " {
            // Commit the highlighted candidate and let the space through to the client.
            commitSelectedCandidate()
            return false
        }

        if let candidate = candidate(forNumberKey: string) {
            pickedCandidate = true
            composition.selectionChanged(to: candidate)
            commit(candidate)
            return true
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
        if heldDeadKey != nil || !heldWord.isEmpty {
            if aSelector == #selector(NSResponder.deleteBackward(_:)) {
                if heldDeadKey != nil {
                    heldDeadKey = nil
                    self.lastFixedText = lastFixedText
                } else {
                    heldWord.removeLast()
                    self.lastFixedText = heldWord.last
                }
                updateFixedMarkedText()
                return true
            }
            // Any other command types the dead key as is and ends the word, then goes to
            // the client.
            releaseDeadKey()
            commitHeldWord()
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
        pickedCandidate = true
        move(panel)
    }

    /// The candidate shown with the number on `key`, if the key picks one instead of
    /// typing a digit.
    private func candidate(forNumberKey key: String) -> String? {
        guard composition.acceptsNumberSelection, let number = Int(key),
              (1...Candidates.visibleCount).contains(number),
              Candidates.shared?.isVisible() == true else { return nil }
        let index = firstVisibleCandidate + number - 1
        return composition.candidates.indices.contains(index) ? composition.candidates[index] : nil
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
        // ANSI output or old style typing may have been turned off mid-word.
        if !holdsWord {
            commitHeldWord()
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
            commitHeldWord()
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

    /// Types `text` into the client, or adds it to the held word.
    private func insert(_ text: String) {
        lastFixedText = text
        if holdsWord {
            heldWord.append(text)
            updateFixedMarkedText()
        } else {
            client()?.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
        }
    }

    /// The held word in Unicode, put in logical order when typed in old style.
    private func heldWordText(atWordEnd: Bool = false) -> String {
        Preferences.oldStyleTyping ? OldStyleTyping.reorder(heldWord, atWordEnd: atWordEnd) : heldWord.joined()
    }

    /// Shows the held word and the held dead key as marked text.
    private func updateFixedMarkedText() {
        guard Preferences.outputAsANSI else {
            setMarkedText(heldWordText() + (heldDeadKey ?? ""))
            return
        }
        var text = Bijoy.convert(heldWordText())
        if let deadKey = heldDeadKey {
            // A lone hasanta has no glyph of its own in Bijoy, so show the visible one.
            text += Bijoy.convert(deadKey + "\u{200C}")
        }
        setMarkedText(text)
    }

    /// Commits the held word, converted to Bijoy with ANSI output.
    private func commitHeldWord() {
        guard !heldWord.isEmpty else { return }
        let unicode = heldWordText(atWordEnd: true)
        let text = Preferences.outputAsANSI ? Bijoy.convert(unicode) : unicode
        heldWord = []
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
