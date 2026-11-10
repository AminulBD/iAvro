//
//  AvroKeyboard
//
//  Copyright (c) 2012 OmicronLab. All rights reserved.
//

import Cocoa
import InputMethodKit

/// The Preferences panel: a toolbar switching between General, AutoCorrect and Credits panes.
final class PreferencesWindowController: NSWindowController {
    private enum Pane: String, CaseIterable {
        case general = "General"
        case autoCorrect = "AutoCorrect"
        case credits = "Credits"

        var identifier: NSToolbarItem.Identifier { NSToolbarItem.Identifier(rawValue) }
        var size: NSSize {
            switch self {
            case .general: return NSSize(width: 450, height: 241)
            case .autoCorrect: return NSSize(width: 450, height: 400)
            case .credits: return NSSize(width: 450, height: 450)
            }
        }
    }

    private var currentPane: Pane = .general
    private var currentView: NSView?

    private lazy var generalView = makeGeneralView()
    private lazy var autoCorrectView = makeAutoCorrectView()
    private lazy var creditsView = makeCreditsView()

    // AutoCorrect pane state
    private enum AutoCorrectList: Int {
        case personal = 0
        case builtIn = 1
    }

    private var autoCorrectList: AutoCorrectList = .personal
    private let builtInEntries: [Replacement] = AutoCorrect.shared.entries
        .sorted { $0.key < $1.key }
        .map { Replacement(shortcut: $0.key, phrase: $0.value) }
    /// The user's entries as edited here, including a new row still being typed.
    private var personalEntries: [Replacement] = AutoCorrect.shared.replacements
        .sorted { $0.shortcut.localizedStandardCompare($1.shortcut) == .orderedAscending }
    /// Rows of the table that match the search: indices into the shown list.
    private var filteredRows: [Int] = []
    private let autoCorrectTable = DeletingTableView()
    private let searchField = NSSearchField()
    private let addRemoveControl = NSSegmentedControl()
    private let messageLabel = NSTextField(wrappingLabelWithString: "")
    private let countLabel = NSTextField(labelWithString: "")

