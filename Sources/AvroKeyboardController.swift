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

    override func composedString(_ sender: Any!) -> Any! {
        NSAttributedString(string: composition.buffer)
    }

    override func commitComposition(_ sender: Any!) {
        client()?.insertText(composition.buffer, replacementRange: NSRange(location: NSNotFound, length: 0))
        composition.clear()
        updateCandidatesPanel()
    }

    private func compositionDidChange() {
        updateComposition()
        updateCandidatesPanel()
    }

    // MARK: - Input

    override func inputText(_ string: String!, client sender: Any!) -> Bool {
        guard let string else { return false }

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

    // MARK: - Input menu

    override func menu() -> NSMenu! {
        AppDelegate.shared.menu
    }

    override func showPreferences(_ sender: Any!) {
        AppDelegate.shared.showPreferences()
    }
}
