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
            case .general: return NSSize(width: 450, height: 115)
            case .autoCorrect: return NSSize(width: 450, height: 331)
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
    private let autoCorrectEntries: [(replace: String, with: String)] = AutoCorrect.shared.entries
        .sorted { $0.key < $1.key }
        .map { (replace: $0.key, with: $0.value) }
    private var filteredEntries: [(replace: String, with: String)] = []
    private let autoCorrectTable = NSTableView()
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

        filteredEntries = autoCorrectEntries
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

        let label = NSTextField(labelWithString: "Suggestion List Orientation:")
        label.alignment = .right

        let grid = NSGridView(views: [
            [label, orientation],
            [NSGridCell.emptyContentView, includeDictionary],
            [NSGridCell.emptyContentView, commitNewline],
        ])
        grid.rowSpacing = 8
        grid.columnSpacing = 8
        grid.column(at: 0).xPlacement = .trailing
        grid.row(at: 0).yPlacement = .center

        let container = NSView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: container.topAnchor, constant: 18),
            grid.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -15),
            orientation.widthAnchor.constraint(equalToConstant: 236),
        ])
        return container
    }

    // MARK: - AutoCorrect

    private func makeAutoCorrectView() -> NSView {
        let searchField = NSSearchField()
        searchField.target = self
        searchField.action = #selector(filterEntries(_:))
        searchField.sendsSearchStringImmediately = true

        for (title, key) in [("Replace", "replace"), ("With", "with")] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(key))
            column.title = title
            column.width = 200
            column.isEditable = false
            autoCorrectTable.addTableColumn(column)
        }
        autoCorrectTable.usesAlternatingRowBackgroundColors = true
        autoCorrectTable.allowsMultipleSelection = false
        autoCorrectTable.allowsColumnReordering = false
        autoCorrectTable.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        autoCorrectTable.dataSource = self
        autoCorrectTable.delegate = self

        let scrollView = NSScrollView()
        scrollView.documentView = autoCorrectTable
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        countLabel.alignment = .right
        updateCountLabel()

        let container = NSView()
        for view in [searchField, scrollView, countLabel] {
            view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(view)
        }
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            searchField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            searchField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: searchField.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: searchField.trailingAnchor),

            countLabel.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 8),
            countLabel.trailingAnchor.constraint(equalTo: searchField.trailingAnchor),
            countLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
        ])
        return container
    }

    @objc private func filterEntries(_ sender: NSSearchField) {
        let query = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            filteredEntries = autoCorrectEntries
        } else {
            filteredEntries = autoCorrectEntries.filter {
                $0.replace.localizedCaseInsensitiveContains(query) || $0.with.contains(query)
            }
        }
        autoCorrectTable.reloadData()
        updateCountLabel()
    }

    private func updateCountLabel() {
        countLabel.stringValue = "\(filteredEntries.count) Items"
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
        filteredEntries.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn else { return nil }
        let entry = filteredEntries[row]
        let text = tableColumn.identifier.rawValue == "replace" ? entry.replace : entry.with

        let identifier = NSUserInterfaceItemIdentifier("cell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView ?? {
            let cell = NSTableCellView()
            cell.identifier = identifier
            let field = NSTextField(labelWithString: "")
            field.lineBreakMode = .byTruncatingTail
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
        return cell
    }
}