    init() {
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: Pane.general.size),
                            styleMask: [.titled, .closable, .nonactivatingPanel],
                            backing: .buffered,
                            defer: true)
        panel.title = "Preferences"
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = true
        panel.toolbarStyle = .preference
        super.init(window: panel)

        let toolbar = NSToolbar(identifier: "PreferencesToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.selectedItemIdentifier = Pane.general.identifier
        panel.toolbar = toolbar

        show(.general, animated: false)
        panel.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Pane switching

    private func view(for pane: Pane) -> NSView {
        switch pane {
        case .general: return generalView
        case .autoCorrect: return autoCorrectView
        case .credits: return creditsView
        }
    }

    @objc private func switchPane(_ sender: NSToolbarItem) {
        guard let pane = Pane(rawValue: sender.itemIdentifier.rawValue), pane != currentPane else { return }
        window?.makeFirstResponder(nil) // finish any edit in the AutoCorrect table
        show(pane, animated: true)
    }

    private func show(_ pane: Pane, animated: Bool) {
        guard let window else { return }
        let view = view(for: pane)
        currentPane = pane
        window.toolbar?.selectedItemIdentifier = pane.identifier

        // Resize the window around its top-left corner so the toolbar stays put.
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: pane.size))
        frame.origin.x = window.frame.origin.x
        frame.origin.y = window.frame.maxY - frame.height

        currentView?.removeFromSuperview()
        window.setFrame(frame, display: true, animate: animated)

        view.frame = window.contentView!.bounds
        view.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(view)
        currentView = view
    }

    // MARK: - General

    private func makeGeneralView() -> NSView {
        let defaults = NSUserDefaultsController.shared
        let controlWidth: CGFloat = 236

        let layout = NSPopUpButton(frame: .zero, pullsDown: false)
        for keyboardLayout in Preferences.KeyboardLayout.allCases {
            layout.addItem(withTitle: keyboardLayout.title)
            layout.lastItem?.tag = keyboardLayout.rawValue
        }
        layout.bind(.selectedTag, to: defaults, withKeyPath: "values.\(Preferences.Key.keyboardLayout)")

        let outputAsANSI = NSButton(checkboxWithTitle: "Output as ANSI (Bijoy fonts)", target: nil, action: nil)
        outputAsANSI.bind(.value, to: defaults, withKeyPath: "values.\(Preferences.Key.outputAsANSI)")

        let oldStyleTyping = NSButton(checkboxWithTitle: "Use Full Old Style Typing", target: nil, action: nil)
        oldStyleTyping.bind(.value, to: defaults, withKeyPath: "values.\(Preferences.Key.oldStyleTyping)")

        let oldStyleNote = NSTextField(wrappingLabelWithString: "Type ি, ে and ৈ before their consonant and the reph after it, as on a typewriter.")
        oldStyleNote.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        oldStyleNote.textColor = .secondaryLabelColor
        oldStyleNote.preferredMaxLayoutWidth = controlWidth

        // Only the fixed layouts (every layout but 0) are typed in old style.
        oldStyleTyping.bind(.enabled, to: defaults, withKeyPath: "values.\(Preferences.Key.keyboardLayout)")

        let orientation = NSPopUpButton(frame: .zero, pullsDown: false)
        for (title, tag) in [("Horizontal", kIMKSingleRowSteppingCandidatePanel), ("Vertical", kIMKSingleColumnScrollingCandidatePanel)] {
            orientation.addItem(withTitle: title)
            orientation.lastItem?.tag = tag
        }
        orientation.bind(.selectedTag, to: defaults, withKeyPath: "values.\(Preferences.Key.candidatePanelType)")

        let includeDictionary = NSButton(checkboxWithTitle: "Include Dictionary Suggestions", target: nil, action: nil)
        includeDictionary.bind(.value, to: defaults, withKeyPath: "values.\(Preferences.Key.includeDictionary)")

        let commitNewline = NSButton(checkboxWithTitle: "Commit new line on Enter/Return", target: nil, action: nil)
        commitNewline.bind(.value, to: defaults, withKeyPath: "values.\(Preferences.Key.commitNewLineOnEnter)")

        // The remaining options only apply to phonetic typing (layout 0).
        for control in [orientation, includeDictionary, commitNewline] {
            control.bind(.enabled, to: defaults, withKeyPath: "values.\(Preferences.Key.keyboardLayout)",
                         options: [.valueTransformerName: NSValueTransformerName.negateBooleanTransformerName])
        }

        let layoutLabel = NSTextField(labelWithString: "Keyboard Layout:")
        let label = NSTextField(labelWithString: "Suggestion List Orientation:")
        label.alignment = .right

        let grid = NSGridView(views: [
            [layoutLabel, layout],
            [NSGridCell.emptyContentView, outputAsANSI],
            [NSGridCell.emptyContentView, oldStyleTyping],
            [NSGridCell.emptyContentView, oldStyleNote],
            [label, orientation],
            [NSGridCell.emptyContentView, includeDictionary],
            [NSGridCell.emptyContentView, commitNewline],
        ])
        grid.rowSpacing = 8
        grid.columnSpacing = 8
        grid.column(at: 0).xPlacement = .trailing
        grid.row(at: 0).yPlacement = .center
        grid.row(at: 4).yPlacement = .center
        grid.row(at: 2).bottomPadding = -4
        grid.row(at: 3).bottomPadding = 8

        let container = NSView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: container.topAnchor, constant: 18),
            grid.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -15),
            orientation.widthAnchor.constraint(equalToConstant: controlWidth),
            layout.widthAnchor.constraint(equalTo: orientation.widthAnchor),
        ])
        return container
    }

    // MARK: - AutoCorrect

    private func makeAutoCorrectView() -> NSView {
        let listSwitch = NSSegmentedControl(labels: ["Personal", "Built-in"], trackingMode: .selectOne,
                                            target: self, action: #selector(switchAutoCorrectList(_:)))
        listSwitch.selectedSegment = autoCorrectList.rawValue

        searchField.target = self
        searchField.action = #selector(filterEntries(_:))
        searchField.sendsSearchStringImmediately = true

        for (title, key) in [("Replace", "replace"), ("With", "with")] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(key))
            column.title = title
            column.width = key == "replace" ? 140 : 260
            autoCorrectTable.addTableColumn(column)
        }
        autoCorrectTable.usesAlternatingRowBackgroundColors = true
        autoCorrectTable.allowsMultipleSelection = true
        autoCorrectTable.allowsColumnReordering = false
        autoCorrectTable.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        autoCorrectTable.dataSource = self
        autoCorrectTable.delegate = self
        autoCorrectTable.target = self
        autoCorrectTable.doubleAction = #selector(editClickedEntry(_:))
        autoCorrectTable.onDelete = { [weak self] in self?.removeSelectedEntries() }

        let scrollView = NSScrollView()
        scrollView.documentView = autoCorrectTable
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        addRemoveControl.segmentCount = 2
        addRemoveControl.trackingMode = .momentary
        addRemoveControl.segmentStyle = .smallSquare
        addRemoveControl.setImage(NSImage(named: NSImage.addTemplateName), forSegment: 0)
        addRemoveControl.setImage(NSImage(named: NSImage.removeTemplateName), forSegment: 1)
        addRemoveControl.setToolTip("Add a replacement", forSegment: 0)
        addRemoveControl.setToolTip("Remove the selected replacements", forSegment: 1)
        for segment in 0..<2 { addRemoveControl.setWidth(24, forSegment: segment) }
        addRemoveControl.target = self
        addRemoveControl.action = #selector(addOrRemoveEntry(_:))

        messageLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        messageLabel.preferredMaxLayoutWidth = 410
        countLabel.alignment = .right

        let container = NSView()
        for view in [listSwitch, searchField, scrollView, addRemoveControl, countLabel, messageLabel] {
            view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(view)
        }
        NSLayoutConstraint.activate([
            listSwitch.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            listSwitch.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            searchField.topAnchor.constraint(equalTo: listSwitch.bottomAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            searchField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: searchField.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: searchField.trailingAnchor),

            // The add/remove buttons sit right under the table, as in macOS's own lists.
            addRemoveControl.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -1),
            addRemoveControl.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),

            countLabel.centerYAnchor.constraint(equalTo: addRemoveControl.centerYAnchor),
            countLabel.trailingAnchor.constraint(equalTo: searchField.trailingAnchor),

            messageLabel.topAnchor.constraint(equalTo: addRemoveControl.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: searchField.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: searchField.trailingAnchor),
            messageLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
        ])

        reloadAutoCorrectTable()
        showMessage(nil)
        return container
    }

    /// The list the table shows: the user's own entries or the built-in ones.
    private var shownEntries: [Replacement] {
        autoCorrectList == .personal ? personalEntries : builtInEntries
    }

    @objc private func switchAutoCorrectList(_ sender: NSSegmentedControl) {
        guard let list = AutoCorrectList(rawValue: sender.selectedSegment), list != autoCorrectList else { return }
        window?.makeFirstResponder(nil)
        autoCorrectList = list
        searchField.stringValue = ""
        addRemoveControl.isHidden = list == .builtIn
        reloadAutoCorrectTable()
        showMessage(nil)
    }

    @objc private func filterEntries(_ sender: NSSearchField) {
        reloadAutoCorrectTable()
    }

    /// Re-applies the search and reloads the table.
    private func reloadAutoCorrectTable() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let entries = shownEntries
        filteredRows = entries.indices.filter { index in
            query.isEmpty
                || entries[index].shortcut.localizedCaseInsensitiveContains(query)
                || entries[index].phrase.contains(query)
        }
        autoCorrectTable.reloadData()
        countLabel.stringValue = filteredRows.count == 1 ? "1 Item" : "\(filteredRows.count) Items"
        updateRemoveButton()
    }

    private func updateRemoveButton() {
        addRemoveControl.setEnabled(!autoCorrectTable.selectedRowIndexes.isEmpty, forSegment: 1)
    }

    /// Shows `problem` in red, else `hint`, else a note on how the shown list is used.
    private func showMessage(_ problem: String?, hint: String? = nil) {
        if let problem {
            messageLabel.stringValue = problem
            messageLabel.textColor = .systemRed
            return
        }
        messageLabel.textColor = .secondaryLabelColor
        if let hint {
            messageLabel.stringValue = hint
            return
        }
        switch autoCorrectList {
        case .personal:
            messageLabel.stringValue = "Your replacements come first in the suggestions when typing with Avro Phonetic, even with dictionary suggestions turned off. Click + to add one; double-click a row to change it."
        case .builtIn:
            messageLabel.stringValue = "Built-in replacements are offered with dictionary suggestions turned on. Add a personal replacement with the same shortcut to override one."
        }
    }

    // MARK: Editing personal replacements

    @objc private func addOrRemoveEntry(_ sender: NSSegmentedControl) {
        if sender.selectedSegment == 0 {
            addEntry()
        } else {
            removeSelectedEntries()
        }
    }

    private func addEntry() {
        guard autoCorrectList == .personal, let window else { return }
        window.makeFirstResponder(nil)
        // Reuse a blank row left from an earlier add.
        if !personalEntries.contains(where: { $0.shortcut.isEmpty && $0.phrase.isEmpty }) {
            personalEntries.append(Replacement(shortcut: "", phrase: ""))
        }
        searchField.stringValue = ""
        reloadAutoCorrectTable()
        guard let row = filteredRows.firstIndex(where: { personalEntries[$0].shortcut.isEmpty && personalEntries[$0].phrase.isEmpty }) else { return }
        autoCorrectTable.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        autoCorrectTable.scrollRowToVisible(row)
        autoCorrectTable.editColumn(0, row: row, with: nil, select: true)
    }

    private func removeSelectedEntries() {
        guard autoCorrectList == .personal else { return }
        window?.makeFirstResponder(nil)
        let indices = autoCorrectTable.selectedRowIndexes.compactMap { filteredRows.indices.contains($0) ? filteredRows[$0] : nil }
        guard !indices.isEmpty else { return }
        for index in indices.sorted(by: >) {
            personalEntries.remove(at: index)
        }
        autoCorrectTable.deselectAll(nil)
        reloadAutoCorrectTable()
        savePersonalEntries()
    }

    @objc private func editClickedEntry(_ sender: NSTableView) {
        guard autoCorrectList == .personal, sender.clickedRow >= 0 else { return }
        sender.editColumn(max(sender.clickedColumn, 0), row: sender.clickedRow, with: nil, select: true)
    }

    /// A cell of the personal list was edited.
    @objc private func entryEdited(_ field: NSTextField) {
        let row = autoCorrectTable.row(for: field)
        let column = autoCorrectTable.column(for: field)
        guard autoCorrectList == .personal, column >= 0, filteredRows.indices.contains(row) else { return }
        let index = filteredRows[row]

        if column == 0 {
            personalEntries[index].shortcut = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            field.stringValue = personalEntries[index].shortcut
        } else {
            personalEntries[index].phrase = field.stringValue
        }
        let entry = personalEntries[index]

        // A row emptied out is removed.
        if entry.shortcut.isEmpty && entry.phrase.isEmpty {
            personalEntries.remove(at: index)
            reloadAutoCorrectTable()
            savePersonalEntries()
            return
        }

        savePersonalEntries()

        // Go on to the phrase of a new entry once its shortcut is in.
        if column == 0, entry.phrase.isEmpty,
           AutoCorrect.problem(withShortcut: entry.shortcut, others: personalEntries.enumerated().filter { $0.offset != index }.map(\.element)) == nil {
            DispatchQueue.main.async { [weak self] in
                self?.autoCorrectTable.editColumn(1, row: row, with: nil, select: true)
            }
        }
    }

    /// Saves the complete, valid entries, and reports the first one that can't be saved.
    private func savePersonalEntries() {
        var valid: [Replacement] = []
        var problem: String?
        var hint: String?
        for entry in personalEntries {
            if entry.shortcut.isEmpty && entry.phrase.isEmpty { continue }
            if let shortcutProblem = AutoCorrect.problem(withShortcut: entry.shortcut, others: valid) {
                problem = problem ?? shortcutProblem
                continue
            }
            if entry.phrase.isEmpty {
                hint = hint ?? "Type what “\(entry.shortcut)” should be replaced with."
                continue
            }
            valid.append(entry)
        }
        do {
            try AutoCorrect.shared.setReplacements(valid)
        } catch {
            problem = "Your replacements could not be saved: \(error.localizedDescription)"
        }
        showMessage(problem, hint: hint)
    }

    // MARK: - Credits

    private func makeCreditsView() -> NSView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.isEditable = false
        textView.usesFindBar = true
        if let credits = Bundle.main.path(forResource: "Credits", ofType: "rtfd") {
            textView.readRTFD(fromFile: credits)
            textView.scrollToBeginningOfDocument(nil)
        }

        // The credits are authored with fixed colours for a light background.
        scrollView.appearance = NSAppearance(named: .aqua)

        let container = NSView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .bezelBorder
        container.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
        ])
        return container
    }
}

// MARK: - NSToolbarDelegate

extension PreferencesWindowController: NSToolbarDelegate {
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Pane.general.identifier, Pane.autoCorrect.identifier, .flexibleSpace, Pane.credits.identifier]
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Pane.allCases.map(\.identifier)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let pane = Pane(rawValue: itemIdentifier.rawValue) else { return nil }
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = pane.rawValue
        item.paletteLabel = pane.rawValue
        item.image = NSImage(named: pane.rawValue)
        item.target = self
        item.action = #selector(switchPane(_:))
        return item
    }
}

// MARK: - NSTableViewDataSource / NSTableViewDelegate

extension PreferencesWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        filteredRows.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn, filteredRows.indices.contains(row) else { return nil }
        let entry = shownEntries[filteredRows[row]]
        let text = tableColumn.identifier.rawValue == "replace" ? entry.shortcut : entry.phrase
        let editable = autoCorrectList == .personal

        let identifier = NSUserInterfaceItemIdentifier(editable ? "editableCell" : "cell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView ?? {
            let cell = NSTableCellView()
            cell.identifier = identifier
            let field = NSTextField(labelWithString: "")
            field.lineBreakMode = .byTruncatingTail
            if editable {
                field.isEditable = true
                field.cell?.isScrollable = true
                field.cell?.wraps = false
                field.cell?.sendsActionOnEndEditing = true
                field.target = self
                field.action = #selector(entryEdited(_:))
            }
            field.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(field)
            cell.textField = field
            NSLayoutConstraint.activate([
                field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
                field.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
            return cell
        }()
        cell.textField?.stringValue = text
        cell.textField?.placeholderString = editable && text.isEmpty
            ? (tableColumn.identifier.rawValue == "replace" ? "Shortcut" : "Replacement")
            : nil
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateRemoveButton()
    }
}

/// A table that reports the Delete key, to remove the selected rows.
private final class DeletingTableView: NSTableView {
    var onDelete: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let deleteKeys: [Character] = ["\u{7F}", Character(UnicodeScalar(NSDeleteFunctionKey)!)]
        if let key = event.charactersIgnoringModifiers?.first, deleteKeys.contains(key), let onDelete {
            onDelete()
        } else {
            super.keyDown(with: event)
        }
    }
}
